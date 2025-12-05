struct ScatterPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                         x_cols::Vector{Symbol}=[:x],
                         y_cols::Vector{Symbol}=[:y],
                         color_cols::Vector{Symbol}=[:color],
                         pointtype_cols::Vector{Symbol}=[:color],
                         pointsize_cols::Vector{Symbol}=[:color],
                         slider_col::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                         facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         show_density::Bool=true,
                         marker_size::Int=4,
                         marker_opacity::Float64=0.6,
                         title::String="Scatter Plot",
                         notes::String="")
        
        # Validate that required columns exist
        all_cols = names(df)
        for col in vcat(x_cols, y_cols, color_cols, pointtype_cols, pointsize_cols)
            if !(String(col) in all_cols)
                error("Column $col not found in dataframe. Available columns: $all_cols")
            end
        end

        # Normalize facet_cols to a vector
        facet_choices = if facet_cols === nothing
            Symbol[]
        elseif facet_cols isa Symbol
            [facet_cols]
        else
            facet_cols
        end

        # Validate facet columns exist
        for col in facet_choices
            if !(String(col) in all_cols)
                error("Facet column $col not found in dataframe. Available columns: $all_cols")
            end
        end

        # Normalize default faceting
        default_facet = if default_facet_cols === nothing
            nothing
        elseif default_facet_cols isa Symbol
            [default_facet_cols]
        else
            default_facet_cols
        end

        # Normalize slider_col to always be a vector
        slider_cols = if slider_col === nothing
            Symbol[]
        elseif slider_col isa Symbol
            [slider_col]
        else
            slider_col
        end
        
        # Build dropdown controls for dynamic dimensions
        dropdowns_html = ""

        # X dimension dropdown
        x_options = ""
        for col in x_cols
            selected = (col == first(x_cols)) ? " selected" : ""
            x_options *= "                <option value=\"$col\"$selected>$col</option>\n"
        end
        dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="x_col_select_$chart_title">X dimension: </label>
            <select id="x_col_select_$chart_title" onchange="updateChart_$chart_title()">
$x_options            </select>
        </div>
        """

        # Y dimension dropdown
        y_options = ""
        for col in y_cols
            selected = (col == first(y_cols)) ? " selected" : ""
            y_options *= "                <option value=\"$col\"$selected>$col</option>\n"
        end
        dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="y_col_select_$chart_title">Y dimension: </label>
            <select id="y_col_select_$chart_title" onchange="updateChart_$chart_title()">
$y_options            </select>
        </div>
        """

        # Color dropdown
        color_options = ""
        for col in color_cols
            selected = (col == first(color_cols)) ? " selected" : ""
            color_options *= "                <option value=\"$col\"$selected>$col</option>\n"
        end
        dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="color_col_select_$chart_title">Color by: </label>
            <select id="color_col_select_$chart_title" onchange="updateChart_$chart_title()">
$color_options            </select>
        </div>
        """

        # Point type dropdown
        pointtype_options = ""
        for col in pointtype_cols
            selected = (col == first(pointtype_cols)) ? " selected" : ""
            pointtype_options *= "                <option value=\"$col\"$selected>$col</option>\n"
        end
        dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="pointtype_col_select_$chart_title">Point type by: </label>
            <select id="pointtype_col_select_$chart_title" onchange="updateChart_$chart_title()">
$pointtype_options            </select>
        </div>
        """

        # Point size dropdown
        pointsize_options = ""
        for col in pointsize_cols
            selected = (col == first(pointsize_cols)) ? " selected" : ""
            pointsize_options *= "                <option value=\"$col\"$selected>$col</option>\n"
        end
        dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="pointsize_col_select_$chart_title">Point size by: </label>
            <select id="pointsize_col_select_$chart_title" onchange="updateChart_$chart_title()">
