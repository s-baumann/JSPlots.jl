using JSPlots, DataFrames, DataFramesMeta, Dates, StableRNGs, Statistics

# Introduction
intro = TextBlock("""
<h1>JSPlots.jl Comprehensive Tutorial</h1>
<p>To briefly show the package, this page demonstrates one example of each plot type available in JSPlots.jl.
Before showing the charts, we will generate a dataset of synthetic data that represents sales for a particular company of door to door salesmen. 
rich enough to create meaningful examples for all chart types.</p>
""")

# Generate comprehensive dataset
dataset_intro = TextBlock("""
<h2>Dataset Generation</h2>
<p>We'll create a business analytics dataset containing sales data with multiple dimensions:</p>
<ul>
    <li><strong>Time series:</strong> Daily sales over one year</li>
    <li><strong>Categories:</strong> Products, regions, and customer segments</li>
    <li><strong>Continuous variables:</strong> Sales amounts, costs, quantities, and customer metrics</li>
    <li><strong>Geographic data:</strong> Latitude and longitude for where the door to door salesperson made each sale.</li>
</ul>
<p> The code that generates this dataset will be shown in the CodeBlock</p>

""")

function generate_comprehensive_data()
    rng = StableRNG(42)

    # Time period: One year of daily data
    start_date = Date(2024, 1, 1)
    dates = start_date:Day(1):(start_date + Day(364))
    n = length(dates)

    # Product categories
    products = ["Laptop", "Tablet", "Phone", "Monitor", "Accessories"]
    regions = ["North", "South", "East", "West"]
    segments = ["Enterprise", "SMB", "Consumer"]

    # Generate sales data
    records = DataFrame[]

    for (i, date) in enumerate(dates)
        for product in products
            for region in regions
                # Base sales with trends and seasonality
                base = 10000 + 1000 * sin(2π * i / 365)
                trend = i * 10

                # Product-specific multipliers
                product_mult = Dict(
                    "Laptop" => 3.0, "Tablet" => 2.0, "Phone" => 4.0,
                    "Monitor" => 1.5, "Accessories" => 1.0
                )[product]

                # Region-specific multipliers
                region_mult = Dict("North" => 1.2, "South" => 1.0, "East" => 1.3, "West" => 1.1)[region]

                sales = (base + trend) * product_mult * region_mult * (1 + 0.2 * randn(rng))
                quantity = round(Int, sales / (100 + 50 * randn(rng)))
                cost = sales * (0.6 + 0.1 * randn(rng))
                profit = sales - cost

                # Customer metrics
                customers = round(Int, quantity * (0.3 + 0.1 * randn(rng)))
                satisfaction = 3.5 + 1.0 * randn(rng)

                # Geographic coordinates
                lat = 35.0 + Dict("North" => 10, "South" => -10, "East" => 0, "West" => 0)[region] + randn(rng)
                lon = -95.0 + Dict("North" => 0, "South" => 0, "East" => 15, "West" => -15)[region] + randn(rng)

                # Random segment assignment
                segment = rand(rng, segments)

                push!(records, DataFrame(
                    date = date,
                    product = product,
                    region = region,
                    segment = segment,
                    sales = max(0, sales),
                    quantity = max(0, quantity),
                    cost = max(0, cost),
                    profit = profit,
                    customers = max(0, customers),
                    satisfaction = clamp(satisfaction, 1, 5),
                    latitude = lat,
                    longitude = lon,
                    month = month(date),
                    quarter = (month(date) - 1) ÷ 3 + 1,
                    day_of_year = dayofyear(date)
                ))
            end
        end
    end

    return vcat(records...)
end

dataset_code = CodeBlock(generate_comprehensive_data,
    notes=" This generates the sampel data used throughout these pages.")

df = dataset_code()

