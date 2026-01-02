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
- `group_cols::Vector{Symbol}`: Columns for grouping data (default: `Symbol[]`). Ignored if `grouping_schemes` is provided.
- `grouping_schemes::Dict{String, Vector{Symbol}}`: Multiple named grouping schemes with dropdown selector (default: `Dict()`).
  If provided, creates a dropdown to switch between different grouping methods. Example:
  `Dict("Industry" => [:industry], "Country" => [:country])` creates a dropdown to switch between grouping by industry or country.
- `facet_cols::Vector{Symbol}`: Columns available for faceting (default: `Symbol[]`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `surface_fitter::Function`: Function to fit surfaces: `(x, y, z, smoothing) -> (x_grid, y_grid, z_grid)`
- `smoothing_params::Vector{Float64}`: Smoothing parameters to pre-compute (default: `[0.1, 0.15, ..., 10.0]`)
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
                               grouping_schemes::Dict{String, Vector{Symbol}}=Dict{String, Vector{Symbol}}(),
                               facet_cols::Vector{Symbol}=Symbol[],
                               filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                               surface_fitter::Union{Function, Nothing}=nothing,
                               smoothing_params::Vector{Float64}=[0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 7.0, 10.0],
                               default_smoothing::Dict{String, Float64}=Dict{String, Float64}(),
                               grid_size::Int=20,
                               marker_size::Int=4,
                               marker_opacity::Float64=0.6,
                               height::Int=600,
                               title::String="3D Scatter with Surfaces",
                               notes::String="")

