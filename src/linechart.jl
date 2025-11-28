
struct PChart <: PivotTablesType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function PChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_col::Symbol=:x,
                            y_col::Symbol=:y,
                            color_col::Symbol=:color,
                            filters::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            title::String="Line Chart",
                            x_label::String="",
                            y_label::String="",
                            line_width::Int=1,
                            marker_size::Int=1,
                            notes::String="")

        # Get unique values for each filter column
        filter_options = Dict()
        for col in keys(filters)
            filter_options[string(col)] = unique(df[!, col])
        end
        
        # Get unique color values and assign colors
        unique_colors = unique(df[!, color_col])
        color_palette = ["#636efa", "#EF553B", "#00cc96", "#ab63fa", "#FFA15A", 
                        "#19d3f3", "#FF6692", "#B6E880", "#FF97FF", "#FECB52"]
        color_map = Dict(
            key => color_palette[(i - 1) % length(color_palette) + 1]
            for (i, key) in enumerate(unique_colors)
        )
        
        dropdowns_html = ""
        for col in keys(filters)
            # Get default value for this column
            default_val = filters[col]
            # Build options HTML with selected attribute
            options_html = ""
            for opt in filter_options[string(col)]
                selected = (opt == default_val) ? " selected" : ""
                options_html *= "                <option value=\"$(opt)\"$selected>$(opt)</option>\n"
            end
            dropdowns_html *= """
            <div style="margin: 10px;">
                <label for="$(col)_select">$(col): </label>
                <select id="$(col)_select" onchange="updateChart()">
    $options_html            </select>
            </div>
            """
        end

        
        # Create filter column names as JavaScript array
        filter_cols_js = "[" * join(["'$col'" for col in keys(filters)], ", ") * "]"
        
        # Create color map as JavaScript object
        color_map_js = "{" * join(["'$k': '$v'" for (k, v) in color_map], ", ") * "}"

        functional_html = """
            // Configuration
            const X_COL = '$x_col';
            const Y_COL = '$y_col';
            const COLOR_COL = '$color_col';
            const FILTER_COLS = $filter_cols_js;
            const COLOR_MAP = $color_map_js;
            const X_LABEL = '$x_label';
            const Y_LABEL = '$y_label';
                        
            let allData = [];

            // Make it global so inline onchange can see it
            window.updateChart = function() {
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select');
                    if (select) {
                        filters[col] = select.value;
                    }
                });

                const filteredData = allData.filter(row => {
                    for (let col in filters) {
                        if (String(row[col]) !== String(filters[col])) {
                            return false;
                        }
                    }
                    return true;
                });

                const groupedData = {};
                filteredData.forEach(row => {
                    const colorVal = row[COLOR_COL];
                    if (!groupedData[colorVal]) {
                        groupedData[colorVal] = [];
                    }
                    groupedData[colorVal].push(row);
                });

                const traces = [];
                for (let colorVal in groupedData) {
                    const group = groupedData[colorVal];
                    group.sort((a, b) => a[X_COL] - b[X_COL]);

                    traces.push({
                        x: group.map(row => row[X_COL]),
                        y: group.map(row => row[Y_COL]),
                        type: 'scatter',
                        mode: 'lines+markers',
                        name: colorVal,
                        line: {
                            color: COLOR_MAP[colorVal] || '#000000',
                            width: $line_width
                        },
                        marker: { size: $marker_size }
                    });
                }
                
                // Layout
                const layout = {
                    xaxis: { title: X_LABEL || X_COL },
                    yaxis: { title: Y_LABEL || Y_COL },
                    hovermode: 'closest',
                    showlegend: true
                };
                
                // Plot
                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            };

            // Parse CSV data
            const csvText = document.getElementById('$data_label').textContent;
            Papa.parse(csvText, {
                header: true,
                dynamicTyping: true,
                skipEmptyLines: true,
                complete: function(results) {
                    allData = results.data;
                    updateChart();
                }
            });
        """

        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>
        
        <!-- Controls -->
        <div id="controls">
            $dropdowns_html
        </div>
        
        <!-- Chart -->
        <div id="$chart_title"></div>
        <br><hr><br>
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end



