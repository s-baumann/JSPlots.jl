using JSPlots, DataFrames, Dates

println("Creating Pages example with easy constructor...")

# Create sample data
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
df_sales = DataFrame(
    Date = dates,
    Revenue = cumsum(randn(length(dates)) .* 1000 .+ 50000),
    Region = rand(["North", "South", "East", "West"], length(dates)),
    Product = rand(["Product A", "Product B", "Product C"], length(dates))
)

df_metrics = DataFrame(
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

# Page 1: Revenue Analysis (with chart title containing spaces)
println("  Creating Page 1: Revenue Analysis...")
revenue_chart = LineChart(Symbol("Revenue Trend 2024"), df_sales, :sales_data;
    x_cols = [:Date],
    y_cols = [:Revenue],
    color_cols = [:Region],
    title = "Revenue Trends by Region",
    notes = "Track revenue performance across different regions"
)

revenue_text = TextBlock("""
<h2>Revenue Analysis</h2>
<p>This page shows revenue trends across regions. The chart title contains spaces to demonstrate
that the sanitization is working correctly!</p>
""")

page1 = JSPlotPage(
    Dict(:sales_data => df_sales),
    [revenue_text, revenue_chart],
    tab_title = "Revenue Analysis",
    page_header = "Financial Performance",
    notes = "Detailed breakdown of revenue streams by region"
)

# Page 2: Metrics Dashboard (with chart title containing spaces)
println("  Creating Page 2: Metrics Dashboard...")
metrics_chart = LineChart(Symbol("Business Metrics - Q1 Q2"), df_metrics, :metrics_data;
    x_cols = [:Month],
    y_cols = [:Score],
    color_cols = [:Metric],
    title = "Key Business Metrics",
    notes = "Tracking customer satisfaction and sales volume"
)

metrics_text = TextBlock("""
<h2>Business Metrics Dashboard</h2>
<p>This dashboard tracks critical business metrics throughout H1 2024. Note the chart title
also contains spaces and special characters (hyphens) to test sanitization.</p>
""")

page2 = JSPlotPage(
    Dict(:metrics_data => df_metrics),
    [metrics_text, metrics_chart],
    tab_title = "Metrics Dashboard",
    page_header = "Business Metrics",
    notes = "Key performance indicators for H1 2024"
)

# Create coverpage content (WITHOUT manually creating LinkList!)
# The easy constructor will automatically create the LinkList from the pages
coverpage_header = TextBlock("""
<h1>H1 2024 Business Report</h1>
<p>Welcome to the first half 2024 Business Performance Report.</p>

<h2>What's New in This Example</h2>
<p>This example demonstrates two powerful features:</p>
<ol>
    <li><strong>Easy Pages Constructor:</strong> You don't need to manually create a LinkList!
        Just provide your coverpage content and pages, and the LinkList is automatically generated.</li>
    <li><strong>Space-Safe Chart Titles:</strong> Chart titles can now contain spaces and special characters.
        They're automatically sanitized for use in JavaScript function names.</li>
</ol>

<h2>Report Sections</h2>
<p>Click on the links below to navigate through the report:</p>
""")

# Use the EASY constructor - just provide content and pages!
# The LinkList will be automatically created and appended
println("  Creating multi-page report with easy constructor...")
report = Pages(
    [coverpage_header],  # Just provide the coverpage content
    [page1, page2],      # Provide the pages
    tab_title = "H1 2024 Report",
    page_header = "Business Report - H1 2024",
    dataformat = :parquet
)

# Generate the HTML output
output_dir = "generated_html_examples"
if !isdir(output_dir)
    mkpath(output_dir)
end

create_html(report, joinpath(output_dir, "easy_report.html"))

println("\n" * "="^60)
println("Pages easy constructor example complete!")
println("="^60)
println("\nOutput location: $output_dir/easy_report/")
println("\nKey Features Demonstrated:")
println("  ✓ Easy constructor automatically creates LinkList")
println("  ✓ Chart titles with spaces work correctly")
println("  ✓ No manual link management required")
println("\nPages:")
println("  - easy_report.html (coverpage with auto-generated links)")
println("  - page_1.html (Revenue Analysis)")
println("  - page_2.html (Metrics Dashboard)")
println("\nOpen with: cd $output_dir/easy_report && ./open.sh (Linux/Mac)")