$pointsize_options            </select>
        </div>
        """

        # Faceting dropdowns (conditional on number of facet options)
        if length(facet_choices) == 1
            # Single facet option - just on/off toggle
            facet_col = first(facet_choices)
            facet1_default = (default_facet !== nothing && facet_col in default_facet) ? facet_col : "None"
            facet1_options = ""
            facet1_options *= "                <option value=\"None\"" * (facet1_default == "None" ? " selected" : "") * ">None</option>\n"
            facet1_options *= "                <option value=\"$facet_col\"" * (facet1_default == facet_col ? " selected" : "") * ">$facet_col</option>\n"
            dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="facet1_select_$chart_title">Facet by: </label>
            <select id="facet1_select_$chart_title" onchange="updateChart_$chart_title()">
$facet1_options            </select>
        </div>
        """
        elseif length(facet_choices) >= 2
            # Multiple facet options - show both facet 1 and facet 2 dropdowns
            facet1_default = (default_facet !== nothing && length(default_facet) >= 1) ? default_facet[1] : "None"
            facet2_default = (default_facet !== nothing && length(default_facet) >= 2) ? default_facet[2] : "None"

            facet1_options = ""
            facet1_options *= "                <option value=\"None\"" * (facet1_default == "None" ? " selected" : "") * ">None</option>\n"
            for col in facet_choices
                selected = (col == facet1_default) ? " selected" : ""
                facet1_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end

            facet2_options = ""
            facet2_options *= "                <option value=\"None\"" * (facet2_default == "None" ? " selected" : "") * ">None</option>\n"
            for col in facet_choices
                selected = (col == facet2_default) ? " selected" : ""
                facet2_options *= "                <option value=\"$col\"$selected>$col</option>\n"
            end

            dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="facet1_select_$chart_title">Facet 1: </label>
            <select id="facet1_select_$chart_title" onchange="updateChart_$chart_title()">
$facet1_options            </select>
        </div>
        <div style="margin: 10px;">
            <label for="facet2_select_$chart_title">Facet 2: </label>
            <select id="facet2_select_$chart_title" onchange="updateChart_$chart_title()">
