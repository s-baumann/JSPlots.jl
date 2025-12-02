struct ScatterPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                         x_col::Symbol=:x,
                         y_col::Symbol=:y,
                         color_col::Union{Symbol,Nothing}=nothing,
                         slider_col::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                         show_density::Bool=true,
                         show_marginals::Bool=true,
                         marker_size::Int=4,
                         marker_opacity::Float64=0.6,
                         title::String="Scatter Plot",
                         x_label::String="",
                         y_label::String="",
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
        trace_js = if color_col !== nothing
            """
            // Group data by color column
            var groups = {};
            data.forEach(function(row) {
                var key = row.$(color_col);
                if (!groups[key]) groups[key] = [];
                groups[key].push(row);
            });
            
            // Create a trace for each group
            Object.keys(groups).forEach(function(key) {
                var groupData = groups[key];
                traces.push({
                    x: groupData.map(d => d.$(x_col)),
                    y: groupData.map(d => d.$(y_col)),
                    mode: 'markers',
                    name: key,
                    marker: {
                        size: $marker_size,
                        opacity: $marker_opacity
                    },
                    type: 'scatter'
                });
            });
            """
        else
            """
            traces.push({
                x: data.map(d => d.$(x_col)),
                y: data.map(d => d.$(y_col)),
                mode: 'markers',
                name: 'points',
                marker: {
                    size: $marker_size,
                    opacity: $marker_opacity,
                    color: 'rgb(31, 119, 180)'
                },
                type: 'scatter'
            });
            """
        end
        
        # Add density contours (controlled by button)
        density_trace_js = """
        
        // Density contours
        if (window.showDensity_$(chart_title)) {
            traces.push({
                x: data.map(d => d.$(x_col)),
                y: data.map(d => d.$(y_col)),
                name: 'density',
                ncontours: 20,
                colorscale: 'Hot',
                reversescale: true,
                showscale: false,
                type: 'histogram2dcontour',
                showlegend: false
            });
        }
        """
        
        trace_js *= density_trace_js
        
        # Add marginal histograms if enabled
        marginal_layout_js = ""
        if show_marginals
            trace_js *= """
            
            // X marginal histogram
            traces.push({
                x: data.map(d => d.$(x_col)),
                name: 'x density',
                marker: {color: 'rgba(128, 128, 128, 0.5)'},
                yaxis: 'y2',
                type: 'histogram',
                showlegend: false
            });
            
            // Y marginal histogram
            traces.push({
                y: data.map(d => d.$(y_col)),
                name: 'y density',
                marker: {color: 'rgba(128, 128, 128, 0.5)'},
                xaxis: 'x2',
                type: 'histogram',
                showlegend: false
            });
            """
            marginal_layout_js = """
                xaxis: {
                    title: '$(x_label != "" ? x_label : string(x_col))',
                    domain: [0, 0.85],
                    showgrid: true,
                    zeroline: true
                },
                yaxis: {
                    title: '$(y_label != "" ? y_label : string(y_col))',
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
            """
        else
            marginal_layout_js = """
                xaxis: {
                    title: '$(x_label != "" ? x_label : string(x_col))',
                    showgrid: true,
                    zeroline: true
                },
                yaxis: {
                    title: '$(y_label != "" ? y_label : string(y_col))',
                    showgrid: true,
                    zeroline: true
                },
            """
        end
        
        # Add density toggle button to sliders HTML
        density_button_html = """
        <div style="margin: 20px 0;">
            <button id="$(chart_title)_density_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_density ? "Hide" : "Show") Density Contours
            </button>
        </div>
        """
        
        sliders_html = density_button_html * sliders_html
        
        functional_html = """
            // Initialize density toggle state
            window.showDensity_$(chart_title) = $(show_density ? "true" : "false");
            
            // Load and parse CSV data using centralized parser
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
            
            function updatePlot_$(chart_title)(data) {
                var traces = [];
                
                $trace_js
                
                var layout = {
                    title: '$title',
                    showlegend: $(color_col !== nothing),
                    autosize: true,
                    hovermode: 'closest',
                    $marginal_layout_js
                    margin: {t: 100, r: 100, b: 100, l: 100}
                };
                
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