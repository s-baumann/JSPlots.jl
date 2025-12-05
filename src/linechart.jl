
struct LineChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function LineChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_col::Symbol=:x,
                            y_col::Symbol=:y,
                            color_cols::Vector{Symbol}=[:color],
                            linetype_cols::Vector{Symbol}=[:color],
                            filters::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            aggregator::String="none",
                            title::String="Line Chart",
                            x_label::String="",
                            y_label::String="",
                            line_width::Int=1,
                            marker_size::Int=1,
                            notes::String="")

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

        # Validate aggregator
        valid_aggregators = ["none", "mean", "median", "count", "min", "max"]
        if !(aggregator in valid_aggregators)
            error("aggregator must be one of: $(join(valid_aggregators, ", "))")
        end

        # Get unique values for each filter column
        filter_options = Dict()
        for col in keys(filters)
            filter_options[string(col)] = unique(df[!, col])
        end

        # Get available columns in dataframe
        available_cols = Set(names(df))

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
        if isempty(valid_color_cols)
            error("None of the specified color_cols exist in the dataframe. Available columns: $(names(df))")
        end

        # Build linetype maps for all possible linetype columns that exist
        linetype_palette = ["solid", "dot", "dash", "longdash", "dashdot", "longdashdot"]
        linetype_maps = Dict()
        valid_linetype_cols = Symbol[]
        for col in linetype_cols
            if string(col) in available_cols
                push!(valid_linetype_cols, col)
                unique_vals = unique(df[!, col])
                linetype_maps[string(col)] = Dict(
                    string(key) => linetype_palette[(i - 1) % length(linetype_palette) + 1]
                    for (i, key) in enumerate(unique_vals)
                )
            end
        end
        if isempty(valid_linetype_cols)
            error("None of the specified linetype_cols exist in the dataframe. Available columns: $(names(df))")
        end

        # Build filter dropdowns
        dropdowns_html = ""
        for col in keys(filters)
            default_val = filters[col]
            options_html = ""
            for opt in filter_options[string(col)]
                selected = (opt == default_val) ? " selected" : ""
                options_html *= "                <option value=\"$(opt)\"$selected>$(opt)</option>\n"
            end
            dropdowns_html *= """
            <div style="margin: 10px;">
                <label for="$(col)_select">$(col): </label>
                <select id="$(col)_select" onchange="updateChart_$chart_title()">
    $options_html            </select>
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
            dropdowns_html *= """
            <div style="margin: 10px;">
                <label for="color_col_select_$chart_title">Color by: </label>
                <select id="color_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $color_options            </select>
            </div>
            """
        end

        # Build linetype column dropdown
        if length(valid_linetype_cols) > 1
            linetype_options = ""
            for col in valid_linetype_cols
                selected = (col == valid_linetype_cols[1]) ? " selected" : ""
                linetype_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end
            dropdowns_html *= """
            <div style="margin: 10px;">
                <label for="linetype_col_select_$chart_title">Line type by: </label>
                <select id="linetype_col_select_$chart_title" onchange="updateChart_$chart_title()">
    $linetype_options            </select>
            </div>
            """
        end

        # Build aggregator dropdown
        aggregator_options = ""
        for agg in ["none", "mean", "median", "count", "min", "max"]
            selected = (agg == aggregator) ? " selected" : ""
            aggregator_options *= "                <option value=\"$agg\"$selected>$agg</option>\n"
        end
        dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="aggregator_select_$chart_title">Aggregator: </label>
            <select id="aggregator_select_$chart_title" onchange="updateChart_$chart_title()">
    $aggregator_options        </select>
        </div>
        """

        # Build facet dropdowns
        if length(facet_choices) == 1
            # Single facet option - just on/off toggle
            default_facet1 = length(default_facet_array) >= 1 ? string(default_facet_array[1]) : "None"
            facet_col = facet_choices[1]
            facet1_options = ""
            facet1_options *= "                <option value=\"None\"$(default_facet1 == "None" ? " selected" : "")>None</option>\n"
            facet1_options *= "                <option value=\"$facet_col\"$(default_facet1 == string(facet_col) ? " selected" : "")>$facet_col</option>\n"

            dropdowns_html *= """
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

            dropdowns_html *= """
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

            dropdowns_html *= """
            <div style="margin: 10px;">
                <label for="facet2_select_$chart_title">Facet 2: </label>
                <select id="facet2_select_$chart_title" onchange="updateChart_$chart_title()">
    $facet2_options            </select>
            </div>
            """
        end


        # Create filter column names as JavaScript array
        filter_cols_js = "[" * join(["'$col'" for col in keys(filters)], ", ") * "]"

        # Create color_cols and linetype_cols as JavaScript arrays
        color_cols_js = "[" * join(["'$col'" for col in valid_color_cols], ", ") * "]"
        linetype_cols_js = "[" * join(["'$col'" for col in valid_linetype_cols], ", ") * "]"

        # Create color maps as nested JavaScript object
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Create linetype maps as nested JavaScript object
        linetype_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in linetype_maps
        ], ", ") * "}"

        # Default color and linetype columns
        default_color_col = string(valid_color_cols[1])
        default_linetype_col = string(valid_linetype_cols[1])

        functional_html = """
        (function() {
            // Configuration
            const X_COL = '$x_col';
            const Y_COL = '$y_col';
            const FILTER_COLS = $filter_cols_js;
            const COLOR_COLS = $color_cols_js;
            const LINETYPE_COLS = $linetype_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const LINETYPE_MAPS = $linetype_maps_js;
            const DEFAULT_COLOR_COL = '$default_color_col';
            const DEFAULT_LINETYPE_COL = '$default_linetype_col';
            const X_LABEL = '$x_label';
            const Y_LABEL = '$y_label';

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
                // Get current filter values
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select');
                    if (select) {
                        filters[col] = select.value;
                    }
                });

                // Get current color and linetype columns
                const colorColSelect = document.getElementById('color_col_select_$chart_title');
                const COLOR_COL = colorColSelect ? colorColSelect.value : DEFAULT_COLOR_COL;

                const linetypeColSelect = document.getElementById('linetype_col_select_$chart_title');
                const LINETYPE_COL = linetypeColSelect ? linetypeColSelect.value : DEFAULT_LINETYPE_COL;

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

                // Get color and linetype maps for current selections
                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};
                const LINETYPE_MAP = LINETYPE_MAPS[LINETYPE_COL] || {};

                // Filter data
                const filteredData = allData.filter(row => {
                    for (let col in filters) {
                        if (String(row[col]) !== String(filters[col])) {
                            return false;
                        }
                    }
                    return true;
                });

                if (FACET_COLS.length === 0) {
                    // No faceting - group by color and linetype
                    const groupedData = {};
                    filteredData.forEach(row => {
                        const colorVal = String(row[COLOR_COL]);
                        const linetypeVal = String(row[LINETYPE_COL]);
                        const groupKey = colorVal + '|||' + linetypeVal;
                        if (!groupedData[groupKey]) {
                            groupedData[groupKey] = {
                                data: [],
                                color: colorVal,
                                linetype: linetypeVal
                            };
                        }
                        groupedData[groupKey].data.push(row);
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
                            Object.keys(xGroups).sort((a, b) => a - b).forEach(xVal => {
                                const aggregated = aggregate(xGroups[xVal], AGGREGATOR);
                                if (aggregated && aggregated.length > 0) {
                                    xValues.push(parseFloat(xVal));
                                    yValues.push(aggregated[0]);
                                }
                            });
                        }

                        const traceName = COLOR_COL === LINETYPE_COL ?
                            group.color :
                            group.color + ' (' + group.linetype + ')';

                        traces.push({
                            x: xValues,
                            y: yValues,
                            type: 'scatter',
                            mode: 'lines+markers',
                            name: traceName,
                            line: {
                                color: COLOR_MAP[group.color] || '#000000',
                                width: $line_width,
                                dash: LINETYPE_MAP[group.linetype] || 'solid'
                            },
                            marker: { size: $marker_size }
                        });
                    }

                    const layout = {
                        xaxis: { title: X_LABEL || X_COL },
                        yaxis: { title: Y_LABEL || Y_COL },
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

                        // Group by color and linetype within this facet
                        const groupedData = {};
                        facetData.forEach(row => {
                            const colorVal = String(row[COLOR_COL]);
                            const linetypeVal = String(row[LINETYPE_COL]);
                            const groupKey = colorVal + '|||' + linetypeVal;
                            if (!groupedData[groupKey]) {
                                groupedData[groupKey] = {
                                    data: [],
                                    color: colorVal,
                                    linetype: linetypeVal
                                };
                            }
                            groupedData[groupKey].data.push(row);
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
                                Object.keys(xGroups).sort((a, b) => a - b).forEach(xVal => {
                                    const aggregated = aggregate(xGroups[xVal], AGGREGATOR);
                                    if (aggregated && aggregated.length > 0) {
                                        xValues.push(parseFloat(xVal));
                                        yValues.push(aggregated[0]);
                                    }
                                });
                            }

                            const traceName = COLOR_COL === LINETYPE_COL ?
                                group.color :
                                group.color + ' (' + group.linetype + ')';
                            const legendGroup = traceName;

                            traces.push({
                                x: xValues,
                                y: yValues,
                                type: 'scatter',
                                mode: 'lines+markers',
                                name: traceName,
                                legendgroup: legendGroup,
                                showlegend: idx === 0,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                line: {
                                    color: COLOR_MAP[group.color] || '#000000',
                                    width: $line_width,
                                    dash: LINETYPE_MAP[group.linetype] || 'solid'
                                },
                                marker: { size: $marker_size }
                            });
                        }

                        // Add axis configuration
                        layout[xaxis] = {
                            title: row === nRows ? (X_LABEL || X_COL) : '',
                            anchor: yaxis
                        };
                        layout[yaxis] = {
                            title: col === 1 ? (Y_LABEL || Y_COL) : '',
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

                            // Group by color and linetype within this facet
                            const groupedData = {};
                            facetData.forEach(row => {
                                const colorVal = String(row[COLOR_COL]);
                                const linetypeVal = String(row[LINETYPE_COL]);
                                const groupKey = colorVal + '|||' + linetypeVal;
                                if (!groupedData[groupKey]) {
                                    groupedData[groupKey] = {
                                        data: [],
                                        color: colorVal,
                                        linetype: linetypeVal
                                    };
                                }
                                groupedData[groupKey].data.push(row);
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
                                    Object.keys(xGroups).sort((a, b) => a - b).forEach(xVal => {
                                        const aggregated = aggregate(xGroups[xVal], AGGREGATOR);
                                        if (aggregated && aggregated.length > 0) {
                                            xValues.push(parseFloat(xVal));
                                            yValues.push(aggregated[0]);
                                        }
                                    });
                                }

                                const traceName = COLOR_COL === LINETYPE_COL ?
                                    group.color :
                                    group.color + ' (' + group.linetype + ')';
                                const legendGroup = traceName;

                                traces.push({
                                    x: xValues,
                                    y: yValues,
                                    type: 'scatter',
                                    mode: 'lines+markers',
                                    name: traceName,
                                    legendgroup: legendGroup,
                                    showlegend: idx === 0,
                                    xaxis: xaxis,
                                    yaxis: yaxis,
                                    line: {
                                        color: COLOR_MAP[group.color] || '#000000',
                                        width: $line_width,
                                        dash: LINETYPE_MAP[group.linetype] || 'solid'
                                    },
                                    marker: { size: $marker_size }
                                });
                            }

                            // Add axis configuration
                            layout[xaxis] = {
                                title: rowIdx === nRows - 1 ? (X_LABEL || X_COL) : '',
                                anchor: yaxis
                            };
                            layout[yaxis] = {
                                title: colIdx === 0 ? (Y_LABEL || Y_COL) : '',
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

        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>
        
        <!-- Controls -->
        <div id="controls">
            $dropdowns_html
        </div>
        
        <!-- Chart -->
        <div id="$chart_title"></div>
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end



