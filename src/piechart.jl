"""
    PieChart(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Pie chart visualization with support for faceting and interactive controls.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `value_cols::Vector{Symbol}`: Columns available for slice sizes (default: `[:value]`)
- `color_cols`: Columns for slice labels/colors. Can be:
  - `Vector{Symbol}`: `[:col1, :col2]` - uses default palette
  - `Vector{Tuple}`: `[(:col1, :default), (:col2, Dict(:val => "#hex"))]` - with custom colors
  - For continuous: `[(:col, Dict(0 => "#000", 1 => "#fff"))]` - interpolates between stops
  (default: `[:label]`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `hole::Float64`: Size of hole in center (0 = pie, 0-0.99 = donut) (default: `0.0`)
- `show_legend::Bool`: Display legend (default: `true`)
- `title::String`: Chart title (default: `"Pie Chart"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
pc = PieChart(:sales_pie, df, :sales_data,
    value_cols=[:revenue, :units],
    color_cols=[:category, :product],
    title="Sales by Category"
)
```
"""
struct PieChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function PieChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                      value_cols::Vector{Symbol}=[:value],
                      color_cols::ColorColSpec=[:label],
                      filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                      facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                      default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                      hole::Float64=0.0,
                      show_legend::Bool=true,
                      title::String="Pie Chart",
                      notes::String="")

