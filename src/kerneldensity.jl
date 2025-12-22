"""
    KernelDensity(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Kernel density plot visualization with interactive controls.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `value_cols::Vector{Symbol}`: Column(s) for density estimation (default: `[:value]`)
- `color_cols::Vector{Symbol}`: Column(s) for grouping/coloring (default: `[:color]`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict`: Column => default values. Values can be a single value, vector, or nothing for all values
- `facet_cols::Union{Nothing,Symbol,Vector{Symbol}}`: Columns available for faceting (default: `nothing`)
- `default_facet_cols::Union{Nothing,Symbol,Vector{Symbol}}`: Default faceting columns (default: `nothing`)
- `bandwidth::Union{Float64,Nothing}`: Bandwidth for kernel density estimation (default: automatic)
- `density_opacity::Float64`: Opacity of density curves (0-1) (default: `0.6`)
- `fill_density::Bool`: Whether to fill area under density curve (default: `true`)
- `title::String`: Chart title (default: `"Kernel Density Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
kd = KernelDensity(:density, df, :mydata;
    value_cols = [:measurement],
    color_cols = [:category],
    bandwidth = 0.5,
    title = "Distribution by Category"
)
```
"""
struct KernelDensity <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function KernelDensity(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                          value_cols::Vector{Symbol}=Symbol[:value],
                          color_cols::Vector{Symbol}=Symbol[:color],
                          filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                          facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          bandwidth::Union{Float64,Nothing}=nothing,
                          density_opacity::Float64=0.6,
                          fill_density::Bool=true,
                          title::String="Kernel Density Plot",
                          notes::String="")

        all_cols = names(df)

        # Default selections
        default_value_col = first(value_cols)
        default_color_col = isempty(color_cols) ? nothing : first(color_cols)

        # Validate value column
        for col in value_cols
            String(col) in all_cols || error("Value column $col not found in dataframe. Available: $all_cols")
        end

        # Validate color columns if provided
        for col in color_cols
            String(col) in all_cols || error("Color column $col not found in dataframe. Available: $all_cols")
        end

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)
        for col in facet_choices
            String(col) in all_cols || error("Facet column $col not found in dataframe. Available: $all_cols")
        end

        # Normalize filters to standard Dict{Symbol, Vector} format
        normalized_filters = normalize_filters(filters, df)

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title)()"
        filter_dropdowns = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n")
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))

        # Generate facet dropdowns using html_controls abstraction
        facet_dropdowns_html = generate_facet_dropdowns_html(
            string(chart_title),
            facet_choices,
            default_facet_array,
            "updateChart_$chart_title()"
        )

        # Generate value column dropdown using html_controls abstraction
        value_dropdown_html, value_dropdown_js = generate_value_column_dropdown_html(
            string(chart_title),
            value_cols,
            default_value_col,
            "updateChart_$(chart_title)();"
        )

        # Generate group column dropdown using html_controls abstraction
        group_dropdown_html, group_dropdown_js = generate_group_column_dropdown_html(
            string(chart_title),
            color_cols,
            default_color_col,
            "updateChart_$(chart_title)();"
        )

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

                Plotly.newPlot('$chart_title', traces, {
                    title: '$title',
                    showlegend: GROUP_COL !== null,
                    autosize: true,
                    hovermode: 'closest',
                    xaxis: {
                        title: VALUE_COL,
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
                    layout['xaxis' + ax] = {title: VALUE_COL};
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
                        layout['xaxis' + ax] = {title: VALUE_COL};
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
                let GROUP_COL = $(length(color_cols) >= 2 ?
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

            // Wrapper function
            window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title) = function() {
                const FILTER_COLS = $filter_cols_js;

                // Get filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$(chart_title)');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Filter data (support multiple selections per filter)
                const filteredData = window.allData_$(chart_title).filter(row => {
                    for (let col in filters) {
                        const selectedValues = filters[col];
                        if (selectedValues.length > 0 && !selectedValues.includes(String(row[col]))) {
                            return false;
                        }
                    }
                    return true;
                });

                // Render with filtered data
                updatePlot_$(chart_title)(filteredData);
            };

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title) = data;

                // Initialize controls after data is loaded
                \$(function() {
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

        # Use html_controls abstraction to generate base appearance HTML
        base_appearance_html = generate_appearance_html_from_sections(
            filters_html,
            combined_controls_html,
            facet_dropdowns_html,
            title,
            notes,
            string(chart_title)
        )

        # Add bandwidth slider after chart div
        appearance_html = replace(base_appearance_html,
            "<div id=\"$chart_title\"></div>" =>
            "<div id=\"$chart_title\"></div>\n\n        <!-- Bandwidth slider below chart -->\n        $bandwidth_slider_html"
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::KernelDensity) = [a.data_label]
