"""
    ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol}; kwargs...)

Scatter plot with optional marginal distributions and interactive filtering.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary
- `dimensions::Vector{Symbol}`: Vector of dimension columns for x and y axes

# Keyword Arguments
- `color_cols::Vector{Symbol}`: Columns available for color grouping (default: `[:color]`)
- `slider_col`: Column(s) for filter sliders (default: `nothing`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `show_density::Bool`: Show marginal density plots (default: `true`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points (default: `0.6`)
- `title::String`: Chart title (default: `"Scatter Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
sp = ScatterPlot(:scatter_chart, df, :data, [:x, :y],
    color_cols=[:category],
    marker_size=6,
    title="X vs Y"
)
```
"""
struct ScatterPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol};
                         color_cols::Vector{Symbol}=[:color],
                         slider_col::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                         facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         show_density::Bool=true,
                         marker_size::Int=4,
                         marker_opacity::Float64=0.6,
                         title::String="Scatter Plot",
                         notes::String="")

        all_cols = names(df)

        # Helper function to validate columns
        validate_cols(cols, name) = begin
            valid = [col for col in cols if String(col) in all_cols]
            isempty(valid) && error("None of the specified $(name) exist in dataframe. Available: $all_cols")
            valid
        end

        valid_x_cols = dimensions
        valid_y_cols = dimensions
        default_x_col = string(dimensions[1])  # First dimension is default X
        default_y_col = string(dimensions[2])  # Second dimension is default Y

        valid_color_cols = validate_cols(color_cols, "color_cols")
        default_color_col = string(valid_color_cols[1])
        # Point type always uses the same variable as color
        valid_pointtype_cols = valid_color_cols

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

        # Normalize slider_col
        slider_cols = if slider_col === nothing
            Symbol[]
        elseif slider_col isa Symbol
            [slider_col]
        else
            slider_col
        end

        # Helper function to build dropdown HTML
        build_dropdown(id, label, cols, title, default_value) = begin
            length(cols) <= 1 && return ""
            options = join(["                    <option value=\"$col\"$((string(col) == default_value) ? " selected" : "")>$col</option>"
                           for col in cols], "\n")
            """
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="$(id)_$title">$label:</label>
                    <select id="$(id)_$title" onchange="updateChart_$title()">
$options                </select>
                </div>
            """
        end


        # Generate sliders
        sliders_html = ""
        slider_init_js = ""

        for col in slider_cols
            slider_type = detect_slider_type(df, col)
            slider_id = "$(chart_title)_$(col)_slider"

            if slider_type == :categorical
                unique_vals = sort(unique(skipmissing(df[!, col])))
                options = join(["<option value=\"$(v)\" selected>$(v)</option>" for v in unique_vals], "\n")
                sliders_html *= """
                <div style="margin: 20px 0;">
                    <label for="$slider_id">Filter by $(col): </label>
                    <select id="$slider_id" multiple style="width: 300px; height: 100px;">
                        $options
                    </select>
                    <p style="margin: 5px 0;"><em>Hold Ctrl/Cmd to select multiple values</em></p>
                </div>
                """
                slider_init_js *= "                    document.getElementById('$slider_id').addEventListener('change', () => updatePlotWithFilters_$(chart_title)());\n"
            elseif slider_type == :continuous
                min_val, max_val = extrema(skipmissing(df[!, col]))
                sliders_html *= """
                <div style="margin: 20px 0;">
                    <label>Filter by $(col): </label>
                    <span id="$(slider_id)_label">$(round(min_val, digits=2)) to $(round(max_val, digits=2))</span>
                    <div id="$slider_id" style="width: 300px; margin: 10px 0;"></div>
                </div>
                """
                slider_init_js *= """
                    \$("#$slider_id").slider({
                        range: true, min: $min_val, max: $max_val, step: $(abs(max_val - min_val) / 1000),
                        values: [$min_val, $max_val],
                        slide: (e, ui) => \$("#$(slider_id)_label").text(ui.values[0].toFixed(2) + " to " + ui.values[1].toFixed(2)),
                        change: () => updatePlotWithFilters_$(chart_title)()
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
                        range: true, min: 0, max: $(length(unique_dates)-1), step: 1,
                        values: [0, $(length(unique_dates)-1)],
                        slide: (e, ui) => \$("#$(slider_id)_label").text(window.dateValues_$(slider_id)[ui.values[0]] + " to " + window.dateValues_$(slider_id)[ui.values[1]]),
                        change: () => updatePlotWithFilters_$(chart_title)()
                    });
                """
            end
        end

        # Generate filter logic
        filter_logic_js = if !isempty(slider_cols)
            filter_checks = String[]
            for col in slider_cols
                slider_type = detect_slider_type(df, col)
                slider_id = "$(chart_title)_$(col)_slider"

                if slider_type == :categorical
                    push!(filter_checks, "const $(col)_selected = Array.from(document.getElementById('$slider_id').selectedOptions).map(opt => opt.value);\n" *
                                        "                        if ($(col)_selected.length > 0 && !$(col)_selected.includes(String(row.$(col)))) return false;")
                elseif slider_type == :continuous
                    push!(filter_checks, "if (\$(\"#$slider_id\").data('ui-slider')) {\n" *
                                        "                            const $(col)_values = \$(\"#$slider_id\").slider(\"values\");\n" *
                                        "                            const $(col)_val = parseFloat(row.$(col));\n" *
                                        "                            if ($(col)_val < $(col)_values[0] || $(col)_val > $(col)_values[1]) return false;\n" *
                                        "                        }")
                elseif slider_type == :date
                    push!(filter_checks, "if (\$(\"#$slider_id\").data('ui-slider')) {\n" *
                                        "                            const $(col)_values = \$(\"#$slider_id\").slider(\"values\");\n" *
                                        "                            const $(col)_minDate = window.dateValues_$(slider_id)[$(col)_values[0]];\n" *
                                        "                            const $(col)_maxDate = window.dateValues_$(slider_id)[$(col)_values[1]];\n" *
                                        "                            if (row.$(col) < $(col)_minDate || row.$(col) > $(col)_maxDate) return false;\n" *
                                        "                        }")
                end
            end
            """
                function updatePlotWithFilters_$(chart_title)() {
                    const filteredData = window.allData_$(chart_title).filter(row => {
                        $(join(filter_checks, "\n                        "))
                        return true;
                    });
                    updatePlot_$(chart_title)(filteredData);
                }
            """
        else
            "function updatePlotWithFilters_$(chart_title)() { updatePlot_$(chart_title)(window.allData_$(chart_title)); }"
        end

        point_symbols = ["circle", "square", "diamond", "cross", "x", "triangle-up",
                        "triangle-down", "triangle-left", "triangle-right", "pentagon", "hexagon", "star"]

        functional_html = """
            (function() {
            window.showDensity_$(chart_title) = $(show_density ? "true" : "false");
            const POINT_SYMBOLS = $(JSON.json(point_symbols));
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';

            const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };
            const buildSymbolMap = (data, col) => {
                const uniqueVals = [...new Set(data.map(row => row[col]))].sort();
                return Object.fromEntries(uniqueVals.map((val, i) => [val, POINT_SYMBOLS[i % POINT_SYMBOLS.length]]));
            };

            function createTraces(data, X_COL, Y_COL, COLOR_COL, xaxis='x', yaxis='y', showlegend=true) {
                const symbolMap = buildSymbolMap(data, COLOR_COL);
                const groups = {};
                data.forEach(row => {
                    const key = row[COLOR_COL];
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(row);
                });

                return Object.entries(groups).map(([key, groupData]) => ({
                    x: groupData.map(d => d[X_COL]),
                    y: groupData.map(d => d[Y_COL]),
                    mode: 'markers',
                    name: key,
                    legendgroup: key,
                    showlegend: showlegend,
                    xaxis: xaxis,
                    yaxis: yaxis,
                    marker: {
                        size: $marker_size,
                        opacity: $marker_opacity,
                        symbol: groupData.map(d => symbolMap[d[COLOR_COL]])
                    },
                    type: 'scatter'
                }));
            }

            function renderNoFacets(data, X_COL, Y_COL, COLOR_COL) {
                const traces = createTraces(data, X_COL, Y_COL, COLOR_COL);

                if (window.showDensity_$(chart_title)) {
                    traces.push({
                        x: data.map(d => d[X_COL]), y: data.map(d => d[Y_COL]),
                        name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                        showscale: false, type: 'histogram2dcontour', showlegend: false
                    });
                }

                traces.push(
                    { x: data.map(d => d[X_COL]), name: 'x density', marker: {color: 'rgba(128, 128, 128, 0.5)'}, yaxis: 'y2', type: 'histogram', showlegend: false },
                    { y: data.map(d => d[Y_COL]), name: 'y density', marker: {color: 'rgba(128, 128, 128, 0.5)'}, xaxis: 'x2', type: 'histogram', showlegend: false }
                );

                Plotly.newPlot('$chart_title', traces, {
                    title: '$title', showlegend: true, autosize: true, hovermode: 'closest',
                    xaxis: { title: X_COL, domain: [0, 0.85], showgrid: true, zeroline: true },
                    yaxis: { title: Y_COL, domain: [0, 0.85], showgrid: true, zeroline: true },
                    xaxis2: { domain: [0.85, 1], showgrid: false, zeroline: false },
                    yaxis2: { domain: [0.85, 1], showgrid: false, zeroline: false },
                    margin: {t: 100, r: 100, b: 100, l: 100}
                }, {responsive: true});
            }

            function renderFacetWrap(data, X_COL, Y_COL, COLOR_COL, FACET_COL) {
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const nFacets = facetValues.length, cols = Math.ceil(Math.sqrt(nFacets)), rows = Math.ceil(nFacets / cols);
                const traces = [];

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                    traces.push(...createTraces(facetData, X_COL, Y_COL, COLOR_COL, xaxis, yaxis, idx === 0));

                    if (window.showDensity_$(chart_title)) {
                        traces.push({
                            x: facetData.map(d => d[X_COL]), y: facetData.map(d => d[Y_COL]),
                            name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                            showscale: false, type: 'histogram2dcontour', showlegend: false, xaxis: xaxis, yaxis: yaxis
                        });
                    }
                });

                const layout = {
                    title: '$title', showlegend: true, grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: facetValues.map((val, idx) => ({
                        text: FACET_COL + ': ' + val, showarrow: false,
                        xref: (idx === 0 ? 'x' : 'x' + (idx + 1)) + ' domain',
                        yref: (idx === 0 ? 'y' : 'y' + (idx + 1)) + ' domain',
                        x: 0.5, y: 1.1, xanchor: 'center', yanchor: 'bottom'
                    })),
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };
                facetValues.forEach((val, idx) => {
                    const ax = idx === 0 ? '' : (idx + 1);
                    layout['xaxis' + ax] = {title: X_COL};
                    layout['yaxis' + ax] = {title: Y_COL};
                });
                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function renderFacetGrid(data, X_COL, Y_COL, COLOR_COL, FACET1_COL, FACET2_COL) {
                const facet1Values = [...new Set(data.map(row => row[FACET1_COL]))].sort();
                const facet2Values = [...new Set(data.map(row => row[FACET2_COL]))].sort();
                const rows = facet1Values.length, cols = facet2Values.length;
                const traces = [];

                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row => row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val);
                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);
                        traces.push(...createTraces(facetData, X_COL, Y_COL, COLOR_COL, xaxis, yaxis, idx === 0));

                        if (window.showDensity_$(chart_title)) {
                            traces.push({
                                x: facetData.map(d => d[X_COL]), y: facetData.map(d => d[Y_COL]),
                                name: 'density', ncontours: 20, colorscale: 'Hot', reversescale: true,
                                showscale: false, type: 'histogram2dcontour', showlegend: false, xaxis: xaxis, yaxis: yaxis
                            });
                        }
                    });
                });

                const layout = {
                    title: '$title', showlegend: true, grid: {rows: rows, columns: cols, pattern: 'independent'},
                    annotations: [
                        ...facet2Values.map((val, colIdx) => ({
                            text: FACET2_COL + ': ' + val, showarrow: false,
                            xref: (colIdx === 0 ? 'x' : 'x' + (colIdx + 1)) + ' domain',
                            yref: (colIdx === 0 ? 'y' : 'y' + (colIdx + 1)) + ' domain',
                            x: 0.5, y: 1.1, xanchor: 'center', yanchor: 'bottom'
                        })),
                        ...facet1Values.map((val, rowIdx) => ({
                            text: FACET1_COL + ': ' + val, showarrow: false,
                            xref: (rowIdx * cols === 0 ? 'x' : 'x' + (rowIdx * cols + 1)) + ' domain',
                            yref: (rowIdx * cols === 0 ? 'y' : 'y' + (rowIdx * cols + 1)) + ' domain',
                            x: -0.15, y: 0.5, xanchor: 'center', yanchor: 'middle', textangle: -90
                        }))
                    ],
                    margin: {t: 100, r: 50, b: 50, l: 50}
                };
                facet1Values.forEach((v1, rowIdx) => {
                    facet2Values.forEach((v2, colIdx) => {
                        const idx = rowIdx * cols + colIdx, ax = idx === 0 ? '' : (idx + 1);
                        layout['xaxis' + ax] = {title: X_COL};
                        layout['yaxis' + ax] = {title: Y_COL};
                    });
                });
                Plotly.newPlot('$chart_title', traces, layout, {responsive: true});
            }

            function updatePlot_$(chart_title)(data) {
                const X_COL = getCol('x_col_select_$chart_title', DEFAULT_X_COL);
                const Y_COL = getCol('y_col_select_$chart_title', DEFAULT_Y_COL);
                const COLOR_COL = getCol('color_col_select_$chart_title', DEFAULT_COLOR_COL);

                let FACET1 = getCol('facet1_select_$chart_title', null);
                let FACET2 = getCol('facet2_select_$chart_title', null);
                if (FACET1 === 'None') FACET1 = null;
                if (FACET2 === 'None') FACET2 = null;

                if (FACET1 && FACET2) {
                    renderFacetGrid(data, X_COL, Y_COL, COLOR_COL, FACET1, FACET2);
                } else if (FACET1) {
                    renderFacetWrap(data, X_COL, Y_COL, COLOR_COL, FACET1);
                } else {
                    renderNoFacets(data, X_COL, Y_COL, COLOR_COL);
                }
            }

            window.updateChart_$(chart_title) = () => updatePlotWithFilters_$(chart_title)();
            $filter_logic_js

            loadDataset('$data_label').then(data => {
                window.allData_$(chart_title) = data;
                \$(function() {
                    const densityBtn = document.getElementById('$(chart_title)_density_toggle');
                    if (densityBtn) {
                        densityBtn.addEventListener('click', function() {
                            window.showDensity_$(chart_title) = !window.showDensity_$(chart_title);
                            this.textContent = window.showDensity_$(chart_title) ? 'Hide Density Contours' : 'Show Density Contours';
                            updatePlotWithFilters_$(chart_title)();
                        });
                    }
$slider_init_js                    updatePlotWithFilters_$(chart_title)();
                });
            }).catch(error => console.error('Error loading data for chart $chart_title:', error));
            })();
        """

        # Separate controls into filters, plot attributes, and faceting
        filters_html = sliders_html

        # Separate plot attributes from faceting
        plot_attributes_html = ""
        faceting_html = ""

        # Build plot attributes section (density toggle, X/Y selectors, color selector)
        plot_attributes_html = """
        <div style="margin: 10px 0;">
            <button id="$(chart_title)_density_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_density ? "Hide" : "Show") Density Contours
            </button>
        </div>
        """

        # X and Y dropdowns (on same line if either has multiple options)
        xy_html = build_dropdown("x_col_select", "X", valid_x_cols, chart_title, default_x_col) *
                  build_dropdown("y_col_select", "Y", valid_y_cols, chart_title, default_y_col)
        if !isempty(xy_html)
            plot_attributes_html *= """<div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
$xy_html        </div>
"""
        end

        # Style dropdown (color/point type)
        style_html = build_dropdown("color_col_select", "Color/Point type", valid_color_cols, chart_title, default_color_col)
        if !isempty(style_html)
            plot_attributes_html *= """<div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
$style_html        </div>
"""
        end

        # Build faceting section
        if length(facet_choices) == 1
            facet1_default = (length(default_facet_array) >= 1 && first(facet_choices) in default_facet_array) ? first(facet_choices) : "None"
            options = "                <option value=\"None\"$((facet1_default == "None") ? " selected" : "")>None</option>\n" *
                     "                <option value=\"$(first(facet_choices))\"$((facet1_default == first(facet_choices)) ? " selected" : "")>$(first(facet_choices))</option>"
            faceting_html = """
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

            faceting_html = """
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

        # Use html_controls abstraction to generate appearance HTML
        appearance_html = generate_appearance_html_from_sections(
            filters_html,
            plot_attributes_html,
            faceting_html,
            title,
            notes,
            string(chart_title)
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

function detect_slider_type(df::DataFrame, col::Symbol)
    col_data = df[!, col]
    eltype(col_data) <: Union{Date, DateTime, Missing} && return :date

    if eltype(col_data) <: Union{Number, Missing}
        unique_vals = unique(skipmissing(col_data))
        return length(unique_vals) <= 20 ? :categorical : :continuous
    end

    return :categorical
end

dependencies(a::ScatterPlot) = [a.data_label]
