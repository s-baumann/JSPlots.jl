using JSPlots, DataFrames, Dates, StableRNGs, Statistics

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
<p> The code that generates this dataset will be shown below as an example for the CodeBlock type in JSPlots.jl.</p>

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
    notes="Generates a comprehensive business dataset with 7,300 records spanning multiple dimensions")

df = dataset_code()

# Show the generated data
data_preview = TextBlock("""
<h3>Generated Dataset Preview</h3>
<p>The dataset contains $(nrow(df)) records with $(ncol(df)) variables.
Now let's explore this data using all available chart types in JSPlots.jl.</p>
""")

# ===== Tabular Data and Text =====
tabular_section = TextBlock("<h2>1. Tabular Data and Text</h2>")

# PivotTable
pivot_intro = TextBlock("""
<h3>PivotTable</h3>
<p>PivotTables can do quite alot. Indeed many of the charttypes of this package would alternatively be doable just using a PivotTable so you might prefer doing that in some cases.</p>
""")

pivot_chart = PivotTable(:pivot, :sales_data,
    rows=[:product],
    cols=[:region],
    vals=:sales,
    aggregatorName = :Count,
    rendererName = :Heatmap,
    colour_map = Dict{Float64,String}([0.0, 50.0, 100.0, 150.0] .=>
                                      ["#f7fbff", "#9ecae1", "#4292c6", "#08519c"]),
    notes="Interactive pivot table - drag fields to explore different views")

# Table
table_intro = TextBlock("<h3>Table - Data Table</h3><p> This just displays your DataFrame in a nice way on the html page. There is a download as csv button at the bottom of it. You could also just use a PivotTable but this is lighterweight for cases where a PivotTable is overkill </p>")

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
line_intro = TextBlock("<h3>LineChart - Time Series Trends</h3>")

daily_product = combine(groupby(df, [:date, :product]), :sales => sum => :total_sales)

line_chart = LineChart(:line, daily_product, :sales_data,
    x_cols=[:date],
    y_cols=[:total_sales],
    facet_cols=[:product],
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
    group_cols=[:region, :product, :segment],
    filter_cols=[:region, :product, :segment, :date],
    notes="Multi-view distribution analysis of profit")

# KernelDensity
kde_intro = TextBlock("<h3>KernelDensity - Smooth Distribution</h3><p>This shows kernel density estimates for a variable seperated by groups in the observations. It also has faceting available (unlike DistPlot). There is a slider at the bottom for controlling the bandwidth of the kernel density estimate.</p>")

kde_chart = KernelDensity(:kde, df, :sales_data,
    value_cols=[:profit, :sales, :cost, :quantity, :customers, :satisfaction],
    group_cols=[:region, :product, :segment],
    filter_cols=[:region, :product, :segment, :date],
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

# ScatterSurface3D
picture_intro = TextBlock("""
<h3>Picture</h3>
<p> There are two uses for picture. One is if you have a particular picture you want on the html. This could be anything.
The other use is if you want to save a static chart from another charting package into the html (VegaLite, Plots.jl and Makie are directly supported or if there is another charting library you are using you could save it first and then input it as a picture).
Below I will just include Tux the linux mascot picture but you can see more interesting examples on the relevent examples page.</p>""")

picpic = Picture

scattersurface_chart = ScatterSurface3D(:scattersurface, df, :df,
    x_col=:customers,
    y_col=:quantity,
    z_col=:sales,
    group_cols= [:region, :product, :segment],
    facet_cols= [:region, :product, :segment],
    notes="3D scatter with L2-fitted surface")

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

# Collect all data
all_data = Dict{Symbol, DataFrame}(
    :sales_data => df,
    :product_summary => product_summary,
    :daily_product => daily_product,
    :surface_df => surface_df,
)

# Collect all charts
all_charts = [
    intro,
    dataset_intro, data_preview,
    tabular_section,
    pivot_intro, pivot_chart,
    table_intro, table_chart,
    code_intro, code_chart,
    link_intro, linklist_chart,
    text_intro, textblock_example,
    plotting_2d_section,
    line_intro, line_chart,
    area_intro, area_chart,
    scatter_intro, scatter_chart,
    path_intro, path_chart,
    distribution_section,
    dist_intro, dist_chart,
    kde_intro, kde_chart,
    pie_intro, pie_chart,
    plotting_3d_section,
    scatter3d_intro, scatter3d_chart,
    surface3d_intro, surface3d_chart,
    scattersurface_intro, scattersurface_chart,
    integration_section,
    conclusion
]

# Create the page
page = JSPlotPage(
    all_data,
    all_charts,
    tab_title="JSPlots.jl Comprehensive Tutorial"
)

# Generate HTML
create_html(page, "generated_html_examples/z_general_example.html")

println("\n" * "="^70)
println("Comprehensive Tutorial created successfully!")
println("="^70)
println("\nFile: generated_html_examples/z_general_example.html")
println("\nThis tutorial demonstrates all chart types in JSPlots.jl")
println("Open the HTML file in your browser to explore!")
println("="^70)
