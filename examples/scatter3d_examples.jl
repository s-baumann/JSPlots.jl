using JSPlots, DataFrames, StableRNGs

println("Creating 3D Scatter Plot examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(666)

# Prepare header
header = TextBlock("""
<h1>3D Scatter Plot Examples</h1>
<p>This page demonstrates 3D scatter plots in JSPlots with advanced interactive features.</p>
<ul>
    <li><strong>Dimension selection:</strong> Choose which variables to display on x, y, and z axes</li>
    <li><strong>Eigenvector visualization:</strong> Show principal components (PC1, PC2, PC3) to understand data structure</li>
    <li><strong>Color coding:</strong> Customize visualization by category</li>
    <li><strong>Filtering:</strong> Filter data with interactive dropdowns (shown in gray "Filters" box)</li>
    <li><strong>Faceting:</strong> Create multiple plots by categorical variables (facet wrap or grid)</li>
    <li><strong>Synchronized camera:</strong> When using facets, camera rotation is automatically synchronized across all plots</li>
    <li><strong>Interactive 3D controls:</strong> Rotate, zoom, and pan to explore from all angles</li>
</ul>
<p><em>Click and drag to rotate the 3D plots. Use scroll wheel to zoom!</em></p>
""")

# Example 1: Basic 3D Scatter with Eigenvectors
example1_text = TextBlock("""
<h2>Example 1: Basic 3D Scatter with Eigenvectors</h2>
<p>A simple 3D scatter plot showing data points in three dimensions. The eigenvectors (PC1, PC2, PC3) show the principal components of the data,
indicating the directions of maximum variance. Toggle them on/off to see how they align with your data.</p>
""")

n = 200
df1 = DataFrame(
    x = randn(rng,n) .* 2,
    y = randn(rng,n) .* 1.5 .+ randn(rng,n) .* 0.5,  # Correlated with x
    z = randn(rng,n),
    category = rand(rng,["Group A", "Group B", "Group C"], n)
)

chart1 = Scatter3D(:basic_3d_scatter, df1, :df1, [:x, :y, :z];
    color_cols = [:category],
    show_eigenvectors = true,
    title = "Basic 3D Scatter with Eigenvectors",
    notes = "Red arrow = PC1 (most variance), Green = PC2, Blue = PC3"
)

# Example 2: Multiple Dimensions with Axis Selection
example2_text = TextBlock("""
<h2>Example 2: Multiple Dimensions with Axis Selection</h2>
<p>This example has 6 dimensions. Use the dropdown menus to choose which dimensions to display on each axis.
This is perfect for exploring high-dimensional data from different perspectives!</p>
""")

n = 300
df2 = DataFrame(
    dim1 = randn(rng,n),
    dim2 = randn(rng,n) .* 1.5,
    dim3 = randn(rng,n) .+ 2,
    dim4 = abs.(randn(rng,n)),
    dim5 = randn(rng,n) .* 0.5 .- 1,
    dim6 = cumsum(randn(rng,n)) ./ sqrt.(1:n),
    cluster = rand(rng,["Cluster 1", "Cluster 2", "Cluster 3"], n)
)

chart2 = Scatter3D(:multi_dim_scatter, df2, :df2,
    [:dim1, :dim2, :dim3, :dim4, :dim5, :dim6];
    color_cols = [:cluster],
    show_eigenvectors = true,
    title = "6-Dimensional Data Explorer",
    notes = "Use the dropdowns to select which dimensions to visualize on each axis"
)

# Example 3: With Filtering
example3_text = TextBlock("""
<h2>Example 3: 3D Scatter with Filtering</h2>
<p>Filter the data using dropdown filters to focus on specific subsets. The eigenvectors update dynamically to show
the principal components of the filtered data!</p>
""")

n = 400
df3 = DataFrame(
    x = randn(rng,n) .* 2,
    y = randn(rng,n) .* 1.5,
    z = randn(rng,n) .+ 1,
    temperature = rand(rng,15.0:0.1:35.0, n),
    region = rand(rng,["North", "South", "East", "West"], n),
    category = rand(rng,["Type A", "Type B", "Type C"], n)
)

chart3 = Scatter3D(:filtered_scatter, df3, :df3, [:x, :y, :z];
    color_cols = [:category],
    filters = Dict{Symbol, Any}(:temperature => [20.0], :region => ["North"]),
    show_eigenvectors = true,
    marker_size = 5,
    marker_opacity = 0.7,
    title = "3D Scatter with Filtering",
    notes = "Use the filters to filter by temperature and region - eigenvectors update with the data"
)

# Example 4: Clustering Visualization
example4_text = TextBlock("""
<h2>Example 4: Clustering Visualization</h2>
<p>Visualize clustering results in 3D. Each color represents a different cluster.
The eigenvectors show the principal axes of variation across all clusters.</p>
""")

n = 150
# Generate 3 distinct clusters
cluster1 = DataFrame(
    x = randn(rng,n÷3) .+ 3,
    y = randn(rng,n÷3) .+ 3,
    z = randn(rng,n÷3) .+ 3,
    w = randn(rng,n÷3) .* 0.5,
    cluster = "Cluster 1",
    density = rand(rng,["High", "Medium", "Low"], n÷3)
)

cluster2 = DataFrame(
    x = randn(rng,n÷3) .- 3,
    y = randn(rng,n÷3) .+ 2,
    z = randn(rng,n÷3) .- 2,
    w = randn(rng,n÷3) .* 0.5 .+ 2,
    cluster = "Cluster 2",
    density = rand(rng,["High", "Medium", "Low"], n÷3)
)

cluster3 = DataFrame(
    x = randn(rng,n÷3) .+ 1,
    y = randn(rng,n÷3) .- 3,
    z = randn(rng,n÷3) .+ 2,
    w = randn(rng,n÷3) .* 0.5 .- 1,
    cluster = "Cluster 3",
    density = rand(rng,["High", "Medium", "Low"], n÷3)
)

df4 = vcat(cluster1, cluster2, cluster3)

chart4 = Scatter3D(:cluster_scatter, df4, :df4, [:x, :y, :z, :w];
    color_cols = [:cluster, :density],
    show_eigenvectors = true,
    marker_size = 6,
    title = "Clustering Visualization",
    notes = "Three distinct clusters - eigenvectors show overall data structure"
)

# Example 5: Time Series in 3D
example5_text = TextBlock("""
<h2>Example 5: Time Series Visualization in 3D</h2>
<p>Visualize temporal data in 3D space. Color represents different time periods or categories.
This is useful for understanding how multivariate time series evolve in 3D space.</p>
""")

n = 300
t = range(0, 10π, length=n)
df5 = DataFrame(
    x = cos.(t) .+ randn(rng,n) .* 0.1,
    y = sin.(t) .+ randn(rng,n) .* 0.1,
    z = t ./ (2π) .+ randn(rng,n) .* 0.1,
    phase = [t_val < 10π/3 ? "Early" : (t_val < 20π/3 ? "Middle" : "Late") for t_val in t],
    time = t
)

chart5 = Scatter3D(:timeseries_scatter, df5, :df5, [:x, :y, :z];
    color_cols = [:phase],
    filters = Dict{Symbol, Any}(:time => [5.0]),
    show_eigenvectors = true,
    marker_size = 4,
    title = "Time Series in 3D Space",
    notes = "A spiral trajectory through 3D space - filter by time to see different segments"
)

# Example 6: Faceting with Synchronized Camera
example6_text = TextBlock("""
<h2>Example 6: Faceting with Synchronized Camera</h2>
<p>When using facets, the camera view is automatically synchronized across all plots.
Rotating one plot rotates them all - perfect for comparing similar data across categories from the same perspective!</p>
""")

n = 300
df6 = DataFrame(
    x = vcat([randn(rng,n÷3) .+ i for i in [-2, 0, 2]]...),
    y = vcat([randn(rng,n÷3) .+ i for i in [2, 0, -2]]...),
    z = randn(rng,n),
    experiment = vcat(fill("Exp 1", n÷3), fill("Exp 2", n÷3), fill("Exp 3", n÷3)),
    condition = rand(rng,["Control", "Treatment"], n)
)

chart6 = Scatter3D(:faceted_scatter, df6, :df6, [:x, :y, :z];
    color_cols = [:condition],
    facet_cols = :experiment,
    default_facet_cols = :experiment,
    show_eigenvectors = true,
    marker_size = 5,
    title = "Faceted 3D Scatter with Synchronized Camera",
    notes = "Camera rotation is automatically synchronized across all faceted plots"
)

# Example 7: Comprehensive - All Features
example7_text = TextBlock("""
<h2>Example 7: Comprehensive Example</h2>
<p>This example demonstrates all features together: multiple dimensions for axis selection, multiple color options,
filtering by continuous and categorical variables, faceting, and eigenvector visualization. Try different combinations!</p>
""")

n = 500
df7 = DataFrame(
    measurement1 = randn(rng,n) .* 2,
    measurement2 = randn(rng,n) .* 1.5 .+ randn(rng,n) .* 0.3,
    measurement3 = randn(rng,n) .+ 1,
    measurement4 = abs.(randn(rng,n)) .* 2,
    measurement5 = cumsum(randn(rng,n)) ./ sqrt.(1:n),
    temperature = rand(rng,15.0:0.1:35.0, n),
    pressure = rand(rng,980.0:0.1:1030.0, n),
    location = rand(rng,["Site A", "Site B", "Site C", "Site D"], n),
    experiment = rand(rng,["Exp 1", "Exp 2", "Exp 3"], n),
    quality = rand(rng,["High", "Medium", "Low"], n)
)

chart7 = Scatter3D(:comprehensive_scatter, df7, :df7,
    [:measurement1, :measurement2, :measurement3, :measurement4, :measurement5];
    color_cols = [:experiment, :quality, :location],
    filters = Dict{Symbol, Any}(:temperature => [25.0], :pressure => [1000.0], :location => ["Site A"]),
    facet_cols = [:experiment, :quality],
    show_eigenvectors = true,
    marker_size = 4,
    marker_opacity = 0.6,
    title = "Comprehensive 3D Scatter Example",
    notes = "All features: dimension selection, color options, filtering, faceting, and eigenvectors"
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Interactive 3D controls:</strong> Click and drag to rotate, scroll to zoom, shift+drag to pan</li>
    <li><strong>Organized UI:</strong> Controls are organized in sections - Filters (gray), Plot Attributes (blue), and Faceting (orange)</li>
    <li><strong>Dimension selection:</strong> Choose which variables to display on x, y, and z axes (dropdowns appear when 2+ dimensions available)</li>
    <li><strong>Eigenvector visualization:</strong> Toggle principal components on/off to understand data structure</li>
    <li><strong>PC1 (Red):</strong> Direction of maximum variance</li>
    <li><strong>PC2 (Green):</strong> Second direction of maximum variance (orthogonal to PC1)</li>
    <li><strong>PC3 (Blue):</strong> Third direction of maximum variance (orthogonal to PC1 and PC2)</li>
    <li><strong>Color selection:</strong> Switch between different categorical variables for coloring</li>
    <li><strong>Data filtering:</strong> Interactive multi-select dropdowns for both continuous and categorical variables</li>
    <li><strong>Faceting:</strong> Split your data into multiple plots by categorical variables (facet wrap or grid)</li>
    <li><strong>Camera synchronization:</strong> When faceting is enabled, camera rotation is automatically synchronized across all plots</li>
    <li><strong>Dynamic updates:</strong> All settings update immediately - eigenvectors recalculate when you change any setting</li>
    <li><strong>Scientific applications:</strong> Perfect for clustering visualization, dimensionality reduction, multivariate analysis, and exploratory data analysis</li>
</ul>
<p><strong>Tip:</strong> Hover over points to see exact coordinates! Eigenvectors are scaled for visibility.</p>
<p><strong>Note:</strong> Eigenvector calculation uses a simplified power iteration method suitable for visualization purposes.</p>
""")

# Create single combined page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :df1 => df1,
        :df2 => df2,
        :df3 => df3,
        :df4 => df4,
        :df5 => df5,
        :df6 => df6,
        :df7 => df7
    ),
    [header,
     example1_text, chart1,
     example2_text, chart2,
     example3_text, chart3,
     example4_text, chart4,
     example5_text, chart5,
     example6_text, chart6,
     example7_text, chart7,
     conclusion],
    tab_title = "3D Scatter Plot Examples"
)

create_html(page, "generated_html_examples/scatter3d_examples.html")

println("\n" * "="^60)
println("3D Scatter Plot examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/scatter3d_examples.html")
println("\nThis page includes:")
println("  • Basic 3D scatter with eigenvectors")
println("  • Multiple dimensions with axis selection")
println("  • Filtering with sliders (continuous and categorical)")
println("  • Clustering visualization")
println("  • Time series in 3D space")
println("  • Faceting with synchronized camera rotation")
println("  • Comprehensive example with all features")
println("  • Eigenvector visualization for understanding data structure")
