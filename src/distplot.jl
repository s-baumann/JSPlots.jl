"""
    DistPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Distribution visualization combining histogram, box plot, and rug plot.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `value_cols`: Column(s) containing values to plot (default: `:value`)
- `group_cols`: Column(s) for group comparison (default: `nothing`)
- `filter_cols`: Column(s) for filter sliders (default: `nothing`)
- `show_histogram::Bool`: Display histogram (default: `true`)
- `show_box::Bool`: Display box plot (default: `true`)
- `show_rug::Bool`: Display rug plot (default: `true`)
- `histogram_bins::Int`: Number of histogram bins (default: `30`)
- `box_opacity::Float64`: Transparency of box plot (default: `0.7`)
- `show_controls::Bool`: Show control panel (default: `false`)
- `title::String`: Chart title (default: `"Distribution Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
dp = DistPlot(:dist_chart, df, :data,
    value_cols=:age,
    group_cols=:gender,
    histogram_bins=20,
    title="Age Distribution"
)
```
"""
struct DistPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function DistPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                      value_cols::Union{Symbol,Vector{Symbol}}=:value,
                      group_cols::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                      filter_cols::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                      show_histogram::Bool=true,
                      show_box::Bool=true,
                      show_rug::Bool=true,
                      histogram_bins::Int=30,
                      box_opacity::Float64=0.7,
                      show_controls::Bool=false,
                      title::String="Distribution Plot",
                      notes::String="")
        
        # Normalize filter_cols to always be a vector
        slider_cols = if filter_cols === nothing
            Symbol[]
        elseif filter_cols isa Symbol
            [filter_cols]
        else
            filter_cols
        end

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
        
        # Generate value column dropdown using html_controls abstraction
        value_dropdown_html, value_dropdown_js = generate_value_column_dropdown_html(
            string(chart_title),
            value_cols_vec,
            default_value_col,
            "updatePlotWithFilters_$(chart_title)();"
        )

        # Generate group column dropdown using html_controls abstraction
        group_dropdown_html, group_dropdown_js = generate_group_column_dropdown_html(
            string(chart_title),
            group_cols_vec,
            default_group_col,
            "updatePlotWithFilters_$(chart_title)();"
        )

        # Combine dropdowns on same line if either exists
        combined_dropdown_html = ""
        if value_dropdown_html != "" || group_dropdown_html != ""
            combined_dropdown_html = """
            <div style="margin: 20px 0;">
                $value_dropdown_html
                $group_dropdown_html
            </div>
            """
        end

        # Generate sliders using html_controls abstraction
        sliders_html, slider_init_js = generate_slider_html_and_js(
            df,
            slider_cols,
            string(chart_title),
            "updatePlotWithFilters_$(chart_title)()"
        )

        # Generate filtering JavaScript using html_controls abstraction
        filter_logic_js = generate_slider_filter_logic_js(
            df,
            slider_cols,
            string(chart_title),
            "updatePlot_$(chart_title)"
        )
        
        # Generate trace creation JavaScript
        trace_js = """
            // Get current selections from dropdowns
            var currentValueCol = $(length(value_cols_vec) >= 2 ?
                "document.getElementById('$(chart_title)_value_selector').value" :
                "'$(default_value_col)'");
            var currentGroupCol = $(length(group_cols_vec) >= 2 ?
                "document.getElementById('$(chart_title)_group_selector').value" :
                (default_group_col !== nothing ? "'$(default_group_col)'" : "null"));

            // Handle "None" option for group selector
            if (currentGroupCol === '_none_') {
                currentGroupCol = null;
            }

            // Get current bins from slider
            var binsSlider = document.getElementById('$(chart_title)_bins_slider');
            var currentBins = binsSlider ? parseInt(binsSlider.value) : $histogram_bins;

            if (currentGroupCol) {
                // Group data by group column
                var groups = {};
                data.forEach(function(row) {
                    var key = row[currentGroupCol];
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(row);
                });

                var groupKeys = Object.keys(groups);
                var numGroups = groupKeys.length;

                // Create traces for each group
                groupKeys.forEach(function(key, idx) {
                    var groupData = groups[key];
                    var values = groupData.map(d => d[currentValueCol]);

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
                            nbinsx: currentBins
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
            } else {
                // No grouping
                var values = data.map(d => d[currentValueCol]);

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
                        nbinsx: currentBins,
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
            }
            """
        
        # Layout configuration for distribution plot
        layout_js = """
            var layout = {
                title: '$title',
                showlegend: currentGroupCol !== null,
                autosize: true,
                grid: {
                    rows: 3,
                    columns: 1,
                    pattern: 'independent',
                    roworder: 'top to bottom'
                },
                xaxis: {
                    title: currentValueCol,
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
        
        # Add toggle buttons for histogram, box, and rug (only if show_controls is true)
        toggle_buttons_html = if show_controls
            """
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
        else
            ""
        end

        # Separate filters from plot attributes
        filter_sliders_html = sliders_html
        plot_attributes_html = toggle_buttons_html * combined_dropdown_html

        # Generate bins slider (placed below chart)
        bins_slider_html = """
        <div style="margin: 20px 0;">
            <label for="$(chart_title)_bins_slider">Number of bins: </label>
            <span id="$(chart_title)_bins_label">$histogram_bins</span>
            <input type="range" id="$(chart_title)_bins_slider"
                   min="5"
                   max="100"
                   step="1"
                   value="$histogram_bins"
                   style="width: 300px; margin-left: 10px;">
        </div>
        """
        bins_slider_js = """
            document.getElementById('$(chart_title)_bins_slider').addEventListener('input', function() {
                var bins = parseInt(this.value);
                document.getElementById('$(chart_title)_bins_label').textContent = bins;
                updatePlotWithFilters_$(chart_title)();
            });
        """

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
                        $(show_controls ? """
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
                        """ : "")

                        $value_dropdown_js

                        $group_dropdown_js

                        $bins_slider_js

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
        
        # Use html_controls abstraction to generate base appearance HTML
        base_appearance_html = generate_appearance_html_from_sections(
            filter_sliders_html,
            plot_attributes_html,
            "",  # No faceting in DistPlot
            title,
            notes,
            string(chart_title)
        )

        # Add bins slider after chart div
        appearance_html = replace(base_appearance_html,
            "<div id=\"$chart_title\"></div>" =>
            "<div id=\"$chart_title\"></div>\n\n        <!-- Bins slider below chart -->\n        $bins_slider_html"
        )
        
        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::DistPlot) = [a.data_label]
