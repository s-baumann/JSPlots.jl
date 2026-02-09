"""
    KernelDensity(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Kernel density plot visualization with interactive controls.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `value_cols::Vector{Symbol}`: Column(s) for density estimation (default: `[:value]`)
- `color_cols::ColorColSpec`: Column(s) for grouping/coloring. Supports custom color mapping:
  - `[:col1, :col2]` - columns using default palette
  - `[(:col1, Dict("A" => "#ff0000", "B" => "#00ff00"))]` - custom categorical colors
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict`: Column => default values. Values can be a single value, vector, or nothing for all values
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
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
                          value_cols::Vector{Symbol}=[:value],
                          color_cols::ColorColSpec=Symbol[],
                          filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                          choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
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
        color_col_names = extract_color_col_names(color_cols)
        default_color_col = isempty(color_col_names) ? nothing : first(color_col_names)

        # Build color maps for custom colors
        color_maps, color_scales, _ = build_color_maps_extended(color_cols, df)
        color_maps_js = JSON.json(color_maps)
        color_scales_js = build_color_scales_js(color_scales)

        # Validate value column
        for col in value_cols
            String(col) in all_cols || error("Value column $col not found in dataframe. Available: $all_cols")
        end

        # Validate color columns if provided
        for col in color_col_names
            String(col) in all_cols || error("Color column $col not found in dataframe. Available: $all_cols")
        end

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)
        for col in facet_choices
            String(col) in all_cols || error("Facet column $col not found in dataframe. Available: $all_cols")
        end

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(string(chart_title), normalized_choices, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") *
                       join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")

        # Separate categorical and continuous filters for JavaScript
        categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
        continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]
        choice_cols = collect(keys(normalized_choices))

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)

        # Generate facet dropdowns using html_controls abstraction
        facet_dropdowns_html = generate_facet_dropdowns_html(
            string(chart_title),
            facet_choices,
            default_facet_array,
            "updateChart_$chart_title()"
        )

        # Generate group column dropdown using html_controls abstraction
        group_dropdown_html, group_dropdown_js = generate_group_column_dropdown_html(
            string(chart_title),
            color_col_names,
            default_color_col,
            "updateChart_$(chart_title)();"
        )

        # Use only group dropdown (X dimension is controlled by axes section)
        combined_controls_html = ""
        if group_dropdown_html != ""
            combined_controls_html = """
            <div style="margin: 20px 0;">
                $group_dropdown_html
            </div>
            """
        end

        # Build axis controls HTML (only X axis for value dimension)
        axes_html = build_axis_controls_html(
            string(chart_title),
            "updateChart_$(chart_title)()";
            x_cols = value_cols,
            default_x = default_value_col
        )
        combined_controls_html *= axes_html

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
                   style="width: 75%; margin-left: 10px;">
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
            // Filter configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;

            // Plotly default colors
            const plotlyColors = [
                'rgb(31, 119, 180)', 'rgb(255, 127, 14)', 'rgb(44, 160, 44)',
                'rgb(214, 39, 40)', 'rgb(148, 103, 189)', 'rgb(140, 86, 75)',
                'rgb(227, 119, 194)', 'rgb(127, 127, 127)', 'rgb(188, 189, 34)',
                'rgb(23, 190, 207)'
            ];

            // Color maps for custom colors
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;
            $JS_COLOR_INTERPOLATION

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

            function createDensityTraces(data, VALUE_COL, GROUP_COL, BANDWIDTH, X_TRANSFORM, xaxis='x', yaxis='y', showlegend=true) {
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
                        let values = groupData.map(d => parseFloat(d[VALUE_COL])).filter(v => !isNaN(v));

                        // Apply axis transformation
                        values = applyAxisTransform(values, X_TRANSFORM);

                        if (values.length > 0) {
                            const kde = kernelDensity(values, BANDWIDTH);

                            // Get color for this group (custom map or fallback to palette)
                            const defaultColor = plotlyColors[idx % plotlyColors.length];
                            const groupColor = getColor(COLOR_MAPS, COLOR_SCALES, GROUP_COL, key, defaultColor);

                            // Convert color to rgba for fill
                            let fillColor;
                            if (groupColor.startsWith('rgb(')) {
                                fillColor = groupColor.replace('rgb', 'rgba').replace(')', ', $density_opacity)');
                            } else if (groupColor.startsWith('#')) {
                                const r = parseInt(groupColor.slice(1,3), 16);
                                const g = parseInt(groupColor.slice(3,5), 16);
                                const b = parseInt(groupColor.slice(5,7), 16);
                                fillColor = 'rgba(' + r + ', ' + g + ', ' + b + ', $density_opacity)';
                            } else {
                                fillColor = groupColor;
                            }

                            traces.push({
                                x: kde.x,
                                y: kde.y,
                                name: key,
                                type: 'scatter',
                                mode: 'lines',
                                fill: $(fill_density ? "'tozeroy'" : "'none'"),
                                line: {
                                    color: groupColor,
                                    width: 2
                                },
                                fillcolor: fillColor,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                showlegend: showlegend,
                                legendgroup: key
                            });
                        }
                    });
                } else {
                    // Single group
                    let values = data.map(d => parseFloat(d[VALUE_COL])).filter(v => !isNaN(v));

                    // Apply axis transformation
                    values = applyAxisTransform(values, X_TRANSFORM);

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

            function renderNoFacets(data, VALUE_COL, GROUP_COL, BANDWIDTH, X_TRANSFORM) {
                const traces = createDensityTraces(data, VALUE_COL, GROUP_COL, BANDWIDTH, X_TRANSFORM);

                Plotly.newPlot('$chart_title', traces, {
                    title: '$title',
                    showlegend: GROUP_COL !== null,
                    autosize: true,
                    hovermode: 'closest',
                    xaxis: {
                        title: getAxisLabel(VALUE_COL, X_TRANSFORM),
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

            function renderFacetWrap(data, VALUE_COL, GROUP_COL, FACET_COL, BANDWIDTH, X_TRANSFORM) {
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const nFacets = facetValues.length;
                const cols = Math.ceil(Math.sqrt(nFacets));
                const rows = Math.ceil(nFacets / cols);
                const traces = [];

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                    traces.push(...createDensityTraces(facetData, VALUE_COL, GROUP_COL, BANDWIDTH, X_TRANSFORM, xaxis, yaxis, idx === 0));
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
                    layout['xaxis' + ax] = {title: getAxisLabel(VALUE_COL, X_TRANSFORM)};
                    layout['yaxis' + ax] = {title: 'Density'};
                });

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function renderFacetGrid(data, VALUE_COL, GROUP_COL, FACET1_COL, FACET2_COL, BANDWIDTH, X_TRANSFORM) {
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
                        traces.push(...createDensityTraces(facetData, VALUE_COL, GROUP_COL, BANDWIDTH, X_TRANSFORM, xaxis, yaxis, idx === 0));
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
                        layout['xaxis' + ax] = {title: getAxisLabel(VALUE_COL, X_TRANSFORM)};
                        layout['yaxis' + ax] = {title: 'Density'};
                    });
                });

                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function updatePlot_$(chart_title)(data) {
                // Get current value column from axes X selector or use default
                const VALUE_COL = $(length(value_cols) >= 2 ?
                    "document.getElementById('x_col_select_$(chart_title)').value" :
                    "'$(default_value_col)'");

                // Get current group column from dropdown or use default
                let GROUP_COL = $(length(color_col_names) >= 2 ?
                    "document.getElementById('$(chart_title)_group_selector').value" :
                    (default_color_col !== nothing ? "'$(default_color_col)'" : "null"));

                // Handle "None" option for group selector
                if (GROUP_COL === '_none_') {
                    GROUP_COL = null;
                }

                // Get current axis transformation
                const xTransformSelect = document.getElementById('x_transform_select_$(chart_title)');
                const X_TRANSFORM = xTransformSelect ? xTransformSelect.value : 'identity';

                // Get bandwidth from slider (0 means auto)
                const bandwidthSlider = document.getElementById('$(chart_title)_bandwidth_slider');
                const BANDWIDTH = bandwidthSlider ? parseFloat(bandwidthSlider.value) : $(bandwidth_default);

                let FACET1 = getCol('facet1_select_$chart_title', null);
                let FACET2 = getCol('facet2_select_$chart_title', null);
                if (FACET1 === 'None') FACET1 = null;
                if (FACET2 === 'None') FACET2 = null;

                if (FACET1 && FACET2) {
                    renderFacetGrid(data, VALUE_COL, GROUP_COL, FACET1, FACET2, BANDWIDTH, X_TRANSFORM);
                } else if (FACET1) {
                    renderFacetWrap(data, VALUE_COL, GROUP_COL, FACET1, BANDWIDTH, X_TRANSFORM);
                } else {
                    renderNoFacets(data, VALUE_COL, GROUP_COL, BANDWIDTH, X_TRANSFORM);
                }
            }

            // Wrapper function
            window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title) = function() {
                // Get current filter values
                const { filters, rangeFilters, choices } = readFilterValues('$(chart_title)', CATEGORICAL_FILTERS, CONTINUOUS_FILTERS, CHOICE_FILTERS);

                // Apply filters with observation counting (centralized function)
                const filteredData = applyFiltersWithCounting(
                    window.allData_$(chart_title),
                    '$chart_title',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters,
                    CHOICE_FILTERS,
                    choices
                );

                // Render with filtered data
                updatePlot_$(chart_title)(filteredData);
            };

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title) = data;

                // Initialize controls after data is loaded
                \$(function() {
                    $group_dropdown_js

                    $bandwidth_slider_js

                    // Initial plot
                    updatePlotWithFilters_$(chart_title)();

                    // Setup aspect ratio control after initial render
                    setupAspectRatioControl('$chart_title');
                });
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
            })();
        """

        # Generate choices HTML
        choices_html = join([generate_choice_dropdown_html(dd) for dd in choice_dropdowns], "\n")

        # Use html_controls abstraction to generate base appearance HTML
        base_appearance_html = generate_appearance_html_from_sections(
            filters_html,
            combined_controls_html,
            facet_dropdowns_html,
            title,
            notes,
            string(chart_title);
            choices_html=choices_html
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
js_dependencies(::KernelDensity) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
