using JSPlots, DataFrames, Dates, StableRNGs

println("Creating AreaChart examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(789)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/areachart_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>AreaChart Examples</h1>
<p>This page demonstrates the key features of AreaChart plots in JSPlots.</p>
<ul>
    <li><strong>Continuous areas:</strong> Smooth filled areas for continuous x values (like dates)</li>
    <li><strong>Discrete areas:</strong> Bar-style areas for categorical x values</li>
    <li><strong>Stack modes:</strong> Unstack (overlapping), stack (cumulative), normalized stack (percentage), and dodge (side-by-side bars)</li>
    <li><strong>Grouping:</strong> Multiple series with automatic color assignment and legend</li>
    <li><strong>Interactive filters:</strong> Dropdown menus to filter data dynamically</li>
    <li><strong>Dynamic controls:</strong> Change X-axis, grouping, stacking, and faceting on the fly</li>
    <li><strong>Faceting:</strong> Facet wrap (1 variable) and facet grid (2 variables)</li>
</ul>
""")

# Example 1: Continuous Area Chart with Dates (Stacked)
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
df1 = DataFrame()
regions = ["North", "South", "East", "West"]
for region in regions
    for date in dates
        push!(df1, (
            Date = date,
            Sales = abs(10000 + randn(rng) * 2000) + (Dates.dayofyear(date) * 50),
            Region = region
        ))
    end
end

chart1 = AreaChart(:stacked_area, df1, :sales_by_region;
    x_cols = [:Date],
    y_cols = [:Sales],
    color_cols = [:Region],
    stack_mode = "stack",
    title = "Example 1: Regional Sales Over Time (Stacked Area Chart)",
    notes = "Continuous time series with dates on x-axis. Stacked areas show cumulative sales across regions."
)

# Example 2: Continuous Unstacked Areas with Transparency
df2 = DataFrame()
products = ["Product A", "Product B", "Product C"]
time_points = 0:0.5:20  # Continuous numeric time
for product in products
    for t in time_points
        push!(df2, (
            Time = t,
            Value = 50 + 20 * sin(t + hash(product) * 0.01) + randn(rng) * 5,
            Product = product
        ))
    end
end

chart2 = AreaChart(:unstacked_area, df2, :product_values;
    x_cols = [:Time],
    y_cols = [:Value],
    color_cols = [:Product],
    stack_mode = "unstack",
    fill_opacity = 0.4,
    title = "Example 2: Product Values - Continuous Unstack",
    notes = "Continuous x-axis (numeric). Overlapping areas with transparency allow comparison of individual trends."
)

# Example 3: Normalized Stacking (Percentage) - Continuous
df3 = DataFrame()
categories = ["Category A", "Category B", "Category C", "Category D"]
months = 1:12
for category in categories
    for month in months
        push!(df3, (
            Month = month,
            MarketShare = abs(20 + randn(rng) * 5),
            Category = category
        ))
    end
end

chart3 = AreaChart(:normalized_area, df3, :market_share;
    x_cols = [:Month],
    y_cols = [:MarketShare],
    color_cols = [:Category],
    stack_mode = "normalised_stack",
    title = "Example 3: Market Share Distribution (Normalized Stack)",
    notes = "Continuous numeric x-axis. Normalized stacking shows relative proportions - total always reaches 100%."
)

# Example 4: Discrete Area Chart (Bar-style with Categorical X)
df4 = DataFrame()
departments = ["Engineering", "Sales", "Marketing", "Operations", "HR"]
teams = ["Team A", "Team B", "Team C"]
for dept in departments
    for team in teams
        push!(df4, (
            Department = dept,
            Headcount = rand(rng, 5:25),
            Team = team
        ))
    end
end

chart4 = AreaChart(:discrete_area, df4, :headcount_data;
    x_cols = [:Department],
    y_cols = [:Headcount],
    color_cols = [:Team],
    stack_mode = "stack",
    title = "Example 4: Headcount by Department (Discrete/Stacked Bars)",
    notes = "Categorical x-axis. When x values are discrete, areas automatically become stacked bars."
)

# Example 5: Time Series with Filters
df5 = DataFrame()
years = [2022, 2023, 2024]
channels = ["Online", "Retail", "Wholesale"]
regions_filter = ["North", "South"]
dates5 = Date(2024, 1, 1):Week(1):Date(2024, 12, 31)

for year in years
    for channel in channels
        for region in regions_filter
            for date in dates5
                push!(df5, (
                    Date = date,
                    Revenue = abs(100000 + randn(rng) * 20000 + Dates.week(date) * 1000),
                    Channel = channel,
                    Region = region,
                    Year = year
                ))
            end
        end
    end
end

chart5 = AreaChart(:filtered_area, df5, :channel_revenue;
    x_cols = [:Date],
    y_cols = [:Revenue],
    color_cols = [:Channel],
    filters = Dict{Symbol,Any}(:Year => 2024, :Region => "North"),
    stack_mode = "stack",
    title = "Example 5: Revenue by Channel with Filters",
    notes = "Continuous date axis with interactive filters. Select different years and regions to update the view."
)

# Example 6: Facet Wrap (1 facet variable) - Continuous
df6 = DataFrame()
metrics = ["Metric A", "Metric B", "Metric C", "Metric D"]
sources = ["Source 1", "Source 2", "Source 3"]
weeks = 1:12

for metric in metrics
    for source in sources
        for week in weeks
            push!(df6, (
                Week = week,
                Value = abs(100 + randn(rng) * 20 + week * 3),
                Metric = metric,
                Source = source
            ))
        end
    end
end

chart6 = AreaChart(:facet_wrap_area, df6, :metrics_data;
    x_cols = [:Week],
    y_cols = [:Value],
    color_cols = [:Source],
    facet_cols = [:Metric],
    default_facet_cols = :Metric,
    stack_mode = "stack",
    title = "Example 6: Metrics by Source (Facet Wrap)",
    notes = "Continuous x-axis with faceting. Each facet shows one metric with stacked sources."
)

# Example 7: Facet Grid (2 facet variables) - Continuous
df7 = DataFrame()
products_grid = ["Product X", "Product Y"]
regions_grid = ["East", "West"]
segments = ["Segment 1", "Segment 2"]
months7 = 1:6

for product in products_grid
    for region in regions_grid
        for segment in segments
            for month in months7
                push!(df7, (
                    Month = month,
                    Sales = abs(50000 + randn(rng) * 10000 + month * 2000),
                    Product = product,
                    Region = region,
                    Segment = segment
                ))
            end
        end
    end
end

chart7 = AreaChart(:facet_grid_area, df7, :grid_sales;
    x_cols = [:Month],
    y_cols = [:Sales],
    color_cols = [:Segment],
    facet_cols = [:Product, :Region],
    default_facet_cols = [:Product, :Region],
    stack_mode = "stack",
    title = "Example 7: Sales by Product and Region (Facet Grid)",
    notes = "Continuous x-axis with 2D facet grid. Products in rows, Regions in columns."
)

# Example 8: Dynamic Controls - Multiple Grouping Options
df8 = DataFrame()
industries = ["Tech", "Finance", "Healthcare"]
company_sizes = ["Small", "Medium", "Large"]
quarters = 1:4

for industry in industries
    for size in company_sizes
        for quarter in quarters
            push!(df8, (
                Quarter = quarter,
                Revenue = abs(100 + randn(rng) * 20),
                Profit = abs(20 + randn(rng) * 5),
                Growth = abs(5 + randn(rng) * 3),
                Industry = industry,
                CompanySize = size
            ))
        end
    end
end

chart8 = AreaChart(:dynamic_grouping, df8, :business_metrics;
    x_cols = [:Quarter],
    y_cols = [:Revenue, :Profit, :Growth],
    color_cols = [:Industry, :CompanySize],
    facet_cols = [:Industry, :CompanySize],
    stack_mode = "stack",
    title = "Example 8: Business Metrics with Dynamic Controls",
    notes = "Continuous x-axis. Use dropdowns to dynamically change: Y metric, grouping variable, stack mode, and faceting."
)

# Example 9: Comparing All Three Stack Modes Side by Side
df9 = DataFrame()
categories_compare = ["Cat 1", "Cat 2", "Cat 3"]
time_compare = 1:20

for category in categories_compare
    for time in time_compare
        push!(df9, (
            Time = time,
            Value = abs(10 + randn(rng) * 3 + time * 0.5),
            Category = category
        ))
    end
end

comparison_header = TextBlock("""
<h2>Stack Mode Comparison</h2>
<p>The following three charts use the same data but different stack modes to illustrate their differences:</p>
""")

chart9a = AreaChart(:unstack_mode, df9, :compare_data;
    x_cols = [:Time],
    y_cols = [:Value],
    color_cols = [:Category],
    stack_mode = "unstack",
    fill_opacity = 0.5,
    title = "Stack Mode: UNSTACK",
    notes = "Areas overlap with transparency - see individual trends clearly"
)

chart9b = AreaChart(:stack_mode, df9, :compare_data;
    x_cols = [:Time],
    y_cols = [:Value],
    color_cols = [:Category],
    stack_mode = "stack",
    title = "Stack Mode: STACK",
    notes = "Areas are stacked - shows cumulative total and individual contributions"
)

chart9c = AreaChart(:normalized_mode, df9, :compare_data;
    x_cols = [:Time],
    y_cols = [:Value],
    color_cols = [:Category],
    stack_mode = "normalised_stack",
    title = "Stack Mode: NORMALIZED STACK",
    notes = "Areas are stacked and normalized to 100% - shows relative proportions over time"
)

# Example 10: Dynamic X-Axis Selection
df10 = DataFrame()
quarters10 = 1:12
for region in ["North", "South", "East"]
    for product in ["Widget", "Gadget", "Gizmo"]
        for quarter in quarters10
            push!(df10, (
                Quarter = quarter,
                Month = (quarter - 1) * 3 + 1,  # Map quarters to months
                Week = (quarter - 1) * 13 + 1,   # Map quarters to weeks
                Revenue = abs(50000 + randn(rng) * 10000 + quarter * 2000),
                Units = abs(500 + randn(rng) * 100 + quarter * 20),
                Region = region,
                Product = product
            ))
        end
    end
end

dynamic_x_header = TextBlock("""
<h2>Dynamic X-Axis Selection</h2>
<p>This example demonstrates how to dynamically change the X-axis dimension from within the HTML page.</p>
<p>Try switching between Quarter, Month, and Week views using the dropdown control!</p>
""")

chart10 = AreaChart(:dynamic_x_axis, df10, :sales_data_x;
    x_cols = [:Quarter, :Month, :Week],
    y_cols = [:Revenue, :Units],
    color_cols = [:Region],
    stack_mode = "stack",
    title = "Example 10: Sales with Dynamic X-Axis Selection",
    notes = "Use the X-Axis dropdown to switch between different time granularities (Quarter/Month/Week). Also switch between Revenue and Units on Y-axis."
)

# Example 11: Dodge Mode (Grouped Bars) with Discrete X
df11 = DataFrame()
products_dodge = ["Product A", "Product B", "Product C"]
stores = ["Store 1", "Store 2", "Store 3", "Store 4", "Store 5"]

for product in products_dodge
    for store in stores
        push!(df11, (
            Store = store,
            Sales = abs(10000 + randn(rng) * 2000),
            Product = product
        ))
    end
end

dodge_header = TextBlock("""
<h2>Dodge Mode (Grouped Bars)</h2>
<p>Dodge mode places bars side-by-side for each x value, making it easy to compare groups directly.</p>
<p>This mode only works with discrete (categorical) x values. For continuous x values, it falls back to unstack mode.</p>
""")

chart11 = AreaChart(:dodge_mode, df11, :sales_by_store;
    x_cols = [:Store],
    y_cols = [:Sales],
    color_cols = [:Product],
    stack_mode = "dodge",
    title = "Example 11: Sales by Store (Dodge Mode)",
    notes = "Dodge mode with discrete x-axis. Bars for each product are placed side-by-side within each store for easy comparison."
)

# Example 12: Comparing Dodge vs Stack Mode
df12 = DataFrame()
categories_comparison = ["Category A", "Category B", "Category C", "Category D"]
segments_comparison = ["Segment 1", "Segment 2", "Segment 3"]

for category in categories_comparison
    for segment in segments_comparison
        push!(df12, (
            Category = category,
            Value = abs(50 + randn(rng) * 10),
            Segment = segment
        ))
    end
end

dodge_comparison_header = TextBlock("""
<h2>Dodge vs Stack Comparison</h2>
<p>The following two charts show the same data using dodge and stack modes:</p>
""")

chart12a = AreaChart(:dodge_comparison, df12, :comparison_data;
    x_cols = [:Category],
    y_cols = [:Value],
    color_cols = [:Segment],
    stack_mode = "dodge",
    title = "Dodge Mode - Side-by-Side Comparison",
    notes = "Bars are placed next to each other, making it easy to compare segments within each category."
)

chart12b = AreaChart(:stack_comparison, df12, :comparison_data;
    x_cols = [:Category],
    y_cols = [:Value],
    color_cols = [:Segment],
    stack_mode = "stack",
    title = "Stack Mode - Cumulative View",
    notes = "Bars are stacked, showing the total value and how each segment contributes to it."
)

# Example 13: Using a Struct as Data Source
# Demonstrates passing a struct containing DataFrames and referencing fields via dot notation

struct RegionalSalesData
    monthly_sales::DataFrame
    quarterly_summary::DataFrame
end

# Create monthly sales data
monthly_df = DataFrame()
regions_struct = ["North", "South", "East", "West"]
for region in regions_struct
    for month in 1:12
        push!(monthly_df, (
            Month = month,
            Sales = abs(50000 + randn(rng) * 10000 + month * 2000),
            Units = abs(500 + randn(rng) * 100 + month * 20),
            Region = region
        ))
    end
end

# Create quarterly summary
quarterly_df = DataFrame(
    Quarter = repeat(1:4, 4),
    Region = repeat(regions_struct, inner=4),
    TotalSales = abs.(200000 .+ randn(rng, 16) .* 20000)
)

# Create the struct instance
regional_data = RegionalSalesData(monthly_df, quarterly_df)

struct_intro = TextBlock("""
<h2>Struct Data Source Example</h2>
<p>This area chart uses data from a struct containing multiple DataFrames.
The <code>RegionalSalesData</code> struct holds both monthly_sales and quarterly_summary.
Charts reference the monthly sales using <code>Symbol("regional.monthly_sales")</code>.</p>
""")

chart13 = AreaChart(:struct_area, regional_data.monthly_sales, Symbol("regional.monthly_sales");
    x_cols = [:Month],
    y_cols = [:Sales, :Units],
    color_cols = [:Region],
    stack_mode = "stack",
    title = "Example 13: Regional Sales from Struct Data Source",
    notes = "This chart references a DataFrame field within a struct. The RegionalSalesData struct " *
           "contains monthly_sales and quarterly_summary DataFrames."
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Automatic discrete/continuous detection:</strong> Continuous x values (dates, numeric) create smooth areas; discrete x values (categories) create stacked bars</li>
    <li><strong>Four stack modes:</strong>
        <ul>
            <li><em>Unstack:</em> Overlapping areas with transparency - best for comparing trends</li>
            <li><em>Stack:</em> Cumulative areas - best for showing total and parts</li>
            <li><em>Normalized stack:</em> Percentage areas - best for showing proportions</li>
            <li><em>Dodge:</em> Side-by-side bars (discrete x only) - best for direct comparison between groups</li>
        </ul>
    </li>
    <li><strong>Dynamic X-axis selection:</strong> Switch between different X-axis dimensions (e.g., Quarter/Month/Week) from dropdown</li>
    <li><strong>Dynamic grouping:</strong> Choose which variable to group/color by from dropdown</li>
    <li><strong>Interactive filters:</strong> Filter data dynamically with dropdown menus</li>
    <li><strong>Faceting:</strong> Create small multiples with 1 or 2 faceting variables</li>
    <li><strong>Customization:</strong> Control opacity, titles, and stack modes</li>
    <li><strong>Date support:</strong> Automatic formatting and proper handling of date-based time series</li>
</ul>
<p><strong>Tip:</strong> Hover over areas to see detailed values. Use the dropdown controls to explore different views of your data!</p>
""")

