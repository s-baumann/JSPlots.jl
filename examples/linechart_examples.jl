using JSPlots, DataFrames, Dates

println("Creating LineChart examples...")

# Prepare header
header = TextBlock("""
<h1>LineChart Examples</h1>
<p>This page demonstrates the key features of LineChart plots in JSPlots.</p>
<ul>
    <li><strong>Basic time series:</strong> Simple line chart with date axis</li>
    <li><strong>Multiple series:</strong> Comparing multiple lines with color dimension</li>
    <li><strong>Interactive filters:</strong> Dropdown menus to filter data dynamically</li>
    <li><strong>Dynamic controls:</strong> Change color, aggregation, and faceting on the fly</li>
    <li><strong>Aggregation:</strong> Handle multiple observations per x value</li>
    <li><strong>Faceting:</strong> Facet wrap (1 variable) and facet grid (2 variables)</li>
    <li><strong>Integration:</strong> Combining charts with images and text</li>
</ul>
""")

# Example 1: Basic Time Series Line Chart
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
df1 = DataFrame(
    Date = dates,
    Revenue = cumsum(randn(length(dates)) .* 1000 .+ 50000),
    color = repeat(["Revenue"], length(dates))
)

chart1 = LineChart(:revenue_trend, df1, :revenue_data;
    x_cols = [:Date],
    y_cols = [:Revenue],
    color_cols = [:color],
    title = "Daily Revenue Trend - H1 2024",
    notes = "Basic time series showing 6-month revenue trend"
)

# Example 2: Multiple Series Line Chart
df2 = DataFrame(
    Month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 3),
    Sales = vcat(
        [120, 135, 150, 145, 160, 175, 190, 185, 200, 210, 230, 250],  # 2022
        [130, 145, 165, 160, 180, 195, 210, 205, 220, 235, 255, 280],  # 2023
        [145, 165, 185, 180, 200, 220, 240, 235, 250, 270, 290, 320]   # 2024
    ),
    Year = vcat(repeat(["2022"], 12), repeat(["2023"], 12), repeat(["2024"], 12))
)

chart2 = LineChart(:multi_series, df2, :sales_data;
    x_cols = [:Month],
    y_cols = [:Sales],
    color_cols = [:Year],
    title = "Monthly Sales Comparison Across Years",
    notes = "Multiple series chart demonstrating color dimension to compare years"
)

# Example 3: Line Chart with Interactive Filters
departments = ["Engineering", "Sales", "Marketing", "Operations"]
metrics_df = DataFrame()

for dept in departments
    for quarter in ["Q1", "Q2", "Q3", "Q4"]
        for month in 1:3
            month_name = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][
                             (parse(Int, quarter[2])-1)*3 + month
                         ]
            push!(metrics_df, (
                Department = dept,
                Quarter = quarter,
                Month = month_name,
                Productivity = 70 + rand() * 30,
                Metric = "Productivity"
            ))
        end
    end
end

chart3 = LineChart(:filtered_metrics, metrics_df, :metrics;
    x_cols = [:Month],
    y_cols = [:Productivity],
    color_cols = [:Metric],
    filters = Dict{Symbol,Any}(:Department => "Engineering", :Quarter => "Q1"),
    title = "Department Productivity by Month",
    notes = "Interactive filters allow you to select different departments and quarters"
)

# Example 4: Combined with Image
example_image = joinpath(@__DIR__, "pictures", "images.jpeg")
pic = Picture(:example_visual, example_image;
             notes = "Example visualization image")

# Example 5: Facet Wrap (1 facet variable)
# Create data with multiple products across regions
facet_df = DataFrame()
products = ["Product A", "Product B", "Product C", "Product D"]
regions = ["North", "South", "East", "West"]

for product in products
    for region in regions
        for month in 1:12
            push!(facet_df, (
                Month = month,
                Sales = 100 + rand() * 50 + (month - 1) * 5,
                Product = product,
                Region = region,
                color = region
            ))
        end
    end
end

chart5 = LineChart(:facet_wrap_example, facet_df, :facet_data;
    x_cols = [:Month],
    y_cols = [:Sales],
    color_cols = [:color, :Product],
    facet_cols = [:Product],
    default_facet_cols = :Product,
    title = "Sales by Product (Facet Wrap)",
    notes = "Facet wrap creates a grid of subplots, one for each product. Similar to ggplot2's facet_wrap."
)

# Example 6: Facet Grid (2 facet variables)
# Using the same data, create a grid by Product (rows) and Region (columns)
# For a cleaner example, let's use fewer categories
facet_grid_df = DataFrame()
products_small = ["Product A", "Product B"]
regions_small = ["North", "South"]
years = ["2023", "2024"]

for product in products_small
    for region in regions_small
        for year in years
            for month in 1:12
                push!(facet_grid_df, (
                    Month = month,
                    Sales = 100 + rand() * 50 + (month - 1) * 5,
                    Product = product,
                    Region = region,
                    Year = year,
                    color = year
                ))
            end
        end
    end
end

chart6 = LineChart(:facet_grid_example, facet_grid_df, :facet_grid_data;
    x_cols = [:Month],
    y_cols = [:Sales],
    color_cols = [:color],
    facet_cols = [:Product, :Region],
    default_facet_cols = [:Product, :Region],
    title = "Sales by Product and Region (Facet Grid)",
    notes = "Facet grid creates a 2D grid of subplots. First facet variable (Product) defines rows, second (Region) defines columns. Similar to ggplot2's facet_grid."
)

