"""
    Path(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Path chart showing trajectories through a 2D space ordered by a sequence variable.

Displays scatter points connected by lines in the order of a specified column (e.g., year),
with arrows indicating direction. Useful for visualizing how metrics evolve over time
or other sequences.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_cols::Vector{Symbol}`: Columns available for x-axis (default: `[:x]`)
- `y_cols::Vector{Symbol}`: Columns available for y-axis (default: `[:y]`)
- `order_col::Symbol`: Column determining the order of points along the path (default: `:order`)
- `color_cols::Vector{Symbol}`: Columns available for color grouping/paths (default: `Symbol[]`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `title::String`: Chart title (default: `"Path Chart"`)
- `line_width::Int`: Width of path lines (default: `2`)
- `marker_size::Int`: Size of markers (default: `8`)
- `show_arrows::Bool`: Show direction arrows on paths (default: `true`)
- `use_alpharange::Bool`: Use transparency gradient from 0.3 (first point) to 1.0 (last point) to show direction (default: `false`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
# Trading strategy evolution over time
path = Path(:strategy_paths, df, :data,
    x_cols=[:volatility],
    y_cols=[:Sharpe],
    order_col=:year,
    color_cols=[:strategy],
    title="Strategy Risk-Return Evolution",
    show_arrows=true
)

# Using transparency gradient instead of arrows
path_alpha = Path(:strategy_paths_alpha, df, :data,
    x_cols=[:volatility],
    y_cols=[:Sharpe],
    order_col=:year,
    color_cols=[:strategy],
    use_alpharange=true,  # Gradient from 0.3 (first) to 1.0 (last)
    show_arrows=false,
    title="Strategy Evolution with Alpha Gradient"
)
```
"""
struct Path <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function Path(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                  x_cols::Vector{Symbol}=[:x],
                  y_cols::Vector{Symbol}=[:y],
                  order_col::Symbol=:order,
                  color_cols::Vector{Symbol}=Symbol[],
                  filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                  facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                  default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                  title::String="Path Chart",
                  line_width::Int=2,
                  marker_size::Int=8,
                  show_arrows::Bool=true,
                  use_alpharange::Bool=false,
                  notes::String="")

