"""
    ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol}; kwargs...)

Scatter plot with optional marginal distributions and interactive filtering.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary
- `dimensions::Vector{Symbol}`: Vector of dimension columns for x and y axes

# Keyword Arguments
- `expression_mode::Bool`: Enable expression input for X axis (default: `false`)
- `default_x_expr::String`: Default expression for X when expression_mode=true (default: `""`)
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
- `show_density::Bool`: Show marginal density plots (default: `true`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points (default: `0.6`)
- `title::String`: Chart title (default: `"Scatter Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

When `expression_mode=true`, users can type custom expressions for X axis:
- Variables: `:varname` or `varname`
- Operators: `+`, `-`, `*`, `/`
- `z(expr, [groups])` - z-score within groups
- `q(expr, [groups])` - quantile within groups
- `PCA1(:v1, :v2)` - first principal component projection
- `PCA2(:v1, :v2)` - second principal component projection
- `r(y, x)` - OLS residual (y - fitted value)
- `f(y, x)` - OLS fitted value
- `c(expr, min, max)` - clamp values between min and max (use Inf/-Inf for one-sided)

# Examples
```julia
# Standard scatter plot
sp = ScatterPlot(:scatter_chart, df, :data, [:x, :y],
    color_cols=[:category],
    marker_size=6,
    title="X vs Y"
)

# Scatter plot with expression mode
sp_expr = ScatterPlot(:scatter_expr, df, :data, [:returns, :volatility, :volume],
    expression_mode=true,
    default_x_expr="z(:returns, [:sector])",
    color_cols=[:sector],
    title="Custom Expression vs Y"
)
```
"""
struct ScatterPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol};
                         expression_mode::Bool=false,
                         default_x_expr::String="",
                         color_cols::ColorColSpec=[:color],
                         filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                         choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                         facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         show_density::Bool=true,
                         marker_size::Int=4,
                         marker_opacity::Float64=0.6,
                         title::String="Scatter Plot",
                         notes::String="")

