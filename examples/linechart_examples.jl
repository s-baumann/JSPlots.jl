using JSPlots, DataFrames, Dates, StableRNGs, Distributions

println("Creating LineChart examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(456)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/linechart_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
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
    Revenue = cumsum(randn(rng, length(dates)) .* 1000 .+ 50000),
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
    Month = repeat(collect(1:12), 3),
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
    color_cols = [(:Year, Dict("2022" => "#4169E1", "2023" => "#32CD32", "2024" => "#FF6347"))],
    title = "Monthly Sales Comparison Across Years",
    notes = "Multiple series chart with custom colors: 2022 (blue), 2023 (green), 2024 (red)"
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
                Value = 70 + rand(rng) * 30,
                Metric = "Productivity"
            ))
            push!(metrics_df, (
                Department = dept,
                Quarter = quarter,
                Month = month_name,
                Value = rand(rng, Poisson(month)),
                Metric = "Sick_Days"
            ))
        end
    end
end

chart3 = LineChart(:filtered_metrics, metrics_df, :metrics;
    x_cols = [:Month],
    y_cols = [:Value],
    color_cols = [
        (:Department, Dict("Engineering" => "#0066cc", "Sales" => "#00cc66", "Marketing" => "#cc6600", "Operations" => "#cc0066")),
        (:Metric, :default)
    ],
    filters = Dict{Symbol,Any}(:Department => "Engineering", :Quarter => "Q1"),
    title = "Department Productivity by Month",
    notes = "Custom colors for departments, default colors for metrics. Interactive filters allow selection."
)

# Example 3b: Using choices (single-select) instead of filters (multi-select)
# Choices enforce that exactly ONE value is selected at a time
chart3b = LineChart(:single_select_metrics, metrics_df, :metrics;
    x_cols = [:Month],
    y_cols = [:Value],
    color_cols = [:Department],
    choices = Dict{Symbol,Any}(:Metric => :Productivity),  # Single-select: user picks ONE metric
    filters = Dict{Symbol,Any}(:Quarter => ["Q1", "Q2"]),  # Multi-select: user can pick multiple quarters
    title = "Department Performance (Single Metric Selection)",
    notes = """
    This example demonstrates the difference between choices and filters:
    - **Metric (choice)**: Single-select dropdown - pick exactly ONE metric at a time
    - **Quarter (filter)**: Multi-select dropdown - can select multiple quarters

    Use choices when the user must select exactly one option (like choosing a strategy or metric type).
    """
)

# Example 3c: Shorthand syntax for choices
# Instead of specifying default values, just list the column names
# JSPlots will automatically use the first unique value from each column as the default
chart3c = LineChart(:shorthand_choices, metrics_df, :metrics;
    x_cols = [:Month],
    y_cols = [:Value],
    color_cols = [:Department],
    choices = [:Metric, :Quarter],  # Shorthand: uses first unique value from each column
    title = "Shorthand Choices Syntax",
    notes = """
    **Shorthand syntax for choices:** Instead of `Dict{Symbol,Any}(:Metric => :Productivity)`,
    you can simply use `[:Metric, :Quarter]`. JSPlots automatically selects the first unique
    value from each column as the default.

    This is equivalent to: `Dict{Symbol,Any}(:Metric => first(unique(df.Metric)), :Quarter => first(unique(df.Quarter)))`
    """
)

# Example 4: Combined with Image
example_image = joinpath(dirname(@__FILE__),"pictures", "images.jpeg")
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
                Sales = 100 + rand(rng) * 50 + (month - 1) * 5,
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
                    Sales = 100 + rand(rng) * 50 + (month - 1) * 5,
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
                    Return = 5 + randn(rng) * 3 + (month - 6) * 0.3,
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
    aggregator = "mean",
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
                Sales = 100 + rand(rng, 1)[1] * 50 + month * 5,
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
    temperature_celsius = 15 .+ 8 .* sin.(2π .* (1:24) ./ 24) .+ randn(rng, 24),
    temperature_fahrenheit = 59 .+ 14.4 .* sin.(2π .* (1:24) ./ 24) .+ randn(rng, 24) .* 1.8,
    humidity_percent = 60 .+ 20 .* cos.(2π .* (1:24) ./ 24) .+ randn(rng, 24) .* 5,
    pressure_hpa = 1013 .+ 5 .* sin.(2π .* (1:24) ./ 24 .+ π/4) .+ randn(rng, 24) .* 2,
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