# Example 7: Dynamic Controls - Color, and Faceting
# Create richer dataset with multiple categorical variables
dynamic_df = DataFrame()
stocks = ["AAPL", "GOOGL", "MSFT"]
strategies = ["Buy", "Sell", "Hold"]
regions = ["US", "EU", "ASIA"]

for stock in stocks
    for strategy in strategies
        for region in regions
            for month in 1:12
                push!(dynamic_df, (
                    Month = month,
                    Return = 5 + randn() * 3 + (month - 6) * 0.3,
                    Stock = stock,
                    Strategy = strategy,
                    Region = region
                ))
            end
        end
    end
end

chart7 = LineChart(:dynamic_controls, dynamic_df, :dynamic_data;
    x_cols = [:Month],
    y_cols = [:Return],
    color_cols = [:Stock, :Strategy, :Region],
    facet_cols = [:Stock, :Strategy, :Region],
    default_facet_cols = nothing,
    aggregator = "none",
    title = "Dynamic Controls Demo - Stock Returns",
    notes = "Use the dropdown menus to dynamically change: (1) Color by, (2) Line type by, (3) Aggregator, (4) Facet 1, (5) Facet 2."
)

# Example 8: Aggregation Demo
# Create data with multiple observations per x value
agg_df = DataFrame()
for product in ["Product A", "Product B"]
    for month in 1:12
        # Multiple observations per month (simulating multiple stores or days)
        for rep in 1:5
            push!(agg_df, (
                Month = month,
                Sales = 100 + rand() * 50 + month * 5,
                Product = product,
                color = product
            ))
        end
    end
end

chart8 = LineChart(:aggregation_demo, agg_df, :agg_data;
    x_cols = [:Month],
    y_cols = [:Sales],
    color_cols = [:Product],
    aggregator = "mean",
    title = "Aggregation Demo - Multiple Observations per X",
    notes = "This dataset has 5 observations per month. Use the Aggregator dropdown to switch between: none (all points), mean, median, count, min, max."
)

# Example 9: Multiple X and Y dimensions with dynamic switching
df_multi = DataFrame(
    time_hours = 1:24,
    time_halfhours = 0.5:0.5:12,
    temperature_celsius = 15 .+ 8 .* sin.(2π .* (1:24) ./ 24) .+ randn(24),
    temperature_fahrenheit = 59 .+ 14.4 .* sin.(2π .* (1:24) ./ 24) .+ randn(24) .* 1.8,
    humidity_percent = 60 .+ 20 .* cos.(2π .* (1:24) ./ 24) .+ randn(24) .* 5,
    pressure_hpa = 1013 .+ 5 .* sin.(2π .* (1:24) ./ 24 .+ π/4) .+ randn(24) .* 2,
    location = repeat(["Station A"], 24),
    color = repeat(["default"], 24)
)

chart9 = LineChart(:multi_dimensions, df_multi, :multi_data;
    x_cols = [:time_hours, :time_halfhours],
    y_cols = [:temperature_celsius, :temperature_fahrenheit, :humidity_percent, :pressure_hpa],
    color_cols = [:color],
    title = "Multi-Dimensional Weather Data - Dynamic X and Y Selection",
    notes = "Use the dropdowns to dynamically switch between different time scales (X) and measurements (Y). " *
           "This demonstrates how you can provide multiple options for both axes and let users explore different views of the same dataset."
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Dynamic X and Y dimensions:</strong> Choose which variables to plot on X and Y axes from dropdowns</li>
    <li><strong>Time series support:</strong> Automatic date formatting and axis scaling</li>
    <li><strong>Dynamic color grouping:</strong> Choose which variable to color by from dropdown</li>
    <li><strong>Aggregation:</strong> Handle multiple observations per x value with mean, median, count, min, max, or none</li>
    <li><strong>Interactive filters:</strong> Dropdown menus for dynamic data filtering</li>
    <li><strong>Dynamic faceting:</strong> Choose 0, 1, or 2 variables for faceting on the fly</li>
    <li><strong>Customization:</strong> Control titles, labels, line width, and markers</li>
    <li><strong>Integration:</strong> Combine with other plot types, images, and text</li>
</ul>
<p><strong>Tip:</strong> Hover over lines to see detailed values!</p>
""")

# Create single combined page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :revenue_data => df1,
        :sales_data => df2,
        :metrics => metrics_df,
        :facet_data => facet_df,
        :facet_grid_data => facet_grid_df,
        :dynamic_data => dynamic_df,
        :agg_data => agg_df,
        :multi_data => df_multi
    ),
    [header, chart1, chart2, chart3, pic, chart5, chart6, chart7, chart8, chart9, conclusion],
    tab_title = "LineChart Examples"
)

create_html(page, "generated_html_examples/linechart_examples.html")

println("\n" * "="^60)
println("LineChart examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/linechart_examples.html")
println("\nThis page includes:")
println("  • Basic time series chart")
println("  • Multiple series with color grouping")
println("  • Interactive filtered chart")
println("  • Facet wrap (1 variable)")
println("  • Facet grid (2 variables)")
println("  • Dynamic controls (color, faceting)")
println("  • Aggregation demo (mean, median, count, min, max)")
println("  • Dynamic X and Y dimension selection")
println("  • Integration with images and text")