# ===== General Coding Patterns =====
coding_patterns = TextBlock("""
<h2>General Coding Patterns</h2>
<p>The arguments each chart type accepts are slightly different reflecting the nature of each plot.
However, there are some common elements found across many plot types:</p>

<h3>Filters</h3>
<p>Filters can be specified with either a Dict or a Vector:</p>
<ul>
    <li><strong>Vector of Symbols:</strong> <code>filters = [:region, :product]</code> creates multi-select dropdown filters
    with all unique values selected by default</li>
    <li><strong>Dict:</strong> <code>filters = Dict(:region => ["North", "South"], :product => nothing)</code> where each key
    is a column name and each value specifies the default selected values:
        <ul>
            <li>A single value: <code>:region => "North"</code></li>
            <li>A vector of values: <code>:region => ["North", "South"]</code></li>
            <li><code>nothing</code> for all values: <code>:product => nothing</code></li>
        </ul>
    </li>
</ul>

<h3>Color Columns</h3>
<p><code>color_cols</code> are the options that affect the grouping and color of objects in the chart.
For example, in a scatter plot, points can be colored by different categories. In a distribution plot,
separate distributions can be shown for different groups.</p>

<h3>Facet Columns</h3>
<p><code>facet_cols</code> specify which columns can be used for faceting (creating small multiples of the same plot).</p>
<ul>
    <li><strong>facet_cols:</strong> Defines which columns are available for faceting. Can be a single Symbol or Vector of Symbols.</li>
    <li><strong>default_facet_cols:</strong> Specifies which facet columns should be used by default:
        <ul>
            <li>If <code>nothing</code>, no faceting will appear initially (but users can enable it if <code>facet_cols</code> is provided)</li>
            <li>If specified, the chart will start with faceting enabled using those columns</li>
        </ul>
    </li>
</ul>

<h3>Value Columns</h3>
<p>Many chart types accept <code>value_cols</code> which specify the columns containing the data to visualize.
For plots that can display multiple value columns (like DistPlot or KernelDensity), you can provide a vector
of column names and use dropdown controls to switch between them.</p>

<h3>Interactive Controls</h3>
<p>Most chart types support interactive controls including:</p>
<ul>
    <li><strong>Multi-select dropdown filters:</strong> Filter data by selecting values from categorical or continuous variables</li>
    <li><strong>Column selectors:</strong> Switch between different value columns, grouping variables, or plot dimensions</li>
    <li><strong>Facet controls:</strong> Enable/disable faceting and choose facet variables</li>
    <li><strong>show_controls parameter:</strong> Set to <code>true</code> to display all available controls, or <code>false</code> to hide them</li>
</ul>
""")

# ===== Tabular Data and Text =====
tabular_section = TextBlock("<h2>1. Tabular Data and Text</h2>")

# PivotTable
pivot_intro = TextBlock("""
<h3>PivotTable</h3>
<p>PivotTables can do quite alot. Indeed many of the charttypes of this package would alternatively be doable just using a PivotTable so you might prefer doing that in some cases.</p>
<p> Now we have example data generated (from the above function) we will shoow this in a pivottable (and it will be used throughout the rest of the examples).</p>
""")

pivot_chart = PivotTable(:pivot, :sales_data,
    rows=[:product],
    cols=[:region],
    vals=:customers,
    aggregatorName = :Average,
    rendererName = :Heatmap,
    colour_map = Dict{Float64,String}([0.0, 50.0, 100.0, 150.0] .=>
                                      ["#ffffff", "#ccccff", "#99ccff", "#3366ff"]),
    extrapolate_colours = false,
    notes="Interactive pivot table - drag fields to explore different views")

# Table
table_intro = TextBlock("""
    <h3>Table - Data Table</h3>
    <p> This just displays your DataFrame in a nice way on the html page. There is a download as csv button at the bottom of it. You could also just use a PivotTable but this is lighterweight for cases where a PivotTable is overkill </p>
    """)

product_summary = combine(groupby(df, :product),
    :sales => sum => :total_sales,
    :quantity => sum => :total_quantity,
    :profit => sum => :total_profit)
sort!(product_summary, :total_sales, rev=true)

table_chart = Table(:table, product_summary,
    notes="Summary statistics by product category")

# CodeBlock
code_intro = TextBlock("<h3>CodeBlock - Display Code</h3> We can use a CodeBlock to show code snippets with syntax highlighting. We have correct Syntax highlighting for Julia, Python, R, JavaScript, Java, C, C++, SQL, pl/pgsql, Rust. For anything else it will all be black.")

code_chart = dataset_code

# LinkList
link_intro = TextBlock("<h3>LinkList - Navigation Links</h3> A LinkList shows you a list of links with optional descriptions. These are automatically generated if you make a Pages struct where there is a LinkList on the top page with links to the others. You can also make your own.")

linklist_chart = LinkList([
    ("Interactive Examples", "https://s-baumann.github.io/JSPlots.jl/dev/index.html", "Browse interactive examples"),
    ("Full Documentation", "https://s-baumann.github.io/JSPlots.jl/dev/api.html", "API reference"),
    ("GitHub Repository", "https://github.com/s-baumann/JSPlots.jl", "Source code")
], chart_title=:links)

# TextBlock
text_intro = TextBlock("<h3>TextBlock - Rich Text and HTML</h3><p>You can write whatever HTML you want and put it in a TextBlock which will put it in the resultant HTML.</p>")
textblock_example = TextBlock("""
<div style="background-color: #f0f0f0; padding: 15px; border-radius: 5px;">
    <p><strong>TextBlock</strong> allows you to add rich text, HTML, and annotations to your reports.</p>
    <p>You can include <em>formatting</em>, <strong>styled text</strong>, and even <code>inline code</code>.</p>
</div>
""")

