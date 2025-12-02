struct DistPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function DistPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                      value_col::Symbol=:value,
                      group_col::Union{Symbol,Nothing}=nothing,
                      slider_col::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                      show_histogram::Bool=true,
                      show_box::Bool=true,
                      show_rug::Bool=true,
                      histogram_bins::Int=30,
                      box_opacity::Float64=0.7,
                      title::String="Distribution Plot",
                      value_label::String="",
                      notes::String="")
        
        # Normalize slider_col to always be a vector
        slider_cols = if slider_col === nothing
            Symbol[]
        elseif slider_col isa Symbol
            [slider_col]
        else
            slider_col
        end
        
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
        
        # Generate trace creation JavaScript
        trace_js = if group_col !== nothing
            """
            // Group data by group column
            var groups = {};
            data.forEach(function(row) {
                var key = row.$(group_col);
                if (!groups[key]) groups[key] = [];
                groups[key].push(row);
            });
            
            var groupKeys = Object.keys(groups);
            var numGroups = groupKeys.length;
            
            // Create traces for each group
            groupKeys.forEach(function(key, idx) {
                var groupData = groups[key];
                var values = groupData.map(d => d.$(value_col));
                
                // Box plot (top portion)
                if (window.showBox_$(chart_title)) {
                    traces.push({
                        x: values,
                        name: key,
                        type: 'box',
                        xaxis: 'x2',
                        yaxis: 'y2',
                        orientation: 'h',
                        marker: {
                            color: plotlyColors[idx % plotlyColors.length]
                        },
                        boxmean: 'sd',
                        opacity: $box_opacity,
                        showlegend: false
                    });
                }
                
                // Histogram (bottom portion)
                if (window.showHistogram_$(chart_title)) {
                    traces.push({
                        x: values,
                        name: key,
                        type: 'histogram',
                        xaxis: 'x',
                        yaxis: 'y',
                        marker: {
                            color: plotlyColors[idx % plotlyColors.length]
                        },
                        opacity: 0.7,
                        nbinsx: $histogram_bins
                    });
                }
                
                // Rug plot (tick marks at bottom)
                if (window.showRug_$(chart_title)) {
                    traces.push({
                        x: values,
                        name: key + ' rug',
                        type: 'scatter',
                        mode: 'markers',
                        xaxis: 'x',
                        yaxis: 'y3',
                        marker: {
                            symbol: 'line-ns-open',
                            color: plotlyColors[idx % plotlyColors.length],
                            size: 8,
                            line: {
                                width: 1
                            }
                        },
                        showlegend: false,
                        hoverinfo: 'x'
                    });
                }
            });
            """
        else
            """
            var values = data.map(d => d.$(value_col));
            
            // Box plot (top portion)
            if (window.showBox_$(chart_title)) {
                traces.push({
                    x: values,
                    name: 'distribution',
                    type: 'box',
                    xaxis: 'x2',
                    yaxis: 'y2',
                    orientation: 'h',
                    marker: {
                        color: 'rgb(31, 119, 180)'
                    },
                    boxmean: 'sd',
                    opacity: $box_opacity,
                    showlegend: false
                });
            }
            
            // Histogram (bottom portion)
            if (window.showHistogram_$(chart_title)) {
                traces.push({
                    x: values,
                    name: 'frequency',
                    type: 'histogram',
                    xaxis: 'x',
                    yaxis: 'y',
                    marker: {
                        color: 'rgb(31, 119, 180)'
                    },
                    opacity: 0.7,
                    nbinsx: $histogram_bins,
                    showlegend: false
                });
            }
            
            // Rug plot (tick marks at bottom)
            if (window.showRug_$(chart_title)) {
                traces.push({
                    x: values,
                    name: 'rug',
                    type: 'scatter',
                    mode: 'markers',
                    xaxis: 'x',
                    yaxis: 'y3',
                    marker: {
                        symbol: 'line-ns-open',
                        color: 'rgb(31, 119, 180)',
                        size: 8,
                        line: {
                            width: 1
                        }
                    },
                    showlegend: false,
                    hoverinfo: 'x'
                });
            }
            """
        end
        
        # Layout configuration for distribution plot
        layout_js = """
            var layout = {
                title: '$title',
                showlegend: $(group_col !== nothing),
                autosize: true,
                grid: {
                    rows: 3,
                    columns: 1,
                    pattern: 'independent',
                    roworder: 'top to bottom'
                },
                xaxis: {
                    title: '$(value_label != "" ? value_label : string(value_col))',
                    domain: [0, 1],
                    showgrid: true,
                    zeroline: true
                },
                yaxis: {
                    title: 'Frequency',
                    domain: [0.07, 0.69],
                    showgrid: true,
                    zeroline: true
                },
                xaxis2: {
                    domain: [0, 1],
                    showgrid: false,
                    showticklabels: false
                },
                yaxis2: {
                    domain: [0.7, 1],
                    showgrid: false,
                    showticklabels: false
                },
                xaxis3: {
                    domain: [0, 1],
                    showgrid: false,
                    showticklabels: false
                },
                yaxis3: {
                    domain: [0, 0.05],
                    showgrid: false,
                    showticklabels: false
                },
                margin: {t: 100, r: 50, b: 100, l: 80}
            };
        """
        
        # Add toggle buttons for histogram, box, and rug
        toggle_buttons_html = """
        <div style="margin: 20px 0;">
            <button id="$(chart_title)_histogram_toggle" style="padding: 5px 15px; cursor: pointer; margin-right: 10px;">
                $(show_histogram ? "Hide" : "Show") Histogram
            </button>
            <button id="$(chart_title)_box_toggle" style="padding: 5px 15px; cursor: pointer; margin-right: 10px;">
                $(show_box ? "Hide" : "Show") Box Plot
            </button>
            <button id="$(chart_title)_rug_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_rug ? "Hide" : "Show") Rug Plot
            </button>
        </div>
        """
        
        sliders_html = toggle_buttons_html * sliders_html
        
        functional_html = """
            // Plotly default colors
            var plotlyColors = [
                'rgb(31, 119, 180)', 'rgb(255, 127, 14)', 'rgb(44, 160, 44)',
                'rgb(214, 39, 40)', 'rgb(148, 103, 189)', 'rgb(140, 86, 75)',
                'rgb(227, 119, 194)', 'rgb(127, 127, 127)', 'rgb(188, 189, 34)',
                'rgb(23, 190, 207)'
            ];
            
            // Initialize toggle states
            window.showHistogram_$(chart_title) = $(show_histogram ? "true" : "false");
            window.showBox_$(chart_title) = $(show_box ? "true" : "false");
            window.showRug_$(chart_title) = $(show_rug ? "true" : "false");
            
            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title) = data;

                // Initialize buttons and sliders after data is loaded
                \$(function() {
                        // Histogram toggle button
                        document.getElementById('$(chart_title)_histogram_toggle').addEventListener('click', function() {
                            window.showHistogram_$(chart_title) = !window.showHistogram_$(chart_title);
                            this.textContent = window.showHistogram_$(chart_title) ? 'Hide Histogram' : 'Show Histogram';
                            updatePlotWithFilters_$(chart_title)();
                        });
                        
                        // Box plot toggle button
                        document.getElementById('$(chart_title)_box_toggle').addEventListener('click', function() {
                            window.showBox_$(chart_title) = !window.showBox_$(chart_title);
                            this.textContent = window.showBox_$(chart_title) ? 'Hide Box Plot' : 'Show Box Plot';
                            updatePlotWithFilters_$(chart_title)();
                        });
                        
                        // Rug plot toggle button
                        document.getElementById('$(chart_title)_rug_toggle').addEventListener('click', function() {
                            window.showRug_$(chart_title) = !window.showRug_$(chart_title);
                            this.textContent = window.showRug_$(chart_title) ? 'Hide Rug Plot' : 'Show Rug Plot';
                            updatePlotWithFilters_$(chart_title)();
                        });
                        
                        $slider_init_js
                        
                    // Initial plot
                    updatePlotWithFilters_$(chart_title)();
                });
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
            
            function updatePlot_$(chart_title)(data) {
                var traces = [];
                
                $trace_js
                
                $layout_js
                
                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }
            
            $filter_logic_js
        """
        
        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>
        
        $sliders_html
        
        <!-- Chart -->
        <div id="$chart_title"></div>
        <br><hr><br>
        """
        
        new(chart_title, data_label, functional_html, appearance_html)
    end
end