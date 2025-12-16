"""
    PieChart(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Pie chart visualization with support for faceting and interactive controls.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `value_cols::Vector{Symbol}`: Columns available for slice sizes (default: `[:value]`)
- `label_cols::Vector{Symbol}`: Columns available for slice labels (default: `[:label]`)
- `filters::Dict{Symbol, Any}`: Default filter values (default: `Dict{Symbol,Any}()`)
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
    label_cols=[:category, :product],
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
                      label_cols::Vector{Symbol}=[:label],
                      filters::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                      facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                      default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                      hole::Float64=0.0,
                      show_legend::Bool=true,
                      title::String="Pie Chart",
                      notes::String="")

        # Get available columns in dataframe
        available_cols = Set(names(df))

        # Validate value_cols
        valid_value_cols = Symbol[]
        for col in value_cols
            if string(col) in available_cols
                push!(valid_value_cols, col)
            end
        end
        if isempty(valid_value_cols)
            error("None of the specified value_cols exist in the dataframe. Available columns: $(names(df))")
        end

        # Validate label_cols
        valid_label_cols = Symbol[]
        for col in label_cols
            if string(col) in available_cols
                push!(valid_label_cols, col)
            end
        end
        if isempty(valid_label_cols)
            error("None of the specified label_cols exist in the dataframe. Available columns: $(names(df))")
        end

        # Validate hole parameter
        if hole < 0.0 || hole >= 1.0
            error("hole must be between 0.0 and 0.99 (0 = pie chart, >0 = donut chart)")
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

        # Build color palette
        color_palette = ["#636efa", "#EF553B", "#00cc96", "#ab63fa", "#FFA15A",
                        "#19d3f3", "#FF6692", "#B6E880", "#FF97FF", "#FECB52"]

        # Build color maps for all possible label columns
        color_maps = Dict()
        for col in valid_label_cols
            unique_labels = unique(df[!, col])
            color_maps[string(col)] = Dict(
                string(key) => color_palette[(i - 1) % length(color_palette) + 1]
                for (i, key) in enumerate(unique_labels)
            )
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
                <label for="$(col)_select_$chart_title">$(col): </label>
                <select id="$(col)_select_$chart_title" multiple style="min-width: 150px; height: 100px;" onchange="updateChart_$chart_title()">
    $options_html            </select>
            </div>
            """
        end

        # Build value column dropdown
        value_col_dropdown = ""
        if length(valid_value_cols) > 1
            value_options = ""
            for col in valid_value_cols
                selected = (col == valid_value_cols[1]) ? " selected" : ""
                value_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end
            value_col_dropdown = """
            <div style="margin: 10px;">
                <label for="value_col_select_$chart_title">Slice size: </label>
                <select id="value_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $value_options            </select>
            </div>
            """
        end

        # Build label column dropdown
        label_col_dropdown = ""
        if length(valid_label_cols) > 1
            label_options = ""
            for col in valid_label_cols
                selected = (col == valid_label_cols[1]) ? " selected" : ""
                label_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end
            label_col_dropdown = """
            <div style="margin: 10px;">
                <label for="label_col_select_$chart_title">Slice grouping: </label>
                <select id="label_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $label_options            </select>
            </div>
            """
        end

        # Build faceting dropdowns
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

        # Default columns
        default_value_col = string(valid_value_cols[1])
        default_label_col = string(valid_label_cols[1])

        # Create JavaScript arrays for columns
        filter_cols_js = "[" * join(["'$col'" for col in keys(filters)], ", ") * "]"
        value_cols_js = "[" * join(["'$col'" for col in valid_value_cols], ", ") * "]"
        label_cols_js = "[" * join(["'$col'" for col in valid_label_cols], ", ") * "]"

        # Create color maps as nested JavaScript object
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Build appearance HTML (controls + chart container)
        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters (for data filtering) -->
        $(filter_dropdowns_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;\">\n            <h4 style=\"margin-top: 0;\">Filters</h4>\n            $filter_dropdowns_html\n        </div>" : "")

        <!-- Plot Attributes (value and label columns) -->
        $((value_col_dropdown != "" || label_col_dropdown != "") ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0f8ff;\">\n            <h4 style=\"margin-top: 0;\">Plot Attributes</h4>\n            $value_col_dropdown\n            $label_col_dropdown\n        </div>" : "")

        <!-- Faceting -->
        $(facet_controls != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff8f0;\">\n            <h4 style=\"margin-top: 0;\">Faceting</h4>\n            $facet_controls\n        </div>" : "")

        <!-- Chart -->
        <div id="$chart_title"></div>
        """

        # Build functional HTML (JavaScript code)
        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const VALUE_COLS = $value_cols_js;
            const LABEL_COLS = $label_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const DEFAULT_VALUE_COL = '$default_value_col';
            const DEFAULT_LABEL_COL = '$default_label_col';
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

                // Get current value and label columns
                const valueColSelect = document.getElementById('value_col_select_$chart_title');
                const VALUE_COL = valueColSelect ? valueColSelect.value : DEFAULT_VALUE_COL;

                const labelColSelect = document.getElementById('label_col_select_$chart_title');
                const LABEL_COL = labelColSelect ? labelColSelect.value : DEFAULT_LABEL_COL;

                // Get color map for current label selection
                const COLOR_MAP = COLOR_MAPS[LABEL_COL] || {};

                // Get current filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

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

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                if (!facet1) {
                    // No faceting - single pie chart
                    const aggregated = aggregateData(filteredData, LABEL_COL, VALUE_COL);
                    const labels = Object.keys(aggregated);
                    const values = Object.values(aggregated);
                    const colors = labels.map(label => COLOR_MAP[label] || '#808080');

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
                        const aggregated = aggregateData(facetData, LABEL_COL, VALUE_COL);
                        const labels = Object.keys(aggregated);
                        const values = Object.values(aggregated);
                        const colors = labels.map(label => COLOR_MAP[label] || '#808080');

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
                                const aggregated = aggregateData(cellData, LABEL_COL, VALUE_COL);
                                const labels = Object.keys(aggregated);
                                const values = Object.values(aggregated);
                                const colors = labels.map(label => COLOR_MAP[label] || '#808080');

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
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::PieChart) = [a.data_label]