$facet2_options            </select>
        </div>
        """
        end

        # Density toggle button
        density_button_html = """
        <div style="margin: 10px;">
            <button id="$(chart_title)_density_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_density ? "Hide" : "Show") Density Contours
            </button>
        </div>
        """

        dropdowns_html = density_button_html * dropdowns_html

        # Generate sliders HTML and initialization
        sliders_html = ""
        slider_init_js = ""
        slider_initialized_checks = String[]
        
        for col in slider_cols
            slider_type = detect_slider_type(df, col)
            slider_id = "$(chart_title)_$(col)_slider"
            
            if slider_type == :categorical
                unique_vals = sort(unique(skipmissing(df[!, col])))
                options_html = join(["""<option value="$(v)" selected>$(v)</option>""" for v in unique_vals], "\n")
                sliders_html *= """
                <div style="margin: 20px 0;">
                    <label for="$slider_id">Filter by $(col): </label>
                    <select id="$slider_id" multiple style="width: 300px; height: 100px;">
                        $options_html
                    </select>
                    <p style="margin: 5px 0;"><em>Hold Ctrl/Cmd to select multiple values</em></p>
                </div>
                """
                slider_init_js *= """
                    document.getElementById('$slider_id').addEventListener('change', function() {
                        updatePlotWithFilters_$(chart_title)();
                    });
                """
            elseif slider_type == :continuous
                min_val = minimum(skipmissing(df[!, col]))
                max_val = maximum(skipmissing(df[!, col]))
                sliders_html *= """
                <div style="margin: 20px 0;">
                    <label>Filter by $(col): </label>
                    <span id="$(slider_id)_label">$(round(min_val, digits=2)) to $(round(max_val, digits=2))</span>
                    <div id="$slider_id" style="width: 300px; margin: 10px 0;"></div>
                </div>
                """
                slider_init_js *= """
                    \$("#$slider_id").slider({
                        range: true,
                        min: $min_val,
                        max: $max_val,
                        step: $(abs(max_val - min_val) / 1000),
                        values: [$min_val, $max_val],
                        slide: function(event, ui) {
                            \$("#$(slider_id)_label").text(ui.values[0].toFixed(2) + " to " + ui.values[1].toFixed(2));
                        },
                        change: function(event, ui) {
                            updatePlotWithFilters_$(chart_title)();
                        }
                    });
                """
                push!(slider_initialized_checks, "\$(\"#$slider_id\").data('ui-slider')")
            elseif slider_type == :date
                unique_dates = sort(unique(skipmissing(df[!, col])))
                date_strings = string.(unique_dates)
                sliders_html *= """
                <div style="margin: 20px 0;">
                    <label>Filter by $(col): </label>
                    <span id="$(slider_id)_label">$(first(date_strings)) to $(last(date_strings))</span>
                    <div id="$slider_id" style="width: 300px; margin: 10px 0;"></div>
                </div>
                """
                slider_init_js *= """
                    window.dateValues_$(slider_id) = $(JSON.json(date_strings));
                    \$("#$slider_id").slider({
                        range: true,
                        min: 0,
                        max: $(length(unique_dates)-1),
                        step: 1,
                        values: [0, $(length(unique_dates)-1)],
                        slide: function(event, ui) {
                            \$("#$(slider_id)_label").text(window.dateValues_$(slider_id)[ui.values[0]] + " to " + window.dateValues_$(slider_id)[ui.values[1]]);
                        },
                        change: function(event, ui) {
                            updatePlotWithFilters_$(chart_title)();
                        }
                    });
                """
                push!(slider_initialized_checks, "\$(\"#$slider_id\").data('ui-slider')")
            end
        end
        
        # Generate filtering JavaScript for all sliders
        filter_logic_js = ""
        if !isempty(slider_cols)
            filter_checks = String[]
            for col in slider_cols
                slider_type = detect_slider_type(df, col)
                slider_id = "$(chart_title)_$(col)_slider"
                
                if slider_type == :categorical
                    push!(filter_checks, """
                        // Filter for $(col) (categorical)
                        var $(col)_select = document.getElementById('$slider_id');
                        var $(col)_selected = Array.from($(col)_select.selectedOptions).map(opt => opt.value);
                        if ($(col)_selected.length > 0 && !$(col)_selected.includes(String(row.$(col)))) {
                            return false;
                        }
                    """)
                elseif slider_type == :continuous
                    push!(filter_checks, """
                        // Filter for $(col) (continuous)
                        if (\$("#$slider_id").data('ui-slider')) {
                            var $(col)_values = \$("#$slider_id").slider("values");
                            var $(col)_val = parseFloat(row.$(col));
                            if ($(col)_val < $(col)_values[0] || $(col)_val > $(col)_values[1]) {
                                return false;
                            }
                        }
                    """)
                elseif slider_type == :date
                    push!(filter_checks, """
                        // Filter for $(col) (date)
                        if (\$("#$slider_id").data('ui-slider')) {
                            var $(col)_values = \$("#$slider_id").slider("values");
                            var $(col)_minDate = window.dateValues_$(slider_id)[$(col)_values[0]];
                            var $(col)_maxDate = window.dateValues_$(slider_id)[$(col)_values[1]];
                            var $(col)_rowDate = row.$(col);
                            if ($(col)_rowDate < $(col)_minDate || $(col)_rowDate > $(col)_maxDate) {
                                return false;
                            }
                        }
                    """)
                end
            end
            
            filter_logic_js = """
                function updatePlotWithFilters_$(chart_title)() {
                    var filteredData = window.allData_$(chart_title).filter(function(row) {
                        $(join(filter_checks, "\n                        "))
                        return true;
                    });
                    updatePlot_$(chart_title)(filteredData);
                }
            """
        else
            filter_logic_js = """
                function updatePlotWithFilters_$(chart_title)() {
                    updatePlot_$(chart_title)(window.allData_$(chart_title));
                }
            """
        end
        
        # Build point type symbol map
        point_symbols = ["circle", "square", "diamond", "cross", "x", "triangle-up",
                        "triangle-down", "triangle-left", "triangle-right", "pentagon",
                        "hexagon", "star"]
        
        functional_html = """
            // Initialize density toggle state
            window.showDensity_$(chart_title) = $(show_density ? "true" : "false");

            // Define point type symbols
            const POINT_SYMBOLS_$(chart_title) = $(JSON.json(point_symbols));

            // Load and parse data using centralized parser
            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title) = data;

                // Initialize sliders and button after data is loaded
                \$(function() {
                    // Density toggle button
                    document.getElementById('$(chart_title)_density_toggle').addEventListener('click', function() {
                        window.showDensity_$(chart_title) = !window.showDensity_$(chart_title);
                        this.textContent = window.showDensity_$(chart_title) ? 'Hide Density Contours' : 'Show Density Contours';
                        updatePlotWithFilters_$(chart_title)();
                    });

                    $slider_init_js

                    // Initial plot
                    updatePlotWithFilters_$(chart_title)();
                });
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });

            // Main update function
            window.updateChart_$(chart_title) = function() {
                updatePlotWithFilters_$(chart_title)();
            }

            // Helper function to build symbol map
            function buildSymbolMap_$(chart_title)(data, col) {
                const uniqueVals = [...new Set(data.map(row => row[col]))].sort();
                const symbolMap = {};
                uniqueVals.forEach((val, i) => {
                    symbolMap[val] = POINT_SYMBOLS_$(chart_title)[i % POINT_SYMBOLS_$(chart_title).length];
                });
                return symbolMap;
            }

            // Helper function to build size map
            function buildSizeMap_$(chart_title)(data, col) {
                const uniqueVals = [...new Set(data.map(row => row[col]))].sort();
                const sizeMap = {};
                const minSize = $marker_size;
                const maxSize = $marker_size * 3;
                uniqueVals.forEach((val, i) => {
                    if (uniqueVals.length === 1) {
                        sizeMap[val] = $marker_size;
                    } else {
                        sizeMap[val] = minSize + (maxSize - minSize) * i / (uniqueVals.length - 1);
                    }
                });
                return sizeMap;
            }

            // Render without faceting (with marginals)
            function renderNoFacets_$(chart_title)(data, X_COL, Y_COL, COLOR_COL, POINTTYPE_COL, POINTSIZE_COL) {
                const traces = [];

                // Build maps
                const symbolMap = buildSymbolMap_$(chart_title)(data, POINTTYPE_COL);
                const sizeMap = buildSizeMap_$(chart_title)(data, POINTSIZE_COL);

                // Group data by color column
                const groups = {};
                data.forEach(row => {
                    const key = row[COLOR_COL];
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(row);
                });

                // Create a trace for each group
                Object.keys(groups).forEach(key => {
                    const groupData = groups[key];
                    traces.push({
                        x: groupData.map(d => d[X_COL]),
                        y: groupData.map(d => d[Y_COL]),
                        mode: 'markers',
                        name: key,
                        marker: {
                            size: groupData.map(d => sizeMap[d[POINTSIZE_COL]]),
                            opacity: $marker_opacity,
                            symbol: groupData.map(d => symbolMap[d[POINTTYPE_COL]])
                        },
                        type: 'scatter'
                    });
                });

                // Add density contours if enabled
                if (window.showDensity_$(chart_title)) {
                    traces.push({
                        x: data.map(d => d[X_COL]),
                        y: data.map(d => d[Y_COL]),
                        name: 'density',
                        ncontours: 20,
                        colorscale: 'Hot',
                        reversescale: true,
                        showscale: false,
                        type: 'histogram2dcontour',
                        showlegend: false
                    });
                }

                // Add marginal histograms
                traces.push({
                    x: data.map(d => d[X_COL]),
                    name: 'x density',
                    marker: {color: 'rgba(128, 128, 128, 0.5)'},
                    yaxis: 'y2',
                    type: 'histogram',
                    showlegend: false
                });

                traces.push({
                    y: data.map(d => d[Y_COL]),
                    name: 'y density',
                    marker: {color: 'rgba(128, 128, 128, 0.5)'},
                    xaxis: 'x2',
                    type: 'histogram',
                    showlegend: false
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    autosize: true,
                    hovermode: 'closest',
                    xaxis: {
                        title: X_COL,
                        domain: [0, 0.85],
                        showgrid: true,
                        zeroline: true
                    },
                    yaxis: {
                        title: Y_COL,
                        domain: [0, 0.85],
                        showgrid: true,
                        zeroline: true
                    },
                    xaxis2: {
                        domain: [0.85, 1],
                        showgrid: false,
                        zeroline: false
                    },
                    yaxis2: {
                        domain: [0.85, 1],
                        showgrid: false,
                        zeroline: false
                    },
                    margin: {t: 100, r: 100, b: 100, l: 100}
                };

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            // Render with facet wrap (1 facet variable, no marginals)
            function renderFacetWrap_$(chart_title)(data, X_COL, Y_COL, COLOR_COL, POINTTYPE_COL, POINTSIZE_COL, FACET_COL) {
                const traces = [];

                // Build maps
                const symbolMap = buildSymbolMap_$(chart_title)(data, POINTTYPE_COL);
                const sizeMap = buildSizeMap_$(chart_title)(data, POINTSIZE_COL);

                // Get unique facet values
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const numFacets = facetValues.length;
                const cols = Math.ceil(Math.sqrt(numFacets));
                const rows = Math.ceil(numFacets / cols);

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);

                    // Group by color within this facet
                    const groups = {};
                    facetData.forEach(row => {
                        const key = row[COLOR_COL];
                        if (!groups[key]) groups[key] = [];
                        groups[key].push(row);
                    });

                    const row = Math.floor(idx / cols);
                    const col = idx % cols;
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                    Object.keys(groups).forEach(key => {
                        const groupData = groups[key];
                        traces.push({
                            x: groupData.map(d => d[X_COL]),
                            y: groupData.map(d => d[Y_COL]),
                            mode: 'markers',
                            name: key,
                            legendgroup: key,
                            showlegend: idx === 0,
                            xaxis: xaxis,
                            yaxis: yaxis,
                            marker: {
                                size: groupData.map(d => sizeMap[d[POINTSIZE_COL]]),
                                opacity: $marker_opacity,
                                symbol: groupData.map(d => symbolMap[d[POINTTYPE_COL]])
                            },
                            type: 'scatter'
                        });
                    });

                    // Add density contours if enabled
                    if (window.showDensity_$(chart_title)) {
                        traces.push({
                            x: facetData.map(d => d[X_COL]),
                            y: facetData.map(d => d[Y_COL]),
                            name: 'density',
                            ncontours: 20,
                            colorscale: 'Hot',
                            reversescale: true,
                            showscale: false,
                            type: 'histogram2dcontour',
                            showlegend: false,
                            xaxis: xaxis,
                            yaxis: yaxis
                        });
                    }
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: facetValues.map((val, idx) => ({
                        text: FACET_COL + ': ' + val,
                        showarrow: false,
                        xref: idx === 0 ? 'x domain' : 'x' + (idx + 1) + ' domain',
                        yref: idx === 0 ? 'y domain' : 'y' + (idx + 1) + ' domain',
                        x: 0.5,
                        y: 1.1,
                        xanchor: 'center',
                        yanchor: 'bottom'
                    })),
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };

                // Set axis titles for all subplots
                facetValues.forEach((val, idx) => {
                    const xaxis = idx === 0 ? 'xaxis' : 'xaxis' + (idx + 1);
                    const yaxis = idx === 0 ? 'yaxis' : 'yaxis' + (idx + 1);
                    layout[xaxis] = {title: X_COL};
                    layout[yaxis] = {title: Y_COL};
                });

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            // Render with facet grid (2 facet variables, no marginals)
            function renderFacetGrid_$(chart_title)(data, X_COL, Y_COL, COLOR_COL, POINTTYPE_COL, POINTSIZE_COL, FACET1_COL, FACET2_COL) {
                const traces = [];

                // Build maps
                const symbolMap = buildSymbolMap_$(chart_title)(data, POINTTYPE_COL);
                const sizeMap = buildSizeMap_$(chart_title)(data, POINTSIZE_COL);

                // Get unique facet values
                const facet1Values = [...new Set(data.map(row => row[FACET1_COL]))].sort();
                const facet2Values = [...new Set(data.map(row => row[FACET2_COL]))].sort();
                const rows = facet1Values.length;
                const cols = facet2Values.length;

                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row =>
                            row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val
                        );

                        if (facetData.length === 0) return;

                        // Group by color within this facet
                        const groups = {};
                        facetData.forEach(row => {
                            const key = row[COLOR_COL];
                            if (!groups[key]) groups[key] = [];
                            groups[key].push(row);
                        });

                        const idx = rowIdx * cols + colIdx;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                        Object.keys(groups).forEach(key => {
                            const groupData = groups[key];
                            traces.push({
                                x: groupData.map(d => d[X_COL]),
                                y: groupData.map(d => d[Y_COL]),
                                mode: 'markers',
                                name: key,
                                legendgroup: key,
                                showlegend: idx === 0,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                marker: {
                                    size: groupData.map(d => sizeMap[d[POINTSIZE_COL]]),
                                    opacity: $marker_opacity,
                                    symbol: groupData.map(d => symbolMap[d[POINTTYPE_COL]])
                                },
                                type: 'scatter'
                            });
                        });

                        // Add density contours if enabled
                        if (window.showDensity_$(chart_title)) {
                            traces.push({
                                x: facetData.map(d => d[X_COL]),
                                y: facetData.map(d => d[Y_COL]),
                                name: 'density',
                                ncontours: 20,
                                colorscale: 'Hot',
                                reversescale: true,
                                showscale: false,
                                type: 'histogram2dcontour',
                                showlegend: false,
                                xaxis: xaxis,
                                yaxis: yaxis
                            });
                        }
                    });
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: [],
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };

                // Add column headers
                facet2Values.forEach((val, colIdx) => {
                    const idx = colIdx;
                    layout.annotations.push({
                        text: FACET2_COL + ': ' + val,
                        showarrow: false,
                        xref: idx === 0 ? 'x domain' : 'x' + (idx + 1) + ' domain',
                        yref: idx === 0 ? 'y domain' : 'y' + (idx + 1) + ' domain',
                        x: 0.5,
                        y: 1.1,
                        xanchor: 'center',
                        yanchor: 'bottom'
                    });
                });

                // Add row headers
                facet1Values.forEach((val, rowIdx) => {
                    const idx = rowIdx * cols;
                    layout.annotations.push({
                        text: FACET1_COL + ': ' + val,
                        showarrow: false,
                        xref: idx === 0 ? 'x domain' : 'x' + (idx + 1) + ' domain',
                        yref: idx === 0 ? 'y domain' : 'y' + (idx + 1) + ' domain',
                        x: -0.15,
                        y: 0.5,
                        xanchor: 'center',
                        yanchor: 'middle',
                        textangle: -90
                    });
                });

                // Set axis titles for all subplots
                facet1Values.forEach((val1, rowIdx) => {
                    facet2Values.forEach((val2, colIdx) => {
                        const idx = rowIdx * cols + colIdx;
                        const xaxis = idx === 0 ? 'xaxis' : 'xaxis' + (idx + 1);
                        const yaxis = idx === 0 ? 'yaxis' : 'yaxis' + (idx + 1);
                        layout[xaxis] = {title: X_COL};
                        layout[yaxis] = {title: Y_COL};
                    });
                });

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function updatePlot_$(chart_title)(data) {
                // Read dropdown values
                const X_COL = document.getElementById('x_col_select_$chart_title').value;
                const Y_COL = document.getElementById('y_col_select_$chart_title').value;
                const COLOR_COL = document.getElementById('color_col_select_$chart_title').value;
                const POINTTYPE_COL = document.getElementById('pointtype_col_select_$chart_title').value;
                const POINTSIZE_COL = document.getElementById('pointsize_col_select_$chart_title').value;

                // Determine faceting mode
                let FACET1 = null;
                let FACET2 = null;

                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');

                if (facet1Select) {
                    FACET1 = facet1Select.value;
                    if (FACET1 === 'None') FACET1 = null;
                }
                if (facet2Select) {
                    FACET2 = facet2Select.value;
                    if (FACET2 === 'None') FACET2 = null;
                }

                // Render based on faceting mode
                if (FACET1 && FACET2) {
                    // Facet grid mode (no marginals)
                    renderFacetGrid_$(chart_title)(data, X_COL, Y_COL, COLOR_COL, POINTTYPE_COL, POINTSIZE_COL, FACET1, FACET2);
                } else if (FACET1) {
                    // Facet wrap mode (no marginals)
                    renderFacetWrap_$(chart_title)(data, X_COL, Y_COL, COLOR_COL, POINTTYPE_COL, POINTSIZE_COL, FACET1);
                } else {
                    // No facets mode (with marginals)
                    renderNoFacets_$(chart_title)(data, X_COL, Y_COL, COLOR_COL, POINTTYPE_COL, POINTSIZE_COL);
                }
            }

            $filter_logic_js
        """
        
        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>
        
        $sliders_html
        
        <!-- Chart -->
        <div id="$chart_title"></div>
        """
        
        new(chart_title, data_label, functional_html, appearance_html)
    end
end

function detect_slider_type(df::DataFrame, col::Symbol)
    col_data = df[!, col]
    
    # Check if it's a Date type
    if eltype(col_data) <: Union{Date, DateTime, Missing}
        return :date
    end
    
    # Check if it's numeric
    if eltype(col_data) <: Union{Number, Missing}
        unique_vals = unique(skipmissing(col_data))
        
        # If there are few unique values, treat as categorical
        if length(unique_vals) <= 20
            return :categorical
        else
            return :continuous
        end
    end
    
    # Otherwise treat as categorical
    return :categorical
end