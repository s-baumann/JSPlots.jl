"""
    Scatter3D(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol}; kwargs...)

Three-dimensional scatter plot with PCA eigenvectors and interactive filtering.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary
- `dimensions::Vector{Symbol}`: Vector of at least 3 dimension columns for x, y, and z axes

# Keyword Arguments
- `color_cols`: Columns for color grouping. Can be:
  - `Vector{Symbol}`: `[:col1, :col2]` - uses default palette
  - `Vector{Tuple}`: `[(:col1, :default), (:col2, Dict(:val => "#hex"))]` - with custom colors
  - For continuous: `[(:col, Dict(0 => "#000", 1 => "#fff"))]` - interpolates between stops
  (default: `[:color]`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `show_eigenvectors::Bool`: Display PCA eigenvectors (default: `true`)
- `shared_camera::Bool`: Synchronize camera view across facets (default: `true`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points (default: `0.6`)
- `title::String`: Chart title (default: `"3D Scatter Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
scatter = Scatter3D(:scatter_3d, df, :data, [:x, :y, :z],
    color_cols=[:category],
    show_eigenvectors=true,
    marker_size=6,
    title="3D Point Cloud"
)
```
"""
struct Scatter3D <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function Scatter3D(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol};
                          color_cols::ColorColSpec=[:color],
                          filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                          choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                          facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          show_eigenvectors::Bool=true,
                          shared_camera::Bool=true,
                          marker_size::Int=4,
                          marker_opacity::Float64=0.6,
                          title::String="3D Scatter Plot",
                          notes::String="")