# ===== 2D Plotting =====
plotting_2d_section = TextBlock("<h2>2. Two-Dimensional Plots</h2>")

# LineChart
line_intro = TextBlock("""<h3>LineChart</h3>
<p>A linechart. There are optional controls to change the variables on the x and or y axis. It is also possible to change the faceting, the grouping variable, the aggregation variable (if there are multiple y values per x value) as well as filters.</p>""")

daily_product = @linq df |> groupby( [:date, :product]) |> combine( :total_sales = sum(:sales))

line_chart = LineChart(:line, df, :sales_data,
    x_cols=[:date, :quarter],
    y_cols=[:sales, :quantity, :profit, :customers, :satisfaction],
    facet_cols=[:product, :region, :segment],
    notes="Time series of daily sales, faceted by product category")

# AreaChart
area_intro = TextBlock("<h3>AreaChart - Stacked Trends</h3>")

area_chart = AreaChart(:area, df, :sales_data,
    x_cols=[:date, :quarter],
    y_cols=[:sales, :quantity, :cost, :customers, :satisfaction],
    group_cols = [:product, :segment, :region],
    filters = Dict{Symbol,Any}(:product => unique(df.product), :segment => unique(df.segment), :region => unique(df.region)),
    facet_cols=[:region, :product, :segment],
    notes="Sales Data in an areachart")

# ScatterPlot
scatter_intro = TextBlock("<h3>ScatterPlot - Relationship Analysis</h3>")

scatter_chart = ScatterPlot(:scatter, df, :sales_data, [:customers, :sales, :quantity, :profit, :cost, :satisfaction];
    color_cols=[:product, :region, :segment, :month],
    facet_cols=[:region, :product, :segment],
    default_facet_cols=nothing,
    notes="Scatter plot showing relationship between customers and sales")


# Path
path_intro = TextBlock("<h3>Path - Trajectory Visualization</h3></p>We can use a Paths chart to show the temporal ordering of sales data. This is like a scatter plot but the points are joined in the order they occured.</p>")


path_chart = Path(:path, df, :sales_data;
    x_cols=[:cost, :quantity, :sales, :profit, :customers, :satisfaction],
    y_cols=[:profit, :sales, :quantity, :cost, :satisfaction, :customers],
    order_col=:date,
    color_cols=[:region, :product, :segment],
    filters = Dict{Symbol,Any}(:product => [:laptop]),
    facet_cols = [:region, :product, :segment],
    default_facet_cols = [:segment],
    notes="Path plot on sales data.")

# ===== Distributional Plots =====
distribution_section = TextBlock("<h2>3. Distributional Plots</h2>")

# DistPlot
dist_intro = TextBlock("<h3>DistPlot - Distribution Analysis</h3><p> This makes a historgram, box and whiskers and rugplot. So you can see differences in distribution for a variable between different groups of observations. Note at the bottom there is a slider for changing the number of bins in the histogram.</p>")

dist_chart = DistPlot(:dist, df, :sales_data,
    value_cols=[:profit, :sales, :cost, :quantity, :customers, :satisfaction],
    color_cols=[:region, :product, :segment],
    filters=[:region, :product, :segment, :date],
    notes="Multi-view distribution analysis of profit")

# KernelDensity
kde_intro = TextBlock("<h3>KernelDensity - Smooth Distribution</h3><p>This shows kernel density estimates for a variable seperated by groups in the observations. It also has faceting available (unlike DistPlot). There is a slider at the bottom for controlling the bandwidth of the kernel density estimate.</p>")

kde_chart = KernelDensity(:kde, df, :sales_data,
    value_cols=[:profit, :sales, :cost, :quantity, :customers, :satisfaction],
    color_cols=[:region, :product, :segment],
    filters=[:region, :product, :segment, :date],
    facet_cols=[:region, :product, :segment],
    default_facet_cols=[:segment],
    notes="Distribution of customer satisfaction ratings")

# PieChart
pie_intro = TextBlock("<h3>PieChart - Categorical Proportions</h3> This gives piecharts. Note that piecharts are generally pretty bad (google it to see more on this) but up to you if you like them. There is faceting available, filtering and you can change the grouping variable and the numeric variable being aggregated over to determine pie width.")

pie_chart = PieChart(:pie, df, :sales_data,
    label_cols=[:region, :product, :segment, :month, :quarter],
    value_cols=[:sales, :profit, :quantity, :cost, :customers, :satisfaction],
    notes="share by grouping")

# ===== 3D Plotting =====
plotting_3d_section = TextBlock("<h2>4. Three-Dimensional Plots</h2>")

