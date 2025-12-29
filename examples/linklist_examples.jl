using JSPlots, DataFrames, OrderedCollections

println("Creating LinkList examples...")

# Introduction
intro = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/linklist_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>LinkList Examples</h1>
<p>LinkList provides a styled navigation component for creating links between pages in multi-page reports or linking to external resources.</p>
<p>This page demonstrates three ways to use LinkList:</p>
<ol>
    <li><strong>Automatic generation</strong> - Using the Pages constructor (explained via code)</li>
    <li><strong>Manual creation</strong> - Building a simple LinkList with a vector of tuples</li>
    <li><strong>Grouped with subheadings</strong> - Using OrderedDict to organize links into sections</li>
</ol>
""")

# Example 1: Automatic Generation (using CodeBlock to show the code)
automatic_explanation = TextBlock("""
<h2>Example 1: Automatic LinkList Generation</h2>
<p>The simplest way to create a LinkList is to use the Pages constructor, which automatically generates
navigation links from your JSPlotPage objects.</p>
<p>When you create a multi-page report using the Pages constructor, it automatically creates a LinkList
on the cover page with links to all subpages. The link text comes from each page's <code>tab_title</code>,
and the description comes from the <code>notes</code> parameter.</p>
<p>Here's how it works:</p>
""")

automatic_code = CodeBlock("""
using JSPlots, DataFrames

# Create some pages
page1 = JSPlotPage(
    Dict(:data => df1),
    [chart1],
    tab_title = "Revenue Analysis",
    notes = "Detailed revenue trends and forecasts"
)

page2 = JSPlotPage(
    Dict(:data => df2),
    [chart2],
    tab_title = "Cost Breakdown",
    notes = "Operating costs by department and category"
)

# The Pages constructor automatically creates a LinkList
pages = Pages(
    [TextBlock("<h1>Annual Report</h1>")],  # Cover page content
    [page1, page2]  # Subpages
)

# This creates:
# - A cover page with an auto-generated LinkList
# - Links labeled "Revenue Analysis" and "Cost Breakdown"
# - Descriptions from the notes parameter
""", Val(:code); language="julia", notes="The Pages constructor automatically generates a LinkList from your subpages")

# Example 2: Manual LinkList
manual_explanation = TextBlock("""
<h2>Example 2: Manual LinkList Creation</h2>
<p>You can manually create a LinkList by providing a vector of tuples. Each tuple contains:</p>
<ul>
    <li><strong>Title</strong> - The display name for the link</li>
    <li><strong>URL</strong> - The target URL (can be relative or absolute)</li>
    <li><strong>Description</strong> - A brief explanation of the linked content</li>
</ul>
<p>This approach gives you complete control over the links and is useful for:</p>
<ul>
    <li>Linking to external documentation or resources</li>
    <li>Creating custom navigation structures</li>
    <li>Building index pages with specific link descriptions</li>