# Example 10: Continuous Range Filters with jQuery UI Slider
# Create data with continuous numeric variables suitable for range filtering
continuous_filter_df = DataFrame()
products_cf = ["Widget", "Gadget", "Doohickey"]
regions_cf = ["North", "South", "East", "West"]

for product in products_cf
    for region in regions_cf
        for month in 1:12
            push!(continuous_filter_df, (
                Month = month,
                Sales = 50000 + rand(rng) * 100000,
                Profit_Margin = 5 + rand(rng) * 45,  # 5% to 50%
                Units = 100 + rand(rng) * 900,  # 100 to 1000 units
                Product = product,
                Region = region
            ))
        end
    end
end

chart10 = LineChart(:continuous_filters, continuous_filter_df, :continuous_filter_data;
    x_cols = [:Month],
    y_cols = [:Sales],
    color_cols = [:Product],
    filters = Dict(
        :Product => ["Widget", "Gadget", "Doohickey"],  # Categorical filter (dropdown)
        :Profit_Margin => [5.0, 50.0],  # Continuous filter (range slider)
        :Units => [100.0, 1000.0]  # Another continuous filter (range slider)
    ),
    aggregator = "mean",
    title = "Sales with Continuous Range Filters",
    notes = "This example demonstrates jQuery UI range sliders for continuous variables. " *
           "Use the Product dropdown for categorical filtering, and the Profit Margin and Units sliders " *
           "to filter by numeric ranges. Each slider has two handles for min/max values."
)

# Example 11: Using a Struct as Data Source
# This demonstrates how to pass a struct containing DataFrames to JSPlotPage
# and reference specific fields in charts using dot notation.

# Define a struct containing related DataFrames
struct FinancialData
    prices::DataFrame
    volumes::DataFrame
end

# Create DataFrames for the struct
prices_df = DataFrame(
    Date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
    AAPL = cumsum(randn(rng, 91)) .+ 180,
    GOOGL = cumsum(randn(rng, 91)) .+ 140,
    MSFT = cumsum(randn(rng, 91)) .+ 400,
    color = repeat(["Price"], 91)
)
# Reshape to long format for plotting
prices_long = stack(prices_df, [:AAPL, :GOOGL, :MSFT], :Date, variable_name=:Stock, value_name=:Price)
prices_long.color = string.(prices_long.Stock)

volumes_df = DataFrame(
    Date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
    AAPL = rand(rng, 1_000_000:10_000_000, 91),
    GOOGL = rand(rng, 500_000:5_000_000, 91),
    MSFT = rand(rng, 800_000:8_000_000, 91),
    color = repeat(["Volume"], 91)
)

# Create the struct instance
financial_data = FinancialData(prices_long, volumes_df)

# Create a chart that references the struct's prices field
# Note: The data_label uses dot notation to access struct fields
struct_chart = LineChart(:struct_prices, financial_data.prices, Symbol("financial.prices");
    x_cols = [:Date],
    y_cols = [:Price],
    color_cols = [:color],
    title = "Stock Prices from Struct Data Source",
    notes = "This chart demonstrates using a struct as a data source. The FinancialData struct " *
           "contains both prices and volumes DataFrames. Charts reference struct fields using " *
           "dot notation in the data_label (e.g., Symbol(\"financial.prices\"))."
)

struct_intro = TextBlock("""
<h2>Struct Data Source Example</h2>
<p>JSPlots supports using custom structs containing DataFrames as data sources. This is useful when:</p>
<ul>
    <li>You have related DataFrames that belong together (e.g., prices and volumes)</li>
    <li>You want to pass complex data structures without unpacking them</li>
    <li>Multiple charts need to reference different parts of the same data</li>
</ul>
<p>Pass the struct to JSPlotPage and reference fields using dot notation: <code>Symbol("struct_name.field_name")</code></p>
""")

