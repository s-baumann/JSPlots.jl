using JSPlots, DataFrames, Dates, Random

# Example 1: Simple scatter plot with single continuous slider
Random.seed!(42)
n = 500
df1 = DataFrame(
    x = randn(n) .* 2,
    y = randn(n) .* 2,
    value = rand(n) .* 100
)
df1.y .+= 0.5 .* df1.x  # Add some correlation

scatter1 = ScatterPlot(:simple_scatter, df1, :df1;
    x_col = :x,
    y_col = :y,
    slider_col = :value,  # Single slider
    title = "Simple Scatter with Continuous Range Slider",
    x_label = "X Variable",
    y_label = "Y Variable",
    notes = "Use the range slider to filter by value"
)


# Example 2: Multiple sliders - categorical + continuous
n = 300
categories = ["A", "B", "C", "D"]
groups = ["Group1", "Group2"]

df2 = DataFrame(
    x = randn(n) .* 3,
    y = randn(n) .* 3,
    category = rand(categories, n),
    group = rand(groups, n),
    score = rand(n) .* 50
)

scatter2 = ScatterPlot(:multi_slider, df2, :df2;
    x_col = :x,
    y_col = :y,
    color_col = :group,
    slider_col = [:category, :score],  # Multiple sliders!
    title = "Scatter with Multiple Filters",
    x_label = "X Variable",
    y_label = "Y Variable",
    notes = "Points must pass ALL filter criteria to be displayed"
)


# Example 3: Three sliders - categorical + date + continuous
dates = Date(2023, 1, 1):Day(1):Date(2023, 12, 31)
n = length(dates)

df3 = DataFrame(
    date = dates,
    temperature = 15 .+ 10 .* sin.(2π .* (1:n) ./ 365) .+ randn(n) .* 2,
    rainfall = abs.(randn(n) .* 20),
    season = map(d -> Dates.month(d) ∈ [12, 1, 2] ? "Winter" :
                      Dates.month(d) ∈ [3, 4, 5] ? "Spring" :
                      Dates.month(d) ∈ [6, 7, 8] ? "Summer" : "Fall", dates)
)

scatter3 = ScatterPlot(:weather_scatter, df3, :df3;
    x_col = :temperature,
    y_col = :rainfall,
    color_col = :season,
    slider_col = [:date, :season, :temperature],  # Three sliders: date, categorical, and continuous
    title = "Weather Data with Multiple Range Sliders",
    x_label = "Temperature (°C)",
    y_label = "Rainfall (mm)",
    notes = "Filter by date range, season(s), and temperature range simultaneously"
)

# Example 4: Scatter without sliders (showing it's still optional)
df4 = DataFrame(
    x = rand(1000) .* 100,
    y = rand(1000) .* 100
)

scatter4 = ScatterPlot(:no_sliders, df4, :df4;
    x_col = :x,
    y_col = :y,
    show_marginals = false,
    marker_size = 3,
    marker_opacity = 0.4,
    title = "Simple Scatter (No Filters)",
    x_label = "X Coordinate",
    y_label = "Y Coordinate"
)

# Example 5: Stock data with date range + categorical filters
stock_data = DataFrame(
    date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 3, 31), inner=3),
    symbol = repeat(["AAPL", "GOOGL", "MSFT"], outer=91),
    return_pct = randn(273) .* 2,
    volume = rand(273) .* 1_000_000,
    sector = repeat(["Tech", "Tech", "Tech"], outer=91)
)

scatter5 = ScatterPlot(:stock_scatter, stock_data, :stock_data;
    x_col = :volume,
    y_col = :return_pct,
    color_col = :symbol,
    slider_col = [:date, :symbol, :volume],  # Date range + multi-select + volume range
    title = "Stock Returns vs Volume with Multiple Filters",
    x_label = "Trading Volume",
    y_label = "Daily Return (%)",
    notes = "Filter by date range, symbol(s), and volume range"
)

# Example 6: Complex filtering scenario
n = 1000
df6 = DataFrame(
    x = randn(n) .* 10,
    y = randn(n) .* 10,
    region = rand(["North", "South", "East", "West"], n),
    priority = rand(["Low", "Medium", "High"], n),
    timestamp = rand(Date(2024, 1, 1):Day(1):Date(2024, 12, 31), n),
    value = rand(n) .* 1000
)

scatter6 = ScatterPlot(:complex_filters, df6, :df6;
    x_col = :x,
    y_col = :y,
    color_col = :priority,
    slider_col = [:region, :priority, :timestamp, :value],  # Four different slider types
    title = "Complex Multi-Filter Scatter Plot",
    x_label = "X Position",
    y_label = "Y Position",
    notes = "Demonstrates 4 simultaneous filters: 2 categorical + 1 date range + 1 continuous range"
)

# Create a page with all scatter plots
data_dict = Dict{Symbol,DataFrame}(
    :df1 => df1,
    :df2 => df2,
    :df3 => df3,
    :df4 => df4,
    :stock_data => stock_data,
    :df6 => df6
)

page = JSPlotPage(
    data_dict,
    [scatter1, scatter2, scatter3, scatter4, scatter5, scatter6];
    dataformat = :parquet
)

create_html(page, "generated_html_examples/scatterplots.html")

# Create individual examples
create_html(scatter2, df2, "generated_html_examples/multi_slider_example.html")
create_html(scatter3, df3, "generated_html_examples/weather_example.html")
create_html(scatter6, df6, "generated_html_examples/complex_example.html")

println("Scatter plots created successfully!")
println("Open scatterplots.html to view all examples")
println("  - Example 1: Single continuous range slider")
println("  - Example 2: Two sliders (categorical + continuous)")
println("  - Example 3: Three sliders (date + categorical + continuous)")
println("  - Example 4: No sliders")
println("  - Example 5: Stock data with multiple filters")
println("  - Example 6: Complex scenario with 4 different filters")