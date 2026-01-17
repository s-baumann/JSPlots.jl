using JSPlots, DataFrames, Dates, VegaLite, StableRNGs
rng = StableRNG(333)


println("Creating Slides examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/slides_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>

Also <a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/slides_examples_external/slides_examples_external.jl" style="color: blue; font-weight: bold;">see here for a different example of Slides using externally held data images</a>
<h1>Slides Examples</h1>
<p>This page demonstrates the interactive Slides chart type in JSPlots.</p>
<ul>
    <li><strong>File-based slides:</strong> Load images from a directory with automatic filtering</li>
    <li><strong>Function-generated slides:</strong> Create slides dynamically from data using a custom function</li>
    <li><strong>Interactive controls:</strong> Play/pause, navigation, adjustable speed</li>
    <li><strong>Filtering:</strong> Filter slides by group dimensions</li>
</ul>
""")

# =============================================================================
# Create sample slide images
# =============================================================================

slides_dir = joinpath(@__DIR__, "slides")
if !isdir(slides_dir)
    mkpath(slides_dir)
end

println("Creating sample slide images...")

# Create sample SVG slides with the pattern: prefix!group1!group2!slidenum.svg
regions = ["North", "South"]
quarters = ["Q1", "Q2"]
colors_map = Dict("North" => "#4CAF50", "South" => "#2196F3",
                  "Q1" => "#FF9800", "Q2" => "#9C27B0")

for region in regions
    for quarter in quarters
        region_color = colors_map[region]
        quarter_color = colors_map[quarter]

        for slide_num in 1:3
            # Create an SVG with information about region, quarter, and slide number
            svg_content = """
            <svg width="600" height="400" xmlns="http://www.w3.org/2000/svg">
              <rect width="600" height="400" fill="#f0f0f0"/>
              <rect x="10" y="10" width="580" height="80" fill="$(region_color)" opacity="0.3"/>
              <text x="300" y="60" text-anchor="middle" font-size="36" fill="#333" font-weight="bold">
                $(region) - $(quarter)
              </text>
              <rect x="50" y="120" width="500" height="200" fill="$(quarter_color)" opacity="0.2" stroke="$(region_color)" stroke-width="3"/>
              <circle cx="300" cy="220" r="$(40 + slide_num * 20)" fill="$(region_color)" opacity="0.6"/>
              <text x="300" y="230" text-anchor="middle" font-size="48" fill="white" font-weight="bold">
                $(slide_num)
              </text>
              <text x="300" y="360" text-anchor="middle" font-size="20" fill="#666">
                Slide $(slide_num) of 3 - Sample Data Visualization
              </text>
            </svg>
            """

            filename = "sales!$(region)!$(quarter)!$(slide_num).svg"
            filepath = joinpath(slides_dir, filename)
            write(filepath, svg_content)
        end
    end
end

println("Created $(2 * 2 * 3) SVG slide files")

# =============================================================================
# Example 1: Slides from Directory Pattern
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Slides from Directory Pattern</h2>
<p>This example loads images from a directory following the pattern: <code>prefix!group1!group2!...!slidenum.extension</code></p>
<p>The slides below were created from SVG files in the pattern: <code>sales!Region!Quarter!SlideNum.svg</code></p>
<p>Features:</p>
<ul>
    <li>Automatic detection of filter groups from filename structure</li>
    <li>Play/Pause controls with adjustable speed (0.05s to 5s on log scale)</li>
    <li>Keyboard shortcuts: ← → for navigation, Space for play/pause</li>
    <li>Filter dropdowns to switch between different group combinations</li>
</ul>
""")

# Create Slides from directory pattern
slides1 = Slides(:sales_slides, slides_dir, "sales", "svg";
    default_filters = Dict{Symbol,Any}(:group_1 => "North", :group_2 => "Q1"),
    title = "Sales Analysis by Region and Quarter",
    notes = "Use filters to switch between regions and quarters. Each region/quarter has 3 slides.",
    autoplay = false,
    delay = 0.5
)

# =============================================================================
# Example 2: Slides from Function
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Slides Generated from Function (VegaLite.jl)</h2>
<p>This example generates slides dynamically using a custom chart function.</p>
<p>The function receives the dataset, group values, and slide number, then generates a chart.</p>
<p>Charts are automatically saved and embedded (or stored externally based on dataformat).</p>
<ul>
    <li>Uses VegaLite.jl to create charts</li>
    <li>Charts are saved as SVG for best quality</li>
    <li>Supports VegaLite.jl, Plots.jl, Makie, or custom chart objects</li>
