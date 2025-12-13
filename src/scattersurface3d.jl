"""
    ScatterSurface3D(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Three-dimensional scatter plot with fitted surfaces, combining point clouds with smoothed surface approximations.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_col::Symbol`: Column for x-axis values (default: `:x`)
- `y_col::Symbol`: Column for y-axis values (default: `:y`)
- `z_col::Symbol`: Column for z-axis values (default: `:z`)
- `group_cols::Vector{Symbol}`: Columns for grouping data (default: `Symbol[]`)
- `facet_cols::Vector{Symbol}`: Columns available for faceting (default: `Symbol[]`)
- `slider_cols::Vector{Symbol}`: Additional categorical filter columns (default: `Symbol[]`)
- `surface_fitter::Function`: Function to fit surfaces: `(x, y, z, smoothing) -> (x_grid, y_grid, z_grid)`
- `smoothing_params::Vector{Float64}`: Smoothing parameters to pre-compute (default: `[0.1, 0.5, 1.0, 5.0]`)
- `default_smoothing::Dict{String, Float64}`: Default smoothing for each group (default: auto-computed)
- `grid_size::Int`: Grid resolution for surfaces (default: `20`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points (default: `0.6`)
- `height::Int`: Plot height in pixels (default: `600`)
- `title::String`: Chart title (default: `"3D Scatter with Surfaces"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
# Simple smoothing function
function simple_smoother(x, y, z, smoothing)
    # Returns gridded surface (x_grid, y_grid, z_grid)
    # ... your smoothing logic ...
end

scatter_surf = ScatterSurface3D(:my_chart, df, :data,
    x_col=:x, y_col=:y, z_col=:z,
    group_cols=[:category],
    surface_fitter=simple_smoother,
    smoothing_params=[0.1, 1.0, 10.0]
)
```
"""
struct ScatterSurface3D <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function ScatterSurface3D(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                               x_col::Symbol=:x,
                               y_col::Symbol=:y,
                               z_col::Symbol=:z,
                               group_cols::Vector{Symbol}=Symbol[],
                               facet_cols::Vector{Symbol}=Symbol[],
                               slider_cols::Vector{Symbol}=Symbol[],
                               surface_fitter::Union{Function, Nothing}=nothing,
                               smoothing_params::Vector{Float64}=[0.1, 0.5, 1.0, 5.0],
                               default_smoothing::Dict{String, Float64}=Dict{String, Float64}(),
                               grid_size::Int=20,
                               marker_size::Int=4,
                               marker_opacity::Float64=0.6,
                               height::Int=600,
                               title::String="3D Scatter with Surfaces",
                               notes::String="")

        chart_title_safe = sanitize_chart_title(chart_title)
        all_cols = names(df)

        # Validate columns
        for (col, name) in [(x_col, "x"), (y_col, "y"), (z_col, "z")]
            String(col) in all_cols || error("Column $col not found. Available: $all_cols")
        end

        for col in vcat(group_cols, facet_cols, slider_cols)
            String(col) in all_cols || error("Column $col not found. Available: $all_cols")
        end

        # If no surface fitter provided, use a simple kernel smoother
        if surface_fitter === nothing
            surface_fitter = default_surface_smoother
        end

        # Determine grouping levels
        if isempty(group_cols)
            group_levels = ["all"]
        else
            group_combos = unique(df[!, group_cols])
            group_levels = [join([string(row[col]) for col in group_cols], "_") for row in eachrow(group_combos)]
        end

        # Auto-compute default smoothing if not provided
        if isempty(default_smoothing)
            # Use middle smoothing parameter as default
            mid_smooth = smoothing_params[ceil(Int, length(smoothing_params)/2)]
            for group in group_levels
                default_smoothing[group] = mid_smooth
            end
        end

        # Pre-compute surfaces for each group and smoothing parameter
        surfaces_data = compute_surfaces(df, x_col, y_col, z_col, group_cols,
                                        group_levels, surface_fitter, smoothing_params,
                                        grid_size)

        # Generate HTML
        functional_html, appearance_html = generate_html(
            chart_title_safe, data_label, df,
            x_col, y_col, z_col, group_cols, facet_cols, slider_cols,
            group_levels, smoothing_params, default_smoothing,
            surfaces_data, marker_size, marker_opacity, height, title, notes
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

"""
Default surface smoother using weighted average kernel
"""
function default_surface_smoother(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, smoothing::Float64)
    # Create grid
    x_min, x_max = extrema(x)
    y_min, y_max = extrema(y)

    x_range = x_max - x_min
    y_range = y_max - y_min

    # Extend range slightly
    x_min -= 0.1 * x_range
    x_max += 0.1 * x_range
    y_min -= 0.1 * y_range
    y_max += 0.1 * y_range

    grid_size = 20
    x_grid = range(x_min, x_max, length=grid_size)
    y_grid = range(y_min, y_max, length=grid_size)

    z_grid = zeros(grid_size, grid_size)

    # Kernel smoothing for each grid point
    for (i, xi) in enumerate(x_grid)
        for (j, yj) in enumerate(y_grid)
            weights = zeros(length(x))
            for k in 1:length(x)
                dist = sqrt((x[k] - xi)^2 + (y[k] - yj)^2)
                weights[k] = exp(-dist^2 / (2 * smoothing^2))
            end

            weight_sum = sum(weights)
            if weight_sum > 0
                z_grid[i, j] = sum(weights .* z) / weight_sum
            else
                z_grid[i, j] = mean(z)
            end
        end
    end

    return (collect(x_grid), collect(y_grid), z_grid)
end

"""
Compute surfaces for all groups and smoothing parameters
"""
function compute_surfaces(df, x_col, y_col, z_col, group_cols, group_levels,
                         surface_fitter, smoothing_params, grid_size)
    surfaces = Dict{String, Any}()

    for group_name in group_levels
        surfaces[group_name] = Dict{Float64, Any}()

        # Filter data for this group
        if group_name == "all"
            group_df = df
        else
            # Parse group name back to filter conditions
            group_parts = split(group_name, "_")
            mask = trues(nrow(df))
            for (i, col) in enumerate(group_cols)
                mask .&= string.(df[!, col]) .== group_parts[i]
            end
            group_df = df[mask, :]
        end

        if nrow(group_df) < 3
            continue  # Skip if too few points
        end

        x_data = Float64.(group_df[!, x_col])
        y_data = Float64.(group_df[!, y_col])
        z_data = Float64.(group_df[!, z_col])

        # Fit surface at each smoothing level
        for smoothing in smoothing_params
            try
                x_grid, y_grid, z_grid = surface_fitter(x_data, y_data, z_data, smoothing)
                surfaces[group_name][smoothing] = (x_grid, y_grid, z_grid)
            catch e
                @warn "Failed to fit surface for group $group_name with smoothing $smoothing: $e"
            end
        end
    end

    return surfaces
end

dependencies(ss::ScatterSurface3D) = [ss.data_label]

"""
Generate HTML and JavaScript for ScatterSurface3D
"""
function generate_html(chart_title_safe, data_label, df,
                      x_col, y_col, z_col, group_cols, facet_cols, slider_cols,
                      group_levels, smoothing_params, default_smoothing,
                      surfaces_data, marker_size, marker_opacity, height, title, notes)

    # Prepare data ranges for sliders
    x_min, x_max = extrema(df[!, x_col])
    y_min, y_max = extrema(df[!, y_col])

    # Get unique values for categorical sliders
    categorical_values = Dict{Symbol, Vector{String}}()
    for col in slider_cols
        categorical_values[col] = sort(unique(string.(skipmissing(df[!, col]))))
    end

    # Generate group colors
    colors = generate_colors(length(group_levels))
    group_colors = Dict(group_levels[i] => colors[i] for i in 1:length(group_levels))

    # Convert surfaces data to JSON-friendly format
    surfaces_json = prepare_surfaces_json(surfaces_data, group_colors)

    # Generate JavaScript
    functional_html = generate_functional_js(
        chart_title_safe, data_label, x_col, y_col, z_col,
        group_cols, facet_cols, slider_cols, group_levels,
        smoothing_params, default_smoothing, categorical_values,
        group_colors, surfaces_json, x_min, x_max, y_min, y_max,
        marker_size, marker_opacity, height
    )

    # Generate HTML appearance
    appearance_html = generate_appearance_html(
        chart_title_safe, title, notes, group_levels, group_colors,
        smoothing_params, default_smoothing, categorical_values,
        x_min, x_max, y_min, y_max, height
    )

    return (functional_html, appearance_html)
end

function generate_colors(n::Int)
    # Generate distinct colors
    colors = String[]
    for i in 1:n
        hue = (i - 1) / n * 360
        push!(colors, "hsl($hue, 70%, 50%)")
    end
    return colors
end

function prepare_surfaces_json(surfaces_data, group_colors)
    surfaces_array = []
    for (group, smoothing_dict) in surfaces_data
        for (smoothing, (x_grid, y_grid, z_grid)) in smoothing_dict
            surface_obj = Dict(
                "group" => group,
                "smoothing" => smoothing,
                "x" => x_grid,
                "y" => y_grid,
                "z" => [z_grid[i, :] for i in 1:size(z_grid, 1)],
                "color" => get(group_colors, group, "#1f77b4")
            )
            push!(surfaces_array, surface_obj)
        end
    end
    return JSON.json(surfaces_array)
end
function generate_functional_js(chart_title_safe, data_label, x_col, y_col, z_col,
                                group_cols, facet_cols, slider_cols, group_levels,
                                smoothing_params, default_smoothing, categorical_values,
                                group_colors, surfaces_json, x_min, x_max, y_min, y_max,
                                marker_size, marker_opacity, height)

    group_cols_json = JSON.json(string.(group_cols))
    facet_cols_json = JSON.json(string.(facet_cols))
    smoothing_json = JSON.json(smoothing_params)
    default_smoothing_json = JSON.json(default_smoothing)
    group_levels_json = JSON.json(group_levels)

    return """
    (function() {
        const surfacesData_$(chart_title_safe) = $(surfaces_json);
        const groupLevels_$(chart_title_safe) = $(group_levels_json);
        const smoothingParams_$(chart_title_safe) = $(smoothing_json);
        const defaultSmoothing_$(chart_title_safe) = $(default_smoothing_json);
        const groupColors_$(chart_title_safe) = $(JSON.json(group_colors));

        let allData = [];
        let currentSmoothing_$(chart_title_safe) = null; // null means "defaults"
        let visibleGroups_$(chart_title_safe) = new Set(groupLevels_$(chart_title_safe));
        let showSurfaces_$(chart_title_safe) = true;
        let showPoints_$(chart_title_safe) = true;
        let currentXRange_$(chart_title_safe) = [$(x_min), $(x_max)];
        let currentYRange_$(chart_title_safe) = [$(y_min), $(y_max)];
        let currentGroup_$(chart_title_safe) = $(JSON.json(length(group_cols) > 0 ? string(group_cols[1]) : ""));

        window.updatePlot_$(chart_title_safe) = function() {
            if (!allData || allData.length === 0) return;

            // Filter data by sliders
            let filtered = allData.filter(row => {
                if (row.$(x_col) < currentXRange_$(chart_title_safe)[0] ||
                    row.$(x_col) > currentXRange_$(chart_title_safe)[1]) return false;
                if (row.$(y_col) < currentYRange_$(chart_title_safe)[0] ||
                    row.$(y_col) > currentYRange_$(chart_title_safe)[1]) return false;
                return true;
            });

            // Create traces
            const traces = [];

            // Add scatter points for each group
            if (showPoints_$(chart_title_safe)) {
                groupLevels_$(chart_title_safe).forEach(group => {
                    if (!visibleGroups_$(chart_title_safe).has(group)) return;

                    const groupData = group === 'all' ? filtered : 
                        filtered.filter(row => getGroupName_$(chart_title_safe)(row) === group);

                    if (groupData.length > 0) {
                        traces.push({
                            type: 'scatter3d',
                            mode: 'markers',
                            name: group + ' (points)',
                            x: groupData.map(r => r.$(x_col)),
                            y: groupData.map(r => r.$(y_col)),
                            z: groupData.map(r => r.$(z_col)),
                            marker: {
                                size: $(marker_size),
                                color: groupColors_$(chart_title_safe)[group],
                                opacity: $(marker_opacity)
                            },
                            showlegend: true
                        });
                    }
                });
            }

            // Add surfaces
            if (showSurfaces_$(chart_title_safe)) {
                groupLevels_$(chart_title_safe).forEach(group => {
                    if (!visibleGroups_$(chart_title_safe).has(group)) return;

                    // Determine which smoothing to use
                    const smoothing = currentSmoothing_$(chart_title_safe) === null ?
                        defaultSmoothing_$(chart_title_safe)[group] : currentSmoothing_$(chart_title_safe);

                    const surface = surfacesData_$(chart_title_safe).find(s => 
                        s.group === group && s.smoothing === smoothing
                    );

                    if (surface) {
                        traces.push({
                            type: 'surface',
                            name: group + ' (surface)',
                            x: surface.x,
                            y: surface.y,
                            z: surface.z,
                            colorscale: [[0, surface.color], [1, surface.color]],
                            showscale: false,
                            opacity: 0.7,
                            showlegend: true
                        });
                    }
                });
            }

            const layout = {
                scene: {
                    xaxis: {title: '$(x_col)'},
                    yaxis: {title: '$(y_col)'},
                    zaxis: {title: '$(z_col)'}
                },
                height: $(height),
                margin: {l: 0, r: 0, b: 0, t: 30}
            };

            Plotly.newPlot('plot_$(chart_title_safe)', traces, layout);
        };

        window.getGroupName_$(chart_title_safe) = function(row) {
            if (groupLevels_$(chart_title_safe).length === 1 && 
                groupLevels_$(chart_title_safe)[0] === 'all') return 'all';

            const groupCols = $(group_cols_json);
            return groupCols.map(col => String(row[col])).join('_');
        };

        window.setXRange_$(chart_title_safe) = function(min, max) {
            currentXRange_$(chart_title_safe) = [parseFloat(min), parseFloat(max)];
            updatePlot_$(chart_title_safe)();
        };

        window.setYRange_$(chart_title_safe) = function(min, max) {
            currentYRange_$(chart_title_safe) = [parseFloat(min), parseFloat(max)];
            updatePlot_$(chart_title_safe)();
        };

        window.toggleGroup_$(chart_title_safe) = function(group) {
            if (visibleGroups_$(chart_title_safe).has(group)) {
                visibleGroups_$(chart_title_safe).delete(group);
            } else {
                visibleGroups_$(chart_title_safe).add(group);
            }
            updatePlot_$(chart_title_safe)();
        };

        window.toggleAllSurfaces_$(chart_title_safe) = function() {
            showSurfaces_$(chart_title_safe) = !showSurfaces_$(chart_title_safe);
            updatePlot_$(chart_title_safe)();
        };

        window.toggleAllPoints_$(chart_title_safe) = function() {
            showPoints_$(chart_title_safe) = !showPoints_$(chart_title_safe);
            updatePlot_$(chart_title_safe)();
        };

        window.setSmoothing_$(chart_title_safe) = function(value) {
            const idx = parseInt(value);
            if (idx === -1) {
                currentSmoothing_$(chart_title_safe) = null; // Use defaults
            } else {
                currentSmoothing_$(chart_title_safe) = smoothingParams_$(chart_title_safe)[idx];
            }
            document.getElementById('smoothing_label_$(chart_title_safe)').textContent = 
                currentSmoothing_$(chart_title_safe) === null ? 'Defaults' : 
                currentSmoothing_$(chart_title_safe).toFixed(2);
            updatePlot_$(chart_title_safe)();
        };

        // Load and parse data using centralized loader
        loadDataset('$(data_label)').then(function(data) {
            allData = data;
            updatePlot_$(chart_title_safe)();
        }).catch(function(error) {
            console.error('Error loading data for chart $(chart_title_safe):', error);
        });
    })();
    """
end

function generate_appearance_html(chart_title_safe, title, notes, group_levels, group_colors,
                                  smoothing_params, default_smoothing, categorical_values,
                                  x_min, x_max, y_min, y_max, height)

    # Generate group toggle buttons
    group_buttons = join(["""
        <button onclick="toggleGroup_$(chart_title_safe)('$(group)')" 
                style="background-color: $(group_colors[group]); margin: 2px; padding: 5px 10px; 
                       border: 1px solid #ccc; cursor: pointer;">
            $(group)
        </button>
    """ for group in group_levels], "\n")

    # Generate smoothing slider (default at index -1, then 0, 1, 2, ...)
    smoothing_options = """<option value="-1">Defaults</option>\n""" *
        join(["<option value=\"$(i-1)\">$(smoothing_params[i])</option>" 
              for i in 1:length(smoothing_params)], "\n")

    return """
    <div class="chart-container">
        <h3>$(title)</h3>
        $(isempty(notes) ? "" : "<p>$(notes)</p>")

        <div style="margin: 10px 0;">
            <strong>Global Controls:</strong>
            <button onclick="toggleAllSurfaces_$(chart_title_safe)()">Toggle All Surfaces</button>
            <button onclick="toggleAllPoints_$(chart_title_safe)()">Toggle All Points</button>
        </div>

        <div style="margin: 10px 0;">
            <strong>Group Colors (click to toggle):</strong><br>
            $(group_buttons)
        </div>

        <div style="margin: 10px 0;">
            <label>X Range: </label>
            <input type="number" id="x_min_$(chart_title_safe)" value="$(x_min)" step="any" style="width: 80px;">
            to
            <input type="number" id="x_max_$(chart_title_safe)" value="$(x_max)" step="any" style="width: 80px;">
            <button onclick="setXRange_$(chart_title_safe)(
                document.getElementById('x_min_$(chart_title_safe)').value,
                document.getElementById('x_max_$(chart_title_safe)').value
            )">Update X</button>
        </div>

        <div style="margin: 10px 0;">
            <label>Y Range: </label>
            <input type="number" id="y_min_$(chart_title_safe)" value="$(y_min)" step="any" style="width: 80px;">
            to
            <input type="number" id="y_max_$(chart_title_safe)" value="$(y_max)" step="any" style="width: 80px;">
            <button onclick="setYRange_$(chart_title_safe)(
                document.getElementById('y_min_$(chart_title_safe)').value,
                document.getElementById('y_max_$(chart_title_safe)').value
            )">Update Y</button>
        </div>

        <div style="margin: 10px 0;">
            <label>Smoothing Parameter: </label>
            <select id="smoothing_select_$(chart_title_safe)" 
                    onchange="setSmoothing_$(chart_title_safe)(this.value)">
                $(smoothing_options)
            </select>
            <span id="smoothing_label_$(chart_title_safe)">Defaults</span>
        </div>

        <div id="plot_$(chart_title_safe)" style="width: 100%; height: $(height)px;"></div>
    </div>
    """
end