# Scatter3D
scatter3d_intro = TextBlock("<h3>Scatter3D</h3> <p> This is a 3D scatter plot. You can rotate it and zoom in and out. There are options for showing PCA eigenvectors as well.</p>")

scatter3d_sample = df[1:200, :]

scatter3d_chart = Scatter3D(:scatter3d, scatter3d_sample, :sales_data,
    [:sales, :quantity, :profit, :cost, :customers, :satisfaction];
    color_cols = [:region, :product, :segment, :month, :quarter],
    facet_cols = [:region, :product, :segment, :month, :quarter],
    filters = Dict{Symbol, Any}(:cost => [10000.0]),
    default_facet_cols = nothing,
    title="3D Scatter Plot",
    notes="3D scatter with PCA eigenvectors")

# Surface3D
surface3d_intro = TextBlock("<h3>Surface3D - Function Surface</h3> <p> This is a 3D surface plot that allows you to display a few surfaces together. You can rotate it and zoom in and out. This example shows average sales over latitude and longitude.</p>")
# We are going to make some surfaces that we can plot with Surface3D. We will make a grid of latitudes and longitudes and then for each grouping variable we will compute average sales for nearby points to make a surface.
lat_range = range(minimum(df.latitude), maximum(df.latitude), length=20)
lon_range = range(minimum(df.longitude), maximum(df.longitude), length=20)
long_df = stack(df[:, [:date, :product, :region, :segment, :sales, :latitude, :longitude]],  Not([:date, :sales, :latitude, :longitude]); variable_name=:grouping_category, value_name=:grouping)

surface_data = DataFrame[]
for lat in lat_range
    for lon in lon_range
        for grp in unique(long_df.grouping)
            subframe = long_df[long_df.grouping .== grp, :]
            nearby = subframe[abs.(subframe.latitude .- lat) .< 5 .&& abs.(subframe.longitude .- lon) .< 10, :]
            avg_sales = isempty(nearby) ? 0.0 : mean(nearby.sales)
            push!(surface_data, DataFrame(latitude=lat, longitude=lon, average_sales=avg_sales, grouping=grp))
        end
    end
end
surface_df = vcat(surface_data...)
surface_df = leftjoin(surface_df, unique(long_df[:, [:grouping_category, :grouping]]), on=:grouping)


surface3d_chart = Surface3D(:surface3d, surface_df, :surface_df,
    x_col=:longitude,
    y_col=:latitude,
    z_col=:average_sales,
    group_col=:grouping,
    filters= Dict{Symbol, Any}(:grouping_category => ["product"]),
    notes="3D surface of sales by geography")

# ScatterSurface3D
scattersurface_intro = TextBlock("<h3>ScatterSurface3D - Scatter with Fitted Surface</h3><p> This is a 3D scatter plot with a fitted surface for each group of points. You can train the surface with differing bandwidth parameters and with the L1 or L2 norm (L2 is default). You can rotate it and zoom in and out.</p>")

scattersurface_chart = ScatterSurface3D(:scattersurface, df, :df,
    x_col=:customers,
    y_col=:quantity,
    z_col=:sales,
    group_cols= [:region, :product, :segment],
    facet_cols= [:region, :product, :segment],
    notes="3D scatter with L2-fitted surface")

# Picture
picture_intro = TextBlock("""
<h3>Picture</h3>
<p> There are two uses for picture. One is if you have a particular picture you want on the html. This could be anything.
The other use is if you want to save a static chart from another charting package into the html (VegaLite, Plots.jl and Makie are directly supported or if there is another charting library you are using you could save it first and then input it as a picture).
Below I will just include Tux the linux mascot picture but you can see more interesting examples on the relevent examples page.</p>""")

picture_chart = Picture(:tux_image, "examples/pictures/Linux2.jpeg", notes="Example image: Tux the Linux mascot")

# ===== Integration Charts =====
integration_section = TextBlock("""
<h2>5. Plots from Other Julia Packages</h2>
<p><strong>Picture</strong> and <strong>Slides</strong> allow you to embed plots from Plots.jl, Makie.jl, and VegaLite.jl.
See the <a href="picture_examples.html">Picture examples</a> and
<a href="slides_examples_embedded.html">Slides examples</a> for demonstrations.</p>
""")

# Conclusion
conclusion = TextBlock("""
<h2>Next Steps</h2>
<p>This tutorial showed one example of each chart type in JSPlots.jl. To learn more:</p>
<ul>
    <li>Click on chart type names in the documentation to see detailed examples</li>
    <li>Explore the <code>examples/</code> folder for source code</li>
    <li>Check the <a href="https://s-baumann.github.io/JSPlots.jl/dev/api.html">API documentation</a></li>
</ul>
""")

# ===== Theoretical Pages =====