</ul>
""")

# Create sample dataset
df = DataFrame(
    Product = repeat(["Widget", "Gadget", "Doohickey"], outer=12),
    Category = repeat(["Electronics", "Home"], inner=18),
    Month = repeat(1:12, inner=3),
    Sales = rand(rng, 100:1000, 36),
    Profit = rand(rng, 10:200, 36)
)

# VegaLite-based chart generation function
function make_sales_chart(data, category, product, month)
    filtered_df = data[(data.Category .== category) .&
                       (data.Product .== product) .&
                       (data.Month .== month), :]

    if nrow(filtered_df) == 0
        sales = 0
        profit = 0
    else
        sales = filtered_df.Sales[1]
        profit = filtered_df.Profit[1]
    end

    cat_color = category == "Electronics" ? "#2196F3" : "#4CAF50"

    chart_data = DataFrame(
        Metric = ["Sales", "Profit"],
        Value = [sales, profit]
    )

    chart = chart_data |> @vlplot(
        :bar,
        title = "$(category) - $(product) - Month $(month)",
        width = 400,
        height = 300,
        x = {:Metric, axis={title="", labelAngle=0}},
        y = {:Value, axis={title="Amount (\$)"}},
        color = {value = cat_color},
        config = {view = {stroke = nothing}}
    )

    return chart
end

# Create a subset of data for the slides (using only month 1-3 as slide numbers)
df_subset = df[df.Month .<= 3, :]

slides2 = Slides(:generated_slides, df_subset, :sales_data,
    [:Category, :Product], :Month, make_sales_chart;
    output_format = :svg,
    default_filters = Dict{Symbol,Any}(:Category => "Electronics", :Product => "Widget"),
    title = "Product Sales Analysis (VegaLite.jl Charts)",
    notes = "Generated slides using VegaLite.jl. Shows sales and profit for each product by category across 3 months.",
    autoplay = false,
    delay = 1.5
)

# =============================================================================
# Example 3: External Storage with Parquet Dataformat
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: External Storage of slides</h2>
<p>This example demonstrates using Slides with external storage.</p>
<p>When using external dataformats (parquet, csv_external, json_external), slide images are stored in a <code>slides/</code> subdirectory rather than being embedded in the HTML file.</p>
<ul>
    <li>Creates a portable project directory structure</li>
    <li>Slide images stored in <code>slides/</code> subdirectory</li>
    <li>Data stored in <code>data/</code> subdirectory (if applicable)</li>
    <li>Useful for large slide sets or when you need external file access</li>
</ul>
""")

# Create a smaller dataset for this example
# 2 regions × 2 quarters × 2 months = 8 rows total
df_external = DataFrame(
    Region = repeat(["East", "West"], inner=4),
    Quarter = repeat(repeat(["Q3", "Q4"], inner=2), outer=2),
    Month = repeat([1, 2], 4),
    Revenue = rand(rng, 5000:15000, 8)
)

# Chart function for external example
function make_revenue_chart(data, region, quarter, month)
    filtered_df = data[(data.Region .== region) .&
                       (data.Quarter .== quarter) .&
                       (data.Month .== month), :]

    if nrow(filtered_df) == 0
        revenue = 0
    else
        revenue = filtered_df.Revenue[1]
    end

    region_color = region == "East" ? "#9C27B0" : "#FF5722"

    chart_data = DataFrame(
        Category = ["Revenue"],
        Value = [revenue]
    )

    chart = chart_data |> @vlplot(
        :bar,
        title = "$(region) - $(quarter) - Month $(month)",
        width = 400,
        height = 300,
        x = {:Category, axis={title=""}},
        y = {:Value, axis={title="Revenue (\$)"}},
        color = {value = region_color},
        config = {view = {stroke = nothing}}
    )

    return chart
end

slides3 = Slides(:external_slides, df_external, :revenue_data,
    [:Region, :Quarter], :Month, make_revenue_chart;
    output_format = :svg,
    default_filters = Dict{Symbol,Any}(:Region => "East", :Quarter => "Q3"),
    title = "Revenue Analysis (External Storage)",
    notes = "Slides stored externally in slides/ directory. Useful for large datasets or when images need to be accessible as separate files.",
    autoplay = false,
    delay = 1.0
)

# =============================================================================
# Example 4: Embedded JPEG Images (Bitmap Format)
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: Embedded JPEG Images (Bitmap Format)</h2>
<p>This example demonstrates embedding JPEG photographs (bitmap format) in the HTML file.</p>
<p>Unlike SVG which stores drawing instructions, JPEG images are encoded as base64 binary data.</p>
<ul>
    <li>JPEG images embedded as base64-encoded data URLs</li>
    <li>Works for photographs and any bitmap images (PNG, JPEG)</li>
    <li>Larger file size than SVG but necessary for photos</li>
    <li>Still produces a single portable HTML file</li>
