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
- `color_cols`: Columns for grouping/coloring. Can be:
  - `Vector{Symbol}`: `[:col1, :col2]` - uses default palette
  - `Vector{Tuple}`: `[(:col1, :default), (:col2, Dict(:val => "#hex"))]` - with custom colors
  - For continuous: `[(:col, Dict(0 => "#000", 1 => "#fff"))]` - interpolates between stops
  (default: `Symbol[]`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict{Symbol, Any}`: Column => default values. Values can be a single value, vector, or nothing for all values
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
  Unlike filters, choices only allow selecting ONE value at a time.
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `stack_mode::String`: Stacking mode - "unstack", "stack", "normalised_stack", or "dodge" (default: `"stack"`)
- `title::String`: Chart title (default: `"Area Chart"`)
- `fill_opacity::Float64`: Opacity of filled areas (0-1) (default: `0.6`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Stacking Modes
- `unstack`: Areas are overlaid with transparency, allowing all to be visible
- `stack`: Areas are stacked on top of each other, showing cumulative values
- `normalised_stack`: Areas are stacked and normalized to 100%, showing proportions
- `dodge`: Bars are placed side-by-side for each x value (only available for discrete x values)

# Examples
```julia
ac = AreaChart(:sales_chart, df, :sales_data,
    x_cols=[:date],
    y_cols=[:revenue],
    color_cols=[:region],
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
                            color_cols::ColorColSpec=Symbol[],
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            stack_mode::String="stack",
                            title::String="Area Chart",
                            fill_opacity::Float64=0.6,
                            notes::String="")

        # Normalize filters and choices to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Sanitize chart title for use in JavaScript/HTML IDs
        chart_title_safe = string(sanitize_chart_title(chart_title))

        # Validate columns exist in dataframe
        valid_x_cols = validate_and_filter_columns(x_cols, df, "x_cols")
        valid_y_cols = validate_and_filter_columns(y_cols, df, "y_cols")

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Validate stack_mode
        valid_stack_modes = ["unstack", "stack", "normalised_stack", "dodge"]
        if !(stack_mode in valid_stack_modes)
            error("stack_mode must be one of: $(join(valid_stack_modes, ", "))")
        end

        # Validate fill_opacity
        if fill_opacity < 0.0 || fill_opacity > 1.0
            error("fill_opacity must be between 0.0 and 1.0")
        end

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build color maps for all possible group columns that exist (with optional custom colors)
        color_maps, color_scales, valid_color_cols = build_color_maps_extended(color_cols, df)
        # Build group order maps (preserving order of first appearance)
        group_order_maps = Dict()
        for col in valid_color_cols
            unique_vals = unique(df[!, col])
            group_order_maps[string(col)] = [string(val) for val in unique_vals]
        end

        # Build HTML controls using abstraction
        update_function = "updatePlot_$chart_title_safe()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_safe, normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(chart_title_safe, normalized_choices, df, update_function)

        # Create JavaScript arrays for columns (split categorical and continuous)
        categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
        continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]
        choice_cols = collect(keys(normalized_choices))

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)
        x_cols_js = build_js_array(valid_x_cols)
        y_cols_js = build_js_array(valid_y_cols)
        color_cols_js = build_js_array(valid_color_cols)

        # Create color maps as nested JavaScript object (categorical)
        color_maps_js = if isempty(color_maps)
            "{}"
        else
            "{" * join([
                "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
                for (col, map) in color_maps
            ], ", ") * "}"
        end

        # Create color scales as nested JavaScript object (continuous)
        color_scales_js = build_color_scales_js(color_scales)

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
        default_color_col = select_default_column(valid_color_cols, "__no_group__")

        functional_html = """
        (function() {
            // Configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;
            const X_COLS = $x_cols_js;
            const Y_COLS = $y_cols_js;
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;
            const GROUP_ORDER = $group_order_js;
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const FILL_OPACITY = $fill_opacity;

            $JS_COLOR_INTERPOLATION

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

                // Get current axis transformations
                const xTransformSelect = document.getElementById('x_transform_select_$chart_title_safe');
                const X_TRANSFORM = xTransformSelect ? xTransformSelect.value : 'identity';

                const yTransformSelect = document.getElementById('y_transform_select_$chart_title_safe');
                const Y_TRANSFORM = yTransformSelect ? yTransformSelect.value : 'identity';

                // Get choice filter values (single-select)
                const choices = {};
                CHOICE_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_choice_$chart_title_safe');
                    if (select) {
                        choices[col] = select.value;
                    }
                });

                // Get categorical filter values (multiple selections)
                const filters = {};
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title_safe');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Get continuous filter values (range sliders)
                const rangeFilters = {};
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title_safe' + '_slider');
                    if (slider.length > 0) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                // Get current group column
                const groupColSelect = document.getElementById('color_col_select_$chart_title_safe');
                const GROUP_COL = groupColSelect ? groupColSelect.value : DEFAULT_COLOR_COL;

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

                // Apply filters with observation counting (centralized function)
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title_safe',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters,
                    CHOICE_FILTERS,
                    choices
                );

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

                        let xValues = groupData.map(row => row[X_COL]);
                        let yValues = groupData.map(row => row[Y_COL]);

                        // Apply axis transformations
                        xValues = applyAxisTransform(xValues, X_TRANSFORM);
                        yValues = applyAxisTransform(yValues, Y_TRANSFORM);

                        const color = getColor(COLOR_MAPS, COLOR_SCALES, GROUP_COL, groupKey);
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
                        } else if (STACK_MODE === 'dodge') {
                            if (discrete) {
                                trace.type = 'bar';
                            }
                            // For continuous x, dodge doesn't make sense, so we treat it like unstack
                            if (!discrete) {
                                trace.fill = 'tozeroy';
                                if (color.startsWith('#')) {
                                    const r = parseInt(color.substr(1,2), 16);
                                    const g = parseInt(color.substr(3,2), 16);
                                    const b = parseInt(color.substr(5,2), 16);
                                    trace.fillcolor = `rgba(\${r}, \${g}, \${b}, \${FILL_OPACITY})`;
                                }
                            }
                        }

                        traces.push(trace);
                    }

                    const layout = {
                        xaxis: { title: getAxisLabel(X_COL, X_TRANSFORM) },
                        yaxis: {
                            title: STACK_MODE === 'normalised_stack' ?
                                getAxisLabel(Y_COL, Y_TRANSFORM) + ' (%)' :
                                getAxisLabel(Y_COL, Y_TRANSFORM)
                        },
                        hovermode: 'closest',
                        showlegend: true,
                        barmode: STACK_MODE === 'stack' || STACK_MODE === 'normalised_stack' ? 'stack' :
                                 STACK_MODE === 'dodge' ? 'group' : 'overlay',
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
                        barmode: STACK_MODE === 'stack' || STACK_MODE === 'normalised_stack' ? 'stack' :
                                 STACK_MODE === 'dodge' ? 'group' : 'overlay',
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

                            let xValues = groupData.map(row => row[X_COL]);
                            let yValues = groupData.map(row => row[Y_COL]);

                            // Apply axis transformations
                            xValues = applyAxisTransform(xValues, X_TRANSFORM);
                            yValues = applyAxisTransform(yValues, Y_TRANSFORM);

                            const color = getColor(COLOR_MAPS, COLOR_SCALES, GROUP_COL, groupKey);
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
                            } else if (STACK_MODE === 'dodge') {
                                // For continuous x, dodge doesn't make sense, so we treat it like unstack
                                if (!discrete) {
                                    trace.fill = 'tozeroy';
                                    if (color.startsWith('#')) {
                                        const r = parseInt(color.substr(1,2), 16);
                                        const g = parseInt(color.substr(3,2), 16);
                                        const b = parseInt(color.substr(5,2), 16);
                                        trace.fillcolor = `rgba(\${r}, \${g}, \${b}, \${FILL_OPACITY})`;
                                    }
                                }
                            }

                            traces.push(trace);
                        }

                        // Add axis configuration
                        layout[xaxis] = {
                            title: row === nRows ? getAxisLabel(X_COL, X_TRANSFORM) : '',
                            anchor: yaxis
                        };
                        layout[yaxis] = {
                            title: col === 1 ?
                                (STACK_MODE === 'normalised_stack' ?
                                    getAxisLabel(Y_COL, Y_TRANSFORM) + ' (%)' :
                                    getAxisLabel(Y_COL, Y_TRANSFORM)) : '',
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
                        barmode: STACK_MODE === 'stack' || STACK_MODE === 'normalised_stack' ? 'stack' :
                                 STACK_MODE === 'dodge' ? 'group' : 'overlay',
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

                                let xValues = groupData.map(row => row[X_COL]);
                                let yValues = groupData.map(row => row[Y_COL]);

                                // Apply axis transformations
                                xValues = applyAxisTransform(xValues, X_TRANSFORM);
                                yValues = applyAxisTransform(yValues, Y_TRANSFORM);

                                const color = getColor(COLOR_MAPS, COLOR_SCALES, GROUP_COL, groupKey);
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
                                } else if (STACK_MODE === 'dodge') {
                                    // For continuous x, dodge doesn't make sense, so we treat it like unstack
                                    if (!discrete) {
                                        trace.fill = 'tozeroy';
                                        if (color.startsWith('#')) {
                                            const r = parseInt(color.substr(1,2), 16);
                                            const g = parseInt(color.substr(3,2), 16);
                                            const b = parseInt(color.substr(5,2), 16);
                                            trace.fillcolor = `rgba(\${r}, \${g}, \${b}, \${FILL_OPACITY})`;
                                        }
                                    }
                                }

                                traces.push(trace);
                            }

                            // Add axis configuration
                            layout[xaxis] = {
                                title: rowIdx === nRows - 1 ? getAxisLabel(X_COL, X_TRANSFORM) : '',
                                anchor: yaxis
                            };
                            layout[yaxis] = {
                                title: colIdx === 0 ?
                                    (STACK_MODE === 'normalised_stack' ?
                                        getAxisLabel(Y_COL, Y_TRANSFORM) + ' (%)' :
                                        getAxisLabel(Y_COL, Y_TRANSFORM)) : '',
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

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title_safe');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title_safe:', error);
            });
        })();
        """

        # Build axis controls HTML (X and Y dimensions + transforms)
        axes_html = build_axis_controls_html(
            chart_title_safe,
            update_function;
            x_cols = valid_x_cols,
            y_cols = valid_y_cols,
            default_x = valid_x_cols[1],
            default_y = valid_y_cols[1]
        )

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # Group column dropdown
        if length(valid_color_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "color_col_select_$chart_title_safe",
                "Color by",
                [string(col) for col in valid_color_cols],
                string(valid_color_cols[1]),
                update_function
            ))
        end

        # Stack mode dropdown (always shown)
        stack_mode_display = ["unstack", "stack", "normalized stack", "dodge"]
        stack_mode_values = ["unstack", "stack", "normalised_stack", "dodge"]
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
            choice_dropdowns,
            filter_dropdowns,
            filter_sliders,
            attribute_dropdowns,
            axes_html,
            facet_dropdowns,
            title,
            notes
        )
        appearance_html = generate_appearance_html(controls; aspect_ratio_default=0.4)

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::AreaChart) = [a.data_label]
js_dependencies(::AreaChart) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