# Normalize filters and choices to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)
normalized_choices = normalize_choices(choices, df)

        # Validate columns exist in dataframe
        valid_x_cols = dimensions
        valid_y_cols = dimensions
        default_x_col = string(dimensions[1])  # First dimension is default X
        default_y_col = string(dimensions[2])  # Second dimension is default Y

        # Extract column names and validate they exist
        color_col_names = extract_color_col_names(color_cols)
        valid_color_cols = validate_and_filter_columns(color_col_names, df, "color_cols")
        default_color_col = string(valid_color_cols[1])
        # Build color maps for custom colors (categorical and continuous)
        color_maps, color_scales, _ = build_color_maps_extended(color_cols, df)
        color_maps_js = JSON.json(color_maps)
        color_scales_js = build_color_scales_js(color_scales)
        # Point type always uses the same variable as color
        valid_pointtype_cols = valid_color_cols

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)
        all_cols = names(df)
        for col in facet_choices
            String(col) in all_cols || error("Facet column $col not found in dataframe. Available: $all_cols")
        end

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(string(chart_title), normalized_choices, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") *
                       join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")
        choices_html = join([generate_choice_dropdown_html(dd) for dd in choice_dropdowns], "\n")

        # Separate categorical and continuous filters for JavaScript
        categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
        continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]
        choice_cols = collect(keys(normalized_choices))

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)

        # Helper function to build dropdown HTML
        build_dropdown(id, label, cols, title, default_value) = begin
            length(cols) <= 1 && return ""
            options = join(["                    <option value=\"$col\"$((string(col) == default_value) ? " selected" : "")>$col</option>"
                           for col in cols], "\n")
            """
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="$(id)_$title">$label:</label>
                    <select id="$(id)_$title" onchange="updateChart_$title()">
$options                </select>
                </div>
            """
        end

        point_symbols = ["circle", "square", "diamond", "cross", "x", "triangle-up",
                        "triangle-down", "triangle-left", "triangle-right", "pentagon", "hexagon", "star"]

        # Escape the default expression for JavaScript
        escaped_default_expr = replace(default_x_expr, "\"" => "\\\"", "\\" => "\\\\")

        # Build different JavaScript based on expression_mode
        if expression_mode
            functional_html = """
            (function() {
            // Filter configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;
            const EXPRESSION_MODE = true;

            window.showDensity_$(chart_title) = $(show_density ? "true" : "false");
            const POINT_SYMBOLS = $(JSON.json(point_symbols));
            const DEFAULT_X_EXPR = "$escaped_default_expr";
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;

            $JS_COLOR_INTERPOLATION

            const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };
            const buildSymbolMap = (data, col) => {
                const uniqueVals = [...new Set(data.map(row => row[col]))].sort();
                return Object.fromEntries(uniqueVals.map((val, i) => [val, POINT_SYMBOLS[i % POINT_SYMBOLS.length]]));
            };

            function createTracesExpr(data, xValues, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, xaxis='x', yaxis='y', showlegend=true) {
                const symbolMap = buildSymbolMap(data, COLOR_COL);
                const groups = {};
                data.forEach((row, idx) => {
                    const key = row[COLOR_COL];
                    if (!groups[key]) groups[key] = { rows: [], indices: [] };
                    groups[key].rows.push(row);
                    groups[key].indices.push(idx);
                });

                return Object.entries(groups).map(([key, groupInfo]) => {
                    let groupXValues = groupInfo.indices.map(i => xValues[i]);
                    let yValues = groupInfo.rows.map(d => d[Y_COL]);

                    // Apply axis transformations
                    groupXValues = applyAxisTransform(groupXValues, X_TRANSFORM);
                    yValues = applyAxisTransform(yValues, Y_TRANSFORM);

                    return {
                        x: groupXValues,
                        y: yValues,
                        mode: 'markers',
                        name: key,
                        legendgroup: key,
                        showlegend: showlegend,
                        xaxis: xaxis,
                        yaxis: yaxis,
                        marker: {
                            size: $marker_size,
                            opacity: $marker_opacity,
                            symbol: groupInfo.rows.map(d => symbolMap[d[COLOR_COL]]),
                            color: groupInfo.rows.map(d => getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, d[COLOR_COL]))
                        },
                        type: 'scatter'
                    };
                });
            }

            function renderNoFacetsExpr(data, xValues, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, xLabel) {
                const traces = createTracesExpr(data, xValues, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM);

                if (window.showDensity_$(chart_title)) {
                    let xDensityValues = applyAxisTransform(xValues.slice(), X_TRANSFORM);
                    let yDensityValues = data.map(d => d[Y_COL]);
                    yDensityValues = applyAxisTransform(yDensityValues, Y_TRANSFORM);

                    traces.push({
                        x: xDensityValues, y: yDensityValues,
                        name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                        showscale: false, type: 'histogram2dcontour', showlegend: false
                    });
                }

                let xHistValues = applyAxisTransform(xValues.slice(), X_TRANSFORM);
                let yHistValues = data.map(d => d[Y_COL]);
                yHistValues = applyAxisTransform(yHistValues, Y_TRANSFORM);

                traces.push(
                    { x: xHistValues, name: 'x density', marker: {color: 'rgba(128, 128, 128, 0.5)'}, yaxis: 'y2', type: 'histogram', showlegend: false },
                    { y: yHistValues, name: 'y density', marker: {color: 'rgba(128, 128, 128, 0.5)'}, xaxis: 'x2', type: 'histogram', showlegend: false }
                );

                var xAxisTitle = X_TRANSFORM === 'identity' ? xLabel : X_TRANSFORM + '(' + xLabel + ')';

                Plotly.newPlot('$chart_title', traces, {
                    title: '$title', showlegend: true, autosize: true, hovermode: 'closest',
                    xaxis: { title: xAxisTitle, domain: [0, 0.85], showgrid: true, zeroline: true },
                    yaxis: { title: getAxisLabel(Y_COL, Y_TRANSFORM), domain: [0, 0.85], showgrid: true, zeroline: true },
                    xaxis2: { domain: [0.85, 1], showgrid: false, zeroline: false },
                    yaxis2: { domain: [0.85, 1], showgrid: false, zeroline: false },
                    margin: {t: 100, r: 100, b: 100, l: 100}
                }, {responsive: true});
            }

            function updatePlot_$(chart_title)(data) {
                // Get X expression from input
                const xExprInput = document.getElementById('x_expr_input_$chart_title');
                const X_EXPR = xExprInput ? xExprInput.value : DEFAULT_X_EXPR;

                const Y_COL = getCol('y_col_select_$chart_title', DEFAULT_Y_COL);
                const COLOR_COL = getCol('color_col_select_$chart_title', DEFAULT_COLOR_COL);

                // Get current axis transformations
                const X_TRANSFORM = getCol('x_transform_select_$chart_title', 'identity');
                const Y_TRANSFORM = getCol('y_transform_select_$chart_title', 'identity');

                // Evaluate the X expression
                const xValues = evaluateExpressionString(X_EXPR, data);

                // For now, only support no-facet mode in expression mode
                renderNoFacetsExpr(data, xValues, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, X_EXPR || 'X');
            }

            window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title) = function() {
                // Get current filter values
                const { filters, rangeFilters, choices } = readFilterValues('$(chart_title)', CATEGORICAL_FILTERS, CONTINUOUS_FILTERS, CHOICE_FILTERS);

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
                    const densityBtn = document.getElementById('$(chart_title)_density_toggle');
                    if (densityBtn) {
                        densityBtn.addEventListener('click', function() {
                            window.showDensity_$(chart_title) = !window.showDensity_$(chart_title);
                            this.textContent = window.showDensity_$(chart_title) ? 'Hide Density Contours' : 'Show Density Contours';
                            updatePlotWithFilters_$(chart_title)();
                        });
                    }

                    // Set default expression
                    const xExprInput = document.getElementById('x_expr_input_$chart_title');
                    if (xExprInput && DEFAULT_X_EXPR) {
                        xExprInput.value = DEFAULT_X_EXPR;
                    }

                    updatePlotWithFilters_$(chart_title)();

                    // Setup aspect ratio control after initial render
                    setupAspectRatioControl('$chart_title');
                });
            }).catch(error => console.error('Error loading data for chart $chart_title:', error));
            })();
        """
        else
            # Standard mode - original JavaScript
            functional_html = """
            (function() {
            // Filter configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;
            const EXPRESSION_MODE = false;

            window.showDensity_$(chart_title) = $(show_density ? "true" : "false");
            const POINT_SYMBOLS = $(JSON.json(point_symbols));
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;

            $JS_COLOR_INTERPOLATION

            const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };
            const buildSymbolMap = (data, col) => {
                const uniqueVals = [...new Set(data.map(row => row[col]))].sort();
                return Object.fromEntries(uniqueVals.map((val, i) => [val, POINT_SYMBOLS[i % POINT_SYMBOLS.length]]));
            };

            function createTraces(data, X_COL, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, xaxis='x', yaxis='y', showlegend=true) {
                const symbolMap = buildSymbolMap(data, COLOR_COL);
                const groups = {};
                data.forEach(row => {
                    const key = row[COLOR_COL];
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(row);
                });

                return Object.entries(groups).map(([key, groupData]) => {
                    let xValues = groupData.map(d => d[X_COL]);
                    let yValues = groupData.map(d => d[Y_COL]);

                    // Apply axis transformations
                    xValues = applyAxisTransform(xValues, X_TRANSFORM);
                    yValues = applyAxisTransform(yValues, Y_TRANSFORM);

                    return {
                    x: xValues,
                    y: yValues,
                    mode: 'markers',
                    name: key,
                    legendgroup: key,
                    showlegend: showlegend,
                    xaxis: xaxis,
                    yaxis: yaxis,
                    marker: {
                        size: $marker_size,
                        opacity: $marker_opacity,
                        symbol: groupData.map(d => symbolMap[d[COLOR_COL]]),
                        color: groupData.map(d => getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, d[COLOR_COL]))
                    },
                    type: 'scatter'
                    };
                });
            }

            function renderNoFacets(data, X_COL, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM) {
                const traces = createTraces(data, X_COL, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM);

                if (window.showDensity_$(chart_title)) {
                    let xDensityValues = data.map(d => d[X_COL]);
                    let yDensityValues = data.map(d => d[Y_COL]);
                    xDensityValues = applyAxisTransform(xDensityValues, X_TRANSFORM);
                    yDensityValues = applyAxisTransform(yDensityValues, Y_TRANSFORM);

                    traces.push({
                        x: xDensityValues, y: yDensityValues,
                        name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                        showscale: false, type: 'histogram2dcontour', showlegend: false
                    });
                }

                let xHistValues = data.map(d => d[X_COL]);
                let yHistValues = data.map(d => d[Y_COL]);
                xHistValues = applyAxisTransform(xHistValues, X_TRANSFORM);
                yHistValues = applyAxisTransform(yHistValues, Y_TRANSFORM);

                traces.push(
                    { x: xHistValues, name: 'x density', marker: {color: 'rgba(128, 128, 128, 0.5)'}, yaxis: 'y2', type: 'histogram', showlegend: false },
                    { y: yHistValues, name: 'y density', marker: {color: 'rgba(128, 128, 128, 0.5)'}, xaxis: 'x2', type: 'histogram', showlegend: false }
                );

                Plotly.newPlot('$chart_title', traces, {
                    title: '$title', showlegend: true, autosize: true, hovermode: 'closest',
                    xaxis: { title: getAxisLabel(X_COL, X_TRANSFORM), domain: [0, 0.85], showgrid: true, zeroline: true },
                    yaxis: { title: getAxisLabel(Y_COL, Y_TRANSFORM), domain: [0, 0.85], showgrid: true, zeroline: true },
                    xaxis2: { domain: [0.85, 1], showgrid: false, zeroline: false },
                    yaxis2: { domain: [0.85, 1], showgrid: false, zeroline: false },
                    margin: {t: 100, r: 100, b: 100, l: 100}
                }, {responsive: true});
            }

            function renderFacetWrap(data, X_COL, Y_COL, COLOR_COL, FACET_COL, X_TRANSFORM, Y_TRANSFORM) {
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const nFacets = facetValues.length, cols = Math.ceil(Math.sqrt(nFacets)), rows = Math.ceil(nFacets / cols);
                const traces = [];

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                    traces.push(...createTraces(facetData, X_COL, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, xaxis, yaxis, idx === 0));

                    if (window.showDensity_$(chart_title)) {
                        let xDensityValues = facetData.map(d => d[X_COL]);
                        let yDensityValues = facetData.map(d => d[Y_COL]);
                        xDensityValues = applyAxisTransform(xDensityValues, X_TRANSFORM);
                        yDensityValues = applyAxisTransform(yDensityValues, Y_TRANSFORM);

                        traces.push({
                            x: xDensityValues, y: yDensityValues,
                            name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                            showscale: false, type: 'histogram2dcontour', showlegend: false, xaxis: xaxis, yaxis: yaxis
                        });
                    }
                });

                const layout = {
                    title: '$title', showlegend: true, grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: facetValues.map((val, idx) => ({
                        text: FACET_COL + ': ' + val, showarrow: false,
                        xref: (idx === 0 ? 'x' : 'x' + (idx + 1)) + ' domain',
                        yref: (idx === 0 ? 'y' : 'y' + (idx + 1)) + ' domain',
                        x: 0.5, y: 1.1, xanchor: 'center', yanchor: 'bottom'
                    })),
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };
                facetValues.forEach((val, idx) => {
                    const ax = idx === 0 ? '' : (idx + 1);
                    layout['xaxis' + ax] = {title: getAxisLabel(X_COL, X_TRANSFORM)};
                    layout['yaxis' + ax] = {title: getAxisLabel(Y_COL, Y_TRANSFORM)};
                });
                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function renderFacetGrid(data, X_COL, Y_COL, COLOR_COL, FACET1_COL, FACET2_COL, X_TRANSFORM, Y_TRANSFORM) {
                const facet1Values = [...new Set(data.map(row => row[FACET1_COL]))].sort();
                const facet2Values = [...new Set(data.map(row => row[FACET2_COL]))].sort();
                const rows = facet1Values.length, cols = facet2Values.length;
                const traces = [];

                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row => row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val);
                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                        traces.push(...createTraces(facetData, X_COL, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM, xaxis, yaxis, idx === 0));

                        if (window.showDensity_$(chart_title)) {
                            let xDensityValues = facetData.map(d => d[X_COL]);
                            let yDensityValues = facetData.map(d => d[Y_COL]);
                            xDensityValues = applyAxisTransform(xDensityValues, X_TRANSFORM);
                            yDensityValues = applyAxisTransform(yDensityValues, Y_TRANSFORM);

                            traces.push({
                                x: xDensityValues, y: yDensityValues,
                                name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                                showscale: false, type: 'histogram2dcontour', showlegend: false, xaxis: xaxis, yaxis: yaxis
                            });
                        }
                    });
                });

                const layout = {
                    title: '$title', showlegend: true, grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: [
                        ...facet2Values.map((val, colIdx) => ({
                            text: FACET2_COL + ': ' + val, showarrow: false,
                            xref: (colIdx === 0 ? 'x' : 'x' + (colIdx + 1)) + ' domain',
                            yref: (colIdx === 0 ? 'y' : 'y' + (colIdx + 1)) + ' domain',
                            x: 0.5, y: 1.1, xanchor: 'center', yanchor: 'bottom'
                        })),
                        ...facet1Values.map((val, rowIdx) => ({
                            text: FACET1_COL + ': ' + val, showarrow: false,
                            xref: (rowIdx * cols === 0 ? 'x' : 'x' + (rowIdx * cols + 1)) + ' domain',
                            yref: (rowIdx * cols === 0 ? 'y' : 'y' + (rowIdx * cols + 1)) + ' domain',
                            x: -0.15, y: 0.5, xanchor: 'center', yanchor: 'middle', textangle: -90
                        }))
                    ],
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };
                facet1Values.forEach((v1, rowIdx) => {
                    facet2Values.forEach((v2, colIdx) => {
                        const idx = rowIdx * cols + colIdx, ax = idx === 0 ? '' : (idx + 1);
                        layout['xaxis' + ax] = {title: getAxisLabel(X_COL, X_TRANSFORM)};
                        layout['yaxis' + ax] = {title: getAxisLabel(Y_COL, Y_TRANSFORM)};
                    });
                });
                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function updatePlot_$(chart_title)(data) {
                const X_COL = getCol('x_col_select_$chart_title', DEFAULT_X_COL);
                const Y_COL = getCol('y_col_select_$chart_title', DEFAULT_Y_COL);
                const COLOR_COL = getCol('color_col_select_$chart_title', DEFAULT_COLOR_COL);

                // Get current axis transformations
                const X_TRANSFORM = getCol('x_transform_select_$chart_title', 'identity');
                const Y_TRANSFORM = getCol('y_transform_select_$chart_title', 'identity');

                let FACET1 = getCol('facet1_select_$chart_title', null);
                let FACET2 = getCol('facet2_select_$chart_title', null);
                if (FACET1 === 'None') FACET1 = null;
                if (FACET2 === 'None') FACET2 = null;

                if (FACET1 && FACET2) {
                    renderFacetGrid(data, X_COL, Y_COL, COLOR_COL, FACET1, FACET2, X_TRANSFORM, Y_TRANSFORM);
                } else if (FACET1) {
                    renderFacetWrap(data, X_COL, Y_COL, COLOR_COL, FACET1, X_TRANSFORM, Y_TRANSFORM);
                } else {
                    renderNoFacets(data, X_COL, Y_COL, COLOR_COL, X_TRANSFORM, Y_TRANSFORM);
                }
            }

            window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title) = function() {
                // Get current filter values
                const { filters, rangeFilters, choices } = readFilterValues('$(chart_title)', CATEGORICAL_FILTERS, CONTINUOUS_FILTERS, CHOICE_FILTERS);

                // Apply filters with observation counting (centralized function)
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
                    const densityBtn = document.getElementById('$(chart_title)_density_toggle');
                    if (densityBtn) {
                        densityBtn.addEventListener('click', function() {
                            window.showDensity_$(chart_title) = !window.showDensity_$(chart_title);
                            this.textContent = window.showDensity_$(chart_title) ? 'Hide Density Contours' : 'Show Density Contours';
                            updatePlotWithFilters_$(chart_title)();
                        });
                    }
                    updatePlotWithFilters_$(chart_title)();

                    // Setup aspect ratio control after initial render
                    setupAspectRatioControl('$chart_title');
                });
            }).catch(error => console.error('Error loading data for chart $chart_title:', error));
            })();
        """
        end

        # Separate plot attributes from faceting
        plot_attributes_html = ""
        faceting_html = ""

        # Build plot attributes section (density toggle, color selector)
        plot_attributes_html = """
        <div style="margin: 10px 0;">
            <button id="$(chart_title)_density_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_density ? "Hide" : "Show") Density Contours
            </button>
        </div>
        """

        # Style dropdown (color/point type)
        style_html = build_dropdown("color_col_select", "Color/Point type", valid_color_cols, chart_title, default_color_col)
        if !isempty(style_html)
            plot_attributes_html *= """<div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
$style_html        </div>
"""
        end

        # Build axis controls based on expression_mode
        if expression_mode
            # Expression mode: X is an expression input, Y is a dropdown
            x_transform_options = ["identity", "log", "z_score", "quantile", "inverse_cdf"]
            x_transform_opts = join(["<option value=\"$opt\">$opt</option>" for opt in x_transform_options], "\n")
            y_transform_opts = join(["<option value=\"$opt\">$opt</option>" for opt in x_transform_options], "\n")
            y_options = join(["<option value=\"$col\"$((string(col) == default_y_col) ? " selected" : "")>$col</option>"
                             for col in valid_y_cols], "\n")

            plot_attributes_html *= """
        <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Axes</h4>
        <div style="display: flex; flex-direction: column; gap: 10px;">
            <div style="display: flex; gap: 15px; align-items: center; flex-wrap: wrap;">
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="x_expr_input_$chart_title">X Expression:</label>
                    <input type="text" id="x_expr_input_$chart_title" style="width: 350px; padding: 5px 10px; font-family: monospace;"
                           placeholder="e.g., z(:var1, [:group]) or :var1 + :var2"
                           onchange="updateChart_$chart_title()" onkeyup="if(event.key==='Enter') updateChart_$chart_title()">
                </div>
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="x_transform_select_$chart_title">X Transform:</label>
                    <select id="x_transform_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                        $x_transform_opts
                    </select>
                </div>
            </div>
            <div style="display: flex; gap: 15px; align-items: center; flex-wrap: wrap;">
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="y_col_select_$chart_title">Y:</label>
                    <select id="y_col_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                        $y_options
                    </select>
                </div>
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="y_transform_select_$chart_title">Y Transform:</label>
                    <select id="y_transform_select_$chart_title" style="padding: 5px 10px;" onchange="updateChart_$chart_title()">
                        $y_transform_opts
                    </select>
                </div>
            </div>
        </div>

        <div style="margin-top: 15px; padding: 12px; background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 5px; font-size: 0.9em;">
            <h5 style="margin: 0 0 10px 0; color: #495057;">Expression Syntax Guide</h5>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 10px;">
                <div>
                    <strong>Variables:</strong> <code>:varname</code> or <code>varname</code><br>
                    <span style="color: #6c757d;">Reference any column from your data</span>
                </div>
                <div>
                    <strong>Operators:</strong> <code>+</code> <code>-</code> <code>*</code> <code>/</code><br>
                    <span style="color: #6c757d;">Combine variables arithmetically</span>
                </div>
            </div>
            <h5 style="margin: 15px 0 10px 0; color: #495057;">Available Functions</h5>
            <table style="width: 100%; border-collapse: collapse; font-size: 0.95em;">
                <tr style="border-bottom: 1px solid #dee2e6;">
                    <td style="padding: 6px 8px;"><code>z(expr, [groups])</code></td>
                    <td style="padding: 6px 8px;">Z-score (standardize) within groups. Example: <code>z(:returns, [:sector, :date])</code></td>
                </tr>
                <tr style="border-bottom: 1px solid #dee2e6;">
                    <td style="padding: 6px 8px;"><code>q(expr, [groups])</code></td>
                    <td style="padding: 6px 8px;">Quantile rank (0-1) within groups. Example: <code>q(:returns, [:sector])</code></td>
                </tr>
                <tr style="border-bottom: 1px solid #dee2e6;">
                    <td style="padding: 6px 8px;"><code>PCA1(:v1, :v2)</code></td>
                    <td style="padding: 6px 8px;">Project onto first principal component of v1 and v2</td>
                </tr>
                <tr style="border-bottom: 1px solid #dee2e6;">
                    <td style="padding: 6px 8px;"><code>PCA2(:v1, :v2)</code></td>
                    <td style="padding: 6px 8px;">Project onto second principal component of v1 and v2</td>
                </tr>
                <tr style="border-bottom: 1px solid #dee2e6;">
                    <td style="padding: 6px 8px;"><code>r(y, x)</code></td>
                    <td style="padding: 6px 8px;">OLS residual: y minus fitted value from regressing y on x</td>
                </tr>
                <tr style="border-bottom: 1px solid #dee2e6;">
                    <td style="padding: 6px 8px;"><code>f(y, x)</code></td>
                    <td style="padding: 6px 8px;">OLS fitted value: predicted y from regressing y on x</td>
                </tr>
                <tr>
                    <td style="padding: 6px 8px;"><code>c(expr, min, max)</code></td>
                    <td style="padding: 6px 8px;">Clamp values between min and max. Use <code>Inf</code>/<code>-Inf</code> for one-sided bounds. Example: <code>c(:returns, -0.05, 0.05)</code></td>
                </tr>
            </table>
            <div style="margin-top: 10px; color: #6c757d;">
                <strong>Examples:</strong>
                <code style="margin-left: 10px;">:returns + :volatility</code>
                <code style="margin-left: 10px;">z(:returns, [:sector])</code>
                <code style="margin-left: 10px;">c(:vol, -Inf, 0.5)</code>
            </div>
        </div>
"""
        else
            # Standard mode: X and Y are both dropdowns
            axes_html = build_axis_controls_html(
                string(chart_title),
                "updateChart_$chart_title()";
                x_cols = valid_x_cols,
                y_cols = valid_y_cols,
                default_x = Symbol(default_x_col),
                default_y = Symbol(default_y_col),
                include_x_transform = true,
                include_y_transform = true,
                include_cumulative = false
            )
            plot_attributes_html *= axes_html
        end

        # Build faceting section using html_controls abstraction (only for non-expression mode)
        if !expression_mode
            faceting_html = generate_facet_dropdowns_html(
                string(chart_title),
                facet_choices,
                default_facet_array,
                "updateChart_$chart_title()"
            )
        end

        # Use html_controls abstraction to generate appearance HTML
        appearance_html = generate_appearance_html_from_sections(
            filters_html,
            plot_attributes_html,
            faceting_html,
            title,
            notes,
            string(chart_title);
            choices_html=choices_html,
            aspect_ratio_default=1.0
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::ScatterPlot) = [a.data_label]
js_dependencies(::ScatterPlot) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
