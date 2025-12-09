using JSPlots, DataFrames, Dates

println("Creating Pages (multi-page) example...")

# Create sample data that will be shared across pages
dates = Date(2024, 1, 1):Day(1):Date(2024, 12, 31)
df_sales = DataFrame(
    Date = dates,
    Revenue = cumsum(randn(length(dates)) .* 1000 .+ 50000),
    Costs = cumsum(randn(length(dates)) .* 500 .+ 30000),
    Region = rand(["North", "South", "East", "West"], length(dates)),
    Product = rand(["Product A", "Product B", "Product C"], length(dates))
)

df_metrics = DataFrame(
    Month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 3),
    Metric = vcat(
        [85, 87, 89, 88, 90, 92, 91, 93, 95, 94, 96, 98],     # Customer Satisfaction
        [120, 135, 150, 145, 160, 175, 190, 185, 200, 210, 230, 250],  # Sales Volume
        [95, 96, 97, 96, 98, 97, 99, 98, 99, 100, 99, 100]    # Quality Score
    ),
    Category = vcat(
        repeat(["Customer Satisfaction"], 12),
        repeat(["Sales Volume"], 12),
        repeat(["Quality Score"], 12)
    )
)

# Page 1: Revenue Analysis
println("  Creating Page 1: Revenue Analysis...")
revenue_chart = LineChart(:revenue_trend, df_sales, :sales_data;
    x_cols = [:Date],
    y_cols = [:Revenue, :Costs],
    color_cols = [:Region],
    filters = Dict{Symbol,Any}(:Product => "Product A"),
    title = "Revenue and Costs by Region",
    notes = "Track revenue and costs across different regions"
)

revenue_text = TextBlock("""
<h2>Revenue Analysis</h2>
<p>This page shows revenue trends across regions and products. Use the filters to explore different product categories and the controls to switch between revenue and cost views.</p>
<h3>Key Insights:</h3>
<ul>
    <li>Revenue has grown steadily throughout 2024</li>
    <li>Regional variations show different seasonal patterns</li>
    <li>Product A dominates in most regions</li>
</ul>
""")

page1 = JSPlotPage(
    Dict(:sales_data => df_sales),
    [revenue_text, revenue_chart],
    tab_title = "Revenue Analysis",
    page_header = "Financial Performance - Revenue Analysis",
    notes = "Detailed breakdown of revenue streams"
)

# Page 2: Metrics Dashboard
println("  Creating Page 2: Metrics Dashboard...")
metrics_chart = LineChart(:metrics_trend, df_metrics, :metrics_data;
    x_cols = [:Month],
    y_cols = [:Metric],
    color_cols = [:Category],
    title = "Key Business Metrics - 2024",
    notes = "Tracking customer satisfaction, sales volume, and quality scores"
)

metrics_text = TextBlock("""
<h2>Business Metrics Dashboard</h2>
<p>This dashboard tracks three critical business metrics throughout the year:</p>
<ul>
    <li><strong>Customer Satisfaction:</strong> Scale of 0-100, target is >90</li>
    <li><strong>Sales Volume:</strong> Units sold per month</li>
    <li><strong>Quality Score:</strong> Product quality rating, target is >95</li>
</ul>
<p>All metrics show positive trends, with customer satisfaction and quality scores maintaining high levels consistently.</p>
""")

page2 = JSPlotPage(
    Dict(:metrics_data => df_metrics),
    [metrics_text, metrics_chart],
    tab_title = "Metrics Dashboard",
    page_header = "Business Metrics Dashboard",
    notes = "Key performance indicators"
)

# Page 3: Regional Breakdown
println("  Creating Page 3: Regional Breakdown...")
df_regional = df_sales[df_sales.Date .>= Date(2024, 10, 1), :]  # Last quarter

regional_kde = KernelDensity(:regional_distribution, df_regional, :sales_data;
    value_cols = [:Revenue],
    group_cols = [:Region],
    title = "Revenue Distribution by Region - Q4 2024",
    notes = "Kernel density plot showing revenue distribution patterns across regions"
)

regional_text = TextBlock("""
<h2>Regional Performance Analysis</h2>
<p>This page focuses on Q4 2024 performance across different regions. The kernel density plot reveals the distribution characteristics of each region's revenue.</p>
<h3>Regional Characteristics:</h3>
<ul>
    <li><strong>North:</strong> Stable, predictable revenue patterns</li>
    <li><strong>South:</strong> Higher variability but strong growth</li>
    <li><strong>East:</strong> Consistent mid-range performance</li>
    <li><strong>West:</strong> Emerging market with increasing potential</li>
</ul>
""")

page3 = JSPlotPage(
    Dict(:sales_data => df_regional),
    [regional_text, regional_kde],
    tab_title = "Regional Analysis",
    page_header = "Regional Performance Breakdown",
    notes = "Q4 2024 regional analysis"
)

# Create the coverpage with a LinkList
println("  Creating coverpage with navigation links...")
links = LinkList([
    ("Revenue Analysis", "page_1.html", "Financial performance and revenue trends across regions"),
    ("Metrics Dashboard", "page_2.html", "Key business metrics including customer satisfaction and quality scores"),
    ("Regional Analysis", "page_3.html", "Q4 2024 regional performance breakdown with distribution analysis")
])

coverpage_header = TextBlock("""
<h1>Annual Business Report 2024</h1>
<p>Welcome to the 2024 Business Performance Report. This multi-page report provides comprehensive insights into our company's performance across multiple dimensions.</p>

<h2>Report Structure</h2>
<p>This report is organized into three main sections:</p>
<ol>
    <li><strong>Revenue Analysis:</strong> Detailed financial performance tracking</li>
    <li><strong>Metrics Dashboard:</strong> Key performance indicators and trends</li>
    <li><strong>Regional Analysis:</strong> Geographic performance breakdown</li>
</ol>

<p>Use the links below to navigate to each section. All pages share the same data sources, loaded efficiently for fast browsing.</p>
""")

coverpage = JSPlotPage(
    Dict{Symbol,DataFrame}(),  # No data needed on coverpage
    [coverpage_header, links],
    tab_title = "2024 Business Report",
    page_header = "Annual Business Report 2024",
    notes = "Navigate to different sections using the links below"
)

# Create the multi-page structure with shared data
println("  Creating multi-page report...")
report = Pages(
    coverpage,
    [page1, page2, page3],
    dataformat = :parquet  # Override all pages to use parquet format
)

# Generate the HTML output
output_dir = "generated_html_examples"
if !isdir(output_dir)
    mkpath(output_dir)
end

create_html(report, joinpath(output_dir, "annual_report.html"))

println("\nPages example complete!")
println("Output location: $output_dir/annual_report/")
println("  Structure (flat, all files at same level):")
println("    - annual_report.html (main/cover page)")
println("    - page_1.html (Revenue Analysis)")
println("    - page_2.html (Metrics Dashboard)")
println("    - page_3.html (Regional Analysis)")
println("    - data/ (shared Parquet files)")
println("    - open.sh, open.bat, README.md")
println("\nOpen with: cd $output_dir/annual_report && ./open.sh (Linux/Mac) or open.bat (Windows)")