# Normalize filters and choices to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)
normalized_choices = normalize_choices(choices, df)

        # Sanitize chart_title for use in JavaScript function names
        chart_title_safe = sanitize_chart_title(chart_title)

        all_cols = names(df)

        # Validate dimensions
        length(dimensions) >= 3 || error("dimensions must contain at least 3 columns for x, y, z axes")
        for col in dimensions
            String(col) in all_cols || error("Dimension column $col not found in dataframe. Available: $all_cols")
        end

        # Defaults for x, y, z
        default_x_col = string(dimensions[1])
        default_y_col = string(dimensions[2])
        default_z_col = string(dimensions[3])

        # Validate color columns and build color maps
        color_col_names = extract_color_col_names(color_cols)
        valid_color_cols = validate_and_filter_columns(color_col_names, df, "color_cols")
        default_color_col = string(valid_color_cols[1])
        color_maps, color_scales, _ = build_color_maps_extended(color_cols, df)
        color_maps_js = JSON.json(color_maps)
        color_scales_js = build_color_scales_js(color_scales)

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)
        for col in facet_choices
            String(col) in all_cols || error("Facet column $col not found in dataframe. Available: $all_cols")
        end

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title_safe)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title_safe), normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(string(chart_title_safe), normalized_choices, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") * join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")
        choices_html = join([generate_choice_dropdown_html(dd) for dd in choice_dropdowns], "\n")

        # Helper function to build dropdown HTML
        build_dropdown(id, label, cols, default_value, onchange_fn) = begin
            length(cols) <= 1 && return ""
            options = join(["                    <option value=\"$col\"$((string(col) == default_value) ? " selected" : "")>$col</option>"
                           for col in cols], "\n")
            """
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="$(id)">$label:</label>
                    <select id="$(id)" onchange="$onchange_fn">
$options                </select>
                </div>
            """
        end

        # Build plot attributes section
        plot_attributes_html = """
        <div style="margin: 10px 0; display: flex; gap: 10px; align-items: center;">
            <button id="$(chart_title_safe)_eigenvector_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_eigenvectors ? "Hide" : "Show") Eigenvectors
            </button>
        </div>
        """

        # Style dropdown (color only)
        style_html = build_dropdown("$(chart_title_safe)_color_col_select", "Color", valid_color_cols, default_color_col, "updatePlotWithFilters_$(chart_title_safe)()")
        if !isempty(style_html)
            plot_attributes_html *= """<div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
$style_html        </div>
"""
        end

        # Build axis controls HTML (X, Y, and Z dimensions + transforms)
        # Scatter3D uses both X and Y transforms, but NOT cumulative/cumprod
        axes_html = build_axis_controls_html(
            string(chart_title_safe),
            "updatePlotWithFilters_$(chart_title_safe)()";
            x_cols = dimensions,
            y_cols = dimensions,
            z_cols = dimensions,
            default_x = Symbol(default_x_col),
            default_y = Symbol(default_y_col),
            default_z = Symbol(default_z_col),
            include_x_transform = true,
            include_y_transform = true,
            include_cumulative = false
        )
        plot_attributes_html *= axes_html

        # Generate faceting section using html_controls abstraction
        faceting_html = generate_facet_dropdowns_html(
            string(chart_title_safe),
            facet_choices,
            default_facet_array,
            "updatePlotWithFilters_$chart_title()"
        )

        # Generate filter controls JS arrays
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        choice_cols = collect(keys(normalized_choices))
        choice_filters_js = build_js_array(choice_cols)


        functional_html = """
            (function() {
            window.showEigenvectors_$(chart_title_safe) = $(show_eigenvectors ? "true" : "false");
            window.sharedCamera_$(chart_title_safe) = $(shared_camera ? "true" : "false");
            window.currentCamera_$(chart_title_safe) = null;
            const FILTER_COLS = $filter_cols_js;
            const CHOICE_FILTERS = $choice_filters_js;
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_Z_COL = '$default_z_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;
            $JS_COLOR_INTERPOLATION

            const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };

            // Eigenvector toggle
            document.getElementById('$(chart_title_safe)_eigenvector_toggle').addEventListener('click', function() {
                window.showEigenvectors_$(chart_title_safe) = !window.showEigenvectors_$(chart_title_safe);
                this.textContent = window.showEigenvectors_$(chart_title_safe) ? 'Hide Eigenvectors' : 'Show Eigenvectors';
                updatePlotWithFilters_$(chart_title_safe)();
            });

            function computeEigenvectors(data, X_COL, Y_COL, Z_COL) {
                // Extract numeric data and filter out invalid values
                const validIndices = [];
                const xs = [];
                const ys = [];
                const zs = [];

                data.forEach((row, idx) => {
                    const x = parseFloat(row[X_COL]);
                    const y = parseFloat(row[Y_COL]);
                    const z = parseFloat(row[Z_COL]);

                    // Only include if all three values are valid numbers
                    if (!isNaN(x) && isFinite(x) && !isNaN(y) && isFinite(y) && !isNaN(z) && isFinite(z)) {
                        xs.push(x);
                        ys.push(y);
                        zs.push(z);
                        validIndices.push(idx);
                    }
                });

                // Check if we have enough valid points
                if (xs.length < 3) {
                    return null;  // Not enough valid points for eigenvector computation
                }

                // Compute means
                const meanX = xs.reduce((a, b) => a + b, 0) / xs.length;
                const meanY = ys.reduce((a, b) => a + b, 0) / ys.length;
                const meanZ = zs.reduce((a, b) => a + b, 0) / zs.length;

                // Center the data
                const centeredX = xs.map(x => x - meanX);
                const centeredY = ys.map(y => y - meanY);
                const centeredZ = zs.map(z => z - meanZ);

                // Compute covariance matrix
                const n = xs.length;
                const cov = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];

                for (let i = 0; i < n; i++) {
                    cov[0][0] += centeredX[i] * centeredX[i];
                    cov[0][1] += centeredX[i] * centeredY[i];
                    cov[0][2] += centeredX[i] * centeredZ[i];
                    cov[1][0] += centeredY[i] * centeredX[i];
                    cov[1][1] += centeredY[i] * centeredY[i];
                    cov[1][2] += centeredY[i] * centeredZ[i];
                    cov[2][0] += centeredZ[i] * centeredX[i];
                    cov[2][1] += centeredZ[i] * centeredY[i];
                    cov[2][2] += centeredZ[i] * centeredZ[i];
                }

                for (let i = 0; i < 3; i++) {
                    for (let j = 0; j < 3; j++) {
                        cov[i][j] /= n;
                    }
                }

                // Power iteration for first eigenvector
                let v1 = [1, 0, 0];
                for (let iter = 0; iter < 20; iter++) {
                    const newV = [
                        cov[0][0] * v1[0] + cov[0][1] * v1[1] + cov[0][2] * v1[2],
                        cov[1][0] * v1[0] + cov[1][1] * v1[1] + cov[1][2] * v1[2],
                        cov[2][0] * v1[0] + cov[2][1] * v1[1] + cov[2][2] * v1[2]
                    ];
                    const norm = Math.sqrt(newV[0]**2 + newV[1]**2 + newV[2]**2);
                    v1 = [newV[0]/norm, newV[1]/norm, newV[2]/norm];
                }

                // Second eigenvector (orthogonal to first)
                let v2 = [0, 1, 0];
                const dot12 = v2[0]*v1[0] + v2[1]*v1[1] + v2[2]*v1[2];
                v2 = [v2[0] - dot12*v1[0], v2[1] - dot12*v1[1], v2[2] - dot12*v1[2]];
                const norm2 = Math.sqrt(v2[0]**2 + v2[1]**2 + v2[2]**2);
                v2 = [v2[0]/norm2, v2[1]/norm2, v2[2]/norm2];

                // Third eigenvector (cross product)
                const v3 = [
                    v1[1]*v2[2] - v1[2]*v2[1],
                    v1[2]*v2[0] - v1[0]*v2[2],
                    v1[0]*v2[1] - v1[1]*v2[0]
                ];

                // Compute data ranges for normalization
                const xRange = Math.max(...xs) - Math.min(...xs);
                const yRange = Math.max(...ys) - Math.min(...ys);
                const zRange = Math.max(...zs) - Math.min(...zs);
                const fixedScale = Math.min(xRange, yRange, zRange) * 0.3;

                return {
                    center: [meanX, meanY, meanZ],
                    vectors: [v1, v2, v3],
                    scale: fixedScale,
                    ranges: [xRange, yRange, zRange]
                };
            }

            function createEigenvectorTraces(eigData, sceneId) {
                const traces = [];
                const colors = ['red', 'green', 'blue'];
                const [cx, cy, cz] = eigData.center;
                const [xRange, yRange, zRange] = eigData.ranges;

                eigData.vectors.forEach((vec, idx) => {
                    // Normalize vector components by their axis ranges for visual consistency
                    const normalized = [
                        vec[0] / xRange,
                        vec[1] / yRange,
                        vec[2] / zRange
                    ];

                    // Renormalize to unit length in normalized space
                    const norm = Math.sqrt(normalized[0]**2 + normalized[1]**2 + normalized[2]**2);
                    const unit = [
                        normalized[0] / norm,
                        normalized[1] / norm,
                        normalized[2] / norm
                    ];

                    // Scale back to data space for display
                    const display = [
                        unit[0] * xRange * eigData.scale / Math.min(xRange, yRange, zRange),
                        unit[1] * yRange * eigData.scale / Math.min(xRange, yRange, zRange),
                        unit[2] * zRange * eigData.scale / Math.min(xRange, yRange, zRange)
                    ];

                    traces.push({
                        x: [cx, cx + display[0]],
                        y: [cy, cy + display[1]],
                        z: [cz, cz + display[2]],
                        mode: 'lines+markers',
                        type: 'scatter3d',
                        name: \`PC\${idx + 1}\`,
                        legendgroup: \`PC\${idx + 1}\`,
                        scene: sceneId,
                        line: { color: colors[idx], width: 6 },
                        marker: { size: 6, symbol: 'diamond' },
                        showlegend: idx === 0 || sceneId === 'scene'
                    });
                });

                return traces;
            }

            function updateChart_$(chart_title_safe)(dataOverride) {
                const data = dataOverride || window.allData_$(chart_title_safe);
                const X_COL = getCol('$(chart_title_safe)_x_col_select', DEFAULT_X_COL);
                const Y_COL = getCol('$(chart_title_safe)_y_col_select', DEFAULT_Y_COL);
                const Z_COL = getCol('$(chart_title_safe)_z_col_select', DEFAULT_Z_COL);
                const COLOR_COL = getCol('$(chart_title_safe)_color_col_select', DEFAULT_COLOR_COL);

                // Get current axis transformations
                const X_TRANSFORM = getCol('x_transform_select_$(chart_title_safe)', 'identity');
                const Y_TRANSFORM = getCol('y_transform_select_$(chart_title_safe)', 'identity');
                const Z_TRANSFORM = getCol('z_transform_select_$(chart_title_safe)', 'identity');

                const { facet1: FACET1_COL, facet2: FACET2_COL } = readFacetSelections('$(chart_title_safe)');

                if (!FACET1_COL && !FACET2_COL) {
                    renderNoFacets_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                } else if (FACET1_COL && !FACET2_COL) {
                    renderFacetWrap_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET1_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                } else if (FACET1_COL && FACET2_COL) {
                    renderFacetGrid_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET1_COL, FACET2_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                } else {
                    renderFacetWrap_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET2_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                }
            }

            function renderNoFacets_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM) {
                const groups = {};
                data.forEach(row => {
                    const key = row[COLOR_COL];
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(row);
                });

                const traces = Object.entries(groups).map(([key, groupData]) => {
                    let xValues = groupData.map(d => parseFloat(d[X_COL]));
                    let yValues = groupData.map(d => parseFloat(d[Y_COL]));
                    let zValues = groupData.map(d => parseFloat(d[Z_COL]));

                    // Apply axis transformations
                    xValues = applyAxisTransform(xValues, X_TRANSFORM);
                    yValues = applyAxisTransform(yValues, Y_TRANSFORM);
                    zValues = applyAxisTransform(zValues, Z_TRANSFORM);

                    return {
                        x: xValues,
                        y: yValues,
                        z: zValues,
                        mode: 'markers',
                        name: key,
                        type: 'scatter3d',
                        marker: {
                            size: $marker_size,
                            opacity: $marker_opacity,
                            color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, key)
                        }
                    };
                });

                if (window.showEigenvectors_$(chart_title_safe) && data.length > 3) {
                    // Compute eigenvectors on transformed data
                    // First, extract and transform all data points
                    let allXValues = data.map(d => parseFloat(d[X_COL]));
                    let allYValues = data.map(d => parseFloat(d[Y_COL]));
                    let allZValues = data.map(d => parseFloat(d[Z_COL]));

                    allXValues = applyAxisTransform(allXValues, X_TRANSFORM);
                    allYValues = applyAxisTransform(allYValues, Y_TRANSFORM);
                    allZValues = applyAxisTransform(allZValues, Z_TRANSFORM);

                    // Create transformed data for eigenvector computation
                    const transformedData = data.map((row, i) => ({
                        [X_COL]: allXValues[i],
                        [Y_COL]: allYValues[i],
                        [Z_COL]: allZValues[i]
                    }));

                    const eigData = computeEigenvectors(transformedData, X_COL, Y_COL, Z_COL);
                    if (eigData !== null) {
                        traces.push(...createEigenvectorTraces(eigData, 'scene'));
                    }
                }

                const layout = {
                    title: '$title',
                    autosize: true,
                    showlegend: true,
                    scene: {
                        xaxis: { title: getAxisLabel(X_COL, X_TRANSFORM) },
                        yaxis: { title: getAxisLabel(Y_COL, Y_TRANSFORM) },
                        zaxis: { title: getAxisLabel(Z_COL, Z_TRANSFORM) },
                        camera: window.currentCamera_$(chart_title_safe) || undefined
                    },
                    margin: { t: 50, r: 50, b: 50, l: 50 }
                };

                Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});

                // Store current camera
                const plotDiv = document.getElementById('$(chart_title_safe)');
                plotDiv.on('plotly_relayout', (eventData) => {
                    if (eventData['scene.camera']) {
                        window.currentCamera_$(chart_title_safe) = eventData['scene.camera'];
                    }
                });
            }

            function renderFacetWrap_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM) {
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const nFacets = facetValues.length;
                const cols = Math.ceil(Math.sqrt(nFacets));
                const rows = Math.ceil(nFacets / cols);

                const traces = [];

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);
                    const sceneId = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                    const groups = {};
                    facetData.forEach(row => {
                        const key = row[COLOR_COL];
                        if (!groups[key]) groups[key] = [];
                        groups[key].push(row);
                    });

                    Object.entries(groups).forEach(([key, groupData]) => {
                        let xValues = groupData.map(d => parseFloat(d[X_COL]));
                        let yValues = groupData.map(d => parseFloat(d[Y_COL]));
                        let zValues = groupData.map(d => parseFloat(d[Z_COL]));

                        // Apply axis transformations
                        xValues = applyAxisTransform(xValues, X_TRANSFORM);
                        yValues = applyAxisTransform(yValues, Y_TRANSFORM);
                        zValues = applyAxisTransform(zValues, Z_TRANSFORM);

                        traces.push({
                            x: xValues,
                            y: yValues,
                            z: zValues,
                            mode: 'markers',
                            name: key,
                            legendgroup: key,
                            showlegend: idx === 0,
                            scene: sceneId,
                            type: 'scatter3d',
                            marker: {
                                size: $marker_size,
                                opacity: $marker_opacity,
                                color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, key)
                            }
                        });
                    });

                    if (window.showEigenvectors_$(chart_title_safe) && facetData.length > 3) {
                        // Compute eigenvectors on transformed data
                        let allXValues = facetData.map(d => parseFloat(d[X_COL]));
                        let allYValues = facetData.map(d => parseFloat(d[Y_COL]));
                        let allZValues = facetData.map(d => parseFloat(d[Z_COL]));

                        allXValues = applyAxisTransform(allXValues, X_TRANSFORM);
                        allYValues = applyAxisTransform(allYValues, Y_TRANSFORM);
                        allZValues = applyAxisTransform(allZValues, Z_TRANSFORM);

                        const transformedData = facetData.map((row, i) => ({
                            [X_COL]: allXValues[i],
                            [Y_COL]: allYValues[i],
                            [Z_COL]: allZValues[i]
                        }));

                        const eigData = computeEigenvectors(transformedData, X_COL, Y_COL, Z_COL);
                        if (eigData !== null) {
                            traces.push(...createEigenvectorTraces(eigData, sceneId));
                        }
                    }
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    grid: { rows: rows, columns: cols, pattern: 'independent' },
                    annotations: []
                };

                // Create scene for each facet
                facetValues.forEach((val, idx) => {
                    const row = Math.floor(idx / cols);
                    const col = idx % cols;
                    const sceneKey = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                    const xDomain = [col / cols + 0.01, (col + 1) / cols - 0.01];
                    const yDomain = [1 - (row + 1) / rows + 0.01, 1 - row / rows - 0.01];

                    layout[sceneKey] = {
                        domain: { x: xDomain, y: yDomain },
                        xaxis: { title: getAxisLabel(X_COL, X_TRANSFORM) },
                        yaxis: { title: getAxisLabel(Y_COL, Y_TRANSFORM) },
                        zaxis: { title: getAxisLabel(Z_COL, Z_TRANSFORM) },
                        camera: window.sharedCamera_$(chart_title_safe) ? (window.currentCamera_$(chart_title_safe) || undefined) : undefined
                    };

                    layout.annotations.push({
                        text: FACET_COL + ': ' + val,
                        showarrow: false,
                        xref: sceneKey + ' domain',
                        yref: sceneKey + ' domain',
                        x: 0.5,
                        y: 1.05,
                        xanchor: 'center',
                        yanchor: 'bottom'
                    });
                });

                Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});

                // Setup camera sync if shared
                if (window.sharedCamera_$(chart_title_safe)) {
                    const plotDiv = document.getElementById('$(chart_title_safe)');
                    let isUpdating = false; // Prevent infinite loop

                    plotDiv.on('plotly_relayout', (eventData) => {
                        if (isUpdating) return; // Ignore events triggered by our own updates

                        // Find which scene was updated
                        for (let key in eventData) {
                            if (key.endsWith('.camera')) {
                                const newCamera = eventData[key];
                                window.currentCamera_$(chart_title_safe) = newCamera;

                                // Apply to all scenes
                                isUpdating = true;
                                const updates = {};
                                facetValues.forEach((val, idx) => {
                                    const sceneKey = idx === 0 ? 'scene' : 'scene' + (idx + 1);
                                    updates[sceneKey + '.camera'] = newCamera;
                                });
                                Plotly.relayout(plotDiv, updates).then(() => {
                                    isUpdating = false;
                                });
                                break;
                            }
                        }
                    });
                }
            }

            function renderFacetGrid_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET1_COL, FACET2_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM) {
                const facet1Values = [...new Set(data.map(row => row[FACET1_COL]))].sort();
                const facet2Values = [...new Set(data.map(row => row[FACET2_COL]))].sort();
                const rows = facet1Values.length;
                const cols = facet2Values.length;

                const traces = [];

                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row => row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val);
                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const sceneId = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                        const groups = {};
                        facetData.forEach(row => {
                            const key = row[COLOR_COL];
                            if (!groups[key]) groups[key] = [];
                            groups[key].push(row);
                        });

                        Object.entries(groups).forEach(([key, groupData]) => {
                            let xValues = groupData.map(d => parseFloat(d[X_COL]));
                            let yValues = groupData.map(d => parseFloat(d[Y_COL]));
                            let zValues = groupData.map(d => parseFloat(d[Z_COL]));

                            // Apply axis transformations
                            xValues = applyAxisTransform(xValues, X_TRANSFORM);
                            yValues = applyAxisTransform(yValues, Y_TRANSFORM);
                            zValues = applyAxisTransform(zValues, Z_TRANSFORM);

                            traces.push({
                                x: xValues,
                                y: yValues,
                                z: zValues,
                                mode: 'markers',
                                name: key,
                                legendgroup: key,
                                showlegend: idx === 0,
                                scene: sceneId,
                                type: 'scatter3d',
                                marker: {
                                    size: $marker_size,
                                    opacity: $marker_opacity,
                                    color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, key)
                                }
                            });
                        });

                        if (window.showEigenvectors_$(chart_title_safe) && facetData.length > 3) {
                            // Compute eigenvectors on transformed data
                            let allXValues = facetData.map(d => parseFloat(d[X_COL]));
                            let allYValues = facetData.map(d => parseFloat(d[Y_COL]));
                            let allZValues = facetData.map(d => parseFloat(d[Z_COL]));

                            allXValues = applyAxisTransform(allXValues, X_TRANSFORM);
                            allYValues = applyAxisTransform(allYValues, Y_TRANSFORM);
                            allZValues = applyAxisTransform(allZValues, Z_TRANSFORM);

                            const transformedData = facetData.map((row, i) => ({
                                [X_COL]: allXValues[i],
                                [Y_COL]: allYValues[i],
                                [Z_COL]: allZValues[i]
                            }));

                            const eigData = computeEigenvectors(transformedData, X_COL, Y_COL, Z_COL);
                            if (eigData !== null) {
                                traces.push(...createEigenvectorTraces(eigData, sceneId));
                            }
                        }
                    });
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    grid: { rows: rows, columns: cols, pattern: 'independent' },
                    annotations: []
                };

                // Create scene for each facet
                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row => row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val);
                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const sceneKey = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                        const xDomain = [colIdx / cols + 0.01, (colIdx + 1) / cols - 0.01];
                        const yDomain = [1 - (rowIdx + 1) / rows + 0.01, 1 - rowIdx / rows - 0.01];

                        layout[sceneKey] = {
                            domain: { x: xDomain, y: yDomain },
                            xaxis: { title: getAxisLabel(X_COL, X_TRANSFORM) },
                            yaxis: { title: getAxisLabel(Y_COL, Y_TRANSFORM) },
                            zaxis: { title: getAxisLabel(Z_COL, Z_TRANSFORM) },
                            camera: window.sharedCamera_$(chart_title_safe) ? (window.currentCamera_$(chart_title_safe) || undefined) : undefined
                        };

                        // Column header
                        if (rowIdx === 0) {
                            layout.annotations.push({
                                text: FACET2_COL + ': ' + facet2Val,
                                showarrow: false,
                                xref: sceneKey + ' domain',
                                yref: sceneKey + ' domain',
                                x: 0.5,
                                y: 1.05,
                                xanchor: 'center',
                                yanchor: 'bottom'
                            });
                        }

                        // Row header
                        if (colIdx === 0) {
                            layout.annotations.push({
                                text: FACET1_COL + ': ' + facet1Val,
                                showarrow: false,
                                xref: sceneKey + ' domain',
                                yref: sceneKey + ' domain',
                                x: -0.1,
                                y: 0.5,
                                xanchor: 'center',
                                yanchor: 'middle',
                                textangle: -90
                            });
                        }
                    });
                });

                Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});

                // Setup camera sync if shared
                if (window.sharedCamera_$(chart_title_safe)) {
                    const plotDiv = document.getElementById('$(chart_title_safe)');
                    let isUpdating = false; // Prevent infinite loop

                    plotDiv.on('plotly_relayout', (eventData) => {
                        if (isUpdating) return; // Ignore events triggered by our own updates

                        // Find which scene was updated
                        for (let key in eventData) {
                            if (key.endsWith('.camera')) {
                                const newCamera = eventData[key];
                                window.currentCamera_$(chart_title_safe) = newCamera;

                                // Apply to all scenes
                                isUpdating = true;
                                const updates = {};
                                let sceneCount = 0;
                                facet1Values.forEach((f1, r) => {
                                    facet2Values.forEach((f2, c) => {
                                        const facetData = data.filter(row => row[FACET1_COL] === f1 && row[FACET2_COL] === f2);
                                        if (facetData.length > 0) {
                                            const sceneKey = sceneCount === 0 ? 'scene' : 'scene' + (sceneCount + 1);
                                            updates[sceneKey + '.camera'] = newCamera;
                                            sceneCount++;
                                        }
                                    });
                                });
                                Plotly.relayout(plotDiv, updates).then(() => {
                                    isUpdating = false;
                                });
                                break;
                            }
                        }
                    });
                }
            }

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title_safe) = function() {
                // Get selected columns
                const X_COL = getCol('$(chart_title_safe)_x_col_select', DEFAULT_X_COL);
                const Y_COL = getCol('$(chart_title_safe)_y_col_select', DEFAULT_Y_COL);
                const Z_COL = getCol('$(chart_title_safe)_z_col_select', DEFAULT_Z_COL);
                const COLOR_COL = getCol('$(chart_title_safe)_color_col_select', DEFAULT_COLOR_COL);

                // Get current axis transformations
                const X_TRANSFORM = getCol('x_transform_select_$(chart_title_safe)', 'identity');
                const Y_TRANSFORM = getCol('y_transform_select_$(chart_title_safe)', 'identity');
                const Z_TRANSFORM = getCol('z_transform_select_$(chart_title_safe)', 'identity');

                // Get choice filter values (single-select)
                const choices = {};
                CHOICE_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_choice_$(chart_title_safe)');
                    if (select) {
                        choices[col] = select.value;
                    }
                });

                // Get filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$(chart_title_safe)');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                const { facet1, facet2 } = readFacetSelections('$(chart_title_safe)');

                // Filter data (support multiple selections per filter and choice filters)
                const filteredData = window.allData_$(chart_title_safe).filter(row => {
                    // Apply choice filters first (single-select)
                    for (let col in choices) {
                        if (choices[col] && String(row[col]) !== choices[col]) {
                            return false;
                        }
                    }
                    // Apply multi-select filters
                    for (let col in filters) {
                        const selectedValues = filters[col];
                        if (selectedValues.length > 0 && !selectedValues.includes(String(row[col]))) {
                            return false;
                        }
                    }
                    return true;
                });

                // Render based on faceting
                if (facet1 && facet2) {
                    renderFacetGrid_$(chart_title_safe)(filteredData, X_COL, Y_COL, Z_COL, COLOR_COL, facet1, facet2, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                } else if (facet1 || facet2) {
                    renderFacetWrap_$(chart_title_safe)(filteredData, X_COL, Y_COL, Z_COL, COLOR_COL, facet1 || facet2, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                } else {
                    renderNoFacets_$(chart_title_safe)(filteredData, X_COL, Y_COL, Z_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, Z_TRANSFORM);
                }
            };

            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title_safe) = data;

                // Initial plot
                updatePlotWithFilters_$(chart_title_safe)();

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title_safe');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });

            })();
        """

        # Organize controls into sections
        # filters_html, plot_attributes_html and faceting_html already built above

        # Use html_controls abstraction to generate appearance HTML
        appearance_html = generate_appearance_html_from_sections(
            filters_html,
            plot_attributes_html,
            faceting_html,
            title,
            notes,
            string(chart_title_safe);
            choices_html=choices_html,
            aspect_ratio_default=1.0
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::Scatter3D) = [a.data_label]
js_dependencies(::Scatter3D) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