# Page about creating multi-page reports
pages_theory = TextBlock("""
<h2>Creating Multi-Page Reports with JSPlotPage and Pages</h2>

<h3>Overview</h3>
<p>JSPlots.jl makes it easy to create multi-page HTML reports. You create individual pages using <code>JSPlotPage</code>,
then combine them into a multi-page report using <code>Pages</code>.</p>

<h3>Creating Individual Pages with JSPlotPage</h3>
<p>A <code>JSPlotPage</code> represents a single HTML page with charts, tables, and text content:</p>

<pre><code>page = JSPlotPage(
    Dict(:data_name => dataframe),  # Data dictionary
    [chart1, chart2, text_block],   # Content items
    tab_title = "My Page",          # Browser tab title
    page_header = "Analysis Report", # Page header
    dataformat = :parquet           # Data storage format
)</code></pre>

<h3>Combining Pages with the Pages Constructor</h3>
<p>The <code>Pages</code> constructor creates a multi-page report with automatic navigation:</p>

<pre><code># Easy constructor - automatically creates LinkList!
report = Pages(
    [coverpage_content],  # Items for the coverpage
    [page1, page2, page3], # Your JSPlotPage objects
    tab_title = "Report Home",
    page_header = "Business Report",
    dataformat = :parquet
)</code></pre>

<h3>Automatic LinkList Generation</h3>
<p><strong>Key Feature:</strong> The Pages constructor automatically generates a <code>LinkList</code> from your pages
and adds it to the coverpage!</p>

<ul>
    <li>Each page in the <code>[page1, page2, page3]</code> array becomes a link</li>
    <li>Link titles come from each page's <code>tab_title</code></li>
    <li>Link descriptions come from each page's <code>notes</code> field</li>
    <li>The LinkList is automatically appended to your coverpage content</li>
</ul>

<h3>Manual LinkList (Advanced)</h3>
<p>You can also create LinkLists manually for custom navigation:</p>

<pre><code>links = LinkList([
    ("Title 1", "page_1.html", "Description of page 1"),
    ("Title 2", "page_2.html", "Description of page 2")
])</code></pre>

<h3>Complete Example</h3>
<pre><code># Create individual pages
analysis_page = JSPlotPage(
    Dict(:sales => sales_df),
    [scatter_chart, line_chart],
    tab_title = "Sales Analysis",
    notes = "Detailed sales trends and patterns"
)

metrics_page = JSPlotPage(
    Dict(:kpis => kpi_df),
    [kde_chart, dist_chart],
    tab_title = "Key Metrics",
    notes = "Performance indicators and distributions"
)

# Create multi-page report with automatic LinkList
report = Pages(
    [TextBlock("&lt;h1&gt;Q4 Report&lt;/h1&gt;")],
    [analysis_page, metrics_page],
    tab_title = "Q4 2024 Report"
)

# Generate HTML
create_html(report, "my_report")
# Creates: my_report.html (coverpage with links)
#          page_1.html (Sales Analysis)
#          page_2.html (Key Metrics)</code></pre>

<h3>Benefits</h3>
<ul>
    <li><strong>Automatic Navigation:</strong> No need to manually create links between pages</li>
    <li><strong>Consistent Structure:</strong> All pages follow the same format</li>
    <li><strong>Easy Maintenance:</strong> Add/remove pages without updating navigation</li>
    <li><strong>Professional Output:</strong> Clean, navigable HTML reports</li>
</ul>

<h3>Opening Multi-Page Reports</h3>
<p>When you use external data formats (<code>:parquet</code>, <code>:csv_external</code>, <code>:json_external</code>),
JSPlots.jl automatically generates launcher scripts in the project directory:</p>

<ul>
    <li><strong>open.sh</strong> (Linux/Mac) - Starts a local web server and opens in browser</li>
    <li><strong>open.bat</strong> (Windows) - Opens with appropriate browser permissions</li>
    <li><strong>README.md</strong> - Detailed instructions</li>
</ul>

<p><strong>Why?</strong> Browsers block loading external files from <code>file://</code> URLs for security.
The launcher scripts solve this by either running a local web server or launching the browser
with flags to allow local file access.</p>

<p><strong>Tip:</strong> If you use embedded formats (<code>:csv_embedded</code> or <code>:json_embedded</code>),
you can open the HTML files directly in your browser without launcher scripts!</p>
""")

pages_theory_page = JSPlotPage(
    Dict{Symbol, DataFrame}(),
    [pages_theory],
    tab_title="Creating Multi-Page Reports",
    page_header = "How to Create Multi-Page Reports",
    notes = "Learn how to use JSPlotPage and Pages to create multi-page HTML reports with automatic navigation",
    dataformat = :csv_embedded
)

