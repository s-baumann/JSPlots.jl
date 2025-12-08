struct KernelDensity <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function KernelDensity(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                          value_cols::Union{Symbol,Vector{Symbol}}=:value,
                          group_cols::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                          filter_cols::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                          facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          bandwidth::Union{Float64,Nothing}=nothing,
                          density_opacity::Float64=0.6,
                          fill_density::Bool=true,
                          title::String="Kernel Density Plot",
                          value_label::String="",
                          notes::String="")

        all_cols = names(df)

        # Normalize value_cols and group_cols
        value_cols_vec = value_cols isa Symbol ? [value_cols] : value_cols
        group_cols_vec = if group_cols === nothing
            Symbol[]
        elseif group_cols isa Symbol
            [group_cols]
        else
            group_cols
        end

        # Default selections
        default_value_col = first(value_cols_vec)
        default_group_col = isempty(group_cols_vec) ? nothing : first(group_cols_vec)

        # Validate value column
        for col in value_cols_vec
            String(col) in all_cols || error("Value column $col not found in dataframe. Available: $all_cols")
        end

        # Validate group columns if provided
        for col in group_cols_vec
            String(col) in all_cols || error("Group column $col not found in dataframe. Available: $all_cols")
        end

        # Normalize facet_cols
        facet_choices = if facet_cols === nothing
            Symbol[]
        elseif facet_cols isa Symbol
            [facet_cols]
        else
            facet_cols
        end

        default_facet_array = if default_facet_cols === nothing
            Symbol[]
        elseif default_facet_cols isa Symbol
            [default_facet_cols]
        else
            default_facet_cols
        end

        # Validate facets
        length(default_facet_array) > 2 && error("default_facet_cols can have at most 2 columns")
        for col in default_facet_array
            col in facet_choices || error("default_facet_cols must be a subset of facet_cols")
        end
        for col in facet_choices
            String(col) in all_cols || error("Facet column $col not found in dataframe. Available: $all_cols")
        end

        # Normalize filter_cols to always be a vector
        slider_cols = if filter_cols === nothing
            Symbol[]
        elseif filter_cols isa Symbol
            [filter_cols]
        else
            filter_cols
        end

        # Facet dropdowns
        facet_dropdowns_html = ""
        if length(facet_choices) == 1
            facet1_default = (length(default_facet_array) >= 1 && first(facet_choices) in default_facet_array) ? first(facet_choices) : "None"
            options = "                <option value=\"None\"$((facet1_default == "None") ? " selected" : "")>None</option>\n" *
                     "                <option value=\"$(first(facet_choices))\"$((facet1_default == first(facet_choices)) ? " selected" : "")>$(first(facet_choices))</option>"
            facet_dropdowns_html = """
            <div style="margin: 10px 0;">
                <label for="facet1_select_$chart_title">Facet by: </label>
                <select id="facet1_select_$chart_title" onchange="updateChart_$chart_title()">
$options                </select>
            </div>
            """
        elseif length(facet_choices) >= 2
            facet1_default = length(default_facet_array) >= 1 ? default_facet_array[1] : "None"
            facet2_default = length(default_facet_array) >= 2 ? default_facet_array[2] : "None"

            options1 = "                <option value=\"None\"$((facet1_default == "None") ? " selected" : "")>None</option>\n" *
                      join(["                <option value=\"$col\"$((col == facet1_default) ? " selected" : "")>$col</option>"
                           for col in facet_choices], "\n")
            options2 = "                <option value=\"None\"$((facet2_default == "None") ? " selected" : "")>None</option>\n" *
                      join(["                <option value=\"$col\"$((col == facet2_default) ? " selected" : "")>$col</option>"
                           for col in facet_choices], "\n")

            facet_dropdowns_html = """
            <div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="facet1_select_$chart_title">Facet 1:</label>
                    <select id="facet1_select_$chart_title" onchange="updateChart_$chart_title()">
$options1                </select>
                </div>
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="facet2_select_$chart_title">Facet 2:</label>
                    <select id="facet2_select_$chart_title" onchange="updateChart_$chart_title()">
$options2                </select>
                </div>
            </div>
            """
        end

        # Generate dropdown for value column selection (if multiple options)
        value_dropdown_html = ""
        value_dropdown_js = ""
        if length(value_cols_vec) >= 2
            value_options_html = join(["""<option value="$(col)"$(col == default_value_col ? " selected" : "")>$(col)</option>""" for col in value_cols_vec], "\n")
            value_dropdown_html = """
                <label for="$(chart_title)_value_selector">Select variable: </label>
                <select id="$(chart_title)_value_selector" style="padding: 5px 10px;">
                    $value_options_html
                </select>
            """
            value_dropdown_js = """
                document.getElementById('$(chart_title)_value_selector').addEventListener('change', function() {
                    updateChart_$(chart_title)();
                });
            """
        end

        # Generate dropdown for group column selection (if multiple options)
        group_dropdown_html = ""
        group_dropdown_js = ""
        if length(group_cols_vec) >= 2
            group_options_html = """<option value="_none_"$(default_group_col === nothing ? " selected" : "")>None</option>\n""" *
                               join(["""<option value="$(col)"$(col == default_group_col ? " selected" : "")>$(col)</option>""" for col in group_cols_vec], "\n")
            group_dropdown_html = """
                <label for="$(chart_title)_group_selector" style="margin-left: 20px;">Group by: </label>
                <select id="$(chart_title)_group_selector" style="padding: 5px 10px;">
                    $group_options_html
                </select>
            """
            group_dropdown_js = """
                document.getElementById('$(chart_title)_group_selector').addEventListener('change', function() {
                    updateChart_$(chart_title)();
                });
            """
        end

        # Combine value/group dropdowns on same line
        combined_controls_html = ""
        if value_dropdown_html != "" || group_dropdown_html != ""
            combined_controls_html = """
            <div style="margin: 20px 0;">
                $value_dropdown_html
                $group_dropdown_html
            </div>
            """
        end

        # Generate bandwidth slider (placed below chart)
        # Calculate automatic bandwidth using Silverman's rule to set appropriate slider range
        all_values = Float64[]
        val_cols_vec = value_cols isa AbstractVector ? value_cols : [value_cols]
        for col in val_cols_vec
            vals = df[!, col]
            append!(all_values, filter(!isnan, float.(skipmissing(vals))))
        end
        n = length(all_values)
        if n == 0
            # No data - use default values
            bandwidth_slider_max = 5.0
            bandwidth_slider_step = 0.1
        else
            data_mean = sum(all_values) / n
            data_std = sqrt(sum((all_values .- data_mean).^2) / n)
            auto_bandwidth = 1.06 * data_std * n^(-0.2)

            # Set slider max to 3x auto bandwidth for reasonable range
            # Handle edge case where auto_bandwidth is 0 or very small
            bandwidth_slider_max = max(round(3 * auto_bandwidth, digits=2), 0.1)
            bandwidth_slider_step = round(bandwidth_slider_max / 50, digits=4)  # 50 steps
            bandwidth_slider_step = max(bandwidth_slider_step, 0.001)  # Ensure step is not 0
        end

        # Use bandwidth parameter as default, or 0 for auto
        bandwidth_default = bandwidth !== nothing ? bandwidth : 0.0
        bandwidth_slider_html = """
        <div style="margin: 20px 0;">
            <label for="$(chart_title)_bandwidth_slider">Bandwidth: </label>
            <span id="$(chart_title)_bandwidth_label">$(bandwidth_default > 0 ? string(round(bandwidth_default, digits=2)) : "auto")</span>
            <input type="range" id="$(chart_title)_bandwidth_slider"
                   min="0"
                   max="$(bandwidth_slider_max)"
                   step="$(bandwidth_slider_step)"
                   value="$(bandwidth_default)"
                   style="width: 300px; margin-left: 10px;">
            <span style="margin-left: 10px; color: #666; font-size: 0.9em;">(0 = auto, max ≈ $(round(bandwidth_slider_max, digits=1)))</span>
        </div>
        """
        bandwidth_slider_js = """
            document.getElementById('$(chart_title)_bandwidth_slider').addEventListener('input', function() {
                var bw = parseFloat(this.value);
                document.getElementById('$(chart_title)_bandwidth_label').textContent = bw === 0 ? 'auto' : bw.toFixed(2);
                updateChart_$(chart_title)();
            });
        """

        # Generate sliders HTML and initialization
        sliders_html = ""
        slider_init_js = ""

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

        # Calculate bandwidth if not provided
        bandwidth_js = if bandwidth !== nothing
            "const BANDWIDTH = $bandwidth;"
        else
            "const BANDWIDTH = null; // Auto-calculate"
        end

        # Generate kernel density calculation JavaScript
        functional_html = """
            (function() {
            // Plotly default colors
            const plotlyColors = [
                'rgb(31, 119, 180)', 'rgb(255, 127, 14)', 'rgb(44, 160, 44)',
                'rgb(214, 39, 40)', 'rgb(148, 103, 189)', 'rgb(140, 86, 75)',
                'rgb(227, 119, 194)', 'rgb(127, 127, 127)', 'rgb(188, 189, 34)',
                'rgb(23, 190, 207)'
            ];

            $bandwidth_js

            // Kernel density estimation function
            function kernelDensity(values, bandwidth) {
                // Use Silverman's rule of thumb if bandwidth not specified
                if (!bandwidth) {
                    const n = values.length;
                    const mean = values.reduce((a, b) => a + b, 0) / n;
                    const std = Math.sqrt(values.reduce((sum, x) => {
                        return sum + Math.pow(x - mean, 2);
                    }, 0) / n);
                    bandwidth = 1.06 * std * Math.pow(n, -0.2);
                }

                const min = Math.min(...values);
                const max = Math.max(...values);
                const range = max - min;
                const points = 200;
                const step = range / points;

                const x = [];
                const y = [];

                for (let i = 0; i <= points; i++) {
                    const xi = min - range * 0.1 + (range * 1.2) * i / points;
                    x.push(xi);

                    let density = 0;
                    for (let j = 0; j < values.length; j++) {
                        const u = (xi - values[j]) / bandwidth;
                        // Gaussian kernel
                        density += Math.exp(-0.5 * u * u) / Math.sqrt(2 * Math.PI);
                    }
                    y.push(density / (values.length * bandwidth));
                }

                return {x: x, y: y};
            }

            const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };

            function createDensityTraces(data, VALUE_COL, GROUP_COL, BANDWIDTH, xaxis='x', yaxis='y', showlegend=true) {
                const traces = [];

                if (GROUP_COL) {
                    // Group data by group column
                    const groups = {};
                    data.forEach(function(row) {
                        const key = row[GROUP_COL];
                        if (!groups[key]) groups[key] = [];
                        groups[key].push(row);
                    });

                    const groupKeys = Object.keys(groups);

                    groupKeys.forEach(function(key, idx) {
                        const groupData = groups[key];
                        const values = groupData.map(d => parseFloat(d[VALUE_COL])).filter(v => !isNaN(v));

                        if (values.length > 0) {
                            const kde = kernelDensity(values, BANDWIDTH);

                            traces.push({
                                x: kde.x,
                                y: kde.y,
                                name: key,
                                type: 'scatter',
                                mode: 'lines',
                                fill: $(fill_density ? "'tozeroy'" : "'none'"),
                                line: {
                                    color: plotlyColors[idx % plotlyColors.length],
                                    width: 2
                                },
                                fillcolor: plotlyColors[idx % plotlyColors.length].replace('rgb', 'rgba').replace(')', ', $density_opacity)'),
                                xaxis: xaxis,
                                yaxis: yaxis,
                                showlegend: showlegend,
                                legendgroup: key
                            });
                        }
                    });
                } else {
                    // Single group
                    const values = data.map(d => parseFloat(d[VALUE_COL])).filter(v => !isNaN(v));

                    if (values.length > 0) {
                        const kde = kernelDensity(values, BANDWIDTH);

                        traces.push({
                            x: kde.x,
                            y: kde.y,
                            name: 'Density',
                            type: 'scatter',
                            mode: 'lines',
                            fill: $(fill_density ? "'tozeroy'" : "'none'"),
                            line: {
                                color: 'rgb(31, 119, 180)',
                                width: 2
                            },
                            fillcolor: 'rgba(31, 119, 180, $density_opacity)',
                            xaxis: xaxis,
                            yaxis: yaxis,
                            showlegend: false
                        });
                    }
                }

                return traces;
            }

            function renderNoFacets(data, VALUE_COL, GROUP_COL, BANDWIDTH) {
                const traces = createDensityTraces(data, VALUE_COL, GROUP_COL, BANDWIDTH);

                const valueLabel = $(value_label != "" ? "'$value_label'" : "VALUE_COL");
                Plotly.newPlot('$chart_title', traces, {
                    title: '$title',
                    showlegend: GROUP_COL !== null,
                    autosize: true,
                    hovermode: 'closest',
                    xaxis: {
                        title: valueLabel,
                        showgrid: true,
                        zeroline: true
                    },
                    yaxis: {
                        title: 'Density',
                        showgrid: true,
                        zeroline: true
                    },
                    margin: {t: 100, r: 50, b: 100, l: 80}
                }, {responsive: true});
            }

            function renderFacetWrap(data, VALUE_COL, GROUP_COL, FACET_COL, BANDWIDTH) {
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const nFacets = facetValues.length;
                const cols = Math.ceil(Math.sqrt(nFacets));
                const rows = Math.ceil(nFacets / cols);
                const traces = [];

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                    traces.push(...createDensityTraces(facetData, VALUE_COL, GROUP_COL, BANDWIDTH, xaxis, yaxis, idx === 0));
                });

                const valueLabel = $(value_label != "" ? "'$value_label'" : "VALUE_COL");
                const layout = {
                    title: '$title',
                    showlegend: GROUP_COL !== null,
                    grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: facetValues.map((val, idx) => ({
                        text: FACET_COL + ': ' + val,
                        showarrow: false,
                        xref: (idx === 0 ? 'x' : 'x' + (idx + 1)) + ' domain',
                        yref: (idx === 0 ? 'y' : 'y' + (idx + 1)) + ' domain',
                        x: 0.5,
                        y: 1.1,
                        xanchor: 'center',
                        yanchor: 'bottom'
                    })),
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };

                facetValues.forEach((val, idx) => {
                    const ax = idx === 0 ? '' : (idx + 1);
                    layout['xaxis' + ax] = {title: valueLabel};
                    layout['yaxis' + ax] = {title: 'Density'};
                });

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function renderFacetGrid(data, VALUE_COL, GROUP_COL, FACET1_COL, FACET2_COL, BANDWIDTH) {
                const facet1Values = [...new Set(data.map(row => row[FACET1_COL]))].sort();
                const facet2Values = [...new Set(data.map(row => row[FACET2_COL]))].sort();
                const rows = facet1Values.length;
                const cols = facet2Values.length;
                const traces = [];

                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row =>
                            row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val
                        );

                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                        traces.push(...createDensityTraces(facetData, VALUE_COL, GROUP_COL, BANDWIDTH, xaxis, yaxis, idx === 0));
                    });
                });

                const valueLabel = $(value_label != "" ? "'$value_label'" : "VALUE_COL");
                const layout = {
                    title: '$title',
                    showlegend: GROUP_COL !== null,
                    grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: [
                        ...facet2Values.map((val, colIdx) => ({
                            text: FACET2_COL + ': ' + val,
                            showarrow: false,
                            xref: (colIdx === 0 ? 'x' : 'x' + (colIdx + 1)) + ' domain',
                            yref: (colIdx === 0 ? 'y' : 'y' + (colIdx + 1)) + ' domain',
                            x: 0.5,
                            y: 1.1,
                            xanchor: 'center',
                            yanchor: 'bottom'
                        })),
                        ...facet1Values.map((val, rowIdx) => ({
                            text: FACET1_COL + ': ' + val,
                            showarrow: false,
                            xref: (rowIdx * cols === 0 ? 'x' : 'x' + (rowIdx * cols + 1)) + ' domain',
                            yref: (rowIdx * cols === 0 ? 'y' : 'y' + (rowIdx * cols + 1)) + ' domain',
                            x: -0.15,
                            y: 0.5,
                            xanchor: 'center',
                            yanchor: 'middle',
                            textangle: -90
                        }))
                    ],
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };

                facet1Values.forEach((v1, rowIdx) => {
                    facet2Values.forEach((v2, colIdx) => {
                        const idx = rowIdx * cols + colIdx;
                        const ax = idx === 0 ? '' : (idx + 1);
                        layout['xaxis' + ax] = {title: valueLabel};
                        layout['yaxis' + ax] = {title: 'Density'};
                    });
                });

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function updatePlot_$(chart_title)(data) {
                // Get current value column from dropdown or use default
                const VALUE_COL = $(length(value_cols_vec) >= 2 ?
                    "document.getElementById('$(chart_title)_value_selector').value" :
                    "'$(default_value_col)'");

                // Get current group column from dropdown or use default
                let GROUP_COL = $(length(group_cols_vec) >= 2 ?
                    "document.getElementById('$(chart_title)_group_selector').value" :
                    (default_group_col !== nothing ? "'$(default_group_col)'" : "null"));

                // Handle "None" option for group selector
                if (GROUP_COL === '_none_') {
                    GROUP_COL = null;
                }

                // Get bandwidth from slider (0 means auto)
                const bandwidthSlider = document.getElementById('$(chart_title)_bandwidth_slider');
                const BANDWIDTH = bandwidthSlider ? parseFloat(bandwidthSlider.value) : $(bandwidth_default);

                let FACET1 = getCol('facet1_select_$chart_title', null);
                let FACET2 = getCol('facet2_select_$chart_title', null);
                if (FACET1 === 'None') FACET1 = null;
                if (FACET2 === 'None') FACET2 = null;

                if (FACET1 && FACET2) {
                    renderFacetGrid(data, VALUE_COL, GROUP_COL, FACET1, FACET2, BANDWIDTH);
                } else if (FACET1) {
                    renderFacetWrap(data, VALUE_COL, GROUP_COL, FACET1, BANDWIDTH);
                } else {
                    renderNoFacets(data, VALUE_COL, GROUP_COL, BANDWIDTH);
                }
            }

            window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();
            $filter_logic_js

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title) = data;

                // Initialize sliders after data is loaded
                \$(function() {
                    $slider_init_js

                    $value_dropdown_js

                    $group_dropdown_js

                    $bandwidth_slider_js

                    // Initial plot
                    updatePlotWithFilters_$(chart_title)();
                });
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
            })();
        """

        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters (for data filtering) -->
        $(sliders_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;\">\n            <h4 style=\"margin-top: 0;\">Filters</h4>\n            $sliders_html\n        </div>" : "")

        <!-- Plot Attributes (variable selection and grouping) -->
        $(combined_controls_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0f8ff;\">\n            <h4 style=\"margin-top: 0;\">Plot Attributes</h4>\n            $combined_controls_html\n        </div>" : "")

        <!-- Faceting -->
        $(facet_dropdowns_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff8f0;\">\n            <h4 style=\"margin-top: 0;\">Faceting</h4>\n            $facet_dropdowns_html\n        </div>" : "")

        <!-- Chart -->
        <div id="$chart_title"></div>

        <!-- Bandwidth slider below chart -->
        $bandwidth_slider_html
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::KernelDensity) = [a.data_label]
