using JSPlots, DataFrames, Dates

println("Creating 3D Surface Chart examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/surface3d_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>3D Surface Chart Examples</h1>
<p>This page demonstrates 3D surface plots in JSPlots using Plotly.</p>
<ul>
    <li><strong>Single and multiple surfaces:</strong> Basic 3D surface visualization with grouping</li>
    <li><strong>Interactive controls:</strong> Rotate, zoom, and pan to explore from all angles</li>
    <li><strong>Filtering:</strong> Use dropdown filters to filter data and dynamically update the surface</li>
    <li><strong>Color gradients:</strong> Automatic color schemes for different groups</li>
</ul>
<p><em>Click and drag to rotate the 3D plots. Use scroll wheel to zoom!</em></p>
""")

# Example 1: Basic 3D Surface - Mathematical Function
example1_text = TextBlock("""
<h2>Example 1: Basic 3D Surface</h2>
<p>A simple 3D surface showing a ripple pattern. This demonstrates the basic usage with a single surface.</p>
""")

x_range = -5:0.2:5
y_range = -5:0.2:5
surface_df = DataFrame()

for x in x_range
    for y in y_range
        z = sin(sqrt(x^2 + y^2))
        push!(surface_df, (x=x, y=y, z=z, group="Ripple"))
    end
end

chart1 = Surface3D(:basic_surface, surface_df, :surface_data;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :group,
    title = "3D Surface: sin(√(x² + y²))",
    notes = "Classic ripple pattern - demonstrates basic 3D surface visualization"
)

# Example 2: Multiple Surfaces with Grouping
example2_text = TextBlock("""
<h2>Example 2: Multiple Surfaces with Grouping</h2>
<p>Compare different mathematical functions by grouping. Each function gets its own color gradient.</p>
""")

multi_surface_df = DataFrame()

for x in -5:0.3:5
    for y in -5:0.3:5
        # Surface 1: Sine wave
        z1 = sin(sqrt(x^2 + y^2))
        push!(multi_surface_df, (x=x, y=y, z=z1, function_type="Sine"))

        # Surface 2: Cosine wave (shifted)
        z2 = cos(sqrt(x^2 + y^2)) - 1.5
        push!(multi_surface_df, (x=x, y=y, z=z2, function_type="Cosine"))

        # Surface 3: Combination
        z3 = 0.5 * (sin(x) * cos(y)) + 1.5
        push!(multi_surface_df, (x=x, y=y, z=z3, function_type="Combined"))
    end
end

chart2 = Surface3D(:multi_surfaces, multi_surface_df, :multi_data;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :function_type,
    title = "Multiple 3D Surfaces Comparison",
    notes = "Three different functions shown as separate colored surfaces"
)

# Example 3: 3D Surface with Filtering
example3_text = TextBlock("""
<h2>Example 3: 3D Surface with Filtering</h2>
<p>This example demonstrates filtering capability. Use the dropdown filters to filter by distance from origin or region (quadrant).
The surface updates dynamically as you adjust the filters - perfect for exploring subsets of your data!</p>
""")

filtered_df = DataFrame()

for x in -10:0.5:10
    for y in -10:0.5:10
        # Calculate distance from origin
        r = sqrt(x^2 + y^2)

        # Calculate z value
        z = sin(r) / (r + 0.1) * cos(atan(y, x))

        # Assign region based on quadrant
        region = if x >= 0 && y >= 0
            "NE"
        elseif x < 0 && y >= 0
            "NW"
        elseif x < 0 && y < 0
            "SW"
        else
            "SE"
        end

        push!(filtered_df, (
            x=x,
            y=y,
            z=z,
            distance=r,
            region=region,
            group="Wave"
        ))
    end
end

chart3 = Surface3D(:filtered_surface, filtered_df, :filtered_data;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :group,
    filters = Dict{Symbol, Any}(:distance => [5.0], :region => ["NE"]),
    title = "3D Surface with Filtering",
    notes = "Use the filters to filter by distance from origin or region (quadrant)"
)

# Example 4: Using choices (single-select) instead of filters (multi-select)
example4_text = TextBlock("""
<h2>Example 4: 3D Surface with Single-Select Choice</h2>
<p>This example demonstrates the difference between choices (single-select) and filters (multi-select).
Use the region dropdown to select exactly ONE quadrant at a time.</p>
""")

# Reuse filtered_df from Example 3
chart4 = Surface3D(:choice_surface, filtered_df, :filtered_data;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :group,
    choices = Dict{Symbol,Any}(:region => "NE"),  # Single-select - pick exactly ONE region
    filters = Dict{Symbol,Any}(:distance => [5.0]),  # Multi-select for comparison
    title = "3D Surface with Single-Select Choice",
    notes = """
    This example demonstrates the difference between choices and filters:
    - **region (choice)**: Single-select dropdown - pick exactly ONE quadrant
    - **distance (filter)**: Multi-select dropdown - can select multiple distance thresholds

    Compare with Example 3 which uses filters for both. Use choices when the user must select exactly one option.
    """
)

# Example 5: Trigonometric vs Polynomial Shapes
example5_text = TextBlock("""
<h2>Example 5: Shape Family Filtering</h2>
<p>This example shows the power of filtering for exploring different mathematical families.
Use the shape family filter to switch between trigonometric functions and polynomials.
Within each family, you can see different shapes by color.</p>
""")

shape_df = DataFrame()

for x in -5:0.3:5
    for y in -5:0.3:5
        r = sqrt(x^2 + y^2)

        # Trigonometric family
        push!(shape_df, (
            x=x, y=y,
            z=sin(r) / (r + 0.1),
            shapefamily="Trigonometric",
            shape="Sine Ripple"
        ))

        push!(shape_df, (
            x=x, y=y,
            z=cos(x) * sin(y),
            shapefamily="Trigonometric",
            shape="Wave Product"
        ))

        # Polynomial family
        push!(shape_df, (
            x=x, y=y,
            z=(x^2 - y^2) / 25,
            shapefamily="Polynomial",
            shape="Saddle"
        ))

        push!(shape_df, (
            x=x, y=y,
            z=-(x^2 + y^2) / 25,
            shapefamily="Polynomial",
            shape="Paraboloid"
        ))
    end
end

chart5 = Surface3D(:shape_family, shape_df, :shape_data;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :shape,
    filters = Dict{Symbol, Any}(:shapefamily => ["Trigonometric"]),
    title = "Shape Family Explorer",
    notes = "Filter by shape family to switch between trigonometric and polynomial functions"
)

# Example 6: Wave Interference Pattern
example6_text = TextBlock("""
<h2>Example 6: Wave Interference Pattern</h2>
<p>A classic physics demonstration showing interference from two wave sources.</p>
""")

wave_df = DataFrame()

for x in -10:0.5:10
    for y in -10:0.5:10
        # Two wave sources creating interference
        r1 = sqrt((x-3)^2 + (y-3)^2)
        r2 = sqrt((x+3)^2 + (y+3)^2)

        wave1 = sin(r1) / (r1 + 0.1)
        wave2 = sin(r2) / (r2 + 0.1)

        z = wave1 + wave2

        push!(wave_df, (x=x, y=y, z=z, group="Interference"))
    end
end

chart6 = Surface3D(:wave_interference, wave_df, :wave_data;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :group,
    title = "Wave Interference Pattern",
    notes = "Interference pattern from two wave sources - great for physics simulations"
)

# Example 7: Using a Struct as Data Source
example7_text = TextBlock("""
<h2>Example 7: Terrain Data from Struct Data Source</h2>
<p>This 3D surface uses data from a struct containing multiple DataFrames.
The <code>TerrainData</code> struct holds elevation and metadata information.</p>
""")

struct TerrainData
    elevation::DataFrame
    metadata::DataFrame
end

# Create terrain elevation data
terrain_df = DataFrame()
for x in -5:0.4:5
    for y in -5:0.4:5
        # Simulate hilly terrain with noise
        z = 2 * exp(-((x-1)^2 + (y-1)^2)/4) + 1.5 * exp(-((x+2)^2 + (y+1)^2)/3) + 0.3 * sin(x*2) * cos(y*2)
        push!(terrain_df, (x=x, y=y, elevation=z, group="Terrain"))
    end
end

metadata_df = DataFrame(
    property = ["Area", "Max Elevation", "Min Elevation"],
    value = ["100 sq km", "2.5 m", "0.1 m"]
)

# Create the struct
terrain_data = TerrainData(terrain_df, metadata_df)

chart7 = Surface3D(:struct_terrain, terrain_data.elevation, Symbol("terrain.elevation");
    x_col = :x,
    y_col = :y,
    z_col = :elevation,
    group_col = :group,
    title = "Terrain from Struct Data Source",
    notes = "This surface references data from a TerrainData struct using Symbol(\"terrain.elevation\")."
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Interactive 3D controls:</strong> Click and drag to rotate, scroll to zoom, shift+drag to pan</li>
    <li><strong>Multiple surface support:</strong> Compare different datasets on the same plot with distinct color gradients</li>
    <li><strong>Data filtering:</strong> Interactive multi-select dropdowns for both continuous and categorical variables (like distance, region, or shape family)</li>
    <li><strong>Dynamic updates:</strong> Surfaces update in real-time as you adjust filters - perfect for exploring data subsets</li>
    <li><strong>Scientific applications:</strong> Perfect for mathematical functions, simulations, and terrain data</li>
    <li><strong>Integration:</strong> Combine with other plot types, images, and text blocks</li>
</ul>
<p><strong>Tip:</strong> Hover over the surface to see exact x, y, z coordinates!</p>
""")

# Create single combined page
# Note: terrain_data struct is passed directly - JSPlotPage will extract its DataFrame fields
page = JSPlotPage(
    Dict{Symbol,Any}(
        :surface_data => surface_df,
        :multi_data => multi_surface_df,
        :filtered_data => filtered_df,
        :shape_data => shape_df,
        :wave_data => wave_df,
        :terrain => terrain_data  # Struct with elevation and metadata
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
    tab_title = "3D Surface Chart Examples"
)

# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="surface3d_examples.html",
                               description="Surface3D Examples", date=today(),
                               extra_columns=Dict(:chart_type => "3D Charts", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/surface3d_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("\n" * "="^60)
println("3D Surface Chart examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/surface3d_examples.html")
println("\nThis page includes:")
println("  • Basic 3D surface plot")
println("  • Multiple surfaces with grouping")
println("  • Filtering (continuous and categorical)")
println("  • Single-select choice example")
println("  • Shape family filtering example")
println("  • Wave interference pattern")
println("  • Struct data source (referencing struct fields via dot notation)")
println("  • Integration with text blocks")
