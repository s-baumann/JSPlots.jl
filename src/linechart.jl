"""
    LineChart(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Time series or sequential data visualization with interactive filtering.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_cols::Vector{Symbol}`: Columns available for x-axis (default: `[:x]`)
- `y_cols::Vector{Symbol}`: Columns available for y-axis (default: `[:y]`)
- `color_cols::Vector{Symbol}`: Columns available for color grouping (default: `Symbol[]`)
- `filters::Dict{Symbol, Any}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `aggregator::String`: Aggregation function - "none", "mean", "median", "count", "min", or "max" (default: `"none"`)
- `title::String`: Chart title (default: `"Line Chart"`)
- `line_width::Int`: Width of lines (default: `1`)
- `marker_size::Int`: Size of markers (default: `1`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
lc = LineChart(:sales_chart, df, :sales_data,
    x_cols=[:date],
    y_cols=[:revenue],
    color_cols=[:region],
    title="Sales Over Time"
)
```
"""
struct LineChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function LineChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_cols::Vector{Symbol}=[:x],
                            y_cols::Vector{Symbol}=[:y],
                            color_cols::Vector{Symbol}=Symbol[],
                            filters::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            aggregator::String="none",
                            title::String="Line Chart",
                            line_width::Int=1,
                            marker_size::Int=1,
                            notes::String="")

        # Validate columns exist in dataframe
        valid_x_cols = validate_and_filter_columns(x_cols, df, "x_cols")
        valid_y_cols = validate_and_filter_columns(y_cols, df, "y_cols")

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Validate aggregator
        valid_aggregators = ["none", "mean", "median", "count", "min", "max"]
        if !(aggregator in valid_aggregators)
            error("aggregator must be one of: $(join(valid_aggregators, ", "))")
        end

        # Get unique values for each filter column
        filter_options = build_filter_options(filters, df)

        # Build color maps for all possible color columns that exist
        color_maps, valid_color_cols = build_color_maps(color_cols, df)
        # If no color columns specified or valid, we'll use a default black color for all lines

        # Build HTML controls using abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns = build_filter_dropdowns(chart_title_str, filters, df, update_function)

        # Create JavaScript arrays for columns
        filter_cols_js = build_js_array(collect(keys(filters)))
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

            let allData = [];

            // Aggregation functions
            function aggregate(values, method) {
                if (values.length === 0) return null;
                if (method === 'none') return values;
                if (method === 'count') return [values.length];
                if (method === 'mean') {
                    const sum = values.reduce((a, b) => a + b, 0);
                    return [sum / values.length];
                }
                if (method === 'median') {
                    const sorted = [...values].sort((a, b) => a - b);
                    const mid = Math.floor(sorted.length / 2);
                    return sorted.length % 2 === 0 ?
                        [(sorted[mid - 1] + sorted[mid]) / 2] :
                        [sorted[mid]];
                }
                if (method === 'min') return [Math.min(...values)];
                if (method === 'max') return [Math.max(...values)];
                return values;
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

                // Get current aggregator
                const aggregatorSelect = document.getElementById('aggregator_select_$chart_title');
                const AGGREGATOR = aggregatorSelect ? aggregatorSelect.value : 'none';

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
                    for (let groupKey in groupedData) {
                        const group = groupedData[groupKey];
                        group.data.sort((a, b) => a[X_COL] - b[X_COL]);

                        let xValues, yValues;
                        if (AGGREGATOR === 'none') {
                            xValues = group.data.map(row => row[X_COL]);
                            yValues = group.data.map(row => row[Y_COL]);
                        } else {
                            // Group by x value and aggregate
                            const xGroups = {};
                            group.data.forEach(row => {
                                const xVal = row[X_COL];
                                if (!xGroups[xVal]) xGroups[xVal] = [];
                                xGroups[xVal].push(row[Y_COL]);
                            });

                            xValues = [];
                            yValues = [];
                            // Sort keys - try numeric sort first, fall back to string sort
                            const sortedKeys = Object.keys(xGroups).sort((a, b) => {
                                const aNum = parseFloat(a);
                                const bNum = parseFloat(b);
                                if (!isNaN(aNum) && !isNaN(bNum)) {
                                    return aNum - bNum;
                                }
                                return String(a).localeCompare(String(b));
                            });

                            sortedKeys.forEach(xVal => {
                                const aggregated = aggregate(xGroups[xVal], AGGREGATOR);
                                if (aggregated && aggregated.length > 0) {
                                    // Keep original value type (don't force to float for strings)
                                    const numVal = parseFloat(xVal);
                                    xValues.push(isNaN(numVal) ? xVal : numVal);
                                    yValues.push(aggregated[0]);
                                }
                            });
                        }

                        traces.push({
                            x: xValues,
                            y: yValues,
                            type: 'scatter',
                            mode: 'lines+markers',
                            name: group.color,
                            line: {
                                color: COLOR_MAP[group.color] || '#000000',
                                width: $line_width
                            },
                            marker: { size: $marker_size }
                        });
                    }

                    const layout = {
                        xaxis: { title: X_COL },
                        yaxis: { title: Y_COL },
                        hovermode: 'closest',
                        showlegend: true
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
                        hovermode: 'closest',
                        showlegend: true,
                        grid: {rows: nRows, columns: nCols, pattern: 'independent'}
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
                            group.data.sort((a, b) => a[X_COL] - b[X_COL]);

                            let xValues, yValues;
                            if (AGGREGATOR === 'none') {
                                xValues = group.data.map(row => row[X_COL]);
                                yValues = group.data.map(row => row[Y_COL]);
                            } else {
                                // Group by x value and aggregate
                                const xGroups = {};
                                group.data.forEach(row => {
                                    const xVal = row[X_COL];
                                    if (!xGroups[xVal]) xGroups[xVal] = [];
                                    xGroups[xVal].push(row[Y_COL]);
                                });

                                xValues = [];
                                yValues = [];
                                // Sort keys - try numeric sort first, fall back to string sort
                                const sortedKeys = Object.keys(xGroups).sort((a, b) => {
                                    const aNum = parseFloat(a);
                                    const bNum = parseFloat(b);
                                    if (!isNaN(aNum) && !isNaN(bNum)) {
                                        return aNum - bNum;
                                    }
                                    return String(a).localeCompare(String(b));
                                });

                                sortedKeys.forEach(xVal => {
                                    const aggregated = aggregate(xGroups[xVal], AGGREGATOR);
                                    if (aggregated && aggregated.length > 0) {
                                        // Keep original value type (don't force to float for strings)
                                        const numVal = parseFloat(xVal);
                                        xValues.push(isNaN(numVal) ? xVal : numVal);
                                        yValues.push(aggregated[0]);
                                    }
                                });
                            }

                            const legendGroup = group.color;

                            traces.push({
                                x: xValues,
                                y: yValues,
                                type: 'scatter',
                                mode: 'lines+markers',
                                name: group.color,
                                legendgroup: legendGroup,
                                showlegend: idx === 0,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                line: {
                                    color: COLOR_MAP[group.color] || '#000000',
                                    width: $line_width
                                },
                                marker: { size: $marker_size }
                            });
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
                        if (!layout.annotations) layout.annotations = [];
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
                        hovermode: 'closest',
                        showlegend: true,
                        grid: {rows: nRows, columns: nCols, pattern: 'independent'}
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
                                group.data.sort((a, b) => a[X_COL] - b[X_COL]);

                                let xValues, yValues;
                                if (AGGREGATOR === 'none') {
                                    xValues = group.data.map(row => row[X_COL]);
                                    yValues = group.data.map(row => row[Y_COL]);
                                } else {
                                    // Group by x value and aggregate
                                    const xGroups = {};
                                    group.data.forEach(row => {
                                        const xVal = row[X_COL];
                                        if (!xGroups[xVal]) xGroups[xVal] = [];
                                        xGroups[xVal].push(row[Y_COL]);
                                    });

                                    xValues = [];
                                    yValues = [];
                                    const sortedKeys = Object.keys(xGroups).sort((a, b) => {
                                        const aNum = parseFloat(a);
                                        const bNum = parseFloat(b);
                                        if (!isNaN(aNum) && !isNaN(bNum)) {
                                            return aNum - bNum;
                                        }
                                        return String(a).localeCompare(String(b));
                                    });

                                    sortedKeys.forEach(xVal => {
                                        const aggregated = aggregate(xGroups[xVal], AGGREGATOR);
                                        if (aggregated && aggregated.length > 0) {
                                            const numVal = parseFloat(xVal);
                                            xValues.push(isNaN(numVal) ? xVal : numVal);
                                            yValues.push(aggregated[0]);
                                        }
                                    });
                                }

                                const legendGroup = group.color;

                                traces.push({
                                    x: xValues,
                                    y: yValues,
                                    type: 'scatter',
                                    mode: 'lines+markers',
                                    name: group.color,
                                    legendgroup: legendGroup,
                                    showlegend: idx === 0,
                                    xaxis: xaxis,
                                    yaxis: yaxis,
                                    line: {
                                        color: COLOR_MAP[group.color] || '#000000',
                                        width: $line_width
                                    },
                                    marker: { size: $marker_size }
                                });
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
                            if (!layout.annotations) layout.annotations = [];

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
                "Color by",
                [string(col) for col in valid_color_cols],
                string(valid_color_cols[1]),
                update_function
            ))
        end

        # Aggregator dropdown (always shown)
        push!(attribute_dropdowns, DropdownControl(
            "aggregator_select_$chart_title_str",
            "Aggregator",
            ["none", "mean", "median", "count", "min", "max"],
            aggregator,
            update_function
        ))

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
        appearance_html = generate_appearance_html(controls)

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::LineChart) = [a.data_label]

