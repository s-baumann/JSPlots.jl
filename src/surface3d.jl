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
- `slider_col`: Column(s) for filter sliders (default: `nothing`)
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
                            slider_col::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                            height::Int=600,
                            x_col::Symbol=:x,
                            y_col::Symbol=:y,
                            z_col::Symbol=:z,
                            group_col::Union{Symbol,Nothing}=nothing,
                            title::String="3D Chart",
                            notes::String="")

        all_cols = names(df)

        # Validate columns
        String(x_col) in all_cols || error("Column $x_col not found in dataframe. Available: $all_cols")
        String(y_col) in all_cols || error("Column $y_col not found in dataframe. Available: $all_cols")
        String(z_col) in all_cols || error("Column $z_col not found in dataframe. Available: $all_cols")
        if group_col !== nothing
            String(group_col) in all_cols || error("Column $group_col not found in dataframe. Available: $all_cols")
        end

        # Normalize slider_col to always be a vector
        slider_cols = if slider_col === nothing
            Symbol[]
        elseif slider_col isa Symbol
            [slider_col]
        else
            slider_col
        end

        # Validate slider columns
        for col in slider_cols
            String(col) in all_cols || error("Slider column $col not found in dataframe. Available: $all_cols")
        end

        # Generate sliders using html_controls abstraction
        sliders_html, slider_init_js = generate_slider_html_and_js(
            df,
            slider_cols,
            string(chart_title),
            "updatePlotWithFilters_$(chart_title)()"
        )

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
                        var $(col)_range = \$("#$slider_id").slider("values");
                        if (parseFloat(row.$(col)) < $(col)_range[0] || parseFloat(row.$(col)) > $(col)_range[1]) {
                            return false;
                        }
                    """)
                elseif slider_type == :date
                    push!(filter_checks, """
                        // Filter for $(col) (date)
                        var $(col)_range = \$("#$slider_id").slider("values");
                        var $(col)_dateStrings = window.dateValues_$(slider_id);
                        var row_date_str = String(row.$(col));
                        var row_date_idx = $(col)_dateStrings.indexOf(row_date_str);
                        if (row_date_idx < $(col)_range[0] || row_date_idx > $(col)_range[1]) {
                            return false;
                        }
                    """)
                end
            end

            filter_logic_js = """
            function updatePlotWithFilters_$(chart_title)() {
                var filteredData = window.allData_$(chart_title).filter(function(row) {
                    $(join(filter_checks, "\n"))
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

        # Determine if we're using grouping
        use_grouping = group_col !== nothing

        functional_html = """
            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data3d) {
                window.allData_$(chart_title) = data3d;

                \$(function() {
                    $slider_init_js

                    // Initial plot
                    updatePlotWithFilters_$(chart_title)();
                });
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });

            function updatePlot_$(chart_title)(data3d) {
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

                Plotly.newPlot('$chart_title', plotData, layout);
            }

            $filter_logic_js
        """

        # Use html_controls abstraction to generate appearance HTML
        appearance_html = generate_appearance_html_from_sections(
            sliders_html,
            "",  # No plot attributes in Surface3D
            "",  # No faceting in Surface3D
            title,
            notes,
            string(chart_title)
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::Surface3D) = [a.data_label]

