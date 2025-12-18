"""
    Scatter3D(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol}; kwargs...)

Three-dimensional scatter plot with PCA eigenvectors and interactive filtering.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary
- `dimensions::Vector{Symbol}`: Vector of at least 3 dimension columns for x, y, and z axes

# Keyword Arguments
- `color_cols::Vector{Symbol}`: Columns available for color grouping (default: `[:color]`)
- `slider_col`: Column(s) for filter sliders (default: `nothing`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `show_eigenvectors::Bool`: Display PCA eigenvectors (default: `true`)
- `shared_camera::Bool`: Synchronize camera view across facets (default: `true`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points (default: `0.6`)
- `title::String`: Chart title (default: `"3D Scatter Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
scatter = Scatter3D(:scatter_3d, df, :data, [:x, :y, :z],
    color_cols=[:category],
    show_eigenvectors=true,
    marker_size=6,
    title="3D Point Cloud"
)
```
"""
struct Scatter3D <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function Scatter3D(chart_title::Symbol, df::DataFrame, data_label::Symbol, dimensions::Vector{Symbol};
                          color_cols::Vector{Symbol}=[:color],
                          slider_col::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                          facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                          show_eigenvectors::Bool=true,
                          shared_camera::Bool=true,
                          marker_size::Int=4,
                          marker_opacity::Float64=0.6,
                          title::String="3D Scatter Plot",
                          notes::String="")

        # Sanitize chart_title for use in JavaScript function names
        chart_title_safe = sanitize_chart_title(chart_title)

        all_cols = names(df)

        # Validate dimensions
        length(dimensions) >= 3 || error("dimensions must contain at least 3 columns for x, y, z axes")
        for col in dimensions
            String(col) in all_cols || error("Dimension column $col not found in dataframe. Available: $all_cols")
        end

        # Defaults for x, y, z
        default_x_col = string(dimensions[1])
        default_y_col = string(dimensions[2])
        default_z_col = string(dimensions[3])

        # Validate color columns
        valid_color_cols = Symbol[]
        for col in color_cols
            String(col) in all_cols && push!(valid_color_cols, col)
        end
        isempty(valid_color_cols) && error("None of the specified color_cols exist in dataframe. Available: $all_cols")
        default_color_col = string(valid_color_cols[1])

        # Build color maps for all valid color columns
        color_palette = ["#636efa", "#EF553B", "#00cc96", "#ab63fa", "#FFA15A",
                        "#19d3f3", "#FF6692", "#B6E880", "#FF97FF", "#FECB52"]
        color_maps = Dict()
        for col in valid_color_cols
            unique_vals = unique(df[!, col])
            color_maps[string(col)] = Dict(
                string(key) => color_palette[(i - 1) % length(color_palette) + 1]
                for (i, key) in enumerate(unique_vals)
            )
        end

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

        # Validate slider columns
        for col in slider_cols
            String(col) in all_cols || error("Slider column $col not found in dataframe. Available: $all_cols")
        end

        # Helper function to build dropdown HTML
        build_dropdown(id, label, cols, default_value, onchange_fn) = begin
            length(cols) <= 1 && return ""
            options = join(["                    <option value=\"$col\"$((string(col) == default_value) ? " selected" : "")>$col</option>"
                           for col in cols], "\n")
            """
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="$(id)">$label:</label>
                    <select id="$(id)" onchange="$onchange_fn">
$options                </select>
                </div>
            """
        end

        # Build plot attributes section
        plot_attributes_html = """
        <div style="margin: 10px 0; display: flex; gap: 10px; align-items: center;">
            <button id="$(chart_title_safe)_eigenvector_toggle" style="padding: 5px 15px; cursor: pointer;">
                $(show_eigenvectors ? "Hide" : "Show") Eigenvectors
            </button>
        </div>
        """

        # X, Y, Z dropdowns (only show if more than 3 dimensions)
        xyz_html = ""
        if length(dimensions) > 3
            xyz_html = build_dropdown("$(chart_title_safe)_x_col_select", "X", dimensions, default_x_col, "updatePlotWithFilters_$(chart_title_safe)()") *
                       build_dropdown("$(chart_title_safe)_y_col_select", "Y", dimensions, default_y_col, "updatePlotWithFilters_$(chart_title_safe)()") *
                       build_dropdown("$(chart_title_safe)_z_col_select", "Z", dimensions, default_z_col, "updatePlotWithFilters_$(chart_title_safe)()")
        end
        if !isempty(xyz_html)
            plot_attributes_html *= """<div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
$xyz_html        </div>
"""
        end

        # Style dropdown (color only)
        style_html = build_dropdown("$(chart_title_safe)_color_col_select", "Color", valid_color_cols, default_color_col, "updatePlotWithFilters_$(chart_title_safe)()")
        if !isempty(style_html)
            plot_attributes_html *= """<div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
$style_html        </div>
"""
        end

        # Generate faceting section using html_controls abstraction
        faceting_html = generate_facet_dropdowns_html(
            string(chart_title_safe),
            facet_choices,
            default_facet_array,
            "updatePlotWithFilters_$chart_title()"
        )

        # Generate sliders using html_controls abstraction
        sliders_html, slider_init_js = generate_slider_html_and_js(
            df,
            slider_cols,
            string(chart_title_safe),
            "updatePlotWithFilters_$(chart_title_safe)()"
        )

        # Generate filter logic
        filter_logic_js = if !isempty(slider_cols)
            filter_checks = String[]
            for col in slider_cols
                slider_type = detect_slider_type(df, col)
                slider_id = "$(chart_title_safe)_$(col)_slider"

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
                window.updatePlotWithFilters_$(chart_title_safe) = function() {
                    const filteredData = window.allData_$(chart_title_safe).filter(row => {
                        $(join(filter_checks, "\n                        "))
                        return true;
                    });
                    updateChart_$(chart_title_safe)(filteredData);
                };
            """
        else
            "window.updatePlotWithFilters_$(chart_title_safe) = function() { updateChart_$(chart_title_safe)(window.allData_$(chart_title_safe)); };"
        end

        # Create color maps as nested JavaScript object
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        functional_html = """
            (function() {
            window.showEigenvectors_$(chart_title_safe) = $(show_eigenvectors ? "true" : "false");
            window.sharedCamera_$(chart_title_safe) = true; // Always use shared camera
            window.currentCamera_$(chart_title_safe) = null;
            const DEFAULT_X_COL = '$default_x_col';
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_Z_COL = '$default_z_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const COLOR_MAPS = $color_maps_js;

            const getCol = (id, def) => { const el = document.getElementById(id); return el ? el.value : def; };

            // Eigenvector toggle
            document.getElementById('$(chart_title_safe)_eigenvector_toggle').addEventListener('click', function() {
                window.showEigenvectors_$(chart_title_safe) = !window.showEigenvectors_$(chart_title_safe);
                this.textContent = window.showEigenvectors_$(chart_title_safe) ? 'Hide Eigenvectors' : 'Show Eigenvectors';
                updatePlotWithFilters_$(chart_title_safe)();
            });

            function computeEigenvectors(data, X_COL, Y_COL, Z_COL) {
                // Extract numeric data
                const xs = data.map(row => parseFloat(row[X_COL]));
                const ys = data.map(row => parseFloat(row[Y_COL]));
                const zs = data.map(row => parseFloat(row[Z_COL]));

                // Compute means
                const meanX = xs.reduce((a, b) => a + b, 0) / xs.length;
                const meanY = ys.reduce((a, b) => a + b, 0) / ys.length;
                const meanZ = zs.reduce((a, b) => a + b, 0) / zs.length;

                // Center the data
                const centeredX = xs.map(x => x - meanX);
                const centeredY = ys.map(y => y - meanY);
                const centeredZ = zs.map(z => z - meanZ);

                // Compute covariance matrix
                const n = xs.length;
                const cov = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];

                for (let i = 0; i < n; i++) {
                    cov[0][0] += centeredX[i] * centeredX[i];
                    cov[0][1] += centeredX[i] * centeredY[i];
                    cov[0][2] += centeredX[i] * centeredZ[i];
                    cov[1][0] += centeredY[i] * centeredX[i];
                    cov[1][1] += centeredY[i] * centeredY[i];
                    cov[1][2] += centeredY[i] * centeredZ[i];
                    cov[2][0] += centeredZ[i] * centeredX[i];
                    cov[2][1] += centeredZ[i] * centeredY[i];
                    cov[2][2] += centeredZ[i] * centeredZ[i];
                }

                for (let i = 0; i < 3; i++) {
                    for (let j = 0; j < 3; j++) {
                        cov[i][j] /= n;
                    }
                }

                // Power iteration for first eigenvector
                let v1 = [1, 0, 0];
                for (let iter = 0; iter < 20; iter++) {
                    const newV = [
                        cov[0][0] * v1[0] + cov[0][1] * v1[1] + cov[0][2] * v1[2],
                        cov[1][0] * v1[0] + cov[1][1] * v1[1] + cov[1][2] * v1[2],
                        cov[2][0] * v1[0] + cov[2][1] * v1[1] + cov[2][2] * v1[2]
                    ];
                    const norm = Math.sqrt(newV[0]**2 + newV[1]**2 + newV[2]**2);
                    v1 = [newV[0]/norm, newV[1]/norm, newV[2]/norm];
                }

                // Second eigenvector (orthogonal to first)
                let v2 = [0, 1, 0];
                const dot12 = v2[0]*v1[0] + v2[1]*v1[1] + v2[2]*v1[2];
                v2 = [v2[0] - dot12*v1[0], v2[1] - dot12*v1[1], v2[2] - dot12*v1[2]];
                const norm2 = Math.sqrt(v2[0]**2 + v2[1]**2 + v2[2]**2);
                v2 = [v2[0]/norm2, v2[1]/norm2, v2[2]/norm2];

                // Third eigenvector (cross product)
                const v3 = [
                    v1[1]*v2[2] - v1[2]*v2[1],
                    v1[2]*v2[0] - v1[0]*v2[2],
                    v1[0]*v2[1] - v1[1]*v2[0]
                ];

                // Compute fixed scale (20% of average data range)
                const xRange = Math.max(...xs) - Math.min(...xs);
                const yRange = Math.max(...ys) - Math.min(...ys);
                const zRange = Math.max(...zs) - Math.min(...zs);
                const fixedScale = (xRange + yRange + zRange) / 3 * 0.2;

                return {
                    center: [meanX, meanY, meanZ],
                    vectors: [v1, v2, v3],
                    scale: fixedScale
                };
            }

            function createEigenvectorTraces(eigData, sceneId) {
                const traces = [];
                const colors = ['red', 'green', 'blue'];
                const [cx, cy, cz] = eigData.center;

                eigData.vectors.forEach((vec, idx) => {
                    traces.push({
                        x: [cx, cx + vec[0] * eigData.scale],
                        y: [cy, cy + vec[1] * eigData.scale],
                        z: [cz, cz + vec[2] * eigData.scale],
                        mode: 'lines+markers',
                        type: 'scatter3d',
                        name: \`PC\${idx + 1}\`,
                        legendgroup: \`PC\${idx + 1}\`,
                        scene: sceneId,
                        line: { color: colors[idx], width: 6 },
                        marker: { size: 6, symbol: 'diamond' },
                        showlegend: idx === 0 || sceneId === 'scene'
                    });
                });

                return traces;
            }

            function updateChart_$(chart_title_safe)(dataOverride) {
                const data = dataOverride || window.allData_$(chart_title_safe);
                const X_COL = getCol('$(chart_title_safe)_x_col_select', DEFAULT_X_COL);
                const Y_COL = getCol('$(chart_title_safe)_y_col_select', DEFAULT_Y_COL);
                const Z_COL = getCol('$(chart_title_safe)_z_col_select', DEFAULT_Z_COL);
                const COLOR_COL = getCol('$(chart_title_safe)_color_col_select', DEFAULT_COLOR_COL);

                // Get facet selections
                const FACET1_COL = getCol('facet1_select_$(chart_title_safe)', 'None');
                const FACET2_COL = getCol('facet2_select_$(chart_title_safe)', 'None');

                if (FACET1_COL === 'None' && FACET2_COL === 'None') {
                    renderNoFacets_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL);
                } else if (FACET1_COL !== 'None' && FACET2_COL === 'None') {
                    renderFacetWrap_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET1_COL);
                } else if (FACET1_COL !== 'None' && FACET2_COL !== 'None') {
                    renderFacetGrid_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET1_COL, FACET2_COL);
                } else {
                    renderFacetWrap_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET2_COL);
                }
            }

            function renderNoFacets_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL) {
                const groups = {};
                data.forEach(row => {
                    const key = row[COLOR_COL];
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(row);
                });

                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};
                const traces = Object.entries(groups).map(([key, groupData]) => ({
                    x: groupData.map(d => parseFloat(d[X_COL])),
                    y: groupData.map(d => parseFloat(d[Y_COL])),
                    z: groupData.map(d => parseFloat(d[Z_COL])),
                    mode: 'markers',
                    name: key,
                    type: 'scatter3d',
                    marker: {
                        size: $marker_size,
                        opacity: $marker_opacity,
                        color: COLOR_MAP[key] || '#636efa'
                    }
                }));

                if (window.showEigenvectors_$(chart_title_safe) && data.length > 3) {
                    const eigData = computeEigenvectors(data, X_COL, Y_COL, Z_COL);
                    traces.push(...createEigenvectorTraces(eigData, 'scene'));
                }

                const layout = {
                    title: '$title',
                    autosize: true,
                    showlegend: true,
                    scene: {
                        xaxis: { title: X_COL },
                        yaxis: { title: Y_COL },
                        zaxis: { title: Z_COL },
                        camera: window.currentCamera_$(chart_title_safe) || undefined
                    },
                    margin: { t: 50, r: 50, b: 50, l: 50 }
                };

                Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});

                // Store current camera
                const plotDiv = document.getElementById('$(chart_title_safe)');
                plotDiv.on('plotly_relayout', (eventData) => {
                    if (eventData['scene.camera']) {
                        window.currentCamera_$(chart_title_safe) = eventData['scene.camera'];
                    }
                });
            }

            function renderFacetWrap_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET_COL) {
                const facetValues = [...new Set(data.map(row => row[FACET_COL]))].sort();
                const nFacets = facetValues.length;
                const cols = Math.ceil(Math.sqrt(nFacets));
                const rows = Math.ceil(nFacets / cols);

                const traces = [];
                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};

                facetValues.forEach((facetVal, idx) => {
                    const facetData = data.filter(row => row[FACET_COL] === facetVal);
                    const sceneId = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                    const groups = {};
                    facetData.forEach(row => {
                        const key = row[COLOR_COL];
                        if (!groups[key]) groups[key] = [];
                        groups[key].push(row);
                    });

                    Object.entries(groups).forEach(([key, groupData]) => {
                        traces.push({
                            x: groupData.map(d => parseFloat(d[X_COL])),
                            y: groupData.map(d => parseFloat(d[Y_COL])),
                            z: groupData.map(d => parseFloat(d[Z_COL])),
                            mode: 'markers',
                            name: key,
                            legendgroup: key,
                            showlegend: idx === 0,
                            scene: sceneId,
                            type: 'scatter3d',
                            marker: {
                                size: $marker_size,
                                opacity: $marker_opacity,
                                color: COLOR_MAP[key] || '#636efa'
                            }
                        });
                    });

                    if (window.showEigenvectors_$(chart_title_safe) && facetData.length > 3) {
                        const eigData = computeEigenvectors(facetData, X_COL, Y_COL, Z_COL);
                        traces.push(...createEigenvectorTraces(eigData, sceneId));
                    }
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    grid: { rows: rows, columns: cols, pattern: 'independent' },
                    annotations: []
                };

                // Create scene for each facet
                facetValues.forEach((val, idx) => {
                    const row = Math.floor(idx / cols);
                    const col = idx % cols;
                    const sceneKey = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                    const xDomain = [col / cols + 0.01, (col + 1) / cols - 0.01];
                    const yDomain = [1 - (row + 1) / rows + 0.01, 1 - row / rows - 0.01];

                    layout[sceneKey] = {
                        domain: { x: xDomain, y: yDomain },
                        xaxis: { title: X_COL },
                        yaxis: { title: Y_COL },
                        zaxis: { title: Z_COL },
                        camera: window.sharedCamera_$(chart_title_safe) ? (window.currentCamera_$(chart_title_safe) || undefined) : undefined
                    };

                    layout.annotations.push({
                        text: FACET_COL + ': ' + val,
                        showarrow: false,
                        xref: sceneKey + ' domain',
                        yref: sceneKey + ' domain',
                        x: 0.5,
                        y: 1.05,
                        xanchor: 'center',
                        yanchor: 'bottom'
                    });
                });

                Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});

                // Setup camera sync if shared
                if (window.sharedCamera_$(chart_title_safe)) {
                    const plotDiv = document.getElementById('$(chart_title_safe)');
                    let isUpdating = false; // Prevent infinite loop

                    plotDiv.on('plotly_relayout', (eventData) => {
                        if (isUpdating) return; // Ignore events triggered by our own updates

                        // Find which scene was updated
                        for (let key in eventData) {
                            if (key.endsWith('.camera')) {
                                const newCamera = eventData[key];
                                window.currentCamera_$(chart_title_safe) = newCamera;

                                // Apply to all scenes
                                isUpdating = true;
                                const updates = {};
                                facetValues.forEach((val, idx) => {
                                    const sceneKey = idx === 0 ? 'scene' : 'scene' + (idx + 1);
                                    updates[sceneKey + '.camera'] = newCamera;
                                });
                                Plotly.relayout(plotDiv, updates).then(() => {
                                    isUpdating = false;
                                });
                                break;
                            }
                        }
                    });
                }
            }

            function renderFacetGrid_$(chart_title_safe)(data, X_COL, Y_COL, Z_COL, COLOR_COL, FACET1_COL, FACET2_COL) {
                const facet1Values = [...new Set(data.map(row => row[FACET1_COL]))].sort();
                const facet2Values = [...new Set(data.map(row => row[FACET2_COL]))].sort();
                const rows = facet1Values.length;
                const cols = facet2Values.length;

                const traces = [];
                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};

                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row => row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val);
                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const sceneId = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                        const groups = {};
                        facetData.forEach(row => {
                            const key = row[COLOR_COL];
                            if (!groups[key]) groups[key] = [];
                            groups[key].push(row);
                        });

                        Object.entries(groups).forEach(([key, groupData]) => {
                            traces.push({
                                x: groupData.map(d => parseFloat(d[X_COL])),
                                y: groupData.map(d => parseFloat(d[Y_COL])),
                                z: groupData.map(d => parseFloat(d[Z_COL])),
                                mode: 'markers',
                                name: key,
                                legendgroup: key,
                                showlegend: idx === 0,
                                scene: sceneId,
                                type: 'scatter3d',
                                marker: {
                                    size: $marker_size,
                                    opacity: $marker_opacity,
                                    color: COLOR_MAP[key] || '#636efa'
                                }
                            });
                        });

                        if (window.showEigenvectors_$(chart_title_safe) && facetData.length > 3) {
                            const eigData = computeEigenvectors(facetData, X_COL, Y_COL, Z_COL);
                            traces.push(...createEigenvectorTraces(eigData, sceneId));
                        }
                    });
                });

                const layout = {
                    title: '$title',
                    showlegend: true,
                    grid: { rows: rows, columns: cols, pattern: 'independent' },
                    annotations: []
                };

                // Create scene for each facet
                facet1Values.forEach((facet1Val, rowIdx) => {
                    facet2Values.forEach((facet2Val, colIdx) => {
                        const facetData = data.filter(row => row[FACET1_COL] === facet1Val && row[FACET2_COL] === facet2Val);
                        if (facetData.length === 0) return;

                        const idx = rowIdx * cols + colIdx;
                        const sceneKey = idx === 0 ? 'scene' : 'scene' + (idx + 1);

                        const xDomain = [colIdx / cols + 0.01, (colIdx + 1) / cols - 0.01];
                        const yDomain = [1 - (rowIdx + 1) / rows + 0.01, 1 - rowIdx / rows - 0.01];

                        layout[sceneKey] = {
                            domain: { x: xDomain, y: yDomain },
                            xaxis: { title: X_COL },
                            yaxis: { title: Y_COL },
                            zaxis: { title: Z_COL },
                            camera: window.sharedCamera_$(chart_title_safe) ? (window.currentCamera_$(chart_title_safe) || undefined) : undefined
                        };

                        // Column header
                        if (rowIdx === 0) {
                            layout.annotations.push({
                                text: FACET2_COL + ': ' + facet2Val,
                                showarrow: false,
                                xref: sceneKey + ' domain',
                                yref: sceneKey + ' domain',
                                x: 0.5,
                                y: 1.05,
                                xanchor: 'center',
                                yanchor: 'bottom'
                            });
                        }

                        // Row header
                        if (colIdx === 0) {
                            layout.annotations.push({
                                text: FACET1_COL + ': ' + facet1Val,
                                showarrow: false,
                                xref: sceneKey + ' domain',
                                yref: sceneKey + ' domain',
                                x: -0.1,
                                y: 0.5,
                                xanchor: 'center',
                                yanchor: 'middle',
                                textangle: -90
                            });
                        }
                    });
                });

                Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});

                // Setup camera sync if shared
                if (window.sharedCamera_$(chart_title_safe)) {
                    const plotDiv = document.getElementById('$(chart_title_safe)');
                    let isUpdating = false; // Prevent infinite loop

                    plotDiv.on('plotly_relayout', (eventData) => {
                        if (isUpdating) return; // Ignore events triggered by our own updates

                        // Find which scene was updated
                        for (let key in eventData) {
                            if (key.endsWith('.camera')) {
                                const newCamera = eventData[key];
                                window.currentCamera_$(chart_title_safe) = newCamera;

                                // Apply to all scenes
                                isUpdating = true;
                                const updates = {};
                                let sceneCount = 0;
                                facet1Values.forEach((f1, r) => {
                                    facet2Values.forEach((f2, c) => {
                                        const facetData = data.filter(row => row[FACET1_COL] === f1 && row[FACET2_COL] === f2);
                                        if (facetData.length > 0) {
                                            const sceneKey = sceneCount === 0 ? 'scene' : 'scene' + (sceneCount + 1);
                                            updates[sceneKey + '.camera'] = newCamera;
                                            sceneCount++;
                                        }
                                    });
                                });
                                Plotly.relayout(plotDiv, updates).then(() => {
                                    isUpdating = false;
                                });
                                break;
                            }
                        }
                    });
                }
            }

            $filter_logic_js

            loadDataset('$data_label').then(function(data) {
                window.allData_$(chart_title_safe) = data;

                \$(function() {
                    $slider_init_js

                    // Initial plot
                    updatePlotWithFilters_$(chart_title_safe)();
                });
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });

            })();
        """

        # Organize controls into sections
        filters_html = sliders_html
        # plot_attributes_html and faceting_html already built above

        # Use html_controls abstraction to generate appearance HTML
        appearance_html = generate_appearance_html_from_sections(
            filters_html,
            plot_attributes_html,
            faceting_html,
            title,
            notes,
            string(chart_title_safe)
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::Scatter3D) = [a.data_label]