# Page about data formats
dataformat_theory = TextBlock("""
<h2>Data Storage Formats in JSPlots.jl</h2>

<h3>Overview</h3>
<p>JSPlots.jl supports multiple data storage formats for embedding data in HTML pages.
The format affects file size, loading speed, and browser compatibility.</p>

<h3>Available Formats</h3>

<h4>1. :parquet (Recommended)</h4>
<p><strong>Best for:</strong> Large datasets, multi-page reports, production use</p>
<ul>
    <li><strong>Compressed binary format</strong> - smallest file sizes (typically 5-10x smaller than CSV)</li>
    <li><strong>Fast loading</strong> - efficient decompression in browser</li>
    <li><strong>Modern browsers</strong> - requires JavaScript support</li>
    <li><strong>Column-oriented</strong> - excellent compression for tabular data</li>
</ul>
<pre><code>page = JSPlotPage(data_dict, charts, dataformat = :parquet)</code></pre>

<h4>2. :csv_embedded</h4>
<p><strong>Best for:</strong> Small datasets, maximum compatibility, debugging</p>
<ul>
    <li><strong>Text-based CSV format</strong> - human-readable in HTML source</li>
    <li><strong>Single file</strong> - data embedded directly in HTML</li>
    <li><strong>Compact format</strong> - smaller than JSON for tabular data</li>
    <li><strong>Universal compatibility</strong> - works everywhere</li>
    <li><strong>Easy debugging</strong> - can inspect data in HTML source</li>
    <li><strong>No deduplication</strong> - data embedded separately in each page</li>
</ul>
<pre><code>page = JSPlotPage(data_dict, charts, dataformat = :csv_embedded)</code></pre>

<h4>3. :csv_external</h4>
<p><strong>Best for:</strong> Sharing data files, version control, spreadsheet analysis</p>
<ul>
    <li><strong>Separate CSV files</strong> - one file per dataset in data/ subdirectory</li>
    <li><strong>Multiple files</strong> - HTML + CSV files</li>
    <li><strong>Enables deduplication</strong> - shared datasets only stored once</li>
    <li><strong>Data reusability</strong> - CSV files can be opened in Excel/spreadsheets</li>
    <li><strong>Better for git</strong> - separate data from HTML</li>
</ul>
<pre><code>page = JSPlotPage(data_dict, charts, dataformat = :csv_external)</code></pre>

<h4>4. :json_embedded</h4>
<p><strong>Best for:</strong> Small datasets, web developers, API-like structure</p>
<ul>
    <li><strong>JSON format</strong> - familiar to web developers</li>
    <li><strong>Single file</strong> - data embedded directly in HTML</li>
    <li><strong>Structured data</strong> - preserves data types (numbers, strings, booleans)</li>
    <li><strong>Larger than CSV</strong> - JSON is ~25% larger due to key names in each row</li>
    <li><strong>Fast browser parsing</strong> - native JSON.parse() is highly optimized</li>
    <li><strong>No deduplication</strong> - data embedded separately in each page</li>
</ul>
<pre><code>page = JSPlotPage(data_dict, charts, dataformat = :json_embedded)</code></pre>

<h4>5. :json_external</h4>
<p><strong>Best for:</strong> API consumption, web applications, data interchange</p>
<ul>
    <li><strong>Separate JSON files</strong> - one file per dataset in data/ subdirectory</li>
    <li><strong>Multiple files</strong> - HTML + JSON files</li>
    <li><strong>Enables deduplication</strong> - shared datasets only stored once</li>
    <li><strong>API-ready format</strong> - can be consumed by other web applications</li>
    <li><strong>Type preservation</strong> - maintains data types better than CSV</li>
    <li><strong>Web-friendly</strong> - easy to load from external servers</li>
</ul>
<pre><code>page = JSPlotPage(data_dict, charts, dataformat = :json_external)</code></pre>

<h3>Intelligent Data Deduplication</h3>
<p><strong>Key Efficiency Feature:</strong> JSPlots.jl automatically detects when the same dataset
is used multiple times and only includes it once!</p>

<p><strong>Important:</strong> Data deduplication only works with external formats
(<code>:parquet</code>, <code>:csv_external</code>, <code>:json_external</code>).
With embedded formats (<code>:csv_embedded</code>, <code>:json_embedded</code>),
data is embedded separately in each HTML page, so there's no deduplication benefit.</p>

<h4>How It Works</h4>
<p>When you create a multi-page report with <code>Pages</code>, datasets are identified by their
<code>Symbol</code> key in the data dictionary. <strong>The <code>Pages</code>-level dataformat setting
overrides any individual <code>JSPlotPage</code> dataformat settings.</strong></p>

<pre><code># Both pages use :sales_data
page1 = JSPlotPage(
    Dict(:sales_data => df),
    [chart1, chart2],
    dataformat = :csv_embedded  # This is ignored!
)

page2 = JSPlotPage(
    Dict(:sales_data => df),  # Same Symbol = reuses data!
    [chart3, chart4],
    dataformat = :json_embedded  # This is also ignored!
)

# Pages-level dataformat is what actually gets used
report = Pages(
    [intro],
    [page1, page2],
    dataformat = :parquet  # ← This overrides page-level settings!
)
# Result: One parquet file in data/sales_data.parquet shared by both pages</code></pre>

<h4>Benefits of Deduplication (External Formats Only)</h4>
<ul>
    <li><strong>Reduced File Size:</strong> Large datasets only stored once, not duplicated per page</li>
    <li><strong>Faster Loading:</strong> Less data to download and parse</li>
    <li><strong>Memory Efficiency:</strong> Browser loads dataset into memory once</li>
    <li><strong>Consistency:</strong> All pages use the exact same data</li>
</ul>

<h4>Example: Space Savings with External Formats</h4>
<pre><code># With embedded format - NO deduplication:
report = Pages([intro], [page1, page2, page3], dataformat = :csv_embedded)
# Page 1 HTML: 10 MB (with data embedded)
# Page 2 HTML: 10 MB (with data embedded again)
# Page 3 HTML: 10 MB (with data embedded again)
# Total: 30 MB

# With external format - YES deduplication:
report = Pages([intro], [page1, page2, page3], dataformat = :parquet)
# data/sales_data.parquet: 1 MB (stored once, shared by all pages)
# Page 1 HTML: 50 KB (no data, just loads from data/)
# Page 2 HTML: 50 KB (no data, just loads from data/)
# Page 3 HTML: 50 KB (no data, just loads from data/)
# Total: 1.15 MB  ← 96% size reduction!</code></pre>

<h3>Format Comparison Table</h3>
<table border="1" cellpadding="8" style="border-collapse: collapse; margin: 20px 0; width: 100%;">
    <tr style="background-color: #f0f0f0;">
        <th>Feature</th>
        <th>:parquet</th>
        <th>:csv_embedded</th>
        <th>:csv_external</th>
        <th>:json_embedded</th>
        <th>:json_external</th>
    </tr>
    <tr>
        <td><strong>File Size</strong></td>
        <td style="color: green;">Smallest (5-10x smaller)</td>
        <td style="color: orange;">Medium</td>
        <td style="color: orange;">Medium</td>
        <td style="color: red;">Large (~25% bigger than CSV)</td>
        <td style="color: red;">Large (~25% bigger than CSV)</td>
    </tr>
    <tr>
        <td><strong>Loading Speed</strong></td>
        <td style="color: green;">Fast</td>
        <td style="color: orange;">Moderate</td>
        <td style="color: orange;">Moderate</td>
        <td style="color: green;">Fast (native JSON.parse)</td>
        <td style="color: green;">Fast (native JSON.parse)</td>
    </tr>
    <tr>
        <td><strong>Compatibility</strong></td>
        <td style="color: orange;">Modern browsers</td>
        <td style="color: green;">Universal</td>
        <td style="color: green;">Universal</td>
        <td style="color: green;">Universal</td>
        <td style="color: green;">Universal</td>
    </tr>
    <tr>
        <td><strong>Deduplication</strong></td>
        <td style="color: green;">Yes (in Pages)</td>
        <td style="color: red;">No (embedded)</td>
        <td style="color: green;">Yes (in Pages)</td>
        <td style="color: red;">No (embedded)</td>
        <td style="color: green;">Yes (in Pages)</td>
    </tr>
    <tr>
        <td><strong>Type Preservation</strong></td>
        <td style="color: green;">Excellent</td>
        <td style="color: orange;">Limited (strings)</td>
        <td style="color: orange;">Limited (strings)</td>
        <td style="color: green;">Good</td>
        <td style="color: green;">Good</td>
    </tr>
    <tr>
        <td><strong>Human Readable</strong></td>
        <td>No (binary)</td>
        <td>Yes (in HTML)</td>
        <td>Yes (separate files)</td>
        <td>Yes (in HTML)</td>
        <td>Yes (separate files)</td>
    </tr>
    <tr>
        <td><strong>File Structure</strong></td>
        <td>Single HTML + data/</td>
        <td>Single HTML</td>
        <td>HTML + data/ folder</td>
        <td>Single HTML</td>
        <td>HTML + data/ folder</td>
    </tr>
    <tr>
        <td><strong>Best For</strong></td>
        <td>Production, large data</td>
        <td>Small data, debugging</td>
        <td>Spreadsheet analysis</td>
        <td>Web developers</td>
        <td>API/web apps</td>
    </tr>
</table>

<h3>Setting Format Globally vs Per-Page</h3>
<pre><code># Set format for entire report (RECOMMENDED)
report = Pages(
    [intro],
    [page1, page2],
    dataformat = :parquet  # Overrides any page-level settings
)

# Individual pages (only for single-page JSPlotPage, not Pages)
page1 = JSPlotPage(data_dict, charts, dataformat = :parquet)
create_html(page1, "standalone_page.html")</code></pre>

<p><strong>Note:</strong> When using <code>Pages</code>, the Pages-level <code>dataformat</code>
overrides any <code>dataformat</code> settings in individual <code>JSPlotPage</code> objects.</p>

<h3>Launcher Scripts for External Formats</h3>
<p>When using external formats (<code>:parquet</code>, <code>:csv_external</code>, <code>:json_external</code>),
JSPlots.jl automatically generates launcher scripts to help with browser security restrictions:</p>

<ul>
    <li><strong>open.sh</strong> - Shell script for Linux/Mac that launches a local web server</li>
    <li><strong>open.bat</strong> - Batch script for Windows that opens with appropriate permissions</li>
    <li><strong>README.md</strong> - Instructions for opening the HTML files</li>
</ul>

<p><strong>Why launcher scripts?</strong> Modern browsers block loading external files (data/, pictures/, etc.)
from <code>file://</code> URLs for security reasons. The launcher scripts either:</p>
<ul>
    <li>Start a local web server (on Linux/Mac via Python's http.server)</li>
    <li>Launch the browser with flags to allow local file access (on Windows)</li>
</ul>

<p>For embedded formats (<code>:csv_embedded</code>, <code>:json_embedded</code>), you can open
the HTML file directly in a browser since all data is embedded - no launcher scripts needed!</p>
""")