# Example 12: Smoothing Transforms (EWMA, EWMSTD, SMA)
# Create noisy data where smoothing reveals the underlying trend
smoothing_dates = Date(2024, 1, 1):Day(1):Date(2024, 12, 31)
n_smooth = length(smoothing_dates)
trend = range(100, 200, length=n_smooth)
noise = randn(rng, n_smooth) .* 15
smoothing_df = DataFrame(
    Date = repeat(collect(smoothing_dates), 2),
    Price = vcat(trend .+ noise, trend .* 1.1 .+ randn(rng, n_smooth) .* 20),
    Asset = vcat(repeat(["Stock A"], n_smooth), repeat(["Stock B"], n_smooth))
)

chart12 = LineChart(:smoothing_demo, smoothing_df, :smoothing_data;
    x_cols = [:Date],
    y_cols = [:Price],
    color_cols = [:Asset],
    default_ewma_weight = 0.05,
    default_ewmstd_weight = 0.1,
    default_sma_window = 20,
    title = "Smoothing Transforms Demo (EWMA, EWMSTD, SMA)",
    notes = """
    Use the **Y Transform** dropdown to apply smoothing:
    - **ewma**: Exponentially Weighted Moving Average — smooths prices with configurable weight (lower = smoother)
    - **ewmstd**: Exponentially Weighted Moving Std Dev — shows rolling volatility
    - **sma**: Simple Moving Average — trailing average over N periods

    Each smoothing transform reveals a parameter input box where you can adjust the weight or window size.
    The chart updates immediately when you change the parameter.
    """
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Dynamic X and Y dimensions:</strong> Choose which variables to plot on X and Y axes from dropdowns</li>
    <li><strong>Time series support:</strong> Automatic date formatting and axis scaling</li>
    <li><strong>Dynamic color grouping:</strong> Choose which variable to color by from dropdown</li>
    <li><strong>Aggregation:</strong> Handle multiple observations per x value with mean, median, count, min, max, or none</li>
    <li><strong>Interactive filters:</strong> Dropdown menus for categorical filtering and jQuery UI range sliders for continuous numeric filtering</li>
    <li><strong>Continuous range sliders:</strong> Single slider bar with two draggable handles for min/max values (powered by jQuery UI)</li>
    <li><strong>Dynamic faceting:</strong> Choose 0, 1, or 2 variables for faceting on the fly</li>
    <li><strong>Customization:</strong> Control titles, labels, line width, and markers</li>
    <li><strong>Integration:</strong> Combine with other plot types, images, and text</li>
</ul>
<p><strong>Tip:</strong> Hover over lines to see detailed values!</p>
""")

# Create single combined page
# Note: The financial_data struct is passed directly - JSPlotPage will extract its DataFrame fields
page = JSPlotPage(
    Dict{Symbol,Any}(
        :revenue_data => df1,
        :sales_data => df2,
        :metrics => metrics_df,
        :facet_data => facet_df,
        :facet_grid_data => facet_grid_df,
        :dynamic_data => dynamic_df,
        :agg_data => agg_df,
        :multi_data => df_multi,
        :continuous_filter_data => continuous_filter_df,
        :financial => financial_data,  # Struct with prices and volumes DataFrames
        :smoothing_data => smoothing_df
    ),
    [header, chart1, chart2, chart3, chart3b, chart3c, pic, chart5, chart6, chart7, chart8, chart9, chart10, struct_intro, struct_chart, chart12, conclusion],
    tab_title = "LineChart Examples"
)

# Output to the main generated_html_examples directory
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end


# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="linechart_examples.html",
                               description="LineChart Examples", date=today(),
                               extra_columns=Dict(:chart_type => "2D Charts", :page_type => "Chart Tutorial"))
create_html(page, joinpath(output_dir, "linechart_examples.html");
            manifest=joinpath(output_dir, "z_general_example/manifest.csv"), manifest_entry=manifest_entry)
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
println("  • Continuous range filters with jQuery UI sliders")
println("  • Struct data source (referencing struct fields via dot notation)")
println("  • Smoothing transforms (EWMA, EWMSTD, SMA)")
println("  • Integration with images and text")