# Normalize filters to standard Dict{Symbol, Any} format
normalized_filters = normalize_filters(filters, df)

        chart_title_safe = sanitize_chart_title(chart_title)
        all_cols = names(df)

        # Validate columns
        for (col, name) in [(x_col, "x"), (y_col, "y"), (z_col, "z")]
            String(col) in all_cols || error("Column $col not found. Available: $all_cols")
        end

        for col in vcat(group_cols, facet_cols)
            String(col) in all_cols || error("Column $col not found. Available: $all_cols")
        end

        # Validate grouping_schemes columns
        for (scheme_name, scheme_cols) in grouping_schemes
            for col in scheme_cols
                String(col) in all_cols || error("Column $col in grouping scheme '$scheme_name' not found. Available: $all_cols")
            end
        end

        # Determine if using multiple grouping schemes
        use_multiple_schemes = !isempty(grouping_schemes)

        # Build all grouping configurations
        all_scheme_info = Dict{String, Any}()  # scheme_name => (group_cols, group_levels)

        if use_multiple_schemes
            # Use provided grouping schemes
            for (scheme_name, scheme_cols) in grouping_schemes
                if isempty(scheme_cols)
                    group_levels = ["all"]
                else
                    group_combos = unique(df[!, scheme_cols])
                    group_levels = [join([string(row[col]) for col in scheme_cols], "_") for row in eachrow(group_combos)]
                end
                all_scheme_info[scheme_name] = (scheme_cols, group_levels)
            end
        else
            # Single grouping scheme (backward compatibility)
            if isempty(group_cols)
                group_levels = ["all"]
            else
                group_combos = unique(df[!, group_cols])
                group_levels = [join([string(row[col]) for col in group_cols], "_") for row in eachrow(group_combos)]
            end
            all_scheme_info["default"] = (group_cols, group_levels)
        end

        # Collect all unique group names across all schemes for default smoothing
        all_unique_groups = Set{String}()
        for (scheme_name, (scheme_cols, group_levels)) in all_scheme_info
            union!(all_unique_groups, group_levels)
        end

        # Auto-compute default smoothing if not provided
        if isempty(default_smoothing)
            # Use middle smoothing parameter as default
            mid_smooth = smoothing_params[ceil(Int, length(smoothing_params)/2)]
            for group in all_unique_groups
                default_smoothing[group] = mid_smooth
            end
        end

        # Pre-compute surfaces for each grouping scheme
        # Structure: scheme_name => (surfaces_l2, surfaces_l1)
        all_surfaces_data = Dict{String, Tuple}()

        for (scheme_name, (scheme_cols, group_levels)) in all_scheme_info
            surfaces_data_l2 = nothing
            surfaces_data_l1 = nothing

            if surface_fitter === nothing
                # Compute both L1 and L2 surfaces
                surfaces_data_l2 = compute_surfaces(df, x_col, y_col, z_col, scheme_cols,
                                                    group_levels, true,
                                                    smoothing_params, grid_size)
                surfaces_data_l1 = compute_surfaces(df, x_col, y_col, z_col, scheme_cols,
                                                    group_levels, false,
                                                    smoothing_params, grid_size)
            else
                # Use custom fitter (only L2)
                surfaces_data_l2 = compute_surfaces(df, x_col, y_col, z_col, scheme_cols,
                                                    group_levels, true,
                                                    smoothing_params, grid_size)
            end

            all_surfaces_data[scheme_name] = (surfaces_data_l2, surfaces_data_l1)
        end

        # Generate HTML
        functional_html, appearance_html = generate_html(
            chart_title_safe, data_label, df,
            x_col, y_col, z_col, group_cols, facet_cols, filters,
            all_scheme_info, use_multiple_schemes, smoothing_params, default_smoothing,
            all_surfaces_data, marker_size, marker_opacity, height, title, notes
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

"""
Weighted median for L1 minimization
"""
function weighted_median(values::Vector{Float64}, weights::Vector{Float64})
    if isempty(values)
        return 0.0
    end

    # Sort values and weights together
    perm = sortperm(values)
    sorted_values = values[perm]
    sorted_weights = weights[perm]

    # Find weighted median
    total_weight = sum(sorted_weights)
    cumsum_weights = cumsum(sorted_weights)

    # Find the value where cumulative weight >= 50%
    half_weight = total_weight / 2
    idx = findfirst(w -> w >= half_weight, cumsum_weights)

    if idx === nothing
        return sorted_values[end]
    end

    return sorted_values[idx]
end

"""
Surface smoother using kernel smoothing with L2 minimization (weighted mean)
"""
function surface_smoother(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, smoothing::Float64; L2_metric::Bool=true)
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

    # Kernel smoothing for each grid point (L2: weighted mean)
    for (i, xi) in enumerate(x_grid)
        for (j, yj) in enumerate(y_grid)
            weights = zeros(length(x))
            for k in 1:length(x)
                dist = sqrt((x[k] - xi)^2 + (y[k] - yj)^2)
                weights[k] = exp(-dist^2 / (2 * smoothing^2))
            end

            weight_sum = sum(weights)
            if weight_sum > 0
                z_grid[i, j] = L2_metric ? sum(weights .* z) / weight_sum : weighted_median(z, weights)
            else
                z_grid[i, j] = L2_metric ? mean(z) : median(z)
            end
        end
    end

    return (collect(x_grid), collect(y_grid), z_grid)
end

"""
Compute surfaces for all groups and smoothing parameters
"""
function compute_surfaces(df, x_col, y_col, z_col, group_cols, group_levels,
                         L2_metric::Bool, smoothing_params, grid_size)
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
                x_grid, y_grid, z_grid = surface_smoother(x_data, y_data, z_data, smoothing; L2_metric=L2_metric)
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
                      x_col, y_col, z_col, group_cols, facet_cols, filters,
                      all_scheme_info, use_multiple_schemes, smoothing_params, default_smoothing,
                      all_surfaces_data, marker_size, marker_opacity, height, title, notes)

    # Normalize filters to standard Dict{Symbol, Any} format
    normalized_filters = normalize_filters(filters, df)

    # Build filter dropdowns using html_controls abstraction
    update_function = "updatePlotWithFilters_$(chart_title_safe)()"
    filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title_safe), normalized_filters, df, update_function)
    filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") * join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")

    # Separate categorical and continuous filters for JavaScript
    categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
    continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]

    filter_cols_js = build_js_array(collect(keys(normalized_filters)))
    categorical_filters_js = build_js_array(categorical_filter_cols)
    continuous_filters_js = build_js_array(continuous_filter_cols)

    # Get the first/default grouping scheme for initial display
    scheme_names = collect(keys(all_scheme_info))
    default_scheme_name = use_multiple_schemes ? scheme_names[1] : "default"
    default_group_cols, default_group_levels = all_scheme_info[default_scheme_name]

    # Generate colors for all unique groups across all schemes
    all_unique_groups = Set{String}()
    for (scheme_name, (scheme_cols, group_levels)) in all_scheme_info
        union!(all_unique_groups, group_levels)
    end
    all_groups_list = sort(collect(all_unique_groups))
    colors = generate_colors(length(all_groups_list))
    group_colors = Dict(all_groups_list[i] => colors[i] for i in 1:length(all_groups_list))

    # Prepare surfaces data for all schemes
    all_schemes_surfaces_dict = Dict{String, Any}()
    has_l1 = false

    for (scheme_name, (surfaces_data_l2, surfaces_data_l1)) in all_surfaces_data
        surfaces_l2 = prepare_surfaces_data(surfaces_data_l2, group_colors)
        surfaces_l1 = surfaces_data_l1 !== nothing ? prepare_surfaces_data(surfaces_data_l1, group_colors) : nothing
        has_l1 = has_l1 || (surfaces_data_l1 !== nothing)

        all_schemes_surfaces_dict[scheme_name] = Dict(
            "l2" => surfaces_l2,
            "l1" => surfaces_l1
        )
    end

    # Generate JavaScript
    functional_html = generate_functional_js(
        chart_title_safe, data_label, x_col, y_col, z_col,
        group_cols, facet_cols, categorical_filters_js, continuous_filters_js,
        all_scheme_info, use_multiple_schemes, default_scheme_name,
        smoothing_params, default_smoothing,
        group_colors, all_schemes_surfaces_dict, has_l1,
        marker_size, marker_opacity, height
    )

    # Generate HTML appearance using standard approach for consistency with Scatter3D/Surface3D
    plot_attributes_html = build_scattersurface_attributes_html(
        string(chart_title_safe),
        all_scheme_info, use_multiple_schemes, default_scheme_name,
        group_colors, smoothing_params, has_l1
    )

    base_appearance_html = generate_appearance_html_from_sections(
        filters_html,
        plot_attributes_html,
        "",  # No faceting
        title,
        notes,
        string(chart_title_safe);
        aspect_ratio_default=1.0
    )

    # Add method explanation div after the chart (specific to ScatterSurface3D)
    appearance_html = base_appearance_html * """
    <div id="method_explanation_$(chart_title_safe)" style="margin-top: 10px; font-size: 0.85em; color: #666; line-height: 1.4;">
    </div>
    """

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

