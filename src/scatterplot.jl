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
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
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
                         filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                         facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                         show_density::Bool=true,
                         marker_size::Int=4,
                         marker_opacity::Float64=0.6,
                         title::String="Scatter Plot",
                         notes::String="")

# Normalize filters to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)

        # Validate columns exist in dataframe
        valid_x_cols = dimensions
        valid_y_cols = dimensions
        default_x_col = string(dimensions[1])  # First dimension is default X
        default_y_col = string(dimensions[2])  # Second dimension is default Y

        valid_color_cols = validate_and_filter_columns(color_cols, df, "color_cols")
        default_color_col = string(valid_color_cols[1])
        # Point type always uses the same variable as color
        valid_pointtype_cols = valid_color_cols

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)
        all_cols = names(df)
        for col in facet_choices
            String(col) in all_cols || error("Facet column $col not found in dataframe. Available: $all_cols")
        end

        # Build filter dropdowns
        update_function = "updatePlotWithFilters_$(chart_title)()"
        filter_dropdowns = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n")
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))

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

        point_symbols = ["circle", "square", "diamond", "cross", "x", "triangle-up",
                        "triangle-down", "triangle-left", "triangle-right", "pentagon", "hexagon", "star"]

        functional_html = """
            (function() {
            const FILTER_COLS = $filter_cols_js;
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

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title) = function() {
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

                // Update plot with filtered data
                updatePlot_$(chart_title)(filteredData);
            };

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
                    updatePlotWithFilters_$(chart_title)();
                });
            }).catch(error => console.error('Error loading data for chart $chart_title:', error));
            })();
        """

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

        # Build faceting section using html_controls abstraction
        faceting_html = generate_facet_dropdowns_html(
            string(chart_title),
            facet_choices,
            default_facet_array,
            "updateChart_$chart_title()"
        )

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

dependencies(a::ScatterPlot) = [a.data_label]
