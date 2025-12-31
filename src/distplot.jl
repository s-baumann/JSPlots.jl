"""
    DistPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Distribution visualization combining histogram, box plot, and rug plot.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `value_cols`: Column(s) containing values to plot (default: `:value`)
- `color_cols`: Column(s) for group comparison and coloring (default: `nothing`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict`: Column => default values. Values can be a single value, vector, or nothing for all values
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
    color_cols=:gender,
    filters=[:region, :category],
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
                      value_cols::Vector{Symbol}=[:value],
                      color_cols::Vector{Symbol}=Symbol[],
                      filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                      show_histogram::Bool=true,
                      show_box::Bool=true,
                      show_rug::Bool=true,
                      histogram_bins::Int=30,
                      box_opacity::Float64=0.7,
                      show_controls::Bool=false,
                      title::String="Distribution Plot",
                      notes::String="")

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)

        # Default selections
        default_value_col = first(value_cols)
        default_color_col = isempty(color_cols) ? nothing : first(color_cols)
        
        # Generate value column dropdown using html_controls abstraction
        value_dropdown_html, value_dropdown_js = generate_value_column_dropdown_html(
            string(chart_title),
            value_cols,
            default_value_col,
            "updatePlotWithFilters_$(chart_title)();"
        )

        # Generate group column dropdown using html_controls abstraction
        group_dropdown_html, group_dropdown_js = generate_group_column_dropdown_html(
            string(chart_title),
            color_cols,
            default_color_col,
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

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") *
                       join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")

        # Separate categorical and continuous filters for JavaScript
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]

        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        
        # Generate trace creation JavaScript
        trace_js = """
            // Get current selections from dropdowns
            var currentValueCol = $(length(value_cols) >= 2 ?
                "document.getElementById('$(chart_title)_value_selector').value" :
                "'$(default_value_col)'");
            var currentGroupCol = $(length(color_cols) >= 2 ?
                "document.getElementById('$(chart_title)_group_selector').value" :
                (default_color_col !== nothing ? "'$(default_color_col)'" : "null"));

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
        filter_dropdowns_html = filters_html
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
        (function() {
            // Filter configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;

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

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title) = function() {
                const totalObs = window.allData_$(chart_title).length;

                // Update total observation count
                const totalObsElement = document.getElementById('$(chart_title)_total_obs');
                if (totalObsElement) {
                    totalObsElement.textContent = '(' + totalObs + ' observations)';
                }

                // Get categorical filter values (multiple selections)
                const filters = {};
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$(chart_title)');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Get continuous filter values (range sliders)
                const rangeFilters = {};
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$(chart_title)' + '_slider');
                    if (slider.length > 0) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                // Apply filters incrementally to track observation counts
                let currentData = window.allData_$(chart_title);

                // Apply categorical filters and update counts
                CATEGORICAL_FILTERS.forEach(col => {
                    if (filters[col] && filters[col].length > 0) {
                        currentData = currentData.filter(row => {
                            const rowValueStr = temporalValueToString(row[col]);
                            return filters[col].includes(rowValueStr);
                        });
                    }

                    // Update observation count for this filter
                    const countElement = document.getElementById(col + '_select_$(chart_title)_obs_count');
                    if (countElement) {
                        const pct = totalObs > 0 ? Math.round((currentData.length / totalObs) * 100) : 100;
                        countElement.textContent = pct + '% (' + currentData.length + ') remaining';
                    }
                });

                // Apply continuous filters and update counts
                CONTINUOUS_FILTERS.forEach(col => {
                    if (rangeFilters[col]) {
                        const range = rangeFilters[col];
                        currentData = currentData.filter(row => {
                            const rawValue = row[col];
                            let value;
                            if (rawValue instanceof Date) {
                                value = rawValue.getTime();
                            } else {
                                value = parseFloat(rawValue);
                            }
                            return value >= range.min && value <= range.max;
                        });
                    }

                    // Update observation count for this filter
                    const countElement = document.getElementById(col + '_range_$(chart_title)_obs_count');
                    if (countElement) {
                        const pct = totalObs > 0 ? Math.round((currentData.length / totalObs) * 100) : 100;
                        countElement.textContent = pct + '% (' + currentData.length + ') remaining';
                    }
                });

                // Render with filtered data
                updatePlot_$(chart_title)(currentData);
            };
        })();
        """
        
        # Use html_controls abstraction to generate base appearance HTML
        base_appearance_html = generate_appearance_html_from_sections(
            filter_dropdowns_html,
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