# Normalize filters to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)

        # Validate columns exist in dataframe
        valid_x_cols = validate_and_filter_columns(x_cols, df, "x_cols")
        valid_y_cols = validate_and_filter_columns(y_cols, df, "y_cols")
        validate_column(df, order_col, "order_col")

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build color maps for all possible color columns that exist
        color_maps, valid_color_cols = build_color_maps(color_cols, df)

        # Build HTML controls using abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)

        # Create JavaScript arrays for columns
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        x_cols_js = build_js_array(valid_x_cols)
        y_cols_js = build_js_array(valid_y_cols)
        color_cols_js = build_js_array(valid_color_cols)

        # Create color maps as nested JavaScript object
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Default columns
        default_x_col = string(valid_x_cols[1])
        default_y_col = string(valid_y_cols[1])
        default_color_col = select_default_column(valid_color_cols, "__no_color__")

        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const X_COLS = $x_cols_js;
            const Y_COLS = $y_cols_js;
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const ORDER_COL = '$order_col';
            const USE_ALPHARANGE = $use_alpharange;

            // Global state for arrow/line toggle
            window.showArrows_$chart_title = $(show_arrows ? "true" : "false");

            let allData = [];

            // Helper function to generate alpha values for path progression
            function getAlphaValues(length) {
                if (!USE_ALPHARANGE || length === 0) return undefined;
                if (length === 1) return [1.0];
                const alphaValues = [];
                for (let i = 0; i < length; i++) {
                    // Linear interpolation from 0.3 to 1.0
                    const alpha = 0.3 + (0.7 * i / (length - 1));
                    alphaValues.push(alpha);
                }
                return alphaValues;
            }

            // Helper function to convert hex color to rgba
            function hexToRgba(hex, alpha) {
                const r = parseInt(hex.slice(1, 3), 16);
                const g = parseInt(hex.slice(3, 5), 16);
                const b = parseInt(hex.slice(5, 7), 16);
                return `rgba(\${r}, \${g}, \${b}, \${alpha})`;
            }

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title = function() {
                // Get current X and Y columns
                const xColSelect = document.getElementById('x_col_select_$chart_title');
                const X_COL = xColSelect ? xColSelect.value : DEFAULT_X_COL;

                const yColSelect = document.getElementById('y_col_select_$chart_title');
                const Y_COL = yColSelect ? yColSelect.value : DEFAULT_Y_COL;

                // Get current filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Get current color column
                const colorColSelect = document.getElementById('color_col_select_$chart_title');
                const COLOR_COL = colorColSelect ? colorColSelect.value : DEFAULT_COLOR_COL;

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                // Build FACET_COLS array based on selections
                const FACET_COLS = [];
                if (facet1) FACET_COLS.push(facet1);
                if (facet2) FACET_COLS.push(facet2);

                // Get color map for current selection
                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};

                // Filter data (support multiple selections per filter)
                const filteredData = allData.filter(row => {
                    for (let col in filters) {
                        const selectedValues = filters[col];
                        if (selectedValues.length > 0 && !selectedValues.includes(String(row[col]))) {
                            return false;
                        }
                    }
                    return true;
                });

                if (FACET_COLS.length === 0) {
                    // No faceting - group by color
                    const groupedData = {};
                    filteredData.forEach(row => {
                        const colorVal = (COLOR_COL === '__no_color__') ? 'all' : String(row[COLOR_COL]);
                        if (!groupedData[colorVal]) {
                            groupedData[colorVal] = {
                                data: [],
                                color: colorVal
                            };
                        }
                        groupedData[colorVal].data.push(row);
                    });

                    const traces = [];
                    const annotations = [];

                    for (let groupKey in groupedData) {
                        const group = groupedData[groupKey];

                        // Sort by order column
                        group.data.sort((a, b) => {
                            const aVal = a[ORDER_COL];
                            const bVal = b[ORDER_COL];
                            if (typeof aVal === 'number' && typeof bVal === 'number') {
                                return aVal - bVal;
                            }
                            return String(aVal).localeCompare(String(bVal));
                        });

                        const xValues = group.data.map(row => row[X_COL]);
                        const yValues = group.data.map(row => row[Y_COL]);
                        const orderValues = group.data.map(row => row[ORDER_COL]);

                        const baseColor = COLOR_MAP[group.color] || '#000000';
                        const markerOpacity = getAlphaValues(xValues.length);

                        const markerConfig = {
                            size: $marker_size,
                            color: baseColor
                        };
                        if (markerOpacity !== undefined) {
                            markerConfig.opacity = markerOpacity;
                        }

                        // Add markers trace
                        traces.push({
                            x: xValues,
                            y: yValues,
                            type: 'scatter',
                            mode: 'markers',
                            name: group.color,
                            marker: markerConfig,
                            text: orderValues.map(v => ORDER_COL + ': ' + v),
                            hovertemplate: '%{text}<br>' + X_COL + ': %{x}<br>' + Y_COL + ': %{y}<extra></extra>',
                            showlegend: true
                        });

                        // Add connections between points (arrows or lines)
                        if (xValues.length > 1) {
                            if (window.showArrows_$chart_title) {
                                // Add arrow segments connecting points (each segment is an arrow)
                                for (let i = 0; i < xValues.length - 1; i++) {
                                    const alpha = USE_ALPHARANGE ? 0.3 + (0.7 * i / (xValues.length - 1)) : 1.0;
                                    const arrowColor = USE_ALPHARANGE ? hexToRgba(baseColor, alpha) : baseColor;

                                    annotations.push({
                                        x: xValues[i + 1],
                                        y: yValues[i + 1],
                                        ax: xValues[i],
                                        ay: yValues[i],
                                        xref: 'x',
                                        yref: 'y',
                                        axref: 'x',
                                        ayref: 'y',
                                        showarrow: true,
                                        arrowhead: 2,
                                        arrowsize: 1.5,
                                        arrowwidth: $line_width,
                                        arrowcolor: arrowColor,
                                        opacity: alpha
                                    });
                                }
                            } else {
                                // Add line trace connecting points
                                if (USE_ALPHARANGE) {
                                    // Create individual line segments with varying opacity
                                    for (let i = 0; i < xValues.length - 1; i++) {
                                        const alpha = 0.3 + (0.7 * i / (xValues.length - 1));
                                        const lineColor = hexToRgba(baseColor, alpha);

                                        traces.push({
                                            x: [xValues[i], xValues[i + 1]],
                                            y: [yValues[i], yValues[i + 1]],
                                            type: 'scatter',
                                            mode: 'lines',
                                            line: {
                                                color: lineColor,
                                                width: $line_width
                                            },
                                            showlegend: false,
                                            hoverinfo: 'skip'
                                        });
                                    }
                                } else {
                                    // Simple continuous line
                                    traces.push({
                                        x: xValues,
                                        y: yValues,
                                        type: 'scatter',
                                        mode: 'lines',
                                        name: group.color + ' (path)',
                                        line: {
                                            color: baseColor,
                                            width: $line_width
                                        },
                                        showlegend: false,
                                        hoverinfo: 'skip'
                                    });
                                }
                            }
                        }
                    }

                    const layout = {
                        title: '$title',
                        xaxis: { title: X_COL },
                        yaxis: { title: Y_COL },
                        hovermode: 'closest',
                        showlegend: true,
                        annotations: annotations
                    };

                    Plotly.newPlot('$chart_title', traces, layout, {responsive: true});

                } else if (FACET_COLS.length === 1) {
                    // Facet wrap
                    const facetCol = FACET_COLS[0];
                    const facetValues = [...new Set(filteredData.map(row => row[facetCol]))].sort();
                    const nFacets = facetValues.length;

                    // Calculate grid dimensions (prefer wider grids)
                    const nCols = Math.ceil(Math.sqrt(nFacets * 1.5));
                    const nRows = Math.ceil(nFacets / nCols);

                    const traces = [];
                    const layout = {
                        title: '$title',
                        hovermode: 'closest',
                        showlegend: true,
                        grid: {rows: nRows, columns: nCols, pattern: 'independent'},
                        annotations: []
                    };

                    facetValues.forEach((facetVal, idx) => {
                        const facetData = filteredData.filter(row => row[facetCol] === facetVal);

                        // Group by color within this facet
                        const groupedData = {};
                        facetData.forEach(row => {
                            const colorVal = (COLOR_COL === '__no_color__') ? 'all' : String(row[COLOR_COL]);
                            if (!groupedData[colorVal]) {
                                groupedData[colorVal] = {
                                    data: [],
                                    color: colorVal
                                };
                            }
                            groupedData[colorVal].data.push(row);
                        });

                        const row = Math.floor(idx / nCols) + 1;
                        const col = (idx % nCols) + 1;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                        for (let groupKey in groupedData) {
                            const group = groupedData[groupKey];

                            // Sort by order column
                            group.data.sort((a, b) => {
                                const aVal = a[ORDER_COL];
                                const bVal = b[ORDER_COL];
                                if (typeof aVal === 'number' && typeof bVal === 'number') {
                                    return aVal - bVal;
                                }
                                return String(aVal).localeCompare(String(bVal));
                            });

                            const xValues = group.data.map(row => row[X_COL]);
                            const yValues = group.data.map(row => row[Y_COL]);
                            const orderValues = group.data.map(row => row[ORDER_COL]);

                            const legendGroup = group.color;

                            const baseColor = COLOR_MAP[group.color] || '#000000';
                            const markerOpacity = getAlphaValues(xValues.length);

                            const markerConfig = {
                                size: $marker_size,
                                color: baseColor
                            };
                            if (markerOpacity !== undefined) {
                                markerConfig.opacity = markerOpacity;
                            }

                            // Add markers trace
                            traces.push({
                                x: xValues,
                                y: yValues,
                                type: 'scatter',
                                mode: 'markers',
                                name: group.color,
                                legendgroup: legendGroup,
                                showlegend: idx === 0,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                marker: markerConfig,
                                text: orderValues.map(v => ORDER_COL + ': ' + v),
                                hovertemplate: '%{text}<br>' + X_COL + ': %{x}<br>' + Y_COL + ': %{y}<extra></extra>'
                            });

                            // Add connections between points (arrows or lines)
                            if (xValues.length > 1) {
                                if (window.showArrows_$chart_title) {
                                    // Add arrow segments connecting points (each segment is an arrow)
                                    for (let i = 0; i < xValues.length - 1; i++) {
                                        const alpha = USE_ALPHARANGE ? 0.3 + (0.7 * i / (xValues.length - 1)) : 1.0;
                                        const arrowColor = USE_ALPHARANGE ? hexToRgba(baseColor, alpha) : baseColor;

                                        layout.annotations.push({
                                            x: xValues[i + 1],
                                            y: yValues[i + 1],
                                            ax: xValues[i],
                                            ay: yValues[i],
                                            xref: xaxis === 'x' ? 'x' : xaxis,
                                            yref: yaxis === 'y' ? 'y' : yaxis,
                                            axref: xaxis === 'x' ? 'x' : xaxis,
                                            ayref: yaxis === 'y' ? 'y' : yaxis,
                                            showarrow: true,
                                            arrowhead: 2,
                                            arrowsize: 1.5,
                                            arrowwidth: $line_width,
                                            arrowcolor: arrowColor,
                                            opacity: alpha
                                        });
                                    }
                                } else {
                                    // Add line trace connecting points
                                    if (USE_ALPHARANGE) {
                                        // Create individual line segments with varying opacity
                                        for (let i = 0; i < xValues.length - 1; i++) {
                                            const alpha = 0.3 + (0.7 * i / (xValues.length - 1));
                                            const lineColor = hexToRgba(baseColor, alpha);

                                            traces.push({
                                                x: [xValues[i], xValues[i + 1]],
                                                y: [yValues[i], yValues[i + 1]],
                                                type: 'scatter',
                                                mode: 'lines',
                                                line: {
                                                    color: lineColor,
                                                    width: $line_width
                                                },
                                                legendgroup: legendGroup,
                                                showlegend: false,
                                                xaxis: xaxis,
                                                yaxis: yaxis,
                                                hoverinfo: 'skip'
                                            });
                                        }
                                    } else {
                                        // Simple continuous line
                                        traces.push({
                                            x: xValues,
                                            y: yValues,
                                            type: 'scatter',
                                            mode: 'lines',
                                            name: group.color + ' (path)',
                                            legendgroup: legendGroup,
                                            showlegend: false,
                                            xaxis: xaxis,
                                            yaxis: yaxis,
                                            line: {
                                                color: baseColor,
                                                width: $line_width
                                            },
                                            hoverinfo: 'skip'
                                        });
                                    }
                                }
                            }
                        }

                        // Add axis configuration
                        layout[xaxis] = {
                            title: row === nRows ? X_COL : '',
                            anchor: yaxis
                        };
                        layout[yaxis] = {
                            title: col === 1 ? Y_COL : '',
                            anchor: xaxis
                        };

                        // Add annotation for facet label
                        layout.annotations.push({
                            text: facetCol + ': ' + facetVal,
                            showarrow: false,
                            xref: xaxis === 'x' ? 'x domain' : xaxis + ' domain',
                            yref: yaxis === 'y' ? 'y domain' : yaxis + ' domain',
                            x: 0.5,
                            y: 1.05,
                            xanchor: 'center',
                            yanchor: 'bottom',
                            font: {size: 10}
                        });
                    });

                    Plotly.newPlot('$chart_title', traces, layout, {responsive: true});

                } else {
                    // Facet grid (2 facet columns)
                    const facetRow = FACET_COLS[0];
                    const facetCol = FACET_COLS[1];
                    const rowValues = [...new Set(filteredData.map(row => row[facetRow]))].sort();
                    const colValues = [...new Set(filteredData.map(row => row[facetCol]))].sort();
                    const nRows = rowValues.length;
                    const nCols = colValues.length;

                    const traces = [];
                    const layout = {
                        title: '$title',
                        hovermode: 'closest',
                        showlegend: true,
                        grid: {rows: nRows, columns: nCols, pattern: 'independent'},
                        annotations: []
                    };

                    rowValues.forEach((rowVal, rowIdx) => {
                        colValues.forEach((colVal, colIdx) => {
                            const facetData = filteredData.filter(row =>
                                row[facetRow] === rowVal && row[facetCol] === colVal
                            );

                            // Group by color within this facet
                            const groupedData = {};
                            facetData.forEach(row => {
                                const colorVal = (COLOR_COL === '__no_color__') ? 'all' : String(row[COLOR_COL]);
                                if (!groupedData[colorVal]) {
                                    groupedData[colorVal] = {
                                        data: [],
                                        color: colorVal
                                    };
                                }
                                groupedData[colorVal].data.push(row);
                            });

                            const idx = rowIdx * nCols + colIdx;
                            const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                            const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                            for (let groupKey in groupedData) {
                                const group = groupedData[groupKey];

                                // Sort by order column
                                group.data.sort((a, b) => {
                                    const aVal = a[ORDER_COL];
                                    const bVal = b[ORDER_COL];
                                    if (typeof aVal === 'number' && typeof bVal === 'number') {
                                        return aVal - bVal;
                                    }
                                    return String(aVal).localeCompare(String(bVal));
                                });

                                const xValues = group.data.map(row => row[X_COL]);
                                const yValues = group.data.map(row => row[Y_COL]);
                                const orderValues = group.data.map(row => row[ORDER_COL]);

                                const legendGroup = group.color;

                                const baseColor = COLOR_MAP[group.color] || '#000000';
                                const markerOpacity = getAlphaValues(xValues.length);

                                const markerConfig = {
                                    size: $marker_size,
                                    color: baseColor
                                };
                                if (markerOpacity !== undefined) {
                                    markerConfig.opacity = markerOpacity;
                                }

                                // Add markers trace
                                traces.push({
                                    x: xValues,
                                    y: yValues,
                                    type: 'scatter',
                                    mode: 'markers',
                                    name: group.color,
                                    legendgroup: legendGroup,
                                    showlegend: idx === 0,
                                    xaxis: xaxis,
                                    yaxis: yaxis,
                                    marker: markerConfig,
                                    text: orderValues.map(v => ORDER_COL + ': ' + v),
                                    hovertemplate: '%{text}<br>' + X_COL + ': %{x}<br>' + Y_COL + ': %{y}<extra></extra>'
                                });

                                // Add connections between points (arrows or lines)
                                if (xValues.length > 1) {
                                    if (window.showArrows_$chart_title) {
                                        // Add arrow segments connecting points (each segment is an arrow)
                                        for (let i = 0; i < xValues.length - 1; i++) {
                                            const alpha = USE_ALPHARANGE ? 0.3 + (0.7 * i / (xValues.length - 1)) : 1.0;
                                            const arrowColor = USE_ALPHARANGE ? hexToRgba(baseColor, alpha) : baseColor;

                                            layout.annotations.push({
                                                x: xValues[i + 1],
                                                y: yValues[i + 1],
                                                ax: xValues[i],
                                                ay: yValues[i],
                                                xref: xaxis === 'x' ? 'x' : xaxis,
                                                yref: yaxis === 'y' ? 'y' : yaxis,
                                                axref: xaxis === 'x' ? 'x' : xaxis,
                                                ayref: yaxis === 'y' ? 'y' : yaxis,
                                                showarrow: true,
                                                arrowhead: 2,
                                                arrowsize: 1.5,
                                                arrowwidth: $line_width,
                                                arrowcolor: arrowColor,
                                                opacity: alpha
                                            });
                                        }
                                    } else {
                                        // Add line trace connecting points
                                        if (USE_ALPHARANGE) {
                                            // Create individual line segments with varying opacity
                                            for (let i = 0; i < xValues.length - 1; i++) {
                                                const alpha = 0.3 + (0.7 * i / (xValues.length - 1));
                                                const lineColor = hexToRgba(baseColor, alpha);

                                                traces.push({
                                                    x: [xValues[i], xValues[i + 1]],
                                                    y: [yValues[i], yValues[i + 1]],
                                                    type: 'scatter',
                                                    mode: 'lines',
                                                    line: {
                                                        color: lineColor,
                                                        width: $line_width
                                                    },
                                                    legendgroup: legendGroup,
                                                    showlegend: false,
                                                    xaxis: xaxis,
                                                    yaxis: yaxis,
                                                    hoverinfo: 'skip'
                                                });
                                            }
                                        } else {
                                            // Simple continuous line
                                            traces.push({
                                                x: xValues,
                                                y: yValues,
                                                type: 'scatter',
                                                mode: 'lines',
                                                name: group.color + ' (path)',
                                                legendgroup: legendGroup,
                                                showlegend: false,
                                                xaxis: xaxis,
                                                yaxis: yaxis,
                                                line: {
                                                    color: baseColor,
                                                    width: $line_width
                                                },
                                                hoverinfo: 'skip'
                                            });
                                        }
                                    }
                                }
                            }

                            // Add axis configuration
                            layout[xaxis] = {
                                title: rowIdx === nRows - 1 ? X_COL : '',
                                anchor: yaxis
                            };
                            layout[yaxis] = {
                                title: colIdx === 0 ? Y_COL : '',
                                anchor: xaxis
                            };

                            // Add annotations for facet labels
                            // Column header
                            if (rowIdx === 0) {
                                layout.annotations.push({
                                    text: facetCol + ': ' + colVal,
                                    showarrow: false,
                                    xref: xaxis === 'x' ? 'x domain' : xaxis + ' domain',
                                    yref: yaxis === 'y' ? 'y domain' : yaxis + ' domain',
                                    x: 0.5,
                                    y: 1.1,
                                    xanchor: 'center',
                                    yanchor: 'bottom',
                                    font: {size: 10}
                                });
                            }

                            // Row label
                            if (colIdx === nCols - 1) {
                                layout.annotations.push({
                                    text: facetRow + ': ' + rowVal,
                                    showarrow: false,
                                    xref: xaxis === 'x' ? 'x domain' : xaxis + ' domain',
                                    yref: yaxis === 'y' ? 'y domain' : yaxis + ' domain',
                                    x: 1.05,
                                    y: 0.5,
                                    xanchor: 'left',
                                    yanchor: 'middle',
                                    textangle: -90,
                                    font: {size: 10}
                                });
                            }
                        });
                    });

                    Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
                }
            };

            // Arrow/line toggle button handler
            const arrowToggleBtn = document.getElementById('$(chart_title)_arrow_toggle');
            if (arrowToggleBtn) {
                arrowToggleBtn.addEventListener('click', function() {
                    window.showArrows_$chart_title = !window.showArrows_$chart_title;
                    arrowToggleBtn.textContent = window.showArrows_$chart_title ? 'Show Lines' : 'Show Arrows';
                    window.updateChart_$chart_title();
                });
            }

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title();
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # X dimension dropdown
        if length(valid_x_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "x_col_select_$chart_title_str",
                "X dimension",
                [string(col) for col in valid_x_cols],
                string(valid_x_cols[1]),
                update_function
            ))
        end

        # Y dimension dropdown
        if length(valid_y_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "y_col_select_$chart_title_str",
                "Y dimension",
                [string(col) for col in valid_y_cols],
                string(valid_y_cols[1]),
                update_function
            ))
        end

        # Color column dropdown
        if length(valid_color_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "color_col_select_$chart_title_str",
                "Path grouping",
                [string(col) for col in valid_color_cols],
                string(valid_color_cols[1]),
                update_function
            ))
        end

        # Build faceting dropdowns using html_controls abstraction
        facet_dropdowns = build_facet_dropdowns(chart_title_str, facet_choices, default_facet_array, update_function)

        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
            filter_dropdowns,
            attribute_dropdowns,
            facet_dropdowns,
            title,
            notes
        )

        # Generate base appearance HTML
        base_appearance_html = generate_appearance_html(controls)

        # Add arrow toggle button to Plot Attributes section
        arrow_button_html = """
        <div style="margin: 10px;">
            <button id="$(chart_title)_arrow_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_arrows ? "Show Lines" : "Show Arrows")
            </button>
        </div>"""

        # Insert arrow button before the closing </div> of Plot Attributes section
        appearance_html = replace(base_appearance_html,
            "</div>\n        \n        <!-- Faceting -->" =>
            "$arrow_button_html\n        </div>\n        \n        <!-- Faceting -->")
        # If there's no faceting section, insert before chart div
        if !occursin("<!-- Faceting -->", appearance_html)
            appearance_html = replace(base_appearance_html,
                "</div>\n        <!-- Chart -->" =>
                "$arrow_button_html\n        </div>\n        <!-- Chart -->")
        end

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::Path) = [a.data_label]