# Normalize filters to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)

        # Validate columns exist in dataframe
        valid_value_cols = validate_and_filter_columns(value_cols, df, "value_cols")
        color_col_names = extract_color_col_names(color_cols)
        valid_color_cols = validate_and_filter_columns(color_col_names, df, "color_cols")

        # Validate hole parameter
        if hole < 0.0 || hole >= 1.0
            error("hole must be between 0.0 and 0.99 (0 = pie chart, >0 = donut chart)")
        end

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build color maps for all possible color columns
        color_maps, color_scales, _ = build_color_maps_extended(color_cols, df)
        color_maps_js = JSON.json(color_maps)
        color_scales_js = build_color_scales_js(color_scales)

        # Build filter dropdowns using html_controls abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)

        # Separate categorical and continuous filters for JavaScript
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]
        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # Value column dropdown
        if length(valid_value_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "value_col_select_$chart_title_str",
                "Slice size",
                [string(col) for col in valid_value_cols],
                string(valid_value_cols[1]),
                update_function
            ))
        end

        # Color column dropdown
        if length(valid_color_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "color_col_select_$chart_title_str",
                "Slice grouping",
                [string(col) for col in valid_color_cols],
                string(valid_color_cols[1]),
                update_function
            ))
        end

        # Build faceting dropdowns using html_controls abstraction
        facet_dropdowns = build_facet_dropdowns(chart_title_str, facet_choices, default_facet_array, update_function)

        # Default columns
        default_value_col = string(valid_value_cols[1])
        default_color_col = string(valid_color_cols[1])

        # Create JavaScript arrays for columns
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        value_cols_js = build_js_array(valid_value_cols)
        color_cols_js = build_js_array(valid_color_cols)


        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
            filter_dropdowns,
            filter_sliders,
            attribute_dropdowns,
            "",  # No axes controls for PieChart
            facet_dropdowns,
            title,
            notes
        )
        appearance_html = generate_appearance_html(controls; aspect_ratio_default=0.4)

        # Build functional HTML (JavaScript code)
        functional_html = """
        (function() {
            // Configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const VALUE_COLS = $value_cols_js;
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;
            $JS_COLOR_INTERPOLATION
            const DEFAULT_VALUE_COL = '$default_value_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const HOLE = $(hole);
            const SHOW_LEGEND = $(show_legend);

            // Store data globally
            let allData = [];

            // Function to aggregate data for pie chart
            function aggregateData(data, labelCol, valueCol) {
                const aggregated = {};
                for (const row of data) {
                    const label = String(row[labelCol]);
                    const value = Number(row[valueCol]) || 0;
                    if (aggregated[label]) {
                        aggregated[label] += value;
                    } else {
                        aggregated[label] = value;
                    }
                }
                return aggregated;
            }

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title = function() {
                // Check if data is loaded
                if (!allData || allData.length === 0) {
                    return;
                }

                // Get current value and color columns
                const valueColSelect = document.getElementById('value_col_select_$chart_title');
                const VALUE_COL = valueColSelect ? valueColSelect.value : DEFAULT_VALUE_COL;

                const colorColSelect = document.getElementById('color_col_select_$chart_title');
                const COLOR_COL = colorColSelect ? colorColSelect.value : DEFAULT_COLOR_COL;


                // Get categorical filter values (multiple selections)
                const filters = {};
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Get continuous filter values (range sliders)
                const rangeFilters = {};
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title' + '_slider');
                    if (slider.length > 0) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                // Apply filters with observation counting (centralized function)
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters
                );

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                if (!facet1) {
                    // No faceting - single pie chart
                    const aggregated = aggregateData(filteredData, COLOR_COL, VALUE_COL);
                    const labels = Object.keys(aggregated);
                    const values = Object.values(aggregated);
                    const colors = labels.map(label => getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, label));

                    const trace = {
                        type: 'pie',
                        labels: labels,
                        values: values,
                        marker: { colors: colors },
                        hole: HOLE,
                        textposition: 'auto',
                        hoverinfo: 'label+value+percent'
                    };

                    const layout = {
                        showlegend: SHOW_LEGEND,
                        margin: {l: 50, r: 50, t: 50, b: 50},
                        height: 500
                    };

                    Plotly.newPlot('$chart_title', [trace], layout, {responsive: true});

                } else if (facet1 && !facet2) {
                    // Facet wrap (1 variable)
                    const facetValues = [...new Set(filteredData.map(row => String(row[facet1])))].sort();
                    const nFacets = facetValues.length;
                    const nCols = Math.min(3, nFacets);
                    const nRows = Math.ceil(nFacets / nCols);

                    const traces = [];
                    const annotations = [];

                    for (let i = 0; i < nFacets; i++) {
                        const facetValue = facetValues[i];
                        const facetData = filteredData.filter(row => String(row[facet1]) === facetValue);
                        const aggregated = aggregateData(facetData, COLOR_COL, VALUE_COL);
                        const labels = Object.keys(aggregated);
                        const values = Object.values(aggregated);
                        const colors = labels.map(label => getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, label));

                        const row = Math.floor(i / nCols);
                        const col = i % nCols;

                        const domain = {
                            x: [col / nCols + 0.01, (col + 1) / nCols - 0.01],
                            y: [1 - (row + 1) / nRows + 0.01, 1 - row / nRows - 0.01]
                        };

                        traces.push({
                            type: 'pie',
                            labels: labels,
                            values: values,
                            marker: {colors: colors},
                            hole: HOLE,
                            domain: domain,
                            name: facetValue,
                            hoverinfo: 'label+value+percent',
                            textposition: 'auto'
                        });

                        // Add facet label
                        annotations.push({
                            text: facet1 + ': ' + facetValue,
                            showarrow: false,
                            x: (col + 0.5) / nCols,
                            y: 1 - row / nRows - 0.02,
                            xref: 'paper',
                            yref: 'paper',
                            xanchor: 'center',
                            yanchor: 'top',
                            font: {size: 12, weight: 'bold'}
                        });
                    }

                    const layout = {
                        showlegend: SHOW_LEGEND,
                        annotations: annotations,
                        height: 300 * nRows,
                        margin: {l: 20, r: 20, t: 40, b: 20}
                    };

                    Plotly.newPlot('$chart_title', traces, layout, {responsive: true});

                } else {
                    // Facet grid (2 variables)
                    const rowValues = [...new Set(filteredData.map(row => String(row[facet1])))].sort();
                    const colValues = [...new Set(filteredData.map(row => String(row[facet2])))].sort();
                    const nRows = rowValues.length;
                    const nCols = colValues.length;

                    const traces = [];
                    const annotations = [];

                    for (let r = 0; r < nRows; r++) {
                        for (let c = 0; c < nCols; c++) {
                            const rowVal = rowValues[r];
                            const colVal = colValues[c];
                            const cellData = filteredData.filter(row =>
                                String(row[facet1]) === rowVal &&
                                String(row[facet2]) === colVal
                            );

                            if (cellData.length > 0) {
                                const aggregated = aggregateData(cellData, COLOR_COL, VALUE_COL);
                                const labels = Object.keys(aggregated);
                                const values = Object.values(aggregated);
                                const colors = labels.map(label => getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, label));

                                const domain = {
                                    x: [c / nCols + 0.01, (c + 1) / nCols - 0.01],
                                    y: [1 - (r + 1) / nRows + 0.01, 1 - r / nRows - 0.01]
                                };

                                traces.push({
                                    type: 'pie',
                                    labels: labels,
                                    values: values,
                                    marker: {colors: colors},
                                    hole: HOLE,
                                    domain: domain,
                                    hoverinfo: 'label+value+percent',
                                    textposition: 'auto',
                                    showlegend: false
                                });
                            }
                        }
                    }

                    // Add column headers
                    for (let c = 0; c < nCols; c++) {
                        annotations.push({
                            text: facet2 + ': ' + colValues[c],
                            showarrow: false,
                            x: (c + 0.5) / nCols,
                            y: 1.02,
                            xref: 'paper',
                            yref: 'paper',
                            xanchor: 'center',
                            yanchor: 'bottom',
                            font: {size: 11, weight: 'bold'}
                        });
                    }

                    // Add row headers
                    for (let r = 0; r < nRows; r++) {
                        annotations.push({
                            text: facet1 + ': ' + rowValues[r],
                            showarrow: false,
                            x: -0.02,
                            y: 1 - (r + 0.5) / nRows,
                            xref: 'paper',
                            yref: 'paper',
                            xanchor: 'right',
                            yanchor: 'middle',
                            font: {size: 11, weight: 'bold'}
                        });
                    }

                    const layout = {
                        showlegend: SHOW_LEGEND && nRows * nCols <= 4,
                        annotations: annotations,
                        height: 300 * nRows,
                        margin: {l: 80, r: 20, t: 60, b: 20}
                    };

                    Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
                }
            };

            // Load and parse data
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

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::PieChart) = [a.data_label]
js_dependencies(::PieChart) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
