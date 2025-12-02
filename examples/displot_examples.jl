using JSPlots, DataFrames, Dates, Random, Distributions

# Example 1: Simple distribution plot - single group
Random.seed!(42)
n = 1000
df1 = DataFrame(
    value = randn(n) .* 10 .+ 50
)

distplot1 = DistPlot(:simple_dist, df1, :df1;
    value_col = :value,
    title = "Simple Distribution Plot",
    value_label = "Values",
    notes = "Shows histogram, box plot, and rug plot for a normal distribution"
)

create_html(distplot1, df1, "generated_html_examples/simple_distribution.html")


# Example 2: Comparing multiple groups
n = 500
groups = ["Control", "Treatment A", "Treatment B"]
df2 = DataFrame(
    value = vcat(
        randn(n) .* 5 .+ 100,  # Control group
        randn(n) .* 6 .+ 110,  # Treatment A (shifted higher)
        randn(n) .* 4 .+ 95    # Treatment B (tighter, shifted lower)
    ),
    group = repeat(groups, inner=n)
)

distplot2 = DistPlot(:multi_group_dist, df2, :df2;
    value_col = :value,
    group_col = :group,
    title = "Treatment Effect Comparison",
    value_label = "Response Value",
    notes = "Compare distributions across different treatment groups"
)

create_html(distplot2, df2, "generated_html_examples/multi_group_distribution.html")

# Example 3: Distribution with categorical filter
n = 800
categories = ["Category A", "Category B", "Category C", "Category D"]
df3 = DataFrame(
    value = vcat(
        rand(Normal(50, 10), n÷2),
        rand(Normal(65, 12), n÷2)
    ),
    category = rand(categories, n),
    quality = rand(["High", "Medium", "Low"], n)
)

distplot3 = DistPlot(:filtered_dist, df3, :df3;
    value_col = :value,
    slider_col = :category,
    title = "Distribution with Categorical Filter",
    value_label = "Measurement",
    notes = "Use the multi-select to filter by category"
)


# Example 4: Distribution with continuous range filter
n = 1200
df4 = DataFrame(
    score = abs.(randn(n) .* 15 .+ 70),
    age = rand(18:80, n),
    income = rand(20000:150000, n)
)

distplot4 = DistPlot(:range_filtered_dist, df4, :df4;
    value_col = :score,
    slider_col = [:age, :income],
    histogram_bins = 40,
    title = "Score Distribution with Range Filters",
    value_label = "Test Score",
    notes = "Filter by age and income ranges to see how score distributions change"
)


# Example 5: Time-series distribution analysis
dates = Date(2023, 1, 1):Day(1):Date(2023, 12, 31)
n = length(dates)

# Simulate seasonal temperature data
df5 = DataFrame(
    date = dates,
    temperature = 15 .+ 10 .* sin.(2π .* (1:n) ./ 365) .+ randn(n) .* 3,
    region = rand(["North", "South", "East", "West"], n)
)

distplot5 = DistPlot(:seasonal_dist, df5, :df5;
    value_col = :temperature,
    group_col = :region,
    slider_col = [:date, :region],
    title = "Temperature Distribution by Region",
    value_label = "Temperature (°C)",
    notes = "Filter by date range and region to analyze seasonal patterns"
)


# Example 6: Financial data distribution
n = 2000
symbols = ["AAPL", "GOOGL", "MSFT", "AMZN"]
df6 = DataFrame(
    return_pct = vcat(
        randn(n÷4) .* 2.0 .+ 0.5,   # AAPL
        randn(n÷4) .* 2.5 .+ 0.3,   # GOOGL
        randn(n÷4) .* 1.8 .+ 0.4,   # MSFT
        randn(n÷4) .* 3.0 .+ 0.2    # AMZN
    ),
    symbol = repeat(symbols, inner=n÷4),
    date = rand(Date(2024, 1, 1):Day(1):Date(2024, 12, 31), n),
    volume = rand(1_000_000:50_000_000, n)
)

distplot6 = DistPlot(:stock_returns_dist, df6, :df6;
    value_col = :return_pct,
    group_col = :symbol,
    slider_col = [:symbol, :date, :volume],
    histogram_bins = 50,
    title = "Stock Daily Returns Distribution",
    value_label = "Daily Return (%)",
    notes = "Compare return distributions across stocks with multiple filters"
)


