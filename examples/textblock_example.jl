using JSPlots, DataFrames, Dates

# Prepare header
header = TextBlock("""
<h1>TextBlock Examples</h1>
<p>This page demonstrates how to use TextBlock elements in JSPlots to add formatted text, documentation, and context to your visualizations.</p>
<p>TextBlocks support full HTML formatting including headings, paragraphs, lists, tables, and more.</p>
""")

# Example 1: Simple text block with basic HTML
text1 = TextBlock("""
<h2>Introduction</h2>
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

# Example 4: Combining text blocks with actual plots
df = DataFrame(
    x = 1:10,
    y = rand(10) .* 100,
    color = repeat(["A", "B"], inner=5)
)

line_plot = LineChart(:example_chart, df, :df;
    x_cols = [:x],
    y_cols = [:y],
    color_cols = [:color],
    title = "Sample Data",
    x_label = "Time",
    y_label = "Value"
)

intro_text = TextBlock("""
<h2>Example: Analysis Report</h2>
<p><em>Generated on $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))</em></p>
<p>This section shows how to create a complete analysis report with text blocks and interactive charts.</p>
""")

conclusion_text = TextBlock("""
<h2>Conclusions</h2>
<p>Based on the analysis above, we can conclude that:</p>
<ol>
    <li>The data shows moderate variability</li>
    <li>No significant outliers are present</li>
    <li>Further investigation is recommended</li>
</ol>
<h3>Next Steps</h3>
<p>For more information, contact the data science team.</p>
""")

summary = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated TextBlock features:</p>
<ul>
    <li>Basic HTML formatting (bold, italic, code)</li>
    <li>Lists (unordered and ordered)</li>
    <li>HTML tables for structured data</li>
    <li>Combining text blocks with interactive plots</li>
    <li>Creating complete reports with multiple sections</li>
</ul>
<p><strong>Tip:</strong> TextBlocks can include any valid HTML, making them perfect for documentation, reports, and explanations!</p>
""")

# Create a single page combining all text block examples
page = JSPlotPage(
    Dict{Symbol,DataFrame}(:df => df),
    [header, text1, text2, text3, intro_text, line_plot, conclusion_text, summary],
    tab_title = "TextBlock Examples"
)

create_html(page, "generated_html_examples/textblock_examples.html")

println("\n" * "="^60)
println("TextBlock examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/textblock_examples.html")
println("\nThis page includes:")
println("  • Basic HTML formatting examples")
println("  • Lists (unordered and ordered)")
println("  • HTML tables")
println("  • Text blocks combined with interactive plots")
println("  • Complete analysis report structure")