</ul>
""")

# Create a temporary directory with JPEG images following the pattern
photos_dir = joinpath(@__DIR__, "slides_photos")
if !isdir(photos_dir)
    mkpath(photos_dir)
end

println("Creating photo slide pattern...")

# Copy the JPEG files with the pattern: photos!slidenum.jpeg
source_images = [
    joinpath(@__DIR__, "pictures", "images.jpeg"),
    joinpath(@__DIR__, "pictures", "Linux2.jpeg")
]

for (i, source) in enumerate(source_images)
    if isfile(source)
        dest = joinpath(photos_dir, "photos!$(i).jpeg")
        cp(source, dest, force=true)
    else
        @warn "Source image not found: $source"
    end
end

println("Created $(length(source_images)) JPEG slide files")

# Create Slides from JPEG directory pattern
slides4 = Slides(:photo_slides, photos_dir, "photos", "jpeg";
    title = "Photo Slideshow (Embedded JPEG)",
    notes = "JPEG images embedded as base64 data. Each image is a bitmap encoded as text.",
    autoplay = false,
    delay = 2.0
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated four ways to use the Slides chart type:</p>
<ul>
    <li><strong>Method 1 - From Directory (SVG):</strong> Load existing SVG files with automatic group detection</li>
    <li><strong>Method 2 - From Function (SVG, Embedded):</strong> Generate VegaLite charts as embedded SVG</li>
    <li><strong>Method 3 - From Function (External):</strong> Generate charts with external storage using parquet dataformat</li>
    <li><strong>Method 4 - From Directory (JPEG, Embedded):</strong> Load JPEG photographs as embedded base64 data</li>
</ul>
<h3>Image Format Comparison</h3>
<ul>
    <li><strong>SVG (Vector):</strong> Drawing instructions, scalable, small file size - perfect for charts</li>
    <li><strong>JPEG/PNG (Bitmap):</strong> Pixel data as base64, larger file size - needed for photographs</li>
</ul>
<h3>Storage Options</h3>
<ul>
    <li><strong>Embedded (csv_embedded, json_embedded):</strong> All images embedded in HTML - single portable file</li>
    <li><strong>External (csv_external, json_external, parquet):</strong> Images stored in slides/ directory - better for large datasets</li>
</ul>
<h3>Key Features</h3>
<ul>
    <li>Interactive play/pause controls</li>
    <li>Adjustable playback speed (0.05s to 5s per slide on log scale)</li>
    <li>Keyboard shortcuts for navigation</li>
    <li>Filter dropdowns for group dimensions</li>
    <li>Support for PNG, JPEG, SVG, and PDF formats</li>
    <li>Supports VegaLite.jl, Plots.jl, Makie, or custom chart objects</li>
</ul>
<p><strong>Tips:</strong></p>
<ul>
    <li>Use arrow keys to navigate slides quickly</li>
    <li>Press space to toggle play/pause</li>
    <li>Change filters to see different slide combinations</li>
    <li>Adjust the delay slider to control autoplay speed</li>
</ul>
""")

# =============================================================================
# Create HTML output
# =============================================================================

# Embedded version (single file)
page_embedded = JSPlotPage(
    Dict{Symbol,Any}(:sales_data => df_subset),
    [header, example1_text, slides1, example2_text, slides2, example4_text, slides4, summary],
    tab_title = "Slides Examples (Embedded)"
)

create_html(page_embedded, "generated_html_examples/slides_examples_embedded.html")

# External version (with directory structure)
page_external = JSPlotPage(
    Dict{Symbol,Any}(:revenue_data => df_external),
    [header, example3_text, slides3, summary],
    tab_title = "Slides Examples (External)",
    dataformat = :parquet
)

create_html(page_external, "generated_html_examples/slides_examples_external.html")

println("\n" * "="^60)
println("Slides examples created successfully!")
println("="^60)
println("\nFiles created:")
println("  1. slides_examples_embedded.html (single file, ~125KB)")
println("     - All images embedded in HTML")
println("     - Includes SVG (vector) and JPEG (bitmap) examples")
println("  2. slides_examples_external/ (directory)")
println("     - slides_examples_external.html (main HTML file)")
println("     - slides/ subdirectory with 8 SVG files")
println("     - data/ subdirectory with parquet data")
println("\nEmbedded version includes:")
println("  • Example 1: SVG slides from directory pattern (sales by region/quarter)")
println("  • Example 2: VegaLite-generated SVG charts (product sales)")
println("  • Example 4: JPEG photographs (bitmap images as base64)")
println("\nExternal version includes:")
println("  • Example 3: VegaLite charts with external storage (revenue analysis)")
println("  • Images stored in slides/ directory")
println("\nOpen either HTML file in a browser to interact with the slideshows!")