dataformat_theory_page = JSPlotPage(
    Dict{Symbol, DataFrame}(),
    [dataformat_theory],
    tab_title="Data Storage Formats",
    page_header = "Understanding Data Storage Formats",
    notes = "Learn about the different data formats available in JSPlots.jl and how data deduplication saves space",
    dataformat = :csv_embedded
)



# Collect all data
all_data = Dict{Symbol, DataFrame}(
    :sales_data => df,
    :product_summary => product_summary,
    :daily_product => daily_product,
    :surface_df => surface_df,
)

tabular_plot_page =  JSPlotPage(
    all_data,
    [tabular_section, dataset_intro, coding_patterns,
        code_intro, code_chart,
        pivot_intro, pivot_chart,
        table_intro, table_chart,
        link_intro, linklist_chart,
        text_intro, textblock_example],
    tab_title="Tabular and Text Data page",
    page_header = "Tabular and Text Data page",
    dataformat = :csv_embedded
)

two_d_plot_page =  JSPlotPage(
    all_data,
    [plotting_2d_section,
        line_intro, line_chart,
        area_intro, area_chart,
        scatter_intro, scatter_chart,
        path_intro, path_chart],
    tab_title="2D Chart page",
    page_header = "2D Chart page",
    dataformat = :csv_embedded
)

