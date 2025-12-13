using JSPlots, DataFrames, Statistics

println("Creating ScatterSurface3D examples...")

# Generate synthetic 3D data with different patterns for groups
function generate_3d_data(n=100)
    df = DataFrame()

    # Group A: Saddle surface z = x^2 - y^2 + noise
    x_a = randn(n) .* 2
    y_a = randn(n) .* 2
    z_a = x_a.^2 .- y_a.^2 .+ randn(n) .* 0.5
    df_a = DataFrame(x=x_a, y=y_a, z=z_a, group="A", region="North")

    # Group B: Paraboloid surface z = x^2 + y^2 + noise
    x_b = randn(n) .* 2
    y_b = randn(n) .* 2
    z_b = x_b.^2 .+ y_b.^2 .+ randn(n) .* 0.5
    df_b = DataFrame(x=x_b, y=y_b, z=z_b, group="B", region="South")

    # Group C: Plane z = 2x + 3y + noise
    x_c = randn(n) .* 2
    y_c = randn(n) .* 2
    z_c = 2 .* x_c .+ 3 .* y_c .+ randn(n) .* 0.5
    df_c = DataFrame(x=x_c, y=y_c, z=z_c, group="C", region="North")

    return vcat(df_a, df_b, df_c)
end

# Create test data
df = generate_3d_data(80)

println("Generated $(nrow(df)) data points across 3 groups")

# =============================================================================
# Example 1: Basic ScatterSurface3D with default smoother
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Basic 3D Scatter with Fitted Surfaces</h2>
<p>This example shows 3D scatter points with automatically fitted surfaces using kernel smoothing.</p>
<p>Features:</p>
<ul>
    <li><strong>Three groups:</strong> Each group has different underlying patterns (saddle, paraboloid, plane)</li>
    <li><strong>Default smoothing:</strong> Each group uses its optimal smoothing parameter</li>
    <li><strong>Interactive controls:</strong> Toggle surfaces/points, adjust X/Y ranges, select smoothing levels</li>
    <li><strong>Color coding:</strong> Each group has a distinct color for both points and surface</li>
</ul>
""")

# Create ScatterSurface3D with default smoother
chart1 = ScatterSurface3D(:scatter_surface_basic, df, :data,
    x_col=:x,
    y_col=:y,
    z_col=:z,
    group_cols=[:group],
    smoothing_params=[0.2, 0.5, 1.0, 2.0, 4.0],
    default_smoothing=Dict("A" => 1.0, "B" => 0.5, "C" => 2.0),
    marker_size=5,
    marker_opacity=0.7,
    title="3D Scatter with Auto-Fitted Surfaces",
    notes="Use controls to toggle display and adjust smoothing. Default smoothing varies by group."
)

# =============================================================================
# Example 2: Custom Surface Fitter
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Custom Surface Fitting Function</h2>
<p>This example demonstrates using a custom surface fitting function.</p>
<p>The custom fitter uses a simple moving average approach with adjustable bandwidth.</p>
<ul>
    <li><strong>Custom smoother:</strong> User-defined function for fitting surfaces</li>
    <li><strong>Multiple smoothing levels:</strong> Pre-compute surfaces at different smoothing parameters</li>
    <li><strong>Slider control:</strong> Switch between smoothing levels or use group-specific defaults</li>
</ul>
""")

# Define custom surface fitter (simple moving average)
function custom_smoother(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, bandwidth::Float64)
    # Create a coarser grid for better visualization
    x_min, x_max = extrema(x)
    y_min, y_max = extrema(y)

    # Expand range slightly
    x_range = x_max - x_min
    y_range = y_max - y_min
    x_min -= 0.15 * x_range
    x_max += 0.15 * x_range
    y_min -= 0.15 * y_range
    y_max += 0.15 * y_range

    grid_size = 15
    x_grid = range(x_min, x_max, length=grid_size)
    y_grid = range(y_min, y_max, length=grid_size)

    z_grid = zeros(grid_size, grid_size)

    # Simple weighted averaging
    for (i, xi) in enumerate(x_grid)
        for (j, yj) in enumerate(y_grid)
            weights = exp.(-((x .- xi).^2 .+ (y .- yj).^2) ./ (2 * bandwidth^2))
            weight_sum = sum(weights)
            z_grid[i, j] = weight_sum > 1e-6 ? sum(weights .* z) / weight_sum : mean(z)
        end
    end

    return (collect(x_grid), collect(y_grid), z_grid)
end

# Subset data for second example (just group A and B)
df_subset = df[in.(df.group, Ref(["A", "B"])), :]

chart2 = ScatterSurface3D(:scatter_surface_custom, df_subset, :data_subset,
    x_col=:x,
    y_col=:y,
    z_col=:z,
    group_cols=[:group],
    surface_fitter=custom_smoother,
    smoothing_params=[0.3, 0.7, 1.5, 3.0],
    default_smoothing=Dict("A" => 1.5, "B" => 0.7),
    marker_size=6,
    title="Custom Surface Fitter Example",
    notes="Custom smoothing function with adjustable bandwidth parameter"
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>ScatterSurface3D combines 3D scatter plots with fitted surfaces:</p>
<h3>Key Features</h3>
<ul>
    <li><strong>Fitted Surfaces:</strong> Automatically fit smooth surfaces to point clouds</li>
    <li><strong>Multiple Smoothing Levels:</strong> Pre-compute surfaces at different smoothing parameters</li>
    <li><strong>Group-Specific Defaults:</strong> Each group can have its own optimal smoothing parameter</li>
    <li><strong>Interactive Controls:</strong>
        <ul>
            <li>Toggle all surfaces on/off</li>
            <li>Toggle all points on/off</li>
            <li>Toggle individual groups by clicking color buttons</li>
            <li>Adjust X and Y ranges with sliders</li>
            <li>Select smoothing parameter or use group defaults</li>
        </ul>
    </li>
    <li><strong>Customizable:</strong> Provide your own surface fitting function</li>
</ul>
<h3>Use Cases</h3>
<ul>
    <li>Visualizing complex 3D relationships in data</li>
    <li>Comparing fitted surfaces across different groups</li>
    <li>Exploring optimal smoothing parameters interactively</li>
    <li>Non-parametric regression visualization</li>
</ul>
<p><strong>Controls Guide:</strong></p>
<ul>
    <li><strong>Smoothing dropdown:</strong> Select "Defaults" to use group-specific smoothing, or choose a specific value to apply to all groups</li>
    <li><strong>Color buttons:</strong> Click to toggle visibility of that group's points and surface</li>
    <li><strong>X/Y Range:</strong> Filter data to focus on specific regions</li>
</ul>
""")

# Create combined page
page = JSPlotPage(
    Dict(:data => df, :data_subset => df_subset),
    [example1_text, chart1, example2_text, chart2, summary],
    tab_title="ScatterSurface3D Examples"
)

create_html(page, "generated_html_examples/scattersurface3d_example.html")

println("\n" * "="^60)
println("ScatterSurface3D examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/scattersurface3d_example.html")
println("\nThis page includes:")
println("  • Example 1: Basic scatter with default smoother (3 groups)")
println("  • Example 2: Custom surface fitting function (2 groups)")
println("  • Interactive controls for smoothing, ranges, and visibility")
println("\nOpen the HTML file in a browser to interact with the 3D plots!")