function prepare_surfaces_data(surfaces_data, group_colors)
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
    return surfaces_array  # Return raw array, not JSON string
end
function generate_functional_js(chart_title_safe, data_label, x_col, y_col, z_col,
                                group_cols, facet_cols, categorical_filters_js, continuous_filters_js,
                                all_scheme_info, use_multiple_schemes, default_scheme_name,
                                smoothing_params, default_smoothing,
                                group_colors, all_schemes_surfaces_dict, has_l1,
                                marker_size, marker_opacity, height)

    # Prepare scheme info for JSON
    schemes_json_dict = Dict{String, Any}()
    for (scheme_name, (scheme_cols, group_levels)) in all_scheme_info
        schemes_json_dict[scheme_name] = Dict(
            "group_cols" => string.(scheme_cols),
            "group_levels" => group_levels
        )
    end
    schemes_json = JSON.json(schemes_json_dict)

    # Convert surfaces to JSON (single encoding of the entire structure)
    all_surfaces_json = JSON.json(all_schemes_surfaces_dict)

    smoothing_json = JSON.json(smoothing_params)
    default_smoothing_json = JSON.json(default_smoothing)

    # Get default group info
    default_group_cols, default_group_levels = all_scheme_info[default_scheme_name]
    group_cols_json = JSON.json(string.(default_group_cols))
    group_levels_json = JSON.json(default_group_levels)

    return """
    (function() {
        // Filter configuration
        const CATEGORICAL_FILTERS = $categorical_filters_js;
        const CONTINUOUS_FILTERS = $continuous_filters_js;

        // All grouping schemes and their surfaces
        const allSchemes_$(chart_title_safe) = $(schemes_json);
        const allSurfaces_$(chart_title_safe) = $(all_surfaces_json);
        const hasL1_$(chart_title_safe) = $(has_l1);
        const useMultipleSchemes_$(chart_title_safe) = $(use_multiple_schemes);
        const smoothingParams_$(chart_title_safe) = $(smoothing_json);
        const defaultSmoothing_$(chart_title_safe) = $(default_smoothing_json);
        const groupColors_$(chart_title_safe) = $(JSON.json(group_colors));

        let allData = [];
        let currentScheme_$(chart_title_safe) = "$(default_scheme_name)";
        let currentGroupCols_$(chart_title_safe) = allSchemes_$(chart_title_safe)[currentScheme_$(chart_title_safe)].group_cols;
        let currentGroupLevels_$(chart_title_safe) = allSchemes_$(chart_title_safe)[currentScheme_$(chart_title_safe)].group_levels;
        let currentSmoothing_$(chart_title_safe) = null; // null means "defaults"
        let visibleGroups_$(chart_title_safe) = new Set(currentGroupLevels_$(chart_title_safe));
        let showSurfaces_$(chart_title_safe) = true;
        let showPoints_$(chart_title_safe) = true;
        let useL1_$(chart_title_safe) = false; // Default to L2

        window.updatePlot_$(chart_title_safe) = function(filteredData) {
            if (!filteredData || filteredData.length === 0) return;

            let filtered = filteredData;

            // Create traces
            const traces = [];

            // Add scatter points for each group
            if (showPoints_$(chart_title_safe)) {
                currentGroupLevels_$(chart_title_safe).forEach(group => {
                    if (!visibleGroups_$(chart_title_safe).has(group)) return;

                    const groupData = group === 'all' ? filtered :
                        filtered.filter(row => getGroupName_$(chart_title_safe)(row, currentGroupCols_$(chart_title_safe)) === group);

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
                currentGroupLevels_$(chart_title_safe).forEach(group => {
                    if (!visibleGroups_$(chart_title_safe).has(group)) return;

                    // Determine which smoothing to use
                    const smoothing = currentSmoothing_$(chart_title_safe) === null ?
                        defaultSmoothing_$(chart_title_safe)[group] : currentSmoothing_$(chart_title_safe);

                    // Get surfaces for current scheme
                    const schemeSurfaces = allSurfaces_$(chart_title_safe)[currentScheme_$(chart_title_safe)];
                    if (!schemeSurfaces) return;

                    // Select L1 or L2 surfaces (already parsed, no need for JSON.parse)
                    const surfacesData = useL1_$(chart_title_safe) && hasL1_$(chart_title_safe) && schemeSurfaces.l1 ?
                        schemeSurfaces.l1 : schemeSurfaces.l2;

                    if (!surfacesData) return;

                    const surface = surfacesData.find(s =>
                        s.group === group && s.smoothing === smoothing
                    );

                    if (surface) {
                        const methodLabel = (useL1_$(chart_title_safe) && hasL1_$(chart_title_safe)) ? ' (L1)' : ' (L2)';
                        traces.push({
                            type: 'surface',
                            name: group + ' (surface)' + methodLabel,
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
                margin: {l: 0, r: 0, b: 0, t: 30}
            };

            Plotly.newPlot('$(chart_title_safe)', traces, layout);

            // Update method explanation
            updateMethodExplanation_$(chart_title_safe)();
        };

        window.updateMethodExplanation_$(chart_title_safe) = function() {
            const explanationDiv = document.getElementById('method_explanation_$(chart_title_safe)');
            if (!explanationDiv) return;

            if (!hasL1_$(chart_title_safe)) {
                // Only L2 available (custom fitter)
                explanationDiv.innerHTML = '<em>Surfaces fitted using custom surface fitting function.</em>';
                return;
            }

            const method = useL1_$(chart_title_safe) ? 'L1' : 'L2';
            const methodName = useL1_$(chart_title_safe) ?
                'weighted median (robust to outliers)' :
                'Nadaraya-Watson kernel regression with weighted mean';

            // Build default smoothing info
            const defaultInfo = currentGroupLevels_$(chart_title_safe).map(group => {
                const h = defaultSmoothing_$(chart_title_safe)[group];
                return group + '=' + h.toFixed(2);
            }).join(', ');

            explanationDiv.innerHTML = '<em>Surfaces fitted using ' + method + ' minimization (' +
                methodName + ') with Gaussian kernel. ' +
                'Default smoothing parameters: ' + defaultInfo + '.</em>';
        };

        window.getGroupName_$(chart_title_safe) = function(row, groupCols) {
            if (!groupCols || groupCols.length === 0) return 'all';
            return groupCols.map(col => String(row[col])).join('_');
        };

        window.changeScheme_$(chart_title_safe) = function(schemeName) {
            currentScheme_$(chart_title_safe) = schemeName;
            currentGroupCols_$(chart_title_safe) = allSchemes_$(chart_title_safe)[schemeName].group_cols;
            currentGroupLevels_$(chart_title_safe) = allSchemes_$(chart_title_safe)[schemeName].group_levels;
            visibleGroups_$(chart_title_safe) = new Set(currentGroupLevels_$(chart_title_safe));

            // Update group buttons
            updateGroupButtons_$(chart_title_safe)();

            // Update plot
            updatePlotWithFilters_$(chart_title_safe)();
        };

        window.updateGroupButtons_$(chart_title_safe) = function() {
            const container = document.getElementById('group_buttons_$(chart_title_safe)');
            if (!container) return;

            container.innerHTML = currentGroupLevels_$(chart_title_safe).map(group => {
                const color = groupColors_$(chart_title_safe)[group] || '#ccc';
                return '<button onclick=\"toggleGroup_$(chart_title_safe)(\\'' + group + '\\')\" ' +
                       'style=\"background-color: ' + color + '; margin: 2px; padding: 5px 10px; ' +
                       'border: 1px solid #ccc; cursor: pointer;\">' +
                       group + '</button>';
            }).join('');
        };

        window.toggleGroup_$(chart_title_safe) = function(group) {
            if (visibleGroups_$(chart_title_safe).has(group)) {
                visibleGroups_$(chart_title_safe).delete(group);
            } else {
                visibleGroups_$(chart_title_safe).add(group);
            }
            updatePlotWithFilters_$(chart_title_safe)();
        };

        window.toggleAllSurfaces_$(chart_title_safe) = function() {
            showSurfaces_$(chart_title_safe) = !showSurfaces_$(chart_title_safe);
            updatePlotWithFilters_$(chart_title_safe)();
        };

        window.toggleAllPoints_$(chart_title_safe) = function() {
            showPoints_$(chart_title_safe) = !showPoints_$(chart_title_safe);
            updatePlotWithFilters_$(chart_title_safe)();
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
            updatePlotWithFilters_$(chart_title_safe)();
        };

        window.toggleL1L2_$(chart_title_safe) = function() {
            if (!hasL1_$(chart_title_safe)) return; // No L1 surfaces available
            useL1_$(chart_title_safe) = !useL1_$(chart_title_safe);
            const button = document.getElementById('l1l2_toggle_$(chart_title_safe)');
            if (button) {
                button.textContent = useL1_$(chart_title_safe) ? 'Using L1 (Median)' : 'Using L2 (Mean)';
                button.style.backgroundColor = useL1_$(chart_title_safe) ? '#FF9800' : '#4CAF50';
            }
            updatePlotWithFilters_$(chart_title_safe)();
        };

        // Filter and update function
        window.updatePlotWithFilters_$(chart_title_safe) = function() {
            // Get categorical filter values (multiple selections)
            const filters = {};
            CATEGORICAL_FILTERS.forEach(col => {
                const select = document.getElementById(col + '_select_$(chart_title_safe)');
                if (select) {
                    filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                }
            });

            // Get continuous filter values (range sliders)
            const rangeFilters = {};
            CONTINUOUS_FILTERS.forEach(col => {
                const slider = \$('#' + col + '_range_$(chart_title_safe)' + '_slider');
                if (slider.length > 0) {
                    rangeFilters[col] = {
                        min: slider.slider("values", 0),
                        max: slider.slider("values", 1)
                    };
                }
            });

            // Apply filters with observation counting (centralized function)
            const filteredData = applyFiltersWithCounting(
                allData,
                '$(chart_title_safe)',
                CATEGORICAL_FILTERS,
                CONTINUOUS_FILTERS,
                filters,
                rangeFilters
            );

            // Update plot with filtered data
            updatePlot_$(chart_title_safe)(filteredData);
        };

        // Load and parse data using centralized loader
        loadDataset('$(data_label)').then(function(data) {
            allData = data;
            updatePlotWithFilters_$(chart_title_safe)();

            // Setup aspect ratio control after initial render (same as Scatter3D/Surface3D)
            setupAspectRatioControl('$(chart_title_safe)');
        }).catch(function(error) {
            console.error('Error loading data for chart $(chart_title_safe):', error);
        });
    })();
    """
