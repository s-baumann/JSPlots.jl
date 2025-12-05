using JSPlots, DataFrames, Dates

println("Creating Picture examples...")

# Get the path to the example image
example_image_path = joinpath(@__DIR__, "pictures", "images.jpeg")

# Prepare header
header = TextBlock("""
<h1>Picture Examples</h1>
<p>This page demonstrates how to include images in JSPlots pages.</p>
<ul>
    <li><strong>File-based images:</strong> Load JPEG, PNG, SVG, and other formats</li>
    <li><strong>Custom save functions:</strong> Generate images dynamically</li>
    <li><strong>Embedded vs External:</strong> Choose between embedded (default) and external storage</li>
    <li><strong>Integration:</strong> Combine images with interactive plots and text</li>
</ul>
""")

# Example 1: Basic Picture from file path
pic1 = Picture(:example_image, example_image_path;
               notes="This is an example image loaded from a file path")

# Example 2: Create an SVG file and display it
test_svg_path = tempname() * ".svg"
svg_content = """
<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="300" fill="#f0f0f0"/>
  <circle cx="100" cy="150" r="50" fill="#4CAF50"/>
  <circle cx="200" cy="150" r="50" fill="#2196F3"/>
  <circle cx="300" cy="150" r="50" fill="#FF9800"/>
  <text x="200" y="270" text-anchor="middle" font-size="24" fill="#333">
    JSPlots Picture Example
  </text>
</svg>
"""
write(test_svg_path, svg_content)

pic2 = Picture(:svg_diagram, test_svg_path;
               notes="SVG images are embedded as XML for best quality")

# Example 3: Using custom save function (mock example)
# This demonstrates how you would use a custom plotting library
mock_chart = Dict(:type => "bar", :data => [1, 2, 3, 4, 5])

# Custom save function that creates a simple HTML-based chart
function save_mock_chart(chart, path)
    html_chart = """
    <svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
      <rect width="400" height="300" fill="#ffffff"/>
      <text x="200" y="30" text-anchor="middle" font-size="20" fill="#333">
        Mock Chart: $(chart[:type])
      </text>
      <rect x="50" y="100" width="50" height="100" fill="#3498db"/>
      <rect x="125" y="80" width="50" height="120" fill="#3498db"/>
      <rect x="200" y="60" width="50" height="140" fill="#3498db"/>
      <rect x="275" y="70" width="50" height="130" fill="#3498db"/>
      <text x="200" y="250" text-anchor="middle" font-size="14" fill="#666">
        Data: $(join(chart[:data], ", "))
      </text>
    </svg>
    """
    write(path, html_chart)
end

pic3 = Picture(:custom_chart, mock_chart, save_mock_chart;
               format=:svg,
               notes="This demonstrates using a custom save function")

# Example 4: Create a line chart to combine with pictures
df = DataFrame(
    category = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
    value = [45, 52, 48, 61, 58, 67],
    color = repeat(["A"], 6)
)

# Create a chart
line_chart = LineChart(:trend, df, :df;
    x_col = :category,
    y_col = :value,
    color_cols = [:color],
    title = "Monthly Trend",
    x_label = "Month",
    y_label = "Value"
)

mixed_text = TextBlock("""
<h2>Mixed Content Example</h2>
<p>Below you can see how to combine static images with interactive charts.</p>
""")

comparison_text = TextBlock("""
<h2>Embedded vs External Image Storage</h2>
<h3>Embedded Format (default)</h3>
<p>Images are base64-encoded and embedded directly in the HTML file.</p>
<p><strong>Pros:</strong> Single file, easy to share, no external dependencies</p>
<p><strong>Cons:</strong> Larger file size (especially for PNG/JPEG)</p>

<h3>External Format</h3>
<p>Images are saved to a pictures/ subdirectory and referenced by the HTML.</p>
<p><strong>Pros:</strong> Smaller HTML file, easier to update images separately</p>
<p><strong>Cons:</strong> Multiple files to manage</p>
""")

conclusion = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated all key Picture features:</p>
<ul>
    <li>Loading images from file paths (JPEG, SVG)</li>
    <li>Using custom save functions to generate images dynamically</li>
    <li>Combining images with interactive charts</li>
    <li>Understanding embedded vs external storage options</li>
</ul>
<p><strong>Tip:</strong> For external format examples, use the provided open.sh or open.bat scripts to avoid CORS errors when viewing locally.</p>
""")

# Create single combined page with all picture examples
page = JSPlotPage(
    Dict{Symbol,DataFrame}(:df => df),
    [header, pic1, pic2, pic3, mixed_text, line_chart, comparison_text, conclusion],
    tab_title = "Picture Examples"
)

create_html(page, "generated_html_examples/picture_examples.html")

# Clean up temporary SVG file
rm(test_svg_path, force=true)

println("\n" * "="^60)
println("Picture examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/picture_examples.html")
println("\nThis page includes:")
println("  • Simple image loaded from file path")
println("  • SVG image example")
println("  • Custom save function demonstration")
println("  • Pictures combined with interactive charts")
println("  • Embedded vs external storage comparison")
println("\nTip: For external format examples, use the provided open.sh or open.bat scripts")
println("     to avoid CORS errors when viewing locally.")