# Create single combined page
# Note: regional_data struct is passed directly - JSPlotPage will extract its DataFrame fields
page = JSPlotPage(
    Dict{Symbol,Any}(
        :sales_by_region => df1,
        :product_values => df2,
        :market_share => df3,
        :headcount_data => df4,
        :channel_revenue => df5,
        :metrics_data => df6,
        :grid_sales => df7,
        :business_metrics => df8,
        :compare_data => df9,
        :sales_data_x => df10,
        :sales_by_store => df11,
        :comparison_data => df12,
        :regional => regional_data  # Struct with monthly_sales and quarterly_summary
    ),
    [header, chart1, chart2, chart3, chart4, chart5, chart6, chart7, chart8,
     comparison_header, chart9a, chart9b, chart9c,
     dynamic_x_header, chart10,
     dodge_header, chart11,
     dodge_comparison_header, chart12a, chart12b,
     struct_intro, chart13,
     conclusion],
    tab_title = "AreaChart Examples"
)

create_html(page, "generated_html_examples/areachart_examples.html")

println("\n" * "="^60)
println("AreaChart examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/areachart_examples.html")
println("\nThis page includes:")
println("  • Continuous stacked area chart (with dates)")
println("  • Unstacked overlapping areas (continuous numeric)")
println("  • Normalized stacking (percentage)")
println("  • Discrete/categorical areas (stacked bars)")
println("  • Interactive filters with date axis")
println("  • Facet wrap (1 variable)")
println("  • Facet grid (2 variables)")
println("  • Dynamic controls (grouping, stacking, faceting)")
println("  • Side-by-side stack mode comparison")
println("  • Dynamic X-axis selection (switch between Quarter/Month/Week)")
println("  • Dodge mode (side-by-side grouped bars)")
println("  • Dodge vs Stack comparison")
println("  • Struct data source (referencing struct fields via dot notation)")
