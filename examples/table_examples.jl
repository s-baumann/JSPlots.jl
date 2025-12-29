using JSPlots, DataFrames, Dates, Statistics, StableRNGs

println("Creating Table examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(777)

# Get the path to the example image for later use
example_image_path = joinpath(@__DIR__, "pictures", "images.jpeg")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/table_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Table Examples</h1>
<p>This page demonstrates various Table features in JSPlots.</p>
<ul>
    <li><strong>Basic tables:</strong> Simple data display with CSV download</li>
    <li><strong>Calculated columns:</strong> Tables with computed metrics</li>
    <li><strong>Statistical summaries:</strong> Descriptive statistics</li>
    <li><strong>Special handling:</strong> Missing values and HTML escaping</li>
    <li><strong>Integration:</strong> Combining tables with charts and images</li>
</ul>
<p><em>Every table includes a 'Download as CSV' button for easy data export!</em></p>
""")

# Example 1: Basic Table
df1 = DataFrame(
    Product = ["Widget", "Gadget", "Gizmo", "Tool", "Device"],
    Price = [9.99, 14.99, 24.99, 19.99, 34.99],
    Stock = [100, 50, 25, 75, 15],
    Category = ["Tools", "Electronics", "Accessories", "Tools", "Electronics"]
)

table1 = Table(:basic_table, df1;
               notes="A simple table showing product inventory. Click the download button to export as CSV.")

# Example 2: Table with calculated columns
sales_df = DataFrame(
    Month = ["January", "February", "March", "April", "May", "June"],
    Revenue = [45000, 52000, 48000, 61000, 58000, 67000],
    Expenses = [30000, 32000, 29000, 35000, 33000, 38000],
    Units_Sold = [450, 520, 480, 610, 580, 670]
)

# Add calculated columns
sales_df[!, :Profit] = sales_df.Revenue .- sales_df.Expenses
sales_df[!, :Margin_Percent] = round.((sales_df.Profit ./ sales_df.Revenue) .* 100, digits=1)
sales_df[!, :Avg_Price] = round.(sales_df.Revenue ./ sales_df.Units_Sold, digits=2)

table2 = Table(:financial_table, sales_df;
               notes="Financial performance with calculated metrics (Profit, Margin %, Average Price)")

# Example 3: Table with summary statistics
# Generate sample data
data_values = vcat(
    randn(rng, 50) .* 10 .+ 75,  # Group A
    randn(rng, 50) .* 12 .+ 82   # Group B
)
data_groups = vcat(fill("Group A", 50), fill("Group B", 50))

# Calculate summary statistics
summary_df = DataFrame(
    Statistic = ["Count", "Mean", "Median", "Std Dev", "Min", "Max", "Q1", "Q3"],
    Group_A = [
        50,
        round(mean(data_values[1:50]), digits=2),
        round(median(data_values[1:50]), digits=2),
        round(std(data_values[1:50]), digits=2),
        round(minimum(data_values[1:50]), digits=2),
        round(maximum(data_values[1:50]), digits=2),
        round(quantile(data_values[1:50], 0.25), digits=2),
        round(quantile(data_values[1:50], 0.75), digits=2)
    ],
    Group_B = [
        50,
        round(mean(data_values[51:100]), digits=2),
        round(median(data_values[51:100]), digits=2),
        round(std(data_values[51:100]), digits=2),
        round(minimum(data_values[51:100]), digits=2),
        round(maximum(data_values[51:100]), digits=2),
        round(quantile(data_values[51:100], 0.25), digits=2),
        round(quantile(data_values[51:100], 0.75), digits=2)
    ]
)

table3 = Table(:statistics_table, summary_df;
               notes="Descriptive statistics comparing two groups")

# Example 4: Table with special characters and missing values
special_df = DataFrame(
    Name = ["Alice & Bob", "Charlie's Shop", missing, "D&D Store", "E-Corp"],
    Description = ["Tools & Hardware", "Books <Rare>", "Electronics", missing, "Software \"Pro\""],
    Price = [100.50, missing, 250.00, 75.25, 500.00],
    Rating = [4.5, 4.8, missing, 3.9, 4.2],
    Status = ["Active", "Active", "Pending", "Active", missing]
)

table4 = Table(:special_chars_table, special_df;
               notes="Table demonstrating HTML escaping and missing value handling")

# Example 5: Top performers table
top_performers = DataFrame(
    Rank = 1:5,
    Employee = ["Sarah Johnson", "Mike Chen", "Emma Williams", "David Brown", "Lisa Garcia"],
    Department = ["Sales", "Engineering", "Sales", "Marketing", "Engineering"],
    Score = [98, 96, 95, 94, 93]
)

# Department summary table
dept_summary = DataFrame(
    Department = ["Sales", "Engineering", "Marketing", "Operations"],
    Employees = [12, 25, 8, 15],
    Avg_Score = [87.3, 84.5, 79.2, 81.8],
    Budget = [500000, 1200000, 350000, 600000]
)

table_top = Table(:top_performers, top_performers;
                  notes="Top 5 performers this quarter")

table_dept = Table(:department_summary, dept_summary;
                   notes="Department-level summary statistics")

# Example 6: Table with interactive chart
# Create detailed sales data
detailed_sales = DataFrame(
    Date = Date(2024, 1, 1):Day(1):Date(2024, 6, 30),
)
detailed_sales[!, :Revenue] = rand(rng,5000:8000, nrow(detailed_sales))
detailed_sales[!, :Category] = rand(rng,["Online", "Retail", "Wholesale"], nrow(detailed_sales))

# Monthly summary for table
detailed_sales[!, :MonthNum] = Dates.month.(detailed_sales.Date)
monthly_summary = combine(
    groupby(detailed_sales, :MonthNum),
    :Revenue => sum => :Total_Revenue,
    :Revenue => mean => :Avg_Daily_Revenue,
    :Revenue => length => :Days
)
monthly_summary[!, :Month] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
select!(monthly_summary, :Month, :Days, :Total_Revenue, :Avg_Daily_Revenue)
monthly_summary[!, :Total_Revenue] = round.(monthly_summary.Total_Revenue, digits=0)
monthly_summary[!, :Avg_Daily_Revenue] = round.(monthly_summary.Avg_Daily_Revenue, digits=2)

# Example 7: Large table example
# Create a larger dataset
large_df = DataFrame(
    ID = 1:100,
    Customer = ["Customer_$i" for i in 1:100],
    Order_Date = [Date(2024, 1, 1) + Day(rand(rng,1:180)) for _ in 1:100],
    Product = rand(rng,["Product A", "Product B", "Product C", "Product D", "Product E"], 100),
    Quantity = rand(rng,1:50, 100),
    Unit_Price = rand(rng,[9.99, 14.99, 19.99, 24.99, 34.99], 100)
)
large_df[!, :Total] = large_df.Quantity .* large_df.Unit_Price
large_df[!, :Total] = round.(large_df.Total, digits=2)

table_large = Table(:large_orders, large_df;
                    notes="Large table with 100 rows - demonstrates scrolling and CSV download capability")

# Example 8: Pivot-style comparison table
comparison_df = DataFrame(
    Feature = ["Interactive", "Downloadable", "Data Embedded", "Multiple Formats", "Custom Styling"],
    PivotTable = ["✓", "✓", "✓", "✓", "✓"],
    Table = ["✗", "✓", "✓", "✗", "✓"],
    TextBlock = ["✗", "✗", "✗", "✗", "✓"]
)

table_comparison = Table(:feature_comparison, comparison_df;
                         notes="Comparison of different JSPlots types")

feature_text = TextBlock("""
<h2>JSPlots Type Comparison</h2>
<p>This table compares features across different plot types in JSPlots.</p>
<p>Use the <strong>Table</strong> type when you need:</p>
<ul>
    <li>Simple, static data display</li>
    <li>CSV download capability</li>
    <li>Clean, professional formatting</li>
    <li>No interactive features required</li>
</ul>
<p>Use <strong>PivotTable</strong> when you need interactive data exploration with drag-and-drop capabilities.</p>
""")


# Create single combined page with all tables
page = JSPlotPage(
    Dict{Symbol,DataFrame}(:detailed_sales => detailed_sales),
    [header, table1, table2, table3, table4, table_top, table_dept,
     table_large, feature_text, table_comparison],
    tab_title = "Table Examples"
)

create_html(page, "generated_html_examples/table_examples.html")

println("\n" * "="^60)
println("Table examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/table_examples.html")
println("\nThis page includes:")
println("  • Basic product inventory table")
println("  • Financial data with calculations")
println("  • Statistical summary")
println("  • HTML escaping and missing values")
println("  • Top performers and department summaries")
println("  • Table combined with interactive chart and image")
println("  • Large table with 100 rows")
println("  • Feature comparison")
println("\nTip: Every table includes a 'Download as CSV' button for easy data export!")
