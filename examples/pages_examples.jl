using JSPlots, DataFrames, Dates, StableRNGs

println("Creating Pages (multi-page) examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(555)

# ==============================================================================
# Example 1: Manual LinkList Construction
# ==============================================================================
println("\n=== Example 1: Manual LinkList Construction ===")

# Create sample data that will be shared across pages
dates = Date(2024, 1, 1):Day(1):Date(2024, 12, 31)
df_sales = DataFrame(
    Date = dates,
    Revenue = cumsum(randn(rng,length(dates)) .* 1000 .+ 50000),
    Costs = cumsum(randn(rng,length(dates)) .* 500 .+ 30000),
    Region = rand(rng,["North", "South", "East", "West"], length(dates)),
    Product = rand(rng,["Product A", "Product B", "Product C"], length(dates))
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
    color_cols = [:Region],
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

# Create the coverpage with a manual LinkList
# IMPORTANT: When manually creating LinkList, use sanitize_filename() to ensure
# the link URLs match the actual filenames that will be generated!
println("  Creating coverpage with manual navigation links...")
links = LinkList([
    ("Revenue Analysis", "$(sanitize_filename("Revenue Analysis")).html", "Financial performance and revenue trends across regions"),
    ("Metrics Dashboard", "$(sanitize_filename("Metrics Dashboard")).html", "Key business metrics including customer satisfaction and quality scores"),
    ("Regional Analysis", "$(sanitize_filename("Regional Analysis")).html", "Q4 2024 regional performance breakdown with distribution analysis")
])

coverpage_header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/pages_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
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

<h3>Example Type</h3>
<p><strong>Manual LinkList Construction:</strong> This example demonstrates manually creating a LinkList and adding it to the coverpage. This gives you full control over link text and descriptions.</p>
""")

coverpage1 = JSPlotPage(
    Dict{Symbol,DataFrame}(),  # No data needed on coverpage
    [coverpage_header, links],
    tab_title = "2024 Business Report",
    page_header = "Annual Business Report 2024",
    notes = "Navigate to different sections using the links below"
)

# Create the multi-page structure with shared data
println("  Creating multi-page report (manual LinkList)...")
report1 = Pages(
    coverpage1,
    [page1, page2, page3],
    dataformat = :parquet  # Override all pages to use parquet format
)

create_html(report1, joinpath("generated_html_examples", "annual_report.html"))

println("\n" * "="^60)
println("Manual LinkList example complete!")
println("="^60)
println("Output location: generated_html_examples/annual_report/")
println("  - annual_report.html (main/cover page)")
println("  - revenue_analysis.html (Revenue Analysis)")
println("  - metrics_dashboard.html (Metrics Dashboard)")
println("  - regional_analysis.html (Regional Analysis)")
println("  - data/ (shared Parquet files)")

# ==============================================================================
# Example 2: Easy Constructor with Auto-Generated LinkList
# ==============================================================================
println("\n=== Example 2: Easy Constructor (Auto-Generated LinkList) ===")

# Create simpler data for the second example
dates2 = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
df_sales2 = DataFrame(
    Date = dates2,
    Revenue = cumsum(randn(rng,length(dates2)) .* 1000 .+ 50000),
    Region = rand(rng,["North", "South", "East", "West"], length(dates2)),
    Product = rand(rng,["Product A", "Product B", "Product C"], length(dates2))
)

df_metrics2 = DataFrame(
    Month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun"], 2),
    Score = vcat(
        [85, 87, 89, 88, 90, 92],  # Customer Satisfaction
        [120, 135, 150, 145, 160, 175]  # Sales Volume
    ),
    Metric = vcat(
        repeat(["Customer Satisfaction"], 6),
        repeat(["Sales Volume"], 6)
    )
)

# Page A: Revenue Analysis
println("  Creating Page A: Revenue Analysis...")
revenue_chart2 = LineChart(:revenue_trend_h1, df_sales2, :sales_data2;
    x_cols = [:Date],
    y_cols = [:Revenue],
    color_cols = [:Region],
    title = "Revenue Trends by Region",
    notes = "Track revenue performance across different regions"
)

revenue_text2 = TextBlock("""
<h2>Revenue Analysis</h2>
<p>This page shows revenue trends across regions for the first half of 2024.</p>
""")

pageA = JSPlotPage(
    Dict(:sales_data2 => df_sales2),
    [revenue_text2, revenue_chart2],
    tab_title = "Revenue Analysis",
    page_header = "Financial Performance",
    notes = "Detailed breakdown of revenue streams by region"
)

# Page B: Metrics Dashboard
println("  Creating Page B: Metrics Dashboard...")
metrics_chart2 = LineChart(:metrics_h1, df_metrics2, :metrics_data2;
    x_cols = [:Month],
    y_cols = [:Score],
    color_cols = [:Metric],
    title = "Key Business Metrics",
    notes = "Tracking customer satisfaction and sales volume"
)

metrics_text2 = TextBlock("""
<h2>Business Metrics Dashboard</h2>
<p>This dashboard tracks critical business metrics throughout H1 2024, including customer satisfaction and sales volume.</p>
""")

pageB = JSPlotPage(
    Dict(:metrics_data2 => df_metrics2),
    [metrics_text2, metrics_chart2],
    tab_title = "Metrics Dashboard",
    page_header = "Business Metrics",
    notes = "Key performance indicators for H1 2024"
)

# Create coverpage content (WITHOUT manually creating LinkList!)
# The easy constructor will automatically create the LinkList from the pages
coverpage_header2 = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/pages_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>H1 2024 Business Report</h1>
<p>Welcome to the first half 2024 Business Performance Report.</p>

<h2>What's New in This Example</h2>
<p>This example demonstrates the <strong>Easy Pages Constructor</strong> feature. You don't need to manually create a LinkList! Just provide your coverpage content and pages, and the LinkList is automatically generated from the page metadata.</p>

<h2>Report Sections</h2>
<p>Click on the links below to navigate through the report:</p>
""")

# Use the EASY constructor - just provide content and pages!
# The LinkList will be automatically created and appended
println("  Creating multi-page report with easy constructor...")
report2 = Pages(
    [coverpage_header2],  # Just provide the coverpage content
    [pageA, pageB],      # Provide the pages
    tab_title = "H1 2024 Report",
    page_header = "Business Report - H1 2024",
    dataformat = :parquet
)

create_html(report2, joinpath("generated_html_examples", "easy_report.html"))

println("\n" * "="^60)
println("Easy constructor example complete!")
println("="^60)
println("Output location: generated_html_examples/easy_report/")
println("  - easy_report.html (coverpage with auto-generated links)")
println("  - revenue_analysis.html (Revenue Analysis)")
println("  - metrics_dashboard.html (Metrics Dashboard)")

# ==============================================================================
# Example 3: Dataset Selection with Parquet Format
# ==============================================================================
println("\n=== Example 3: Dataset Selection with Parquet Format ===")

# Define a struct with DataFrame fields (including Union{Missing, DataFrame})
struct ExampleFrame
    aa::DataFrame
    bb::Union{Missing, DataFrame}
end

# Create the struct with two DataFrames
struct_df_aa = DataFrame(
    Category = repeat(["Electronics", "Clothing", "Food", "Sports"], 3),
    Quarter = repeat(["Q1", "Q2", "Q3"], inner=4),
    Sales = rand(rng, 5000:20000, 12),
    Units = rand(rng, 100:500, 12)
)

struct_df_bb = DataFrame(
    Department = repeat(["HR", "Engineering", "Sales", "Marketing"], 3),
    Month = repeat(["Jan", "Feb", "Mar"], inner=4),
    Headcount = rand(rng, 10:100, 12),
    Budget = rand(rng, 50000:200000, 12)
)

example_struct = ExampleFrame(struct_df_aa, struct_df_bb)

# Create a third standalone DataFrame
standalone_df = DataFrame(
    Region = repeat(["North", "South", "East", "West"], 4),
    Product = repeat(["Widget", "Gadget", "Gizmo", "Thingamajig"], inner=4),
    Revenue = rand(rng, 10000:50000, 16),
    Profit = rand(rng, 1000:10000, 16)
)

# Create PivotTable with dataset selection dropdown
pivot_with_selection = PivotTable(:dataset_selector_parquet, [Symbol("struct_data.aa"), Symbol("struct_data.bb"), :standalone_data];
    rows = [:Category],
    aggregatorName = :Sum,
    rendererName = :Heatmap,
    notes = "Dataset selection with Parquet format - switch between datasets stored in subfolders"
)

dataset_text = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/pages_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Dataset Selection with Parquet Format</h1>
<p>This example demonstrates the <strong>dataset selection</strong> feature combined with <strong>Parquet data format</strong>.</p>

<h2>Key Features Demonstrated:</h2>
<ul>
    <li><strong>Struct with DataFrames:</strong> A struct <code>ExampleFrame</code> with fields <code>aa::DataFrame</code> and <code>bb::Union{Missing,DataFrame}</code></li>
    <li><strong>Automatic extraction:</strong> DataFrames are extracted with dot-prefixed names (<code>Symbol("struct_data.aa")</code>, <code>Symbol("struct_data.bb")</code>)</li>
    <li><strong>Subfolder storage:</strong> Struct DataFrames are stored in subfolders (e.g., <code>data/struct_data/aa.parquet</code>)</li>
    <li><strong>Dataset switching:</strong> Use the dropdown to switch between datasets - data is loaded on-demand</li>
</ul>

<h2>How Parquet Storage Works:</h2>
<p>When using <code>dataformat = :parquet</code>, DataFrames from structs are saved in subfolders:</p>
<ul>
    <li><code>data/struct_data/aa.parquet</code> - from example_struct.aa</li>
    <li><code>data/struct_data/bb.parquet</code> - from example_struct.bb</li>
    <li><code>data/standalone_data.parquet</code> - standalone DataFrame (no subfolder)</li>
</ul>
<p>This is efficient for large datasets as data is loaded only when selected.</p>
""")

println("  Creating dataset selection page...")
page_dataset = JSPlotPage(
    Dict{Symbol,Any}(
        :struct_data => example_struct,  # Struct - extracted as :struct_data_aa, :struct_data_bb
        :standalone_data => standalone_df
    ),
    [dataset_text, pivot_with_selection],
    tab_title = "Dataset Selection (Parquet)",
    page_header = "Dataset Selection with Parquet Format",
    dataformat = :parquet
)

create_html(page_dataset, joinpath("generated_html_examples", "dataset_selection_parquet.html"))

println("\n" * "="^60)
println("Dataset selection (Parquet) example complete!")
println("="^60)
println("Output location: generated_html_examples/dataset_selection_parquet/")
println("  - dataset_selection_parquet.html (main page)")
println("  - data/struct_data/aa.parquet")
println("  - data/struct_data/bb.parquet")
println("  - data/standalone_data.parquet")

println("\n" * "="^70)
println("Pages examples complete!")
println("="^70)
println("\nThree examples created:")
println("\n1. Manual LinkList Construction:")
println("   - generated_html_examples/annual_report/annual_report.html")
println("   - Full control over link descriptions")
println("   - 3 pages with detailed business metrics")
println("\n2. Easy Constructor:")
println("   - generated_html_examples/easy_report/easy_report.html")
println("   - Auto-generates LinkList from page metadata")
println("   - 2 pages with simpler H1 2024 business metrics")
println("\n3. Dataset Selection with Parquet:")
println("   - generated_html_examples/dataset_selection_parquet/dataset_selection_parquet.html")
println("   - Struct with DataFrames automatically extracted")
println("   - Dataset dropdown to switch between parquet files")
println("\nOpen with: cd generated_html_examples/annual_report && ./open.sh (Linux/Mac)")
println("       or: cd generated_html_examples/easy_report && ./open.sh (Linux/Mac)")
println("       or: cd generated_html_examples/dataset_selection_parquet && ./open.sh (Linux/Mac)")