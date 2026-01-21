using JSPlots, DataFrames, Dates, StableRNGs
rng = StableRNG(444)

println("Creating TextBlock examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/textblock_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>TextBlock Examples</h1>
<p>This page demonstrates how to use TextBlock elements in JSPlots to add formatted text, documentation, images, and context to your visualizations.</p>
<p>TextBlocks support full HTML formatting including headings, paragraphs, lists, tables, and embedded images.</p>
""")

# Example 1: Simple text block with basic HTML
text1 = TextBlock("""
<h2>Basic HTML Formatting</h2>
<p>This is a simple text block that provides context for the visualizations below.</p>
<p>You can use standard HTML formatting including <strong>bold</strong>, <em>italic</em>, and <code>code</code>.</p>
""")

# Example 2: Text block with lists
text2 = TextBlock("""
<h2>Key Findings</h2>
<ul>
    <li>The distribution shows a clear bimodal pattern</li>
    <li>Group A has a higher mean than Group B</li>
    <li>Outliers are present in both groups</li>
</ul>
""")

# Example 3: Text block with a table
text3 = TextBlock("""
<h2>Summary Statistics</h2>
<table>
    <thead>
        <tr>
            <th>Metric</th>
            <th>Group A</th>
            <th>Group B</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Mean</td>
            <td>105.3</td>
            <td>98.7</td>
        </tr>
        <tr>
            <td>Std Dev</td>
            <td>12.4</td>
            <td>15.8</td>
        </tr>
        <tr>
            <td>Sample Size</td>
            <td>150</td>
            <td>150</td>
        </tr>
    </tbody>
</table>
""")

# Example 4: Company Header with Logo
company_header = TextBlock("""
<div style="display: flex; align-items: center; justify-content: space-between; background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
    <div style="flex: 1;">
        <h1 style="margin: 0; color: #2c3e50;">TuxCorp Analytics</h1>
        <p style="margin: 5px 0 0 0; color: #7f8c8d;">Data-Driven Insights for Better Decisions</p>
    </div>
    <div style="flex: 0 0 auto;">
        {{IMAGE:logo}}
    </div>
</div>
""", Dict("logo" => joinpath(dirname(@__FILE__),"pictures", "images.jpeg")))

# Example 5: Text with Multiple Images
multi_image_content = TextBlock("""
<h2>Product Showcase</h2>
<p>Welcome to our product showcase. Here we demonstrate our flagship products:</p>

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0;">
    <div style="border: 1px solid #ddd; padding: 15px; border-radius: 8px;">
        <h3>Product A</h3>
        {{IMAGE:product_a}}
        <p>Our premium offering with advanced features.</p>
    </div>
    <div style="border: 1px solid #ddd; padding: 15px; border-radius: 8px;">
        <h3>Product B</h3>
        {{IMAGE:product_b}}
        <p>The essential solution for everyday needs.</p>
    </div>
</div>
""", Dict(
    "product_a" => joinpath(dirname(@__FILE__),"pictures", "images.jpeg"),
    "product_b" => joinpath(dirname(@__FILE__),"pictures", "images.jpeg")
))

# Example 6: Simple Image in Text
simple_image = TextBlock("""
<h2>About Our Mascot</h2>
<div style="display: flex; align-items: start; gap: 20px;">
    <div style="flex: 0 0 200px;">
        {{IMAGE:mascot}}
    </div>
    <div style="flex: 1;">
        <p>Meet Tux, our beloved mascot! Tux has been representing our company since its inception, embodying the values of openness, collaboration, and innovation that drive our mission.</p>
        <p>As the face of our brand, Tux appears in all our marketing materials and serves as a constant reminder of our commitment to excellence and community.</p>
    </div>
</div>
""", Dict("mascot" => joinpath(dirname(@__FILE__),"pictures", "images.jpeg")))


summary = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated TextBlock features:</p>
<ul>
    <li><strong>Basic HTML formatting:</strong> Bold, italic, code</li>
    <li><strong>Lists:</strong> Unordered and ordered</li>
    <li><strong>HTML tables:</strong> Structured data display</li>
    <li><strong>Embedded images:</strong> Company logos, product images, mascots</li>
    <li><strong>Flexible layouts:</strong> Grid layouts, side-by-side content</li>
    <li><strong>Combined with plots:</strong> Creating complete analysis reports</li>
</ul>
<p><strong>Tip:</strong> TextBlocks can include any valid HTML and embedded images using {{IMAGE:id}} syntax, making them perfect for professional reports with branding!</p>
""")

# Create a single page combining all text block examples
page = JSPlotPage(
    Dict{Symbol,Any}(),
    [header, text1, text2, text3, company_header, multi_image_content, simple_image, summary],
    tab_title = "TextBlock Examples"
)

# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="textblock_examples.html",
                               description="TextBlock Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Text & Code", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/textblock_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("\n" * "="^60)
println("TextBlock examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/textblock_examples.html")
println("\nThis page includes:")
println("  • Basic HTML formatting examples")
println("  • Lists (unordered and ordered)")
println("  • HTML tables")
println("  • Company header with logo")
println("  • Multiple images in grid layout")
println("  • Side-by-side text and image")
println("  • Text blocks combined with interactive plots")
println("  • Complete analysis report structure")
