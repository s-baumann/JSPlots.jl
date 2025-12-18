"""
    AreaChart(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Area chart visualization with support for stacking modes and interactive controls.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_cols::Vector{Symbol}`: Columns available for x-axis (default: `[:x]`)
- `y_cols::Vector{Symbol}`: Columns available for y-axis (default: `[:y]`)
- `group_cols::Vector{Symbol}`: Columns available for grouping/coloring areas (default: `Symbol[]`)
- `filters::Dict{Symbol, Any}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `stack_mode::String`: Stacking mode - "unstack", "stack", or "normalised_stack" (default: `"stack"`)
- `title::String`: Chart title (default: `"Area Chart"`)
- `fill_opacity::Float64`: Opacity of filled areas (0-1) (default: `0.6`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Stacking Modes
- `unstack`: Areas are overlaid with transparency, allowing all to be visible
- `stack`: Areas are stacked on top of each other, showing cumulative values
- `normalised_stack`: Areas are stacked and normalized to 100%, showing proportions

# Examples
```julia
ac = AreaChart(:sales_chart, df, :sales_data,
    x_cols=[:date],
    y_cols=[:revenue],
    group_cols=[:region],
    stack_mode="stack",
    title="Sales by Region Over Time"
)
```
"""
struct AreaChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function AreaChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_cols::Vector{Symbol}=[:x],
                            y_cols::Vector{Symbol}=[:y],
                            group_cols::Vector{Symbol}=Symbol[],
                            filters::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            stack_mode::String="stack",
                            title::String="Area Chart",
                            fill_opacity::Float64=0.6,
                            notes::String="")

        # Sanitize chart title for use in JavaScript/HTML IDs
        chart_title_safe = string(sanitize_chart_title(chart_title))

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

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Validate stack_mode
        valid_stack_modes = ["unstack", "stack", "normalised_stack"]
        if !(stack_mode in valid_stack_modes)
            error("stack_mode must be one of: $(join(valid_stack_modes, ", "))")
        end

        # Validate fill_opacity
        if fill_opacity < 0.0 || fill_opacity > 1.0
            error("fill_opacity must be between 0.0 and 1.0")
        end

        # Get unique values for each filter column
        filter_options = Dict()
        for col in keys(filters)
            filter_options[string(col)] = unique(df[!, col])
        end

        # Build color maps for all possible group columns that exist
        color_palette = DEFAULT_COLOR_PALETTE
        color_maps = Dict()
        valid_group_cols = Symbol[]
        group_order_maps = Dict()  # Track order of first appearance for each group
        for col in group_cols
            if string(col) in available_cols
                push!(valid_group_cols, col)
                # Preserve order of first appearance
                unique_vals = unique(df[!, col])
                color_maps[string(col)] = Dict(
                    string(key) => color_palette[(i - 1) % length(color_palette) + 1]
                    for (i, key) in enumerate(unique_vals)
                )
                # Store order for JavaScript
                group_order_maps[string(col)] = [string(val) for val in unique_vals]
            end
        end

        # Build HTML controls using abstraction
        update_function = "updatePlot_$chart_title_safe()"
        filter_dropdowns = build_filter_dropdowns(chart_title_safe, filters, df, update_function)

        # Create JavaScript arrays for columns
        filter_cols_js = "[" * join(["'$col'" for col in keys(filters)], ", ") * "]"
        x_cols_js = "[" * join(["'$col'" for col in valid_x_cols], ", ") * "]"
        y_cols_js = "[" * join(["'$col'" for col in valid_y_cols], ", ") * "]"
        group_cols_js = "[" * join(["'$col'" for col in valid_group_cols], ", ") * "]"

        # Create color maps as nested JavaScript object
        color_maps_js = if isempty(color_maps)
            "{}"
        else
            "{" * join([
                "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
                for (col, map) in color_maps
            ], ", ") * "}"
        end

        # Create group order maps as nested JavaScript object
        group_order_js = if isempty(group_order_maps)
            "{}"
        else
            "{" * join([
                "'$col': [" * join(["'$val'" for val in vals], ", ") * "]"
                for (col, vals) in group_order_maps
            ], ", ") * "}"
        end

        # Default columns
        default_x_col = string(valid_x_cols[1])
        default_y_col = string(valid_y_cols[1])
        default_group_col = isempty(valid_group_cols) ? "__no_group__" : string(valid_group_cols[1])

        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const X_COLS = $x_cols_js;
            const Y_COLS = $y_cols_js;
            const GROUP_COLS = $group_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const GROUP_ORDER = $group_order_js;
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_GROUP_COL = '$default_group_col';
            const FILL_OPACITY = $fill_opacity;

            let allData = [];

            // Detect if x values are discrete or continuous
            function isDiscrete(values) {
                // Consider discrete if we have strings, or if numeric with small number of unique values
                const sample = values[0];
                if (typeof sample === 'string') return true;

                const uniqueVals = [...new Set(values)];
                // If less than 20 unique values and they look like categories, treat as discrete
                return uniqueVals.length < 20 && uniqueVals.every(v => Number.isInteger(v) || typeof v === 'string');
            }

            // Make it global so inline onchange can see it
            window.updatePlot_$chart_title_safe = function() {
                // Get current X and Y columns
                const xColSelect = document.getElementById('x_col_select_$chart_title_safe');
                const X_COL = xColSelect ? xColSelect.value : DEFAULT_X_COL;

                const yColSelect = document.getElementById('y_col_select_$chart_title_safe');
                const Y_COL = yColSelect ? yColSelect.value : DEFAULT_Y_COL;

                // Get current filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Get current group column
                const groupColSelect = document.getElementById('group_col_select_$chart_title_safe');
                const GROUP_COL = groupColSelect ? groupColSelect.value : DEFAULT_GROUP_COL;

                // Get current stack mode
                const stackModeSelect = document.getElementById('stack_mode_select_$chart_title_safe');
                const STACK_MODE = stackModeSelect ? stackModeSelect.value : '$stack_mode';

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title_safe');
                const facet2Select = document.getElementById('facet2_select_$chart_title_safe');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                // Build FACET_COLS array based on selections
                const FACET_COLS = [];
                if (facet1) FACET_COLS.push(facet1);
                if (facet2) FACET_COLS.push(facet2);

                // Get color map and group order for current selection
                const COLOR_MAP = COLOR_MAPS[GROUP_COL] || {};
                const GROUP_ORDER_ARRAY = GROUP_ORDER[GROUP_COL] || [];

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
                    // No faceting - create area chart
                    const groupedData = {};
                    filteredData.forEach(row => {
                        const groupVal = (GROUP_COL === '__no_group__') ? 'all' : String(row[GROUP_COL]);
                        if (!groupedData[groupVal]) {
                            groupedData[groupVal] = [];
                        }
                        groupedData[groupVal].push(row);
                    });

                    // Get groups in order of appearance
                    const orderedGroups = GROUP_ORDER_ARRAY.length > 0 ?
                        GROUP_ORDER_ARRAY.filter(g => groupedData[g]) :
                        Object.keys(groupedData);

                    const traces = [];
                    const discrete = isDiscrete(filteredData.map(row => row[X_COL]));

                    for (let groupKey of orderedGroups) {
                        const groupData = groupedData[groupKey];
                        groupData.sort((a, b) => {
                            const aVal = a[X_COL];
                            const bVal = b[X_COL];
                            if (typeof aVal === 'string') return aVal.localeCompare(bVal);
                            return aVal - bVal;
                        });

                        const xValues = groupData.map(row => row[X_COL]);
                        const yValues = groupData.map(row => row[Y_COL]);

                        const color = COLOR_MAP[groupKey] || '#636efa';
                        const trace = {
                            x: xValues,
                            y: yValues,
                            name: groupKey,
                            type: discrete ? 'bar' : 'scatter'
                        };

                        if (discrete) {
                            // Bar chart style
                            trace.marker = {color: color};
                        } else {
                            // Area chart style
                            trace.mode = 'lines';
                            trace.line = {color: color, width: 0};
                        }

                        // Apply stacking mode
                        if (STACK_MODE === 'unstack') {
                            if (!discrete) {
                                trace.fill = 'tozeroy';
                                // Convert hex to rgba
                                if (color.startsWith('#')) {
                                    const r = parseInt(color.substr(1,2), 16);
                                    const g = parseInt(color.substr(3,2), 16);
                                    const b = parseInt(color.substr(5,2), 16);
                                    trace.fillcolor = `rgba(\${r}, \${g}, \${b}, \${FILL_OPACITY})`;
                                }
                            } else {
                                trace.opacity = FILL_OPACITY;
                            }
                        } else if (STACK_MODE === 'stack') {
                            if (discrete) {
                                trace.type = 'bar';
                            } else {
                                trace.fill = 'tonexty';
                                trace.stackgroup = 'one';
                            }
                        } else if (STACK_MODE === 'normalised_stack') {
                            if (discrete) {
                                trace.type = 'bar';
                            } else {
                                trace.fill = 'tonexty';
                                trace.stackgroup = 'one';
                                trace.groupnorm = 'percent';
                            }
                        }

                        traces.push(trace);
                    }

                    const layout = {
                        xaxis: { title: X_COL },
                        yaxis: {
                            title: STACK_MODE === 'normalised_stack' ? Y_COL + ' (%)' : Y_COL
                        },
                        hovermode: 'closest',
                        showlegend: true,
                        barmode: STACK_MODE === 'stack' || STACK_MODE === 'normalised_stack' ? 'stack' : 'overlay',
                        barnorm: STACK_MODE === 'normalised_stack' ? 'percent' : undefined
                    };

                    Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true});

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
                        grid: {rows: nRows, columns: nCols, pattern: 'independent'},
                        barmode: STACK_MODE === 'stack' || STACK_MODE === 'normalised_stack' ? 'stack' : 'overlay',
                        barnorm: STACK_MODE === 'normalised_stack' ? 'percent' : undefined
                    };

                    facetValues.forEach((facetVal, idx) => {
                        const facetData = filteredData.filter(row => row[facetCol] === facetVal);

                        // Group by group column within this facet
                        const groupedData = {};
                        facetData.forEach(row => {
                            const groupVal = (GROUP_COL === '__no_group__') ? 'all' : String(row[GROUP_COL]);
                            if (!groupedData[groupVal]) {
                                groupedData[groupVal] = [];
                            }
                            groupedData[groupVal].push(row);
                        });

                        const orderedGroups = GROUP_ORDER_ARRAY.length > 0 ?
                            GROUP_ORDER_ARRAY.filter(g => groupedData[g]) :
                            Object.keys(groupedData);

                        const row = Math.floor(idx / nCols) + 1;
                        const col = (idx % nCols) + 1;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                        const discrete = isDiscrete(facetData.map(row => row[X_COL]));

                        for (let groupKey of orderedGroups) {
                            const groupData = groupedData[groupKey];
                            groupData.sort((a, b) => {
                                const aVal = a[X_COL];
                                const bVal = b[X_COL];
                                if (typeof aVal === 'string') return aVal.localeCompare(bVal);
                                return aVal - bVal;
                            });

                            const xValues = groupData.map(row => row[X_COL]);
                            const yValues = groupData.map(row => row[Y_COL]);

                            const color = COLOR_MAP[groupKey] || '#636efa';
                            const legendGroup = groupKey;

                            const trace = {
                                x: xValues,
                                y: yValues,
                                name: groupKey,
                                legendgroup: legendGroup,
                                showlegend: idx === 0,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                type: discrete ? 'bar' : 'scatter'
                            };

                            if (discrete) {
                                trace.marker = {color: color};
                            } else {
                                trace.mode = 'lines';
                                trace.line = {color: color, width: 0};
                            }

                            // Apply stacking mode
                            if (STACK_MODE === 'unstack') {
                                if (!discrete) {
                                    trace.fill = 'tozeroy';
                                    if (color.startsWith('#')) {
                                        const r = parseInt(color.substr(1,2), 16);
                                        const g = parseInt(color.substr(3,2), 16);
                                        const b = parseInt(color.substr(5,2), 16);
                                        trace.fillcolor = `rgba(\${r}, \${g}, \${b}, \${FILL_OPACITY})`;
                                    }
                                } else {
                                    trace.opacity = FILL_OPACITY;
                                }
                            } else if (STACK_MODE === 'stack') {
                                if (!discrete) {
                                    trace.fill = 'tonexty';
                                    trace.stackgroup = 'one' + idx;
                                }
                            } else if (STACK_MODE === 'normalised_stack') {
                                if (!discrete) {
                                    trace.fill = 'tonexty';
                                    trace.stackgroup = 'one' + idx;
                                    trace.groupnorm = 'percent';
                                }
                            }

                            traces.push(trace);
                        }

                        // Add axis configuration
                        layout[xaxis] = {
                            title: row === nRows ? X_COL : '',
                            anchor: yaxis
                        };
                        layout[yaxis] = {
                            title: col === 1 ? (STACK_MODE === 'normalised_stack' ? Y_COL + ' (%)' : Y_COL) : '',
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

                    Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true});

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
                        grid: {rows: nRows, columns: nCols, pattern: 'independent'},
                        barmode: STACK_MODE === 'stack' || STACK_MODE === 'normalised_stack' ? 'stack' : 'overlay',
                        barnorm: STACK_MODE === 'normalised_stack' ? 'percent' : undefined
                    };

                    rowValues.forEach((rowVal, rowIdx) => {
                        colValues.forEach((colVal, colIdx) => {
                            const facetData = filteredData.filter(row =>
                                row[facetRow] === rowVal && row[facetCol] === colVal
                            );

                            // Group by group column within this facet
                            const groupedData = {};
                            facetData.forEach(row => {
                                const groupVal = (GROUP_COL === '__no_group__') ? 'all' : String(row[GROUP_COL]);
                                if (!groupedData[groupVal]) {
                                    groupedData[groupVal] = [];
                                }
                                groupedData[groupVal].push(row);
                            });

                            const orderedGroups = GROUP_ORDER_ARRAY.length > 0 ?
                                GROUP_ORDER_ARRAY.filter(g => groupedData[g]) :
                                Object.keys(groupedData);

                            const idx = rowIdx * nCols + colIdx;
                            const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                            const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                            const discrete = isDiscrete(facetData.map(row => row[X_COL]));

                            for (let groupKey of orderedGroups) {
                                const groupData = groupedData[groupKey];
                                groupData.sort((a, b) => {
                                    const aVal = a[X_COL];
                                    const bVal = b[X_COL];
                                    if (typeof aVal === 'string') return aVal.localeCompare(bVal);
                                    return aVal - bVal;
                                });

                                const xValues = groupData.map(row => row[X_COL]);
                                const yValues = groupData.map(row => row[Y_COL]);

                                const color = COLOR_MAP[groupKey] || '#636efa';
                                const legendGroup = groupKey;

                                const trace = {
                                    x: xValues,
                                    y: yValues,
                                    name: groupKey,
                                    legendgroup: legendGroup,
                                    showlegend: idx === 0,
                                    xaxis: xaxis,
                                    yaxis: yaxis,
                                    type: discrete ? 'bar' : 'scatter'
                                };

                                if (discrete) {
                                    trace.marker = {color: color};
                                } else {
                                    trace.mode = 'lines';
                                    trace.line = {color: color, width: 0};
                                }

                                // Apply stacking mode
                                if (STACK_MODE === 'unstack') {
                                    if (!discrete) {
                                        trace.fill = 'tozeroy';
                                        if (color.startsWith('#')) {
                                            const r = parseInt(color.substr(1,2), 16);
                                            const g = parseInt(color.substr(3,2), 16);
                                            const b = parseInt(color.substr(5,2), 16);
                                            trace.fillcolor = `rgba(\${r}, \${g}, \${b}, \${FILL_OPACITY})`;
                                        }
                                    } else {
                                        trace.opacity = FILL_OPACITY;
                                    }
                                } else if (STACK_MODE === 'stack') {
                                    if (!discrete) {
                                        trace.fill = 'tonexty';
                                        trace.stackgroup = 'one' + idx;
                                    }
                                } else if (STACK_MODE === 'normalised_stack') {
                                    if (!discrete) {
                                        trace.fill = 'tonexty';
                                        trace.stackgroup = 'one' + idx;
                                        trace.groupnorm = 'percent';
                                    }
                                }

                                traces.push(trace);
                            }

                            // Add axis configuration
                            layout[xaxis] = {
                                title: rowIdx === nRows - 1 ? X_COL : '',
                                anchor: yaxis
                            };
                            layout[yaxis] = {
                                title: colIdx === 0 ? (STACK_MODE === 'normalised_stack' ? Y_COL + ' (%)' : Y_COL) : '',
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

                    Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true});
                }
            };

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updatePlot_$chart_title_safe();
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title_safe:', error);
            });
        })();
        """

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # X dimension dropdown
        if length(valid_x_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "x_col_select_$chart_title_safe",
                "X dimension",
                [string(col) for col in valid_x_cols],
                string(valid_x_cols[1]),
                update_function
            ))
        end

        # Y dimension dropdown
        if length(valid_y_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "y_col_select_$chart_title_safe",
                "Y dimension",
                [string(col) for col in valid_y_cols],
                string(valid_y_cols[1]),
                update_function
            ))
        end

        # Group column dropdown
        if length(valid_group_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "group_col_select_$chart_title_safe",
                "Group by",
                [string(col) for col in valid_group_cols],
                string(valid_group_cols[1]),
                update_function
            ))
        end

        # Stack mode dropdown (always shown)
        stack_mode_display = ["unstack", "stack", "normalized stack"]
        stack_mode_values = ["unstack", "stack", "normalised_stack"]
        # Map display names to values for the dropdown
        push!(attribute_dropdowns, DropdownControl(
            "stack_mode_select_$chart_title_safe",
            "Stack mode",
            stack_mode_values,
            stack_mode,
            update_function
        ))

        # Build faceting dropdowns using html_controls abstraction
        facet_dropdowns = build_facet_dropdowns(chart_title_safe, facet_choices, default_facet_array, update_function)

        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_safe,
            chart_title_safe,
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

dependencies(a::AreaChart) = [a.data_label]
