"""
    Surface3D(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Three-dimensional surface plot visualization using Plotly.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_col::Symbol`: Column for x-axis values (default: `:x`)
- `y_col::Symbol`: Column for y-axis values (default: `:y`)
- `z_col::Symbol`: Column for z-axis (height) values (default: `:z`)
- `group_col`: Column for grouping multiple surfaces (default: `nothing`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `height::Int`: Plot height in pixels (default: `600`)
- `title::String`: Chart title (default: `"3D Chart"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
surf = Surface3D(:surface_chart, df, :data,
    x_col=:x,
    y_col=:y,
    z_col=:z,
    group_col=:category,
    title="3D Surface Plot"
)
```
"""
struct Surface3D <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function Surface3D(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            height::Int=600,
                            x_col::Symbol=:x,
                            y_col::Symbol=:y,
                            z_col::Symbol=:z,
                            group_col::Union{Symbol,Nothing}=nothing,
                            title::String="3D Chart",
                            notes::String="")

# Normalize filters to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)

        all_cols = names(df)

        # Validate columns
        String(x_col) in all_cols || error("Column $x_col not found in dataframe. Available: $all_cols")
        String(y_col) in all_cols || error("Column $y_col not found in dataframe. Available: $all_cols")
        String(z_col) in all_cols || error("Column $z_col not found in dataframe. Available: $all_cols")
        if group_col !== nothing
            String(group_col) in all_cols || error("Column $group_col not found in dataframe. Available: $all_cols")
        end

        # Sanitize chart_title for use in JavaScript
        chart_title_safe = sanitize_chart_title(chart_title)

        # Build filter dropdowns using html_controls abstraction
        update_function = "updatePlotWithFilters_$(chart_title_safe)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title_safe), normalized_filters, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") * join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))

        # Determine if we're using grouping
        use_grouping = group_col !== nothing

        functional_html = """
            (function() {
            const FILTER_COLS = $filter_cols_js;

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data3d) {
                window.allData_$(chart_title_safe) = data3d;

                // Initial plot
                updatePlotWithFilters_$(chart_title_safe)();

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title_safe');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });

            function updatePlot_$(chart_title_safe)(data3d) {
                // ========== 3D SURFACE PLOT CONFIGURATION ==========
                // Define your column names here
                const x = '$x_col';
                const y = '$y_col';
                const z = '$z_col';
                $(use_grouping ? "const group = '$group_col';" : "")
                // ===================================================

                $(if use_grouping
                    """
                    // Get unique groups
                    const uniqueGroups = [...new Set(data3d.map(row => row[group]))].sort();
                    """
                else
                    ""
                end)

                // Define a set of distinct color gradients
                const colorGradients = [
                    // Blue gradient
                    [[0, 'rgb(8,48,107)'], [0.25, 'rgb(33,102,172)'], [0.5, 'rgb(67,147,195)'], [0.75, 'rgb(146,197,222)'], [1, 'rgb(209,229,240)']],
                    // Red-Orange gradient
                    [[0, 'rgb(127,0,0)'], [0.25, 'rgb(189,0,38)'], [0.5, 'rgb(227,74,51)'], [0.75, 'rgb(252,141,89)'], [1, 'rgb(253,204,138)']],
                    // Green gradient
                    [[0, 'rgb(0,68,27)'], [0.25, 'rgb(0,109,44)'], [0.5, 'rgb(35,139,69)'], [0.75, 'rgb(116,196,118)'], [1, 'rgb(199,233,192)']],
                    // Purple gradient
                    [[0, 'rgb(63,0,125)'], [0.25, 'rgb(106,81,163)'], [0.5, 'rgb(158,154,200)'], [0.75, 'rgb(188,189,220)'], [1, 'rgb(218,218,235)']],
                    // Yellow-Orange gradient
                    [[0, 'rgb(102,37,6)'], [0.25, 'rgb(153,52,4)'], [0.5, 'rgb(217,95,14)'], [0.75, 'rgb(254,153,41)'], [1, 'rgb(254,217,142)']],
                    // Teal gradient
                    [[0, 'rgb(1,70,54)'], [0.25, 'rgb(1,102,94)'], [0.5, 'rgb(2,129,138)'], [0.75, 'rgb(54,175,172)'], [1, 'rgb(178,226,226)']],
                    // Pink-Magenta gradient
                    [[0, 'rgb(73,0,106)'], [0.25, 'rgb(123,50,148)'], [0.5, 'rgb(194,165,207)'], [0.75, 'rgb(231,212,232)'], [1, 'rgb(247,242,247)']],
                    // Brown gradient
                    [[0, 'rgb(84,48,5)'], [0.25, 'rgb(140,81,10)'], [0.5, 'rgb(191,129,45)'], [0.75, 'rgb(223,194,125)'], [1, 'rgb(246,232,195)']],
                ];

                // Function to create z matrix for a group
                function createSurface(groupData, colorscale, name) {
                    const xVals = [...new Set(groupData.map(row => parseFloat(row[x])))].sort((a,b) => a-b);
                    const yVals = [...new Set(groupData.map(row => parseFloat(row[y])))].sort((a,b) => a-b);

                    const zMatrix = [];
                    for (let i = 0; i < yVals.length; i++) {
                        zMatrix[i] = [];
                        for (let j = 0; j < xVals.length; j++) {
                            const point = groupData.find(row =>
                                parseFloat(row[x]) === xVals[j] &&
                                parseFloat(row[y]) === yVals[i]
                            );
                            zMatrix[i][j] = point ? parseFloat(point[z]) : null;
                        }
                    }

                    return {
                        z: zMatrix,
                        x: xVals,
                        y: yVals,
                        type: 'surface',
                        name: name,
                        colorscale: colorscale,
                        showscale: false
                    };
                }

                $(if use_grouping
                    """
                    // Create a surface for each group
                    const plotData = uniqueGroups.map((grp, index) => {
                        const groupData = data3d.filter(row => row[group] === grp);
                        const colorscale = colorGradients[index % colorGradients.length];
                        return createSurface(groupData, colorscale, `Group \${grp}`);
                    });
                    """
                else
                    """
                    // Single surface without grouping
                    const plotData = [createSurface(data3d, colorGradients[0], 'Data')];
                    """
                end)

                const layout = {
                    title: '$title',
                    autosize: true,
                    height: $height,
                    scene: {
                        xaxis: { title: x },
                        yaxis: { title: y },
                        zaxis: { title: z }
                    },
                    showlegend: $(use_grouping ? "true" : "false"),
                };

                Plotly.newPlot('$chart_title_safe', plotData, layout);
            }

            // Filter and update function
            window.updatePlotWithFilters_$(chart_title_safe) = function() {
                // Get filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$(chart_title_safe)');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Filter data (support multiple selections per filter)
                const filteredData = window.allData_$(chart_title_safe).filter(row => {
                    for (let col in filters) {
                        const selectedValues = filters[col];
                        if (selectedValues.length > 0 && !selectedValues.includes(String(row[col]))) {
                            return false;
                        }
                    }
                    return true;
                });

                // Update plot with filtered data
                updatePlot_$(chart_title_safe)(filteredData);
            };

            })();
        """

        # Use html_controls abstraction to generate appearance HTML
        # Add minimal plot attributes section to enable aspect ratio slider
        plot_attributes_html = "<!-- Aspect ratio control below -->"
        appearance_html = generate_appearance_html_from_sections(
            filters_html,
            plot_attributes_html,
            "",  # No faceting in Surface3D
            title,
            notes,
            string(chart_title_safe);
            aspect_ratio_default=1.0
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::Surface3D) = [a.data_label]
js_dependencies(::Surface3D) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)