distributional_plot_page =  JSPlotPage(
    all_data,
    [distribution_section,
        dist_intro, dist_chart,
        kde_intro, kde_chart,
        pie_intro, pie_chart],
    tab_title="Distributional Chart page",
    page_header = "Distributional Chart page",
    dataformat = :csv_embedded
)

three_d_plot_page =  JSPlotPage(
    all_data,
    [plotting_3d_section,
        scatter3d_intro, scatter3d_chart,
        surface3d_intro, surface3d_chart,
        scattersurface_intro, scattersurface_chart],
    tab_title="3D Chart page",
    page_header = "3D Chart page",
    dataformat = :csv_embedded
)

images_page =  JSPlotPage(
    all_data,
    [picture_intro, picture_chart],
    tab_title="Images page",
    page_header = "Images page",
    dataformat = :csv_embedded
)


# Create final Pages object with all pages including the new theoretical ones
pagess = Pages(
    [intro],
    [tabular_plot_page,
        two_d_plot_page,
        distributional_plot_page,
        three_d_plot_page,
        images_page,
        pages_theory_page,
        dataformat_theory_page],
    tab_title="JSPlots - Overall Example",
    page_header = "JSPlots Overall Example",
    dataformat = :csv_embedded
)

# Generate HTML
create_html(pagess, "generated_html_examples/z_general_example.html")

println("\n" * "="^70)
println("Comprehensive Tutorial created successfully!")
println("="^70)
println("\nFile: generated_html_examples/z_general_example.html")
println("\nThis tutorial demonstrates all chart types in JSPlots.jl")
println("Open the HTML file in your browser to explore!")
println("="^70)
