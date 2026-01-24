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
- `color_cols`: Columns for color grouping. Can be:
  - `Vector{Symbol}`: `[:col1, :col2]` - uses default palette
  - `Vector{Tuple}`: `[(:col1, :default), (:col2, Dict(:val => "#hex"))]` - with custom colors
  (default: `Symbol[]`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict{Symbol, Any}`: Column => default values. Values can be a single value, vector, or nothing for all values
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

# With custom color mapping
lc = LineChart(:custom_colors, df, :sales_data,
    x_cols=[:date],
    y_cols=[:revenue],
    color_cols=[(:region, Dict("US" => "#ff0000", "EU" => "#0000ff")), (:product, :default)]
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
                            color_cols::ColorColSpec=Symbol[],
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            aggregator::String="none",
                            title::String="Line Chart",
                            line_width::Int=1,
                            marker_size::Int=1,
                            notes::String="")

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)

        # Validate columns exist in dataframe
        valid_x_cols = validate_and_filter_columns(x_cols, df, "x_cols")
        valid_y_cols = validate_and_filter_columns(y_cols, df, "y_cols")

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Validate aggregator
        valid_aggregators = ["none", "mean", "median", "count", "min", "max", "sum"]
        if !(aggregator in valid_aggregators)
            error("aggregator must be one of: $(join(valid_aggregators, ", "))")
        end

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build color maps for all possible color columns that exist (with optional custom colors)
        color_maps, color_scales, valid_color_cols = build_color_maps_extended(color_cols, df)
        # If no color columns specified or valid, we'll use a default black color for all lines

        # Build HTML controls using abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)

        # Create JavaScript arrays for columns
        # Separate categorical and continuous filters
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]

        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        x_cols_js = build_js_array(valid_x_cols)
        y_cols_js = build_js_array(valid_y_cols)
        color_cols_js = build_js_array(valid_color_cols)

        # Create color maps as nested JavaScript object (categorical)
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Create color scales as nested JavaScript object (continuous)
        color_scales_js = build_color_scales_js(color_scales)

        # Default columns
        default_x_col = string(valid_x_cols[1])
        default_y_col = string(valid_y_cols[1])
        default_color_col = select_default_column(valid_color_cols, "__no_color__")

        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const X_COLS = $x_cols_js;
            const Y_COLS = $y_cols_js;
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;
            const DEFAULT_X_COL = '$default_x_col';

            $JS_COLOR_INTERPOLATION
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';

            let allData = [];

            // Aggregation functions
            function aggregate(values, method) {
                if (values.length === 0) return null;
                if (method === 'none') return values;  // Return all values when no aggregation
                if (method === 'count') return [values.length];

                // Convert all values to numbers for numeric operations
                const numericValues = values.map(v => parseFloat(v)).filter(v => !isNaN(v) && isFinite(v));
                if (numericValues.length === 0) return [NaN];

                if (method === 'sum') {
                    const sum = numericValues.reduce((a, b) => a + b, 0);
                    return [sum];
                }
                if (method === 'mean') {
                    const sum = numericValues.reduce((a, b) => a + b, 0);
                    return [sum / numericValues.length];
                }
                if (method === 'median') {
                    const sorted = [...numericValues].sort((a, b) => a - b);
                    const mid = Math.floor(sorted.length / 2);
                    return sorted.length % 2 === 0 ?
                        [(sorted[mid - 1] + sorted[mid]) / 2] :
                        [sorted[mid]];
                }
                if (method === 'min') return [Math.min(...numericValues)];
                if (method === 'max') return [Math.max(...numericValues)];
                return values;
            }

            // Centralized aggregation logic
            // Takes data that has already been filtered by facets and color
            // Groups by X and aggregates Y values
            function aggregateGroupData(groupData, xCol, yCol, aggregator) {
                // Note: Date parsing is now handled centrally in loadDataset()
                // All dates are already JavaScript Date objects by the time we get here

                let xValues, yValues;

                if (aggregator === 'none') {
                    // No aggregation - return all rows with duplicates
                    xValues = groupData.map(row => row[xCol]);
                    yValues = groupData.map(row => row[yCol]);
                } else {
                    // Group by x value and aggregate y values
                    // Keep track of original x values (including Date objects)
                    const xGroups = {};
                    const xOriginalValues = {};  // Store original values to preserve Date objects

                    groupData.forEach(row => {
                        const xVal = row[xCol];
                        const xKey = String(xVal);  // Use string as key
                        if (!xGroups[xKey]) {
                            xGroups[xKey] = [];
                            xOriginalValues[xKey] = xVal;  // Keep original value (Date object if it's a date)
                        }
                        xGroups[xKey].push(row[yCol]);
                    });

                    xValues = [];
                    yValues = [];

                    // Check first original value to determine type
                    const firstKey = Object.keys(xGroups)[0];
                    const firstOriginal = xOriginalValues[firstKey];
                    const isDate = firstOriginal instanceof Date;

                    // Sort keys appropriately
                    const sortedKeys = Object.keys(xGroups).sort((a, b) => {
                        if (isDate) {
                            // For dates, compare the actual Date objects
                            const dateA = xOriginalValues[a];
                            const dateB = xOriginalValues[b];
                            return dateA - dateB;  // Date subtraction gives milliseconds difference
                        }
                        const aNum = parseFloat(a);
                        const bNum = parseFloat(b);
                        if (!isNaN(aNum) && !isNaN(bNum)) {
                            return aNum - bNum;
                        }
                        return String(a).localeCompare(String(b));
                    });

                    // Aggregate y values for each unique x
                    sortedKeys.forEach(xKey => {
                        const aggregated = aggregate(xGroups[xKey], aggregator);
                        if (aggregated && aggregated.length > 0) {
                            xValues.push(xOriginalValues[xKey]);  // Use original value (preserves Date objects)
                            yValues.push(aggregated[0]);
                        }
                    });
                }

                return {xValues, yValues};
            }

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title = function() {
                // Get current X and Y columns
                const xColSelect = document.getElementById('x_col_select_$chart_title');
                const X_COL = xColSelect ? xColSelect.value : DEFAULT_X_COL;

                const yColSelect = document.getElementById('y_col_select_$chart_title');
                const Y_COL = yColSelect ? yColSelect.value : DEFAULT_Y_COL;

                // Get current Y axis transformation
                const yTransformSelect = document.getElementById('y_transform_select_$chart_title');
                const Y_TRANSFORM = yTransformSelect ? yTransformSelect.value : 'identity';

                // Get current filter values
                const filters = {};
                const rangeFilters = {};

                // Read categorical filters (dropdowns)
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Read continuous filters (range sliders)
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title' + '_slider');
                    // Check slider is initialized before reading values
                    if (slider.length > 0 && slider.hasClass('ui-slider')) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
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

                // Apply filters with observation counting (centralized function)
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters
                );

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
                        // Robust sort that handles dates, numbers, and strings
                        group.data.sort((a, b) => {
                            const aVal = a[X_COL];
                            const bVal = b[X_COL];

                            // Check if values are Date objects
                            if (aVal instanceof Date && bVal instanceof Date) {
                                return aVal - bVal;
                            }

                            const aStr = String(aVal);
                            const bStr = String(bVal);

                            // Try numeric comparison
                            const aNum = parseFloat(aVal);
                            const bNum = parseFloat(bVal);
                            if (!isNaN(aNum) && !isNaN(bNum) && aStr === String(aNum) && bStr === String(bNum)) {
                                return aNum - bNum;
                            }

                            // Fall back to string comparison
                            return aStr.localeCompare(bStr);
                        });

                        // Use centralized aggregation function
                        const result = aggregateGroupData(group.data, X_COL, Y_COL, AGGREGATOR);
                        let xValues = result.xValues;
                        let yValues = result.yValues;

                        // Apply Y axis transformation
                        // Special handling for cumulative transforms (computed per group after aggregation)
                        if (Y_TRANSFORM === 'cumulative') {
                            yValues = computeCumulativeSum(yValues);
                        } else if (Y_TRANSFORM === 'cumprod') {
                            yValues = computeCumulativeProduct(yValues);
                        } else {
                            yValues = applyAxisTransform(yValues, Y_TRANSFORM);
                        }

                        traces.push({
                            x: xValues,
                            y: yValues,
                            type: 'scatter',
                            mode: 'lines+markers',
                            name: group.color,
                            line: {
                                color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, group.color),
                                width: $line_width
                            },
                            marker: { size: $marker_size }
                        });
                    }

                    const layout = {
                        xaxis: { title: X_COL },
                        yaxis: {
                            title: getAxisLabel(Y_COL, Y_TRANSFORM),
                            // Force linear type for cumulative transforms to prevent auto-date detection
                            type: (Y_TRANSFORM === 'cumulative' || Y_TRANSFORM === 'cumprod') ? 'linear' : undefined
                        },
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
                            // Robust sort that handles dates, numbers, and strings
                            group.data.sort((a, b) => {
                                const aVal = a[X_COL];
                                const bVal = b[X_COL];

                                // Check if values are Date objects
                                if (aVal instanceof Date && bVal instanceof Date) {
                                    return aVal - bVal;
                                }

                                const aStr = String(aVal);
                                const bStr = String(bVal);

                                // Try numeric comparison
                                const aNum = parseFloat(aVal);
                                const bNum = parseFloat(bVal);
                                if (!isNaN(aNum) && !isNaN(bNum) && aStr === String(aNum) && bStr === String(bNum)) {
                                    return aNum - bNum;
                                }

                                // Fall back to string comparison
                                return aStr.localeCompare(bStr);
                            });

                            // Use centralized aggregation function
                            const result = aggregateGroupData(group.data, X_COL, Y_COL, AGGREGATOR);
                            let xValues = result.xValues;
                            let yValues = result.yValues;

                            // Apply Y axis transformation
                            // Special handling for cumulative transforms (computed per group after aggregation)
                            if (Y_TRANSFORM === 'cumulative') {
                                yValues = computeCumulativeSum(yValues);
                            } else if (Y_TRANSFORM === 'cumprod') {
                                yValues = computeCumulativeProduct(yValues);
                            } else {
                                yValues = applyAxisTransform(yValues, Y_TRANSFORM);
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
                                    color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, group.color),
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
                            title: col === 1 ? getAxisLabel(Y_COL, Y_TRANSFORM) : '',
                            anchor: xaxis,
                            type: (Y_TRANSFORM === 'cumulative' || Y_TRANSFORM === 'cumprod') ? 'linear' : undefined
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
                                // Robust sort that handles dates, numbers, and strings
                                group.data.sort((a, b) => {
                                    const aVal = a[X_COL];
                                    const bVal = b[X_COL];

                                    // Check if values are Date objects
                                    if (aVal instanceof Date && bVal instanceof Date) {
                                        return aVal - bVal;
                                    }

                                    const aStr = String(aVal);
                                    const bStr = String(bVal);

                                    // Try numeric comparison
                                    const aNum = parseFloat(aVal);
                                    const bNum = parseFloat(bVal);
                                    if (!isNaN(aNum) && !isNaN(bNum) && aStr === String(aNum) && bStr === String(bNum)) {
                                        return aNum - bNum;
                                    }

                                    // Fall back to string comparison
                                    return aStr.localeCompare(bStr);
                                });

                                // Use centralized aggregation function
                                const result = aggregateGroupData(group.data, X_COL, Y_COL, AGGREGATOR);
                                let xValues = result.xValues;
                                let yValues = result.yValues;

                                // Apply Y axis transformation
                                // Special handling for cumulative transforms (computed per group after aggregation)
                                if (Y_TRANSFORM === 'cumulative') {
                                    yValues = computeCumulativeSum(yValues);
                                } else if (Y_TRANSFORM === 'cumprod') {
                                    yValues = computeCumulativeProduct(yValues);
                                } else {
                                    yValues = applyAxisTransform(yValues, Y_TRANSFORM);
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
                                        color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, group.color),
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
                                title: colIdx === 0 ? getAxisLabel(Y_COL, Y_TRANSFORM) : '',
                                anchor: xaxis,
                                type: (Y_TRANSFORM === 'cumulative' || Y_TRANSFORM === 'cumprod') ? 'linear' : undefined
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

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        # Build axis controls HTML (X and Y dimensions + transforms)
        axes_html = build_axis_controls_html(
            chart_title_str,
            update_function;
            x_cols = valid_x_cols,
            y_cols = valid_y_cols,
            default_x = valid_x_cols[1],
            default_y = valid_y_cols[1]
        )

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

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
            ["none", "mean", "median", "count", "min", "max", "sum"],
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

dependencies(a::LineChart) = [a.data_label]
js_dependencies(::LineChart) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)