# Example 7: Custom appearance - histogram only
df7 = DataFrame(
    measurement = rand(Exponential(5), 1000)
)

distplot7 = DistPlot(:histogram_only, df7, :df7;
    value_col = :measurement,
    show_box = false,
    show_rug = false,
    histogram_bins = 35,
    title = "Histogram Only (Exponential Distribution)",
    value_label = "Measurement Value",
    notes = "Box plot and rug plot hidden to focus on histogram shape"
)


# Example 8: Box plot emphasis with grouped data
n = 600
conditions = ["Baseline", "Week 1", "Week 2", "Week 3", "Week 4"]
df8 = DataFrame(
    measurement = vcat(
        randn(n÷5) .* 8 .+ 100,
        randn(n÷5) .* 7 .+ 105,
        randn(n÷5) .* 6 .+ 108,
        randn(n÷5) .* 6 .+ 110,
        randn(n÷5) .* 5 .+ 112
    ),
    time_point = repeat(conditions, inner=n÷5),
    subject_id = repeat(1:20, outer=30)
)

distplot8 = DistPlot(:longitudinal_dist, df8, :df8;
    value_col = :measurement,
    group_col = :time_point,
    show_histogram = true,
    show_box = true,
    show_rug = false,
    box_opacity = 0.8,
    title = "Longitudinal Study - Treatment Progress",
    value_label = "Clinical Measurement",
    notes = "Track how distributions change over time in a clinical trial"
)


# Example 9: Bimodal distribution
n = 1500
df9 = DataFrame(
    value = vcat(
        randn(n÷2) .* 5 .+ 40,
        randn(n÷2) .* 4 .+ 65
    ),
    sample_type = rand(["Morning", "Evening"], n)
)

distplot9 = DistPlot(:bimodal_dist, df9, :df9;
    value_col = :value,
    slider_col = :sample_type,
    histogram_bins = 50,
    title = "Bimodal Distribution Example",
    value_label = "Measurement",
    notes = "Filter by sample type to explore the bimodal pattern"
)


# Example 10: Complex multi-filter scenario
n = 2000
df10 = DataFrame(
    score = abs.(randn(n) .* 20 .+ 75),
    department = rand(["Engineering", "Sales", "Marketing", "HR", "Finance"], n),
    experience_years = rand(0:30, n),
    performance_rating = rand(["Excellent", "Good", "Average", "Poor"], n),
    hire_date = rand(Date(2010, 1, 1):Day(30):Date(2024, 12, 31), n)
)

distplot10 = DistPlot(:employee_scores, df10, :df10;
    value_col = :score,
    group_col = :performance_rating,
    slider_col = [:department, :experience_years, :performance_rating, :hire_date],
    histogram_bins = 30,
    title = "Employee Performance Score Distribution",
    value_label = "Performance Score",
    notes = "Analyze score distributions with multiple demographic and temporal filters"
)


# Create a page with all distribution plots
data_dict = Dict{Symbol,DataFrame}(
    :df1 => df1,
    :df2 => df2,
    :df3 => df3,
    :df4 => df4,
    :df5 => df5,
    :df6 => df6,
    :df7 => df7,
    :df8 => df8,
    :df9 => df9,
    :df10 => df10
)

page = JSPlotPage(
    data_dict,
    [distplot1, distplot2, distplot3, distplot4, distplot5, 
     distplot6, distplot7, distplot8, distplot9, distplot10]
    ; dataformat = :json_embedded
)

create_html(page, "generated_html_examples/distplots.html")

# Create individual examples
create_html(distplot2, df2, "generated_html_examples/multi_group_example.html")
create_html(distplot5, df5, "generated_html_examples/seasonal_example.html")
create_html(distplot6, df6, "generated_html_examples/stock_returns_example.html")
create_html(distplot10, df10, "generated_html_examples/employee_scores_example.html")

println("Distribution plots created successfully!")
println("Open distplots.html to view all examples")
println("  - Example 1: Simple single-group distribution")
println("  - Example 2: Multi-group comparison")
println("  - Example 3: Categorical filter")
println("  - Example 4: Continuous range filters")
println("  - Example 5: Time-series with regional grouping")
println("  - Example 6: Financial returns analysis")
println("  - Example 7: Histogram-only view")
println("  - Example 8: Longitudinal study tracking")
println("  - Example 9: Bimodal distribution")
println("  - Example 10: Complex multi-filter employee data")