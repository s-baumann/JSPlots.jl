"""
    LocalGaussianCorrelationPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Interactive visualization of Local Gaussian Correlation across the joint distribution of two variables.

Local Gaussian Correlation is a nonparametric measure that shows how correlation between two variables
varies across their joint distribution. Unlike global correlation (a single number), this shows that
variables might be strongly correlated in some regions but weakly or negatively correlated in others.

The chart displays:
1. **Main heatmap**: A 2D colored grid where each cell shows the local correlation at that (x, y) location
2. **Right margin**: Line showing average correlation integrated over x values (kernel density weighted)
3. **Bottom margin**: Line showing average correlation integrated over y values (kernel density weighted)

# Display Modes
- **Local Correlation**: Shows the correlation coefficient (-1 to 1) at each grid point
- **Bootstrap t-statistic**: Resamples data 200 times to estimate standard error, then displays t = ρ/SE.
  Values beyond ±1.96 indicate statistical significance at p < 0.05. Bootstrap is computed lazily
  (only when t-statistic mode is selected) to avoid unnecessary computation.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `dimensions::Vector{Symbol}`: Available columns for x and y axes (default: `[:x, :y]`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter columns with default values (default: `Dict{Symbol,Any}()`)
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
- `bandwidth::Union{Float64,Nothing}`: Bandwidth for local correlation kernel (default: automatic via Silverman's rule)
- `grid_size::Int`: Number of grid points in each dimension for the heatmap (default: `30`)
- `min_weight::Float64`: Minimum total kernel weight required at a grid point to compute correlation (default: `0.1`)
- `colorscale::String`: Plotly colorscale for correlation heatmap (default: `"RdBu"`)
- `title::String`: Chart title (default: `"Local Gaussian Correlation"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Theory
For each grid point (x₀, y₀), the local correlation is computed as:
1. Assign kernel weights: w_i = exp(-0.5 * ((X_i - x₀)/h)² - 0.5 * ((Y_i - y₀)/h)²)
2. Compute weighted correlation: ρ = cov_w(X, Y) / (σ_w(X) * σ_w(Y))

The marginal integration lines show the average local correlation at each x (or y) value,
weighted by the kernel density at that location.

# Examples
```julia
# Basic usage
lgc = LocalGaussianCorrelationPlot(:lgc_chart, df, :data,
    dimensions=[:returns, :volatility, :volume],
    title="Local Correlation Analysis"
)

# With filters
lgc = LocalGaussianCorrelationPlot(:lgc_filtered, df, :data,
    dimensions=[:x, :y],
    filters=[:category, :year],
    bandwidth=0.5,
    grid_size=40,
    title="Filtered Local Correlation"
)
```
"""
struct LocalGaussianCorrelationPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function LocalGaussianCorrelationPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                                          dimensions::Vector{Symbol}=[:x, :y],
                                          filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                                          choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                                          bandwidth::Union{Float64,Nothing}=nothing,
                                          grid_size::Int=30,
                                          min_weight::Float64=0.1,
                                          colorscale::String="RdBu",
                                          title::String="Local Gaussian Correlation",
                                          notes::String="")

        # Validate dimensions
        all_cols = names(df)
        for col in dimensions
            String(col) in all_cols || error("Dimension column $col not found in dataframe. Available: $all_cols")
        end

        if length(dimensions) < 2
            error("At least 2 dimension columns are required")
        end

        # Set defaults
        default_x_col = string(dimensions[1])
        default_y_col = string(dimensions[2])

        # Normalize filters and choices
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(string(chart_title), normalized_choices, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") *
                       join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")
        choices_html = join([generate_choice_dropdown_html(dd) for dd in choice_dropdowns], "\n")

        # Separate categorical and continuous filters for JavaScript
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]
        choice_cols = collect(keys(normalized_choices))

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)

        # Calculate automatic bandwidth if not provided
        bandwidth_js = if bandwidth !== nothing
            "const DEFAULT_BANDWIDTH = $bandwidth;"
        else
            "const DEFAULT_BANDWIDTH = null; // Auto-calculate"
        end

        # Build dimension options for dropdowns
        dim_options = join(["<option value=\"$col\"$(string(col) == default_x_col ? " selected" : "")>$col</option>"
                           for col in dimensions], "\n")
        dim_options_y = join(["<option value=\"$col\"$(string(col) == default_y_col ? " selected" : "")>$col</option>"
                             for col in dimensions], "\n")

        # Transform options (no cumulative)
        transform_options = ["identity", "log", "z_score", "quantile", "inverse_cdf"]
        transform_opts_html = join(["<option value=\"$opt\">$opt</option>" for opt in transform_options], "\n")

        functional_html = """
        (function() {
        // Filter configuration
        const CATEGORICAL_FILTERS = $categorical_filters_js;
        const CONTINUOUS_FILTERS = $continuous_filters_js;
        const CHOICE_FILTERS = $choice_filters_js;

        // Settings
        const GRID_SIZE = $grid_size;
        const MIN_WEIGHT = $min_weight;
        const COLORSCALE = '$colorscale';
        const BOOTSTRAP_ITERATIONS = 200;
        $bandwidth_js

        // Cache for bootstrap results (keyed by data hash)
        let bootstrapCache_$(chart_title) = null;
        let lastDataHash_$(chart_title) = null;

        const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };

        // Simple hash for data to detect changes
        function hashData(xData, yData, bandwidth) {
            const sample = xData.slice(0, 10).concat(yData.slice(0, 10));
            return sample.join(',') + ':' + xData.length + ':' + (bandwidth || 'auto');
        }

        // Kernel density function (Gaussian kernel)
        function gaussianKernel(dist, bandwidth) {
            return Math.exp(-0.5 * (dist / bandwidth) ** 2) / (bandwidth * Math.sqrt(2 * Math.PI));
        }

        // 2D Gaussian kernel weight
        function kernel2D(dx, dy, hx, hy) {
            return Math.exp(-0.5 * ((dx / hx) ** 2 + (dy / hy) ** 2));
        }

        // Compute local Gaussian correlation at a grid point
        function localCorrelation(xGrid, yGrid, xData, yData, hx, hy) {
            let sumW = 0, sumWX = 0, sumWY = 0;
            let sumWXX = 0, sumWYY = 0, sumWXY = 0;

            for (let i = 0; i < xData.length; i++) {
                const w = kernel2D(xData[i] - xGrid, yData[i] - yGrid, hx, hy);
                sumW += w;
                sumWX += w * xData[i];
                sumWY += w * yData[i];
            }

            if (sumW < MIN_WEIGHT) return null;

            const meanX = sumWX / sumW;
            const meanY = sumWY / sumW;

            for (let i = 0; i < xData.length; i++) {
                const w = kernel2D(xData[i] - xGrid, yData[i] - yGrid, hx, hy);
                const dx = xData[i] - meanX;
                const dy = yData[i] - meanY;
                sumWXX += w * dx * dx;
                sumWYY += w * dy * dy;
                sumWXY += w * dx * dy;
            }

            const varX = sumWXX / sumW;
            const varY = sumWYY / sumW;
            const covXY = sumWXY / sumW;

            if (varX <= 0 || varY <= 0) return null;

            const corr = covXY / Math.sqrt(varX * varY);
            return Math.max(-1, Math.min(1, corr));  // Clamp to [-1, 1]
        }

        // Compute kernel density at a point
        function kernelDensity1D(x, data, h) {
            let sum = 0;
            for (let i = 0; i < data.length; i++) {
                sum += gaussianKernel(x - data[i], h);
            }
            return sum / data.length;
        }

        // Silverman's rule for bandwidth
        function silvermanBandwidth(data) {
            const n = data.length;
            const mean = data.reduce((a, b) => a + b, 0) / n;
            const std = Math.sqrt(data.reduce((sum, x) => sum + (x - mean) ** 2, 0) / n);
            return 1.06 * std * Math.pow(n, -0.2);
        }

        // Bootstrap resampling - returns indices for a bootstrap sample
        function bootstrapIndices(n) {
            const indices = [];
            for (let i = 0; i < n; i++) {
                indices.push(Math.floor(Math.random() * n));
            }
            return indices;
        }

        // Compute local correlation on a grid for given data (used for bootstrap)
        function computeGridCorrelations(xData, yData, xGrid, yGrid, hx, hy) {
            const gridSize = xGrid.length;
            const zGrid = [];
            for (let j = 0; j < gridSize; j++) {
                const zRow = [];
                for (let i = 0; i < gridSize; i++) {
                    const corr = localCorrelation(xGrid[i], yGrid[j], xData, yData, hx, hy);
                    zRow.push(corr);
                }
                zGrid.push(zRow);
            }
            return zGrid;
        }

        // Compute bootstrap t-statistics
        function computeBootstrapTStats(xData, yData, xGrid, yGrid, hx, hy, originalZGrid, nBootstrap, progressCallback) {
            const gridSize = xGrid.length;
            const n = xData.length;

            // Store all bootstrap correlations for each grid point
            const bootstrapCorrs = [];
            for (let j = 0; j < gridSize; j++) {
                bootstrapCorrs.push([]);
                for (let i = 0; i < gridSize; i++) {
                    bootstrapCorrs[j].push([]);
                }
            }

            // Run bootstrap iterations
            for (let b = 0; b < nBootstrap; b++) {
                // Resample with replacement
                const indices = bootstrapIndices(n);
                const xBoot = indices.map(i => xData[i]);
                const yBoot = indices.map(i => yData[i]);

                // Compute correlations for this bootstrap sample
                const zBoot = computeGridCorrelations(xBoot, yBoot, xGrid, yGrid, hx, hy);

                // Store correlations
                for (let j = 0; j < gridSize; j++) {
                    for (let i = 0; i < gridSize; i++) {
                        if (zBoot[j][i] !== null) {
                            bootstrapCorrs[j][i].push(zBoot[j][i]);
                        }
                    }
                }

                // Progress callback
                if (progressCallback && b % 20 === 0) {
                    progressCallback(b / nBootstrap);
                }
            }

            // Compute t-statistics: t = corr / SE(corr)
            const tGrid = [];
            const seGrid = [];
            for (let j = 0; j < gridSize; j++) {
                const tRow = [];
                const seRow = [];
                for (let i = 0; i < gridSize; i++) {
                    const corrs = bootstrapCorrs[j][i];
                    const origCorr = originalZGrid[j][i];

                    if (origCorr === null || corrs.length < 10) {
                        tRow.push(null);
                        seRow.push(null);
                    } else {
                        // Compute standard error from bootstrap distribution
                        const mean = corrs.reduce((a, b) => a + b, 0) / corrs.length;
                        const variance = corrs.reduce((sum, c) => sum + (c - mean) ** 2, 0) / (corrs.length - 1);
                        const se = Math.sqrt(variance);

                        seRow.push(se);

                        if (se > 0.001) {
                            // t-statistic: original correlation / bootstrap SE
                            const t = origCorr / se;
                            tRow.push(t);
                        } else {
                            // SE too small, correlation is very stable
                            tRow.push(origCorr > 0 ? 10 : (origCorr < 0 ? -10 : 0));
                        }
                    }
                }
                tGrid.push(tRow);
                seGrid.push(seRow);
            }

            return { tGrid, seGrid };
        }

        // Main computation function
        function computeLocalCorrelation(xData, yData, gridSize, bandwidth) {
            const xMin = Math.min(...xData);
            const xMax = Math.max(...xData);
            const yMin = Math.min(...yData);
            const yMax = Math.max(...yData);

            // Extend grid slightly beyond data range
            const xPad = (xMax - xMin) * 0.05;
            const yPad = (yMax - yMin) * 0.05;
            const xRange = [xMin - xPad, xMax + xPad];
            const yRange = [yMin - yPad, yMax + yPad];

            // Compute bandwidth using Silverman's rule if not specified
            const hx = bandwidth || silvermanBandwidth(xData);
            const hy = bandwidth || silvermanBandwidth(yData);

            // Create grid
            const xStep = (xRange[1] - xRange[0]) / (gridSize - 1);
            const yStep = (yRange[1] - yRange[0]) / (gridSize - 1);

            const xGrid = [];
            const yGrid = [];
            const zGrid = [];  // Local correlation values
            const densityGrid = [];  // Kernel density values

            for (let i = 0; i < gridSize; i++) {
                xGrid.push(xRange[0] + i * xStep);
            }
            for (let j = 0; j < gridSize; j++) {
                yGrid.push(yRange[0] + j * yStep);
            }

            // Compute local correlation and density at each grid point
            for (let j = 0; j < gridSize; j++) {
                const zRow = [];
                const densityRow = [];
                for (let i = 0; i < gridSize; i++) {
                    const corr = localCorrelation(xGrid[i], yGrid[j], xData, yData, hx, hy);
                    zRow.push(corr);

                    // Compute 2D kernel density at this point
                    let density = 0;
                    for (let k = 0; k < xData.length; k++) {
                        density += kernel2D(xData[k] - xGrid[i], yData[k] - yGrid[j], hx, hy);
                    }
                    densityRow.push(density / xData.length);
                }
                zGrid.push(zRow);
                densityGrid.push(densityRow);
            }

            // Compute marginal integrations (kernel-density weighted)
            // For each y value, average correlation over all x values, weighted by density
            const marginalY = [];  // Average correlation for each y
            const marginalYDensity = [];  // Density at each y for weighting
            for (let j = 0; j < gridSize; j++) {
                let sumCorr = 0, sumDensity = 0;
                for (let i = 0; i < gridSize; i++) {
                    if (zGrid[j][i] !== null) {
                        sumCorr += zGrid[j][i] * densityGrid[j][i];
                        sumDensity += densityGrid[j][i];
                    }
                }
                marginalY.push(sumDensity > 0 ? sumCorr / sumDensity : null);
                marginalYDensity.push(kernelDensity1D(yGrid[j], yData, hy));
            }

            // For each x value, average correlation over all y values, weighted by density
            const marginalX = [];  // Average correlation for each x
            const marginalXDensity = [];  // Density at each x for weighting
            for (let i = 0; i < gridSize; i++) {
                let sumCorr = 0, sumDensity = 0;
                for (let j = 0; j < gridSize; j++) {
                    if (zGrid[j][i] !== null) {
                        sumCorr += zGrid[j][i] * densityGrid[j][i];
                        sumDensity += densityGrid[j][i];
                    }
                }
                marginalX.push(sumDensity > 0 ? sumCorr / sumDensity : null);
                marginalXDensity.push(kernelDensity1D(xGrid[i], xData, hx));
            }

            return {
                xGrid, yGrid, zGrid, densityGrid,
                marginalX, marginalY, marginalXDensity, marginalYDensity,
                bandwidth: { x: hx, y: hy },
                xData, yData  // Store for bootstrap
            };
        }

        // Compute marginals for t-statistics
        function computeTStatMarginals(tGrid, densityGrid, gridSize) {
            const marginalY = [];
            for (let j = 0; j < gridSize; j++) {
                let sumT = 0, sumDensity = 0;
                for (let i = 0; i < gridSize; i++) {
                    if (tGrid[j][i] !== null) {
                        sumT += tGrid[j][i] * densityGrid[j][i];
                        sumDensity += densityGrid[j][i];
                    }
                }
                marginalY.push(sumDensity > 0 ? sumT / sumDensity : null);
            }

            const marginalX = [];
            for (let i = 0; i < gridSize; i++) {
                let sumT = 0, sumDensity = 0;
                for (let j = 0; j < gridSize; j++) {
                    if (tGrid[j][i] !== null) {
                        sumT += tGrid[j][i] * densityGrid[j][i];
                        sumDensity += densityGrid[j][i];
                    }
                }
                marginalX.push(sumDensity > 0 ? sumT / sumDensity : null);
            }

            return { marginalX, marginalY };
        }

        function renderPlot(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM, displayMode) {
            const isTStat = displayMode === 'tstat';

            // Determine which z values and marginals to display
            let zValues, marginalX, marginalY, colorbarTitle, zmin, zmax, hoverLabel;

            if (isTStat && result.tGrid) {
                zValues = result.tGrid;
                const tMarginals = computeTStatMarginals(result.tGrid, result.densityGrid, GRID_SIZE);
                marginalX = tMarginals.marginalX;
                marginalY = tMarginals.marginalY;
                colorbarTitle = 't-statistic';
                // Use symmetric range centered at 0, cap at ±5 for better visualization
                const maxAbsT = Math.min(5, Math.max(...zValues.flat().filter(v => v !== null).map(Math.abs)));
                zmin = -maxAbsT;
                zmax = maxAbsT;
                hoverLabel = 't';
            } else {
                zValues = result.zGrid;
                marginalX = result.marginalX;
                marginalY = result.marginalY;
                colorbarTitle = 'Local Correlation';
                zmin = -1;
                zmax = 1;
                hoverLabel = 'ρ';
            }

            // Create heatmap trace
            const heatmapTrace = {
                x: result.xGrid,
                y: result.yGrid,
                z: zValues,
                type: 'heatmap',
                colorscale: COLORSCALE,
                reversescale: true,  // Reversed: red=negative, blue=positive
                zmin: zmin,
                zmax: zmax,
                colorbar: {
                    title: colorbarTitle,
                    orientation: 'h',
                    x: 0.4,
                    y: 1.12,
                    xanchor: 'center',
                    len: 0.6,
                    thickness: 15
                },
                xaxis: 'x',
                yaxis: 'y',
                hovertemplate: 'X: %{x:.3f}<br>Y: %{y:.3f}<br>' + hoverLabel + ': %{z:.3f}<extra></extra>'
            };

            // Create scatter plot of actual data points
            const scatterTrace = {
                x: xData,
                y: yData,
                mode: 'markers',
                type: 'scatter',
                marker: {
                    size: 3,
                    color: 'rgba(0, 0, 0, 0.3)'
                },
                xaxis: 'x',
                yaxis: 'y',
                showlegend: false,
                hoverinfo: 'skip'
            };

            // Create marginal Y line (right side)
            const marginalYTrace = {
                x: marginalY.map(v => v !== null ? v : NaN),
                y: result.yGrid,
                type: 'scatter',
                mode: 'lines',
                line: { color: '#2ca02c', width: 2 },
                xaxis: 'x2',
                yaxis: 'y',
                showlegend: false,
                name: 'Avg ' + hoverLabel + ' (over X)',
                hovertemplate: 'Y: %{y:.3f}<br>Avg ' + hoverLabel + ': %{x:.3f}<extra></extra>'
            };

            // Create marginal X line (bottom)
            const marginalXTrace = {
                x: result.xGrid,
                y: marginalX.map(v => v !== null ? v : NaN),
                type: 'scatter',
                mode: 'lines',
                line: { color: '#d62728', width: 2 },
                xaxis: 'x',
                yaxis: 'y2',
                showlegend: false,
                name: 'Avg ' + hoverLabel + ' (over Y)',
                hovertemplate: 'X: %{x:.3f}<br>Avg ' + hoverLabel + ': %{y:.3f}<extra></extra>'
            };

            // Reference lines at 0
            const zeroLineY = {
                x: [0, 0],
                y: [result.yGrid[0], result.yGrid[result.yGrid.length - 1]],
                type: 'scatter',
                mode: 'lines',
                line: { color: '#999', width: 1, dash: 'dash' },
                xaxis: 'x2',
                yaxis: 'y',
                showlegend: false,
                hoverinfo: 'skip'
            };

            const zeroLineX = {
                x: [result.xGrid[0], result.xGrid[result.xGrid.length - 1]],
                y: [0, 0],
                type: 'scatter',
                mode: 'lines',
                line: { color: '#999', width: 1, dash: 'dash' },
                xaxis: 'x',
                yaxis: 'y2',
                showlegend: false,
                hoverinfo: 'skip'
            };

            // Add significance threshold lines for t-stat mode
            const extraTraces = [];
            if (isTStat) {
                // Lines at t = ±1.96 (95% significance)
                extraTraces.push({
                    x: [1.96, 1.96],
                    y: [result.yGrid[0], result.yGrid[result.yGrid.length - 1]],
                    type: 'scatter',
                    mode: 'lines',
                    line: { color: '#ff7f0e', width: 1, dash: 'dot' },
                    xaxis: 'x2',
                    yaxis: 'y',
                    showlegend: false,
                    hoverinfo: 'skip'
                });
                extraTraces.push({
                    x: [-1.96, -1.96],
                    y: [result.yGrid[0], result.yGrid[result.yGrid.length - 1]],
                    type: 'scatter',
                    mode: 'lines',
                    line: { color: '#ff7f0e', width: 1, dash: 'dot' },
                    xaxis: 'x2',
                    yaxis: 'y',
                    showlegend: false,
                    hoverinfo: 'skip'
                });
                extraTraces.push({
                    x: [result.xGrid[0], result.xGrid[result.xGrid.length - 1]],
                    y: [1.96, 1.96],
                    type: 'scatter',
                    mode: 'lines',
                    line: { color: '#ff7f0e', width: 1, dash: 'dot' },
                    xaxis: 'x',
                    yaxis: 'y2',
                    showlegend: false,
                    hoverinfo: 'skip'
                });
                extraTraces.push({
                    x: [result.xGrid[0], result.xGrid[result.xGrid.length - 1]],
                    y: [-1.96, -1.96],
                    type: 'scatter',
                    mode: 'lines',
                    line: { color: '#ff7f0e', width: 1, dash: 'dot' },
                    xaxis: 'x',
                    yaxis: 'y2',
                    showlegend: false,
                    hoverinfo: 'skip'
                });
            }

            const xLabel = X_TRANSFORM === 'identity' ? X_COL : X_TRANSFORM + '(' + X_COL + ')';
            const yLabel = Y_TRANSFORM === 'identity' ? Y_COL : Y_TRANSFORM + '(' + Y_COL + ')';

            const marginalRange = isTStat ? [-5, 5] : [-1, 1];
            const marginalTitle = isTStat ? 'Avg t' : 'Avg ρ';

            const layout = {
                title: '$title' + (isTStat ? ' (t-statistic)' : ''),
                showlegend: false,
                autosize: true,
                margin: { t: 120, r: 120, b: 120, l: 80 },
                xaxis: {
                    title: xLabel,
                    domain: [0, 0.8],
                    showgrid: true,
                    zeroline: false
                },
                yaxis: {
                    title: yLabel,
                    domain: [0.2, 1],
                    showgrid: true,
                    zeroline: false
                },
                xaxis2: {
                    title: marginalTitle,
                    domain: [0.85, 1],
                    range: marginalRange,
                    showgrid: true,
                    zeroline: true
                },
                yaxis2: {
                    title: marginalTitle,
                    domain: [0, 0.15],
                    range: marginalRange,
                    showgrid: true,
                    zeroline: true
                },
                annotations: [
                    {
                        text: 'Integrated over X',
                        x: 0.925,
                        y: 1.05,
                        xref: 'paper',
                        yref: 'paper',
                        showarrow: false,
                        font: { size: 10, color: '#2ca02c' }
                    },
                    {
                        text: 'Integrated over Y',
                        x: 0.4,
                        y: -0.15,
                        xref: 'paper',
                        yref: 'paper',
                        showarrow: false,
                        font: { size: 10, color: '#d62728' }
                    }
                ]
            };

            // Add significance note for t-stat mode
            if (isTStat) {
                layout.annotations.push({
                    text: 'Orange dashed lines: |t| = 1.96 (p < 0.05)',
                    x: 0.5,
                    y: -0.22,
                    xref: 'paper',
                    yref: 'paper',
                    showarrow: false,
                    font: { size: 10, color: '#ff7f0e' }
                });
            }

            Plotly.newPlot('$chart_title',
                [heatmapTrace, scatterTrace, marginalYTrace, zeroLineY, marginalXTrace, zeroLineX, ...extraTraces],
                layout,
                { responsive: true }
            );
        }

        // Async function to compute bootstrap and update plot
        async function computeAndDisplayBootstrap(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM) {
            const statusEl = document.getElementById('$(chart_title)_bootstrap_status');
            const progressEl = document.getElementById('$(chart_title)_bootstrap_progress');

            if (statusEl) statusEl.textContent = 'Computing bootstrap...';
            if (progressEl) progressEl.style.width = '0%';

            // Use setTimeout to allow UI to update
            await new Promise(resolve => setTimeout(resolve, 50));

            const progressCallback = (progress) => {
                if (progressEl) progressEl.style.width = (progress * 100) + '%';
            };

            // Compute bootstrap t-statistics
            const { tGrid, seGrid } = computeBootstrapTStats(
                xData, yData,
                result.xGrid, result.yGrid,
                result.bandwidth.x, result.bandwidth.y,
                result.zGrid,
                BOOTSTRAP_ITERATIONS,
                progressCallback
            );

            // Store in result and cache
            result.tGrid = tGrid;
            result.seGrid = seGrid;
            bootstrapCache_$(chart_title) = result;

            if (statusEl) statusEl.textContent = 'Bootstrap complete (' + BOOTSTRAP_ITERATIONS + ' iterations)';
            if (progressEl) progressEl.style.width = '100%';

            // Render with t-stat
            renderPlot(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM, 'tstat');
        }

        function updatePlot_$(chart_title)(data) {
            const X_COL = getCol('x_col_select_$chart_title', '$default_x_col');
            const Y_COL = getCol('y_col_select_$chart_title', '$default_y_col');
            const X_TRANSFORM = getCol('x_transform_select_$chart_title', 'identity');
            const Y_TRANSFORM = getCol('y_transform_select_$chart_title', 'identity');
            const displayMode = getCol('$(chart_title)_display_mode', 'correlation');

            // Extract and transform data
            const validPairs = [];
            for (let i = 0; i < data.length; i++) {
                const x = parseFloat(data[i][X_COL]);
                const y = parseFloat(data[i][Y_COL]);
                if (!isNaN(x) && !isNaN(y)) {
                    validPairs.push({ x, y });
                }
            }

            if (validPairs.length < 10) {
                document.getElementById('$chart_title').innerHTML =
                    '<p style="color: red; padding: 20px;">Need at least 10 valid data points for local correlation analysis.</p>';
                return;
            }

            let xData = validPairs.map(p => p.x);
            let yData = validPairs.map(p => p.y);

            // Apply transforms
            let xTransformed = applyAxisTransform(xData, X_TRANSFORM);
            let yTransformed = applyAxisTransform(yData, Y_TRANSFORM);

            // Filter out NaN pairs after transformation
            const transformedPairs = [];
            for (let i = 0; i < xTransformed.length; i++) {
                if (!isNaN(xTransformed[i]) && isFinite(xTransformed[i]) &&
                    !isNaN(yTransformed[i]) && isFinite(yTransformed[i])) {
                    transformedPairs.push({ x: xTransformed[i], y: yTransformed[i] });
                }
            }

            if (transformedPairs.length < 10) {
                document.getElementById('$chart_title').innerHTML =
                    '<p style="color: red; padding: 20px;">Need at least 10 valid data points after transformation. Try a different transform.</p>';
                return;
            }

            xData = transformedPairs.map(p => p.x);
            yData = transformedPairs.map(p => p.y);

            // Get bandwidth from slider (0 means auto)
            const bwSlider = document.getElementById('$(chart_title)_bandwidth_slider');
            const bw = bwSlider ? parseFloat(bwSlider.value) : 0;
            const actualBandwidth = bw > 0 ? bw : null;

            // Check if we need to recompute or can use cache
            const dataHash = hashData(xData, yData, actualBandwidth);
            let result;

            if (dataHash === lastDataHash_$(chart_title) && bootstrapCache_$(chart_title)) {
                // Use cached result
                result = bootstrapCache_$(chart_title);
            } else {
                // Compute fresh local correlation
                result = computeLocalCorrelation(xData, yData, GRID_SIZE, actualBandwidth);
                lastDataHash_$(chart_title) = dataHash;
                bootstrapCache_$(chart_title) = null;  // Invalidate bootstrap cache
            }

            // Update bandwidth display
            const bwLabel = document.getElementById('$(chart_title)_bandwidth_label');
            if (bwLabel) {
                bwLabel.textContent = result.bandwidth.x.toFixed(3);
            }

            // Reset bootstrap status if cache was invalidated
            const statusEl = document.getElementById('$(chart_title)_bootstrap_status');
            const progressEl = document.getElementById('$(chart_title)_bootstrap_progress');
            if (!bootstrapCache_$(chart_title) || !bootstrapCache_$(chart_title).tGrid) {
                if (statusEl) statusEl.textContent = 'Not computed';
                if (progressEl) progressEl.style.width = '0%';
            }

            // If t-stat mode requested and not cached, compute bootstrap
            if (displayMode === 'tstat') {
                if (result.tGrid) {
                    // Already have bootstrap results
                    renderPlot(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM, 'tstat');
                } else {
                    // Need to compute bootstrap - show correlation first, then compute
                    renderPlot(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM, 'correlation');
                    computeAndDisplayBootstrap(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM);
                }
            } else {
                // Correlation mode
                renderPlot(result, xData, yData, X_COL, Y_COL, X_TRANSFORM, Y_TRANSFORM, 'correlation');
            }
        }

        window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();

        // Filter and update function
        window.updatePlotWithFilters_$(chart_title) = function() {
            // Get choice values (single selections)
            const choices = {};
            CHOICE_FILTERS.forEach(col => {
                const select = document.getElementById(col + '_choice_$(chart_title)');
                if (select) {
                    choices[col] = select.value;
                }
            });

            // Get categorical filter values (multiple selections)
            const filters = {};
            CATEGORICAL_FILTERS.forEach(col => {
                const select = document.getElementById(col + '_select_$(chart_title)');
                if (select) {
                    filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                }
            });

            // Get continuous filter values (range sliders)
            const rangeFilters = {};
            CONTINUOUS_FILTERS.forEach(col => {
                const slider = \$('#' + col + '_range_$(chart_title)' + '_slider');
                if (slider.length > 0) {
                    rangeFilters[col] = {
                        min: slider.slider("values", 0),
                        max: slider.slider("values", 1)
                    };
                }
            });

            // Apply filters with observation counting
            const filteredData = applyFiltersWithCounting(
                window.allData_$(chart_title),
                '$chart_title',
                CATEGORICAL_FILTERS,
                CONTINUOUS_FILTERS,
                filters,
                rangeFilters,
                CHOICE_FILTERS,
                choices
            );

            // Update plot with filtered data
            updatePlot_$(chart_title)(filteredData);
        };

        loadDataset('$data_label').then(data => {
            window.allData_$(chart_title) = data;
            \$(function() {
                // Setup bandwidth slider
                document.getElementById('$(chart_title)_bandwidth_slider').addEventListener('input', function() {
                    var bw = parseFloat(this.value);
                    document.getElementById('$(chart_title)_bandwidth_label').textContent = bw === 0 ? 'auto' : bw.toFixed(3);
                    // Invalidate cache when bandwidth changes
                    bootstrapCache_$(chart_title) = null;
                    lastDataHash_$(chart_title) = null;
                    updateChart_$(chart_title)();
                });

                // Setup display mode selector
                document.getElementById('$(chart_title)_display_mode').addEventListener('change', function() {
                    updateChart_$(chart_title)();
                });

                updatePlotWithFilters_$(chart_title)();

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title');
            });
        }).catch(error => console.error('Error loading data for chart $chart_title:', error));
        })();
        """

        # Build plot attributes HTML
        plot_attributes_html = """
        <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Display Mode</h4>
        <div style="display: flex; gap: 15px; flex-wrap: wrap; align-items: center;">
            <div>
                <label for="$(chart_title)_display_mode">Show: </label>
                <select id="$(chart_title)_display_mode" style="padding: 5px 10px;">
                    <option value="correlation" selected>Local Correlation</option>
                    <option value="tstat">Bootstrap t-statistic</option>
                </select>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
                <span style="color: #666; font-size: 0.85em;">Bootstrap: </span>
                <span id="$(chart_title)_bootstrap_status" style="font-size: 0.85em; color: #666;">Not computed</span>
                <div style="width: 100px; height: 6px; background: #e0e0e0; border-radius: 3px; overflow: hidden;">
                    <div id="$(chart_title)_bootstrap_progress" style="width: 0%; height: 100%; background: #4CAF50; transition: width 0.2s;"></div>
                </div>
            </div>
        </div>

        <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Axes</h4>
        <div style="display: flex; gap: 15px; flex-wrap: wrap; align-items: center;">
            <div>
                <label for="x_col_select_$chart_title">X: </label>
                <select id="x_col_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                    $dim_options
                </select>
            </div>
            <div>
                <label for="x_transform_select_$chart_title">X Transform: </label>
                <select id="x_transform_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                    $transform_opts_html
                </select>
            </div>
            <div>
                <label for="y_col_select_$chart_title">Y: </label>
                <select id="y_col_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                    $dim_options_y
                </select>
            </div>
            <div>
                <label for="y_transform_select_$chart_title">Y Transform: </label>
                <select id="y_transform_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                    $transform_opts_html
                </select>
            </div>
        </div>

        <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Bandwidth</h4>
        <div style="display: flex; gap: 10px; align-items: center;">
            <label for="$(chart_title)_bandwidth_slider">Kernel Bandwidth: </label>
            <span id="$(chart_title)_bandwidth_label">auto</span>
            <input type="range" id="$(chart_title)_bandwidth_slider"
                   min="0" max="3" step="0.01" value="0"
                   style="width: 50%;">
            <span style="color: #666; font-size: 0.9em;">(0 = auto)</span>
        </div>

        <div style="margin-top: 15px; padding: 12px; background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 5px; font-size: 0.9em;">
            <h5 style="margin: 0 0 10px 0; color: #495057;">About Local Gaussian Correlation</h5>
            <p style="margin: 5px 0;">
                Local Gaussian Correlation shows how the correlation between two variables varies across their joint distribution.
                The <strong>heatmap</strong> displays the local correlation at each (x, y) point, computed using a Gaussian kernel
                to weight nearby observations.
            </p>
            <p style="margin: 5px 0;">
                The <strong style="color: #2ca02c;">green line</strong> on the right shows the average correlation at each Y value
                (integrated over X), weighted by the kernel density.
                The <strong style="color: #d62728;">red line</strong> at the bottom shows the average correlation at each X value
                (integrated over Y).
            </p>
            <p style="margin: 5px 0;">
                <strong>Blue</strong> = positive, <strong>Red</strong> = negative, <strong>White</strong> = zero.
            </p>
            <p style="margin: 5px 0;">
                <strong>Bootstrap t-statistic</strong>: Resamples the data 200 times to estimate the standard error of the local correlation.
                The t-statistic (correlation / SE) indicates statistical significance. Values beyond ±1.96 are significant at p &lt; 0.05.
            </p>
        </div>
        """

        # Generate appearance HTML
        appearance_html = generate_appearance_html_from_sections(
            filters_html,
            plot_attributes_html,
            "",  # No faceting for this chart
            title,
            notes,
            string(chart_title);
            choices_html=choices_html,
            aspect_ratio_default=1.0
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::LocalGaussianCorrelationPlot) = [a.data_label]
js_dependencies(::LocalGaussianCorrelationPlot) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