</ul>
""")

manual_linklist = LinkList([
    ("PivotTable", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/pivottable_examples.html", "Interactive drag-and-drop pivot tables"),
    ("Table", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/table_examples.html", "Sortable data tables with CSV download"),
    ("TextBlock", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/textblock_examples.html", "Rich text and HTML content"),
    ("CodeBlock", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/codeblock_examples.html", "Syntax-highlighted code blocks"),
    ("LineChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/linechart_examples.html", "Time series and trend visualization"),
    ("AreaChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/areachart_examples.html", "Stacked area charts"),
    ("ScatterPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scatterplot_examples.html", "2D scatter plots with marginal distributions"),
    ("Scatter3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scatter3d_examples.html", "3D scatter plots with PCA eigenvectors"),
    ("Picture", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/picture_examples.html", "Display images and plots from other libraries")
],
chart_title = :manual_example,
notes = "Click any link above to see examples of that chart type")

manual_code = CodeBlock("""
# Create a manual LinkList
links = LinkList([
    ("PivotTable", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/pivottable_examples.html", "Interactive drag-and-drop pivot tables"),
    ("Table", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/table_examples.html", "Sortable data tables with CSV download"),
    ("LineChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/linechart_examples.html", "Time series and trend visualization")
],
chart_title = :manual_example,
notes = "Click any link above to see examples of that chart type")
""", Val(:code); language="julia")

# Example 3: Grouped LinkList with Subheadings
grouped_explanation = TextBlock("""
<h2>Example 3: Grouped LinkList with Subheadings</h2>
<p>For larger navigation structures, you can use OrderedDict to organize links into sections with subheadings.</p>
<p>This is particularly useful for:</p>
<ul>
    <li>Documentation sites with multiple categories</li>
    <li>Multi-section reports (e.g., "Financial", "Operational", "Strategic")</li>
    <li>Any scenario where logical grouping improves navigation</li>
</ul>
<p>The OrderedDict preserves insertion order, ensuring sections appear in the sequence you define.</p>
""")

od = OrderedCollections.OrderedDict{String, Vector{Tuple{String,String,String}}}()
od["OverView"] = [("GitHub Repository", "https://github.com/s-baumann/JSPlots.jl", "Source code"),
    ("Documentation", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/z_general_example/z_general_example.html", "General tutorial and overview"),
    ("Pages", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/annual_report.html", "Multi-page reports with navigation")]
od["Tabular Data and Text"] = [("PivotTable", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/pivottable_examples.html", "Interactive drag-and-drop pivot tables"),
    ("Table", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/table_examples.html", "Sortable data tables with CSV download"),
    ("TextBlock", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/textblock_examples.html", "Rich text and HTML content"),
    ("CodeBlock", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/codeblock_examples.html", "Syntax-highlighted code blocks"),
    ("LinkList", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/linklist_examples.html", "Navigation and link lists")]
od["Multimedia"] = [
    ("Picture", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/picture_examples.html", "Display images, GIFs, and filtered charts from VegaLite, Plots.jl, or Makie"),
    ("Slides", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/slides_examples_embedded.html", "Slideshows and animations")]
od["2D Plots"] = [("LineChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/linechart_examples.html", "Time series and trend visualization"),
    ("AreaChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/areachart_examples.html", "Stacked area charts"),
    ("ScatterPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scatterplot_examples.html", "2D scatter plots with marginal distributions"),
    ("Path", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/path_examples.html", "Trajectory visualization with direction arrows")]
od["Distributional Plots"] = [
    ("DistPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/distplot_examples.html", "Histogram, box plot, and rug plot combined"),
    ("KernelDensity", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/kerneldensity_examples.html", "Smooth kernel density estimation"),
    ("PieChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/piechart_examples.html", "Pie charts with faceting and filtering")]
od["3D Plots"] = [
    ("Scatter3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scatter3d_examples.html", "3D scatter plots with PCA eigenvectors"),
    ("Surface3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/surface3d_examples.html", "3D surface visualization"),
    ("ScatterSurface3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scattersurface3d_example.html", "3D scatter with fitted surfaces")]
od["Situational Charts"] = [
    ("CorrPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/corrplot_examples.html", "Make correlation plots with hierarchical clustering dendrograms showing Pearson and Spearman correlations."),
    ("Waterfall", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/waterfall_examples.html", "Make Waterfall plots showing how positive and negative elements add up to an aggregate."),
    ("SanKey", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/sankey_examples.html", "Make SanKey plots showing how individuals change affiliation over multiple waves.")]

grouped_linklist = LinkList(
    od,
    chart_title = :grouped_example,
    notes = "Links are organized by category. This structure is ideal for documentation or multi-section reports."
)

grouped_code = CodeBlock("""
od = OrderedCollections.OrderedDict{String, Vector{Tuple{String,String,String}}}()
od["OverView"] = [("GitHub Repository", "https://github.com/s-baumann/JSPlots.jl", "Source code"),
    ("Documentation", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/z_general_example/z_general_example.html", "General tutorial and overview"),
    ("Pages", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/annual_report.html", "Multi-page reports with navigation")]
od["Tabular Data and Text"] = [("PivotTable", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/pivottable_examples.html", "Interactive drag-and-drop pivot tables"),
    ("Table", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/table_examples.html", "Sortable data tables with CSV download"),
    ("TextBlock", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/textblock_examples.html", "Rich text and HTML content"),
    ("CodeBlock", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/codeblock_examples.html", "Syntax-highlighted code blocks"),
    ("LinkList", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/linklist_examples.html", "Navigation and link lists")]
od["Multimedia"] = [
    ("Picture", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/picture_examples.html", "Display images, GIFs, and filtered charts from VegaLite, Plots.jl, or Makie"),
    ("Slides", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/slides_examples_embedded.html", "Slideshows and animations")]
od["2D Plots"] = [("LineChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/linechart_examples.html", "Time series and trend visualization"),
    ("AreaChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/areachart_examples.html", "Stacked area charts"),
    ("ScatterPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scatterplot_examples.html", "2D scatter plots with marginal distributions"),
    ("Path", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/path_examples.html", "Trajectory visualization with direction arrows")]
od["Distributional Plots"] = [
    ("DistPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/distplot_examples.html", "Histogram, box plot, and rug plot combined"),
    ("KernelDensity", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/kerneldensity_examples.html", "Smooth kernel density estimation"),
    ("PieChart", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/piechart_examples.html", "Pie charts with faceting and filtering")]
od["3D Plots"] = [
    ("Scatter3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scatter3d_examples.html", "3D scatter plots with PCA eigenvectors"),
    ("Surface3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/surface3d_examples.html", "3D surface visualization"),
    ("ScatterSurface3D", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/scattersurface3d_example.html", "3D scatter with fitted surfaces")]
od["Situational Charts"] = [
    ("CorrPlot", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/corrplot_examples.html", "Make correlation plots with hierarchical clustering dendrograms showing Pearson and Spearman correlations."),
    ("Waterfall", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/waterfall_examples.html", "Make Waterfall plots showing how positive and negative elements add up to an aggregate."),
    ("SanKey", "https://s-baumann.github.io/JSPlots.jl/dev/examples_html/sankey_examples.html", "Make SanKey plots showing how individuals change affiliation over multiple waves.")]

grouped_linklist = LinkList(
    od,
    chart_title = :grouped_example,
    notes = "Links are organized by category. This structure is ideal for documentation or multi-section reports."
)
""", Val(:code); language="julia")

# Create the page
page = JSPlotPage(
    Dict{Symbol, DataFrame}(),
    [
        intro,
        automatic_explanation,
        automatic_code,
        manual_explanation,
        manual_linklist,
        manual_code,
        grouped_explanation,
        grouped_linklist,
        grouped_code
    ],
    tab_title = "LinkList Examples",
    page_header = "LinkList Examples",
    notes = "Demonstrates three ways to create navigation links in JSPlots"
)

# Generate HTML file
println("Generating HTML file...")
output_dir = "generated_html_examples"
mkpath(output_dir)
create_html(page, joinpath(output_dir, "linklist_examples.html"))

println("✓ LinkList examples created successfully!")
println("  Output: $(joinpath(output_dir, "linklist_examples.html"))")
