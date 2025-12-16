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
- `filters::Dict{Symbol, Any}`: Default filter values (default: `Dict{Symbol,Any}()`)
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
                  filters::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                  facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                  default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                  title::String="Path Chart",
                  line_width::Int=2,
                  marker_size::Int=8,
                  show_arrows::Bool=true,
                  use_alpharange::Bool=false,
                  notes::String="")

        # Get available columns in dataframe
        available_cols = Set(names(df))

        # Validate x_cols
        valid_x_cols = Symbol[]
        for col in x_cols
            if string(col) in available_cols
                push!(valid_x_cols, col)
            end
        end
        if isempty(valid_x_cols)
            error("None of the specified x_cols exist in the dataframe. Available columns: $(names(df))")
        end

        # Validate y_cols
        valid_y_cols = Symbol[]
        for col in y_cols
            if string(col) in available_cols
                push!(valid_y_cols, col)
            end
        end
        if isempty(valid_y_cols)
            error("None of the specified y_cols exist in the dataframe. Available columns: $(names(df))")
        end

        # Validate order_col
        if !(string(order_col) in available_cols)
            error("order_col :$order_col does not exist in the dataframe. Available columns: $(names(df))")
        end

        # Normalize facet_cols to array (possible choices)
        facet_choices = if facet_cols === nothing
            Symbol[]
        elseif facet_cols isa Symbol
            [facet_cols]
        else
            facet_cols
        end

        # Normalize default_facet_cols to array
        default_facet_array = if default_facet_cols === nothing
            Symbol[]
        elseif default_facet_cols isa Symbol
            [default_facet_cols]
        else
            default_facet_cols
        end

        # Validate default facets are in choices
        if length(default_facet_array) > 2
            error("default_facet_cols can have at most 2 columns")
        end
        for col in default_facet_array
            if !(col in facet_choices)
                error("default_facet_cols must be a subset of facet_cols")
            end
        end

        # Get unique values for each filter column
        filter_options = Dict()
        for col in keys(filters)
            filter_options[string(col)] = unique(df[!, col])
        end

        # Build color maps for all possible color columns that exist
        color_palette = ["#636efa", "#EF553B", "#00cc96", "#ab63fa", "#FFA15A",
                        "#19d3f3", "#FF6692", "#B6E880", "#FF97FF", "#FECB52"]
        color_maps = Dict()
        valid_color_cols = Symbol[]
        for col in color_cols
            if string(col) in available_cols
                push!(valid_color_cols, col)
                unique_vals = unique(df[!, col])
                color_maps[string(col)] = Dict(
                    string(key) => color_palette[(i - 1) % length(color_palette) + 1]
                    for (i, key) in enumerate(unique_vals)
                )
            end
        end

        # Build filter dropdowns (multi-select)
        filter_dropdowns_html = ""
        for col in keys(filters)
            default_val = filters[col]
            options_html = ""
            for opt in filter_options[string(col)]
                selected = (opt == default_val) ? " selected" : ""
                options_html *= "                <option value=\"$(opt)\"$selected>$(opt)</option>\n"
            end
            filter_dropdowns_html *= """
            <div style="margin: 10px;">
                <label for="$(string(col))_select">$(col): </label>
                <select id="$(string(col))_select" multiple style="min-width: 150px; height: 100px;" onchange="updateChart_$chart_title()">
    $options_html            </select>
            </div>
            """
        end

        # Create JavaScript arrays for columns
        filter_cols_js = "[" * join(["'$col'" for col in keys(filters)], ", ") * "]"
        x_cols_js = "[" * join(["'$col'" for col in valid_x_cols], ", ") * "]"
        y_cols_js = "[" * join(["'$col'" for col in valid_y_cols], ", ") * "]"
        color_cols_js = "[" * join(["'$col'" for col in valid_color_cols], ", ") * "]"

        # Create color maps as nested JavaScript object
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Default columns
        default_x_col = string(valid_x_cols[1])
        default_y_col = string(valid_y_cols[1])
        default_color_col = isempty(valid_color_cols) ? "__no_color__" : string(valid_color_cols[1])

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
                    const select = document.getElementById(col + '_select');
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

                        // Add line segments with alpha gradient
                        if (USE_ALPHARANGE && xValues.length > 1) {
                            // Create individual line segments with varying alpha
                            for (let i = 0; i < xValues.length - 1; i++) {
                                const alpha = 0.3 + (0.7 * i / (xValues.length - 1));
                                traces.push({
                                    x: [xValues[i], xValues[i + 1]],
                                    y: [yValues[i], yValues[i + 1]],
                                    type: 'scatter',
                                    mode: 'lines',
                                    line: {
                                        color: hexToRgba(baseColor, alpha),
                                        width: $line_width
                                    },
                                    showlegend: false,
                                    hoverinfo: 'skip'
                                });
                            }
                        } else {
                            // Single line trace without alpha gradient
                            traces.push({
                                x: xValues,
                                y: yValues,
                                type: 'scatter',
                                mode: 'lines',
                                line: {
                                    color: baseColor,
                                    width: $line_width
                                },
                                showlegend: false,
                                hoverinfo: 'skip'
                            });
                        }

                        // Add arrow annotations $(show_arrows ? "if true" : "if false")
                        if ($show_arrows && xValues.length > 1) {
                            // Add arrows every few points to show direction
                            const arrowInterval = Math.max(1, Math.floor(xValues.length / 5));
                            for (let i = arrowInterval; i < xValues.length; i += arrowInterval) {
                                annotations.push({
                                    x: xValues[i],
                                    y: yValues[i],
                                    ax: xValues[i - 1],
                                    ay: yValues[i - 1],
                                    xref: 'x',
                                    yref: 'y',
                                    axref: 'x',
                                    ayref: 'y',
                                    showarrow: true,
                                    arrowhead: 2,
                                    arrowsize: 1,
                                    arrowwidth: 1,
                                    arrowcolor: COLOR_MAP[group.color] || '#000000',
                                    opacity: 0.4
                                });
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

                            // Add line segments with alpha gradient
                            if (USE_ALPHARANGE && xValues.length > 1) {
                                for (let i = 0; i < xValues.length - 1; i++) {
                                    const alpha = 0.3 + (0.7 * i / (xValues.length - 1));
                                    traces.push({
                                        x: [xValues[i], xValues[i + 1]],
                                        y: [yValues[i], yValues[i + 1]],
                                        type: 'scatter',
                                        mode: 'lines',
                                        line: {
                                            color: hexToRgba(baseColor, alpha),
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
                                traces.push({
                                    x: xValues,
                                    y: yValues,
                                    type: 'scatter',
                                    mode: 'lines',
                                    line: {
                                        color: baseColor,
                                        width: $line_width
                                    },
                                    legendgroup: legendGroup,
                                    showlegend: false,
                                    xaxis: xaxis,
                                    yaxis: yaxis,
                                    hoverinfo: 'skip'
                                });
                            }

                            // Add arrow annotations
                            if ($show_arrows && xValues.length > 1) {
                                const arrowInterval = Math.max(1, Math.floor(xValues.length / 5));
                                for (let i = arrowInterval; i < xValues.length; i += arrowInterval) {
                                    layout.annotations.push({
                                        x: xValues[i],
                                        y: yValues[i],
                                        ax: xValues[i - 1],
                                        ay: yValues[i - 1],
                                        xref: xaxis === 'x' ? 'x' : xaxis,
                                        yref: yaxis === 'y' ? 'y' : yaxis,
                                        axref: xaxis === 'x' ? 'x' : xaxis,
                                        ayref: yaxis === 'y' ? 'y' : yaxis,
                                        showarrow: true,
                                        arrowhead: 2,
                                        arrowsize: 1,
                                        arrowwidth: 1,
                                        arrowcolor: COLOR_MAP[group.color] || '#000000',
                                        opacity: 0.4
                                    });
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

                                // Add line segments with alpha gradient
                                if (USE_ALPHARANGE && xValues.length > 1) {
                                    for (let i = 0; i < xValues.length - 1; i++) {
                                        const alpha = 0.3 + (0.7 * i / (xValues.length - 1));
                                        traces.push({
                                            x: [xValues[i], xValues[i + 1]],
                                            y: [yValues[i], yValues[i + 1]],
                                            type: 'scatter',
                                            mode: 'lines',
                                            line: {
                                                color: hexToRgba(baseColor, alpha),
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
                                    traces.push({
                                        x: xValues,
                                        y: yValues,
                                        type: 'scatter',
                                        mode: 'lines',
                                        line: {
                                            color: baseColor,
                                            width: $line_width
                                        },
                                        legendgroup: legendGroup,
                                        showlegend: false,
                                        xaxis: xaxis,
                                        yaxis: yaxis,
                                        hoverinfo: 'skip'
                                    });
                                }

                                // Add arrow annotations
                                if ($show_arrows && xValues.length > 1) {
                                    const arrowInterval = Math.max(1, Math.floor(xValues.length / 5));
                                    for (let i = arrowInterval; i < xValues.length; i += arrowInterval) {
                                        layout.annotations.push({
                                            x: xValues[i],
                                            y: yValues[i],
                                            ax: xValues[i - 1],
                                            ay: yValues[i - 1],
                                            xref: xaxis === 'x' ? 'x' : xaxis,
                                            yref: yaxis === 'y' ? 'y' : yaxis,
                                            axref: xaxis === 'x' ? 'x' : xaxis,
                                            ayref: yaxis === 'y' ? 'y' : yaxis,
                                            showarrow: true,
                                            arrowhead: 2,
                                            arrowsize: 1,
                                            arrowwidth: 1,
                                            arrowcolor: COLOR_MAP[group.color] || '#000000',
                                            opacity: 0.4
                                        });
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

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title();
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        # Build non-facet controls
        non_facet_controls = ""

        # X dimension dropdown
        if length(valid_x_cols) > 1
            x_options = ""
            for col in valid_x_cols
                selected = (col == valid_x_cols[1]) ? " selected" : ""
                x_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end
            non_facet_controls *= """
            <div style="margin: 10px;">
                <label for="x_col_select_$chart_title">X dimension: </label>
                <select id="x_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $x_options            </select>
            </div>
            """
        end

        # Y dimension dropdown
        if length(valid_y_cols) > 1
            y_options = ""
            for col in valid_y_cols
                selected = (col == valid_y_cols[1]) ? " selected" : ""
                y_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end
            non_facet_controls *= """
            <div style="margin: 10px;">
                <label for="y_col_select_$chart_title">Y dimension: </label>
                <select id="y_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $y_options            </select>
            </div>
            """
        end

        # Build color column dropdown
        if length(valid_color_cols) > 1
            color_options = ""
            for col in valid_color_cols
                selected = (col == valid_color_cols[1]) ? " selected" : ""
                color_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end
            non_facet_controls *= """
            <div style="margin: 10px;">
                <label for="color_col_select_$chart_title">Path grouping: </label>
                <select id="color_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $color_options            </select>
            </div>
            """
        end

        # Build facet controls separately
        facet_controls = ""
        if length(facet_choices) == 1
            # Single facet option - just on/off toggle
            default_facet1 = length(default_facet_array) >= 1 ? string(default_facet_array[1]) : "None"
            facet_col = facet_choices[1]
            facet1_options = ""
            facet1_options *= "                <option value=\"None\"$(default_facet1 == "None" ? " selected" : "")>None</option>\n"
            facet1_options *= "                <option value=\"$facet_col\"$(default_facet1 == string(facet_col) ? " selected" : "")>$facet_col</option>\n"

            facet_controls *= """
            <div style="margin: 10px;">
                <label for="facet1_select_$chart_title">Facet by: </label>
                <select id="facet1_select_$chart_title" onchange="updateChart_$chart_title()">
    $facet1_options            </select>
            </div>
            """
        elseif length(facet_choices) >= 2
            # Multiple facet options - show both facet 1 and facet 2 dropdowns
            # Facet 1 dropdown
            default_facet1 = length(default_facet_array) >= 1 ? string(default_facet_array[1]) : "None"
            facet1_options = ""
            facet1_options *= "                <option value=\"None\"$(default_facet1 == "None" ? " selected" : "")>None</option>\n"
            for col in facet_choices
                selected = (string(col) == default_facet1) ? " selected" : ""
                facet1_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end

            facet_controls *= """
            <div style="margin: 10px;">
                <label for="facet1_select_$chart_title">Facet 1: </label>
                <select id="facet1_select_$chart_title" onchange="updateChart_$chart_title()">
    $facet1_options            </select>
            </div>
            """

            # Facet 2 dropdown
            default_facet2 = length(default_facet_array) >= 2 ? string(default_facet_array[2]) : "None"
            facet2_options = ""
            facet2_options *= "                <option value=\"None\"$(default_facet2 == "None" ? " selected" : "")>None</option>\n"
            for col in facet_choices
                selected = (string(col) == default_facet2) ? " selected" : ""
                facet2_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end

            facet_controls *= """
            <div style="margin: 10px;">
                <label for="facet2_select_$chart_title">Facet 2: </label>
                <select id="facet2_select_$chart_title" onchange="updateChart_$chart_title()">
    $facet2_options            </select>
            </div>
            """
        end

        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters (for data filtering) -->
        $(filter_dropdowns_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;\">\n            <h4 style=\"margin-top: 0;\">Filters</h4>\n            $filter_dropdowns_html\n        </div>" : "")

        <!-- Plot Attributes (x, y, color) -->
        $(non_facet_controls != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0f8ff;\">\n            <h4 style=\"margin-top: 0;\">Plot Attributes</h4>\n            $non_facet_controls\n        </div>" : "")

        <!-- Faceting -->
        $(facet_controls != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff8f0;\">\n            <h4 style=\"margin-top: 0;\">Faceting</h4>\n            $facet_controls\n        </div>" : "")

        <!-- Chart -->
        <div id="$chart_title"></div>
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::Path) = [a.data_label]