end

function build_scattersurface_attributes_html(chart_title_safe::String,
                                              all_scheme_info, use_multiple_schemes, default_scheme_name,
                                              group_colors, smoothing_params, has_l1)
    # Get default group levels
    default_group_cols, default_group_levels = all_scheme_info[default_scheme_name]

    # Generate group toggle buttons (will be replaced dynamically if using multiple schemes)
    group_buttons = join(["""
        <button onclick="toggleGroup_$(chart_title_safe)('$(group)')"
                style="background-color: $(group_colors[group]); margin: 2px; padding: 5px 10px;
                       border: 1px solid #ccc; cursor: pointer;">
            $(group)
        </button>
    """ for group in default_group_levels], "\n")

    # Generate grouping scheme selector if using multiple schemes
    scheme_selector = ""
    if use_multiple_schemes
        scheme_options = join(["""<option value="$(scheme_name)"$(scheme_name == default_scheme_name ? " selected" : "")>$(scheme_name)</option>"""
                               for scheme_name in sort(collect(keys(all_scheme_info)))], "\n")
        scheme_selector = """
            <div style="margin: 10px 0;">
                <label><strong>Grouping Scheme: </strong></label>
                <select id="scheme_selector_$(chart_title_safe)"
                        onchange="changeScheme_$(chart_title_safe)(this.value)"
                        style="padding: 5px; font-size: 14px;">
                    $(scheme_options)
                </select>
            </div>
        """
    end

    # Generate smoothing slider (default at index -1, then 0, 1, 2, ...)
    smoothing_options = """<option value="-1">Defaults</option>\n""" *
        join(["<option value=\"$(i-1)\">$(smoothing_params[i])</option>"
              for i in 1:length(smoothing_params)], "\n")

    # Build plot attributes content (aspect ratio will be added automatically by generate_appearance_html_from_sections)
    return """
    <!-- Surface Controls Row -->
    <div style="margin: 10px 0; display: grid; grid-template-columns: 1fr 1fr; gap: 10px; align-items: center;">
        <div>
            <label>Smoothing Parameter: </label>
            <select id="smoothing_select_$(chart_title_safe)"
                    onchange="setSmoothing_$(chart_title_safe)(this.value)"
                    style="padding: 5px;">
                $(smoothing_options)
            </select>
            <span id="smoothing_label_$(chart_title_safe)" style="margin-left: 5px;">Defaults</span>
        </div>
        <div style="text-align: right;">
            $(has_l1 ? """<button id="l1l2_toggle_$(chart_title_safe)" onclick="toggleL1L2_$(chart_title_safe)()"
                         style="background-color: #4CAF50; color: white; padding: 5px 10px;
                                border: 1px solid #ccc; cursor: pointer;">Using L2 (Mean)</button>""" : "")
        </div>
    </div>

    <!-- Toggle Buttons Row -->
    <div style="margin: 10px 0;">
        <button onclick="toggleAllSurfaces_$(chart_title_safe)()" style="padding: 5px 10px; margin-right: 10px;">Toggle All Surfaces</button>
        <button onclick="toggleAllPoints_$(chart_title_safe)()" style="padding: 5px 10px;">Toggle All Points</button>
    </div>

    <!-- Groups Section -->
    <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Groups (click to toggle visibility)</h4>
    $(scheme_selector)
    <div id="group_buttons_$(chart_title_safe)" style="margin: 10px 0;">
        $(group_buttons)
    </div>
    """
end
