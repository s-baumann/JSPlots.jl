# Examples

This page provides comprehensive examples for all JSPlots visualization types and features.

## Complete Example: Multi-Chart Dashboard

Here's a complete example showing multiple plot types on a single page:

```julia
using JSPlots, DataFrames, Dates

# Example 1: Stock Returns Data for Pivot Table
stockReturns = DataFrame(
    Symbol = ["RTX", "RTX", "RTX", "GOOG", "GOOG", "GOOG", "MSFT", "MSFT", "MSFT"],
    Date = Date.(["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03"]),
    Return = [10.01, -10.005, -0.5, 1.0, 0.01, -0.003, 0.008, 0.004, -0.002]
)

# Example 2: Correlation Matrix Data
correlations = DataFrame(
    Symbol1 = ["RTX", "RTX", "GOOG", "RTX", "GOOG", "MSFT", "GOOG", "MSFT", "MSFT"],
    Symbol2 = ["GOOG", "MSFT", "MSFT", "RTX", "GOOG", "MSFT", "RTX", "RTX", "GOOG"],
    Correlation = [-0.85, -0.75, 0.80, 1.0, 1.0, 1.0, -0.85, -0.75, 0.80]
)

# Create first pivot table with exclusions
exclusions = Dict(
    :Symbol => [:MSFT]
)

pt = PivotTable(:Returns_Over_Last_Few_Days, :stockReturns;
    rows = [:Symbol],
    cols = [:Date],
    vals = :Return,
    exclusions = exclusions,
    aggregatorName = :Average,
    rendererName = :Heatmap
)

# Create correlation matrix pivot table with custom colors
pt2 = PivotTable(:Correlation_Matrix, :correlations;
    rows = [:Symbol1],
    cols = [:Symbol2],
    vals = :Correlation,
    colour_map = Dict{Float64,String}([-1.0, 0.0, 1.0] .=> ["#FF4545", "#ffffff", "#4F92FF"]),
    aggregatorName = :Average,
    rendererName = :Heatmap
)

# Example 3: 3D Surface Data
subframe = allcombinations(DataFrame, x = collect(1:6), y = collect(1:6))
subframe[!, :group] .= "A"
sf2 = deepcopy(subframe)
sf2[!, :group] .= "B"
subframe[!, :z] = cos.(sqrt.(subframe.x .^ 2 .+  subframe.y .^ 2))
sf2[!, :z] = cos.(sqrt.(sf2.x .^ 2 .+  sf2.y .^ 1)) .- 1.0
subframe = vcat(subframe, sf2)

pt3 = Chart3d(:threeD, :subframe;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :group,
    title = "3D Surface Chart of shapes",
    x_label = "X directions",
    y_label = "Y dim",
    z_label = "Z directions",
    notes = "This is a 3D surface chart."
)

# Example 4: Line Chart Data
df1 = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df1[!, :categ] .=  [:B, :B, :B, :B, :B, :A, :A, :A, :A, :C]
df1[!, :categ22] .= "Category_A"

df2 = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df2[!, :categ] .= [:A, :A, :A, :A, :A, :B, :B, :B, :B, :C]
df2[!, :categ22] .= "Category_B"
df = vcat(df1, df2)

pt00 = LineChart(:pchart, df, :df;
    x_col = :x,
    y_col = :y,
    color_col = :color,
    filters = Dict(:categ => :A, :categ22 => "Category_A"),
    title = "Line Chart",
    x_label = "This is the x axis",
    y_label = "This is the y axis"
)

# Combine all plots into a single page
pge = JSPlotPage(
    Dict{Symbol,DataFrame}(:stockReturns => stockReturns, :correlations => correlations, :subframe => subframe, :df => df),
    [pt, pt00, pt2, pt3]
)
create_html(pge, "examples/pivottable.html")
```

## Single Plot Output

If you're only creating one visualization, you don't need to create a `JSPlotPage`:

```julia
# Simple single-plot output
create_html(pt, stockReturns, "only_one.html")
```

## PivotTable Examples

### Basic Pivot Table

```julia
df = DataFrame(
    Product = ["A", "A", "B", "B", "C", "C"],
    Region = ["North", "South", "North", "South", "North", "South"],
    Sales = [100, 150, 200, 175, 90, 110],
    Profit = [20, 30, 40, 35, 18, 22]
)

pt = PivotTable(:sales_pivot, :df;
    rows = [:Product],
    cols = [:Region],
    vals = :Sales,
    aggregatorName = :Sum,
    rendererName = :Table
)

create_html(pt, df, "pivot_basic.html")
```

### Heatmap with Custom Colors

```julia
# Create a custom color scale for correlation matrix
pt = PivotTable(:correlation_heatmap, :correlations;
    rows = [:Variable1],
    cols = [:Variable2],
    vals = :Correlation,
    colour_map = Dict{Float64,String}(
        [-1.0, -0.5, 0.0, 0.5, 1.0] .=> ["#d73027", "#fc8d59", "#ffffff", "#91bfdb", "#4575b4"]
    ),
    aggregatorName = :Average,
    rendererName = :Heatmap,
    extrapolate_colours = true
)
```

### Filtering with Inclusions/Exclusions

```julia
# Only include specific categories
inclusions = Dict(
    :Region => ["North", "South"],
    :Year => [2023, 2024]
)

# Exclude specific values
exclusions = Dict(
    :Product => ["Discontinued_Item"]
)

pt = PivotTable(:filtered_pivot, :df;
    rows = [:Product],
    cols = [:Region],
    vals = :Sales,
    inclusions = inclusions,
    exclusions = exclusions,
    aggregatorName = :Average,
    rendererName = :Heatmap
)
```

## LineChart Examples

### Basic Time Series

```julia
df = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 12, 31),
    revenue = cumsum(randn(366) .+ 100)
)

chart = LineChart(:revenue_trend, df, :df;
    x_col = :date,
    y_col = :revenue,
    title = "Revenue Trend 2024",
    x_label = "Date",
    y_label = "Revenue ($)"
)

create_html(chart, df, "revenue.html")
```

### Multiple Series with Color Grouping

```julia
df = DataFrame(
    month = repeat(1:12, 3),
    sales = vcat(
        100 .+ cumsum(randn(12)),
        150 .+ cumsum(randn(12)),
        120 .+ cumsum(randn(12))
    ),
    product = repeat(["Widget", "Gadget", "Gizmo"], inner=12)
)

chart = LineChart(:product_comparison, df, :df;
    x_col = :month,
    y_col = :sales,
    color_col = :product,
    title = "Product Sales by Month",
    x_label = "Month",
    y_label = "Sales"
)
```

### With Interactive Filters

```julia
df[!, :region] = rand(["East", "West"], nrow(df))
df[!, :category] = rand(["A", "B"], nrow(df))

chart = LineChart(:filtered_chart, df, :df;
    x_col = :month,
    y_col = :sales,
    color_col = :product,
    filters = Dict(:region => "East", :category => "A"),
    title = "Filtered Sales Data"
)
```

## AreaChart Examples

### Basic Stacked Area Chart with Dates

```julia
using JSPlots, DataFrames, Dates

# Create time series data
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
df = DataFrame(
    Date = repeat(dates, 4),
    Sales = abs.(rand(length(dates) * 4) .* 10000 .+ 20000),
    Region = repeat(["North", "South", "East", "West"], inner=length(dates))
)

# Stacked area chart shows cumulative sales
chart = AreaChart(:regional_sales, df, :sales_data;
    x_cols = [:Date],
    y_cols = [:Sales],
    group_cols = [:Region],
    stack_mode = "stack",
    title = "Regional Sales Over Time (Stacked)"
)

create_html(chart, df, "stacked_area.html")
```

### Unstacked Areas with Transparency

```julia
# Create overlapping areas to compare trends
df = DataFrame(
    Time = repeat(1:24, 3),
    Value = vcat(
        50 .+ 10 .* sin.(2π .* (1:24) ./ 24) .+ randn(24),
        45 .+ 8 .* sin.(2π .* (1:24) ./ 24 .+ π/3) .+ randn(24),
        55 .+ 12 .* sin.(2π .* (1:24) ./ 24 .+ 2π/3) .+ randn(24)
    ),
    Product = repeat(["Product A", "Product B", "Product C"], inner=24)
)

chart = AreaChart(:product_comparison, df, :product_data;
    x_cols = [:Time],
    y_cols = [:Value],
    group_cols = [:Product],
    stack_mode = "unstack",
    fill_opacity = 0.4,
    title = "Product Values Comparison (Overlapping)"
)
```

### Normalized Stacking (Percentage View)

```julia
# Market share that always totals 100%
df = DataFrame(
    Quarter = repeat(1:8, 4),
    MarketShare = abs.(randn(32) .* 5 .+ 20),
    Company = repeat(["Alpha", "Beta", "Gamma", "Delta"], inner=8)
)

chart = AreaChart(:market_share, df, :market_data;
    x_cols = [:Quarter],
    y_cols = [:MarketShare],
    group_cols = [:Company],
    stack_mode = "normalised_stack",
    title = "Market Share Distribution (%)",
    notes = "Normalized stacking shows relative proportions"
)
```

### Discrete Areas (Categorical X-axis)

```julia
# When x is categorical, creates stacked bars automatically
df = DataFrame(
    Department = repeat(["Engineering", "Sales", "Marketing", "Operations"], inner=3),
    Headcount = rand(10:40, 12),
    Team = repeat(["Team A", "Team B", "Team C"], 4)
)

chart = AreaChart(:headcount_by_dept, df, :headcount_data;
    x_cols = [:Department],
    y_cols = [:Headcount],
    group_cols = [:Team],
    stack_mode = "stack",
    title = "Headcount by Department and Team"
)
```

### With Interactive Filters and Faceting

```julia
# Create rich dataset with multiple grouping options
years = ["2022", "2023", "2024"]
channels = ["Online", "Retail", "Wholesale"]
regions = ["North", "South"]
dates = Date(2024, 1, 1):Week(1):Date(2024, 12, 31)

df = DataFrame()
for year in years, channel in channels, region in regions, date in dates
    push!(df, (
        Date = date,
        Revenue = abs(randn() * 20000 + 100000),
        Channel = channel,
        Region = region,
        Year = year
    ))
end

chart = AreaChart(:revenue_analysis, df, :revenue_data;
    x_cols = [:Date],
    y_cols = [:Revenue],
    group_cols = [:Channel],
    filters = Dict{Symbol,Any}(:Year => "2024", :Region => "North"),
    facet_cols = [:Region],
    stack_mode = "stack",
    title = "Revenue by Channel",
    notes = "Use filters to explore different years and regions"
)
```

### Comparing Stack Modes

```julia
# Same data, different stack modes
df = DataFrame(
    Time = repeat(1:20, 3),
    Value = abs.(randn(60) .* 3 .+ 10),
    Category = repeat(["Cat 1", "Cat 2", "Cat 3"], inner=20)
)

# Unstack: see individual trends
unstack = AreaChart(:unstack, df, :data;
    x_cols = [:Time],
    y_cols = [:Value],
    group_cols = [:Category],
    stack_mode = "unstack",
    fill_opacity = 0.5,
    title = "Unstack: Individual Trends Visible"
)

# Stack: see cumulative total
stack = AreaChart(:stack, df, :data;
    x_cols = [:Time],
    y_cols = [:Value],
    group_cols = [:Category],
    stack_mode = "stack",
    title = "Stack: Cumulative Values"
)

# Normalized: see relative proportions
normalized = AreaChart(:normalized, df, :data;
    x_cols = [:Time],
    y_cols = [:Value],
    group_cols = [:Category],
    stack_mode = "normalised_stack",
    title = "Normalized: Relative Proportions (%)"
)

# Display all three on one page
page = JSPlotPage(
    Dict(:data => df),
    [TextBlock("<h1>Stack Mode Comparison</h1>"),
     unstack, stack, normalized],
    tab_title = "Area Chart Modes"
)
```

## Chart3d Examples

### Single Surface

```julia
df = allcombinations(DataFrame, x = 1:30, y = 1:30)
df[!, :z] = sin.(df.x / 5) .* cos.(df.y / 5)

chart = Chart3d(:wave, :df;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    title = "Wave Function",
    x_label = "X",
    y_label = "Y",
    z_label = "Z"
)

create_html(chart, df, "3d_wave.html")
```

### Multiple Grouped Surfaces

```julia
# Create first surface
df1 = allcombinations(DataFrame, x = 1:20, y = 1:20)
df1[!, :z] = exp.(-(df1.x .- 10).^2 ./ 20 .- (df1.y .- 10).^2 ./ 20)
df1[!, :group] .= "Gaussian"

# Create second surface
df2 = allcombinations(DataFrame, x = 1:20, y = 1:20)
df2[!, :z] = sin.(sqrt.(df2.x.^2 .+ df2.y.^2) / 3) ./ (sqrt.(df2.x.^2 .+ df2.y.^2) / 3)
df2[!, :group] .= "Sinc"

df = vcat(df1, df2)

chart = Chart3d(:comparison, :df;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    group_col = :group,
    title = "Surface Comparison"
)
```

## ScatterPlot Examples

### Basic Scatter

```julia
df = DataFrame(
    x = randn(500),
    y = randn(500)
)

scatter = ScatterPlot(:basic_scatter, df, :df;
    x_col = :x,
    y_col = :y,
    title = "Random Distribution",
    x_label = "X Variable",
    y_label = "Y Variable"
)

create_html(scatter, df, "scatter.html")
```

### With Color Groups and Marginals

```julia
df = DataFrame(
    height = randn(500) .* 10 .+ 170,
    weight = randn(500) .* 15 .+ 70,
    gender = rand(["Male", "Female"], 500),
    age = rand(20:60, 500)
)

scatter = ScatterPlot(:demographics, df, :df;
    x_col = :height,
    y_col = :weight,
    color_col = :gender,
    show_marginals = true,
    marker_size = 6,
    marker_opacity = 0.6,
    title = "Height vs Weight by Gender",
    x_label = "Height (cm)",
    y_label = "Weight (kg)"
)
```

### With Interactive Sliders

```julia
scatter = ScatterPlot(:filtered_scatter, df, :df;
    x_col = :height,
    y_col = :weight,
    color_col = :gender,
    slider_col = [:age, :gender],  # Add sliders for filtering
    title = "Interactive Scatter Plot"
)
```

## DistPlot Examples

### Single Distribution

```julia
df = DataFrame(
    score = randn(1000) .* 15 .+ 75
)

dist = DistPlot(:score_distribution, df, :df;
    value_col = :score,
    histogram_bins = 30,
    title = "Test Score Distribution",
    value_label = "Score"
)

create_html(dist, df, "distribution.html")
```

### Comparing Groups

```julia
df = DataFrame(
    value = vcat(randn(500) .* 10 .+ 50, randn(500) .* 12 .+ 55),
    group = vcat(fill("Control", 500), fill("Treatment", 500)),
    cohort = rand(["A", "B", "C"], 1000)
)

dist = DistPlot(:treatment_comparison, df, :df;
    value_col = :value,
    group_col = :group,
    slider_col = [:cohort],
    histogram_bins = 40,
    show_histogram = true,
    show_box = true,
    show_rug = true,
    title = "Treatment Effect Analysis",
    value_label = "Outcome Measure"
)
```

### Customized Distribution Plot

```julia
dist = DistPlot(:custom_dist, df, :df;
    value_col = :value,
    group_col = :group,
    histogram_bins = 50,
    show_histogram = true,
    show_box = true,
    show_rug = false,  # Hide rug plot
    box_opacity = 0.8,
    title = "Custom Distribution"
)
```

## TextBlock Examples

### Adding Documentation

```julia
intro = TextBlock("""
<h1>Quarterly Analysis Report</h1>
<p>This report presents the findings from Q1 2024 analysis.</p>
<h2>Key Highlights</h2>
<ul>
    <li>Revenue increased by 15%</li>
    <li>Customer satisfaction improved</li>
    <li>Operating costs decreased by 8%</li>
</ul>
""")

summary = TextBlock("""
<h2>Statistical Summary</h2>
<table border="1">
    <tr><th>Metric</th><th>Value</th><th>Change</th></tr>
    <tr><td>Mean Revenue</td><td>$125K</td><td>+12%</td></tr>
    <tr><td>Median Revenue</td><td>$118K</td><td>+10%</td></tr>
    <tr><td>Std Deviation</td><td>$23K</td><td>-5%</td></tr>
</table>
""")

# Combine with plots
page = JSPlotPage(
    Dict{Symbol,DataFrame}(:data => df),
    [intro, some_chart, summary],
    tab_title = "Q1 Report"
)
```

## Data Format Examples

### Using Embedded CSV (Default)

```julia
page = JSPlotPage(dataframes, plots)
create_html(page, "output.html")
```

### Using External JSON Files

```julia
page = JSPlotPage(dataframes, plots, dataformat=:json_external)
create_html(page, "output_dir/myplots.html")

# This creates:
# output_dir/myplots/myplots.html
# output_dir/myplots/data/*.json
# output_dir/myplots/open.sh
# output_dir/myplots/open.bat
```

### Using Parquet for Large Datasets

```julia
# Best for datasets > 50MB
page = JSPlotPage(large_dataframes, plots, dataformat=:parquet)
create_html(page, "large_data_analysis.html")
```

### Comparing Data Formats

```julia
# For small datasets: single file convenience
page1 = JSPlotPage(small_df_dict, plots, dataformat=:csv_embedded)
create_html(page1, "small_report.html")  # Single portable file

# For medium datasets: human-readable external files
page2 = JSPlotPage(medium_df_dict, plots, dataformat=:csv_external)
create_html(page2, "medium_analysis/report.html")  # Can inspect CSVs

# For large datasets: optimized binary format
page3 = JSPlotPage(large_df_dict, plots, dataformat=:parquet)
create_html(page3, "big_data/analysis.html")  # Fastest loading
```

## Picture Examples

### Basic Picture from File

```julia
# Display an existing image file
pic = Picture(:my_image, "examples/pictures/images.jpeg"; notes="Example visualization")
create_html(pic, "picture_display.html")
```

### Picture with VegaLite

```julia
using VegaLite, DataFrames

df = DataFrame(category = ["A", "B", "C"], value = [10, 20, 15])

# VegaLite plot - automatically detected
vl_plot = df |> @vlplot(
    :bar,
    x = :category,
    y = :value,
    title = "Bar Chart"
)

pic = Picture(:vegalite_chart, vl_plot; format=:svg, notes="Created with VegaLite")
create_html(pic, "vegalite_example.html")
```

### Picture with Plots.jl

```julia
using Plots

# Create a plot
p = plot(1:100, cumsum(randn(100)),
         title = "Random Walk",
         xlabel = "Time",
         ylabel = "Position",
         legend = false,
         linewidth = 2)

# Automatically detected as Plots.jl
pic = Picture(:plots_chart, p; format=:png)
create_html(pic, "plots_example.html")
```

### Picture with CairoMakie

```julia
using CairoMakie

# Create a Makie figure
fig = Figure(size = (800, 600))
ax = Axis(fig[1, 1], title = "Sine Wave", xlabel = "x", ylabel = "sin(x)")
x = 0:0.1:10
lines!(ax, x, sin.(x), linewidth = 3)

# Automatically detected as Makie
pic = Picture(:makie_plot, fig; format=:png)
create_html(pic, "makie_example.html")
```

### Picture with Custom Save Function

```julia
# For libraries not auto-detected, provide a save function
using MyCustomPlottingLib

chart = MyCustomPlottingLib.create_chart(data)

pic = Picture(:custom_chart, chart,
              (obj, path) -> MyCustomPlottingLib.save_to_file(obj, path);
              format=:png,
              notes="Custom plotting library")

create_html(pic, "custom_plot.html")
```

### Multiple Pictures on One Page

```julia
using Plots

# Create multiple plots
p1 = plot(sin, 0, 2π, title="Sine")
p2 = plot(cos, 0, 2π, title="Cosine")
p3 = plot(tan, 0, π/2, title="Tangent", ylims=(-5, 5))

pic1 = Picture(:sine_plot, p1)
pic2 = Picture(:cosine_plot, p2)
pic3 = Picture(:tangent_plot, p3)

intro = TextBlock("<h1>Trigonometric Functions</h1>")

page = JSPlotPage(
    Dict{Symbol,DataFrame}(),
    [intro, pic1, pic2, pic3],
    tab_title = "Trig Functions"
)

create_html(page, "trig_plots.html")
```

### Mixing Pictures with Interactive Plots

```julia
using Plots

# Static plot from Plots.jl
static_plot = plot(1:10, rand(10), title="Static Plot")
pic = Picture(:static, static_plot)

# Interactive JSPlots chart
df = DataFrame(x = 1:10, y = rand(10), color = repeat(["A"], 10))
interactive = LineChart(:interactive, df, :df; x_col=:x, y_col=:y)

page = JSPlotPage(
    Dict{Symbol,DataFrame}(:df => df),
    [pic, interactive]
)

create_html(page, "mixed_plots.html")
```

## Table Examples

### Basic Table

```julia
using DataFrames

df = DataFrame(
    Product = ["Widget", "Gadget", "Gizmo"],
    Price = [9.99, 14.99, 24.99],
    Stock = [100, 50, 25],
    Category = ["Tools", "Electronics", "Accessories"]
)

table = Table(:products, df; notes="Product inventory as of today")
create_html(table, "products.html")
```

### Table with Calculated Columns

```julia
sales_df = DataFrame(
    Month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
    Revenue = [45000, 52000, 48000, 61000, 58000, 67000],
    Expenses = [30000, 32000, 29000, 35000, 33000, 38000]
)

# Add calculated column
sales_df[!, :Profit] = sales_df.Revenue .- sales_df.Expenses
sales_df[!, :Margin] = round.((sales_df.Profit ./ sales_df.Revenue) .* 100, digits=1)

table = Table(:financial_summary, sales_df;
              notes="H1 2024 Financial Performance")

create_html(table, "finances.html")
```

### Multiple Tables on One Page

```julia
# Summary statistics table
summary_df = DataFrame(
    Metric = ["Mean", "Median", "Std Dev", "Min", "Max"],
    Value = [75.3, 74.0, 12.5, 45.0, 98.0]
)

# Detailed data table
detailed_df = DataFrame(
    ID = 1:10,
    Score = rand(50:100, 10),
    Grade = rand(["A", "B", "C"], 10)
)

summary_table = Table(:summary, summary_df)
detailed_table = Table(:details, detailed_df)

intro = TextBlock("<h1>Test Results Analysis</h1>")

page = JSPlotPage(
    Dict{Symbol,DataFrame}(),
    [intro, summary_table, detailed_table]
)

create_html(page, "test_results.html")
```

### Table with Charts

```julia
# Create a summary table
summary = DataFrame(
    Category = ["Sales", "Marketing", "Operations"],
    Q1 = [125000, 45000, 78000],
    Q2 = [142000, 52000, 81000],
    Q3 = [138000, 48000, 85000],
    Q4 = [156000, 61000, 92000]
)

table = Table(:quarterly_summary, summary;
              notes="Quarterly performance by department")

# Create a visualization of the same data
df_long = DataFrame(
    Quarter = repeat(["Q1", "Q2", "Q3", "Q4"], 3),
    Category = repeat(["Sales", "Marketing", "Operations"], inner=4),
    Amount = [125000, 142000, 138000, 156000,  # Sales
              45000, 52000, 48000, 61000,        # Marketing
              78000, 81000, 85000, 92000]        # Operations
)
df_long[!, :color] = df_long.Category

chart = LineChart(:trend, df_long, :df_long;
                  x_col = :Quarter,
                  y_col = :Amount,
                  color_col = :Category,
                  title = "Quarterly Trends")

page = JSPlotPage(
    Dict{Symbol,DataFrame}(:df_long => df_long),
    [table, chart],
    tab_title = "Department Performance"
)

create_html(page, "department_analysis.html")
```

## Advanced Examples

### Custom Page Title

```julia
page = JSPlotPage(
    dataframes,
    plots,
    tab_title = "My Custom Dashboard Title"
)
```

### Mixing All Plot Types

```julia
# Create one of each plot type
pivot = PivotTable(:pivot, :df1; rows=[:cat], vals=:val)
line = LineChart(:line, df2, :df2; x_col=:x, y_col=:y)
surface = Chart3d(:surf, :df3; x_col=:x, y_col=:y, z_col=:z)
scatter = ScatterPlot(:scatter, df4, :df4; x_col=:a, y_col=:b)
dist = DistPlot(:dist, df5, :df5; value_col=:value)
pic = Picture(:image, "examples/pictures/images.jpeg")
tbl = Table(:summary, summary_df)
text = TextBlock("<h2>Analysis Overview</h2><p>Comprehensive visualization</p>")

# Combine all
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :df1 => df1, :df2 => df2, :df3 => df3,
        :df4 => df4, :df5 => df5
    ),
    [text, tbl, pivot, line, surface, scatter, dist, pic],
    dataformat = :json_external,
    tab_title = "Complete Analysis"
)

create_html(page, "comprehensive/analysis.html")
```

### Multi-Page Reports with Pages and LinkList

The `Pages` struct allows you to create multi-page reports with a coverpage and navigation links.

```julia
using JSPlots, DataFrames, Dates

# Create sample data
dates = Date(2024, 1, 1):Day(1):Date(2024, 12, 31)
sales_df = DataFrame(
    Date = dates,
    Revenue = cumsum(randn(length(dates)) .* 1000 .+ 50000),
    Region = rand(["North", "South", "East", "West"], length(dates))
)

metrics_df = DataFrame(
    Month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun"], 2),
    Score = [85, 87, 89, 88, 90, 92, 91, 93, 95, 94, 96, 98],
    Category = vcat(repeat(["Satisfaction"], 6), repeat(["Quality"], 6))
)

# Page 1: Sales Analysis
revenue_chart = LineChart(:revenue, sales_df, :sales_data;
    x_cols = [:Date],
    y_cols = [:Revenue],
    color_cols = [:Region],
    title = "Revenue by Region"
)

page1 = JSPlotPage(
    Dict(:sales_data => sales_df),
    [TextBlock("<h2>Sales Performance</h2><p>Regional revenue trends.</p>"),
     revenue_chart],
    tab_title = "Sales",
    page_header = "Sales Analysis"
)

# Page 2: Quality Metrics
metrics_chart = LineChart(:metrics, metrics_df, :metrics_data;
    x_cols = [:Month],
    y_cols = [:Score],
    color_cols = [:Category],
    title = "Performance Metrics"
)

page2 = JSPlotPage(
    Dict(:metrics_data => metrics_df),
    [TextBlock("<h2>Quality Dashboard</h2><p>Track key metrics.</p>"),
     metrics_chart],
    tab_title = "Metrics",
    page_header = "Quality Metrics"
)

# Coverpage with navigation links
links = LinkList([
    ("Sales Analysis", "page_1.html", "Revenue trends across regions"),
    ("Quality Metrics", "page_2.html", "Customer satisfaction and quality scores")
])

coverpage = JSPlotPage(
    Dict{Symbol,DataFrame}(),
    [TextBlock("<h1>2024 Business Report</h1>"),
     links],
    tab_title = "Home"
)

# Create multi-page report
# All pages will use parquet format (overrides individual page formats)
# Data is shared across pages and saved only once
report = Pages(coverpage, [page1, page2], dataformat = :parquet)
create_html(report, "business_report.html")

# Output structure (flat, single-level folder):
# business_report/
#   ├── index.html (coverpage with links)
#   ├── page_1.html (sales analysis - at same level)
#   ├── page_2.html (quality metrics - at same level)
#   ├── data/
#   │   ├── sales_data.parquet (shared across all pages)
#   │   └── metrics_data.parquet (shared across all pages)
#   ├── open.sh (Linux/Mac launcher - opens index.html)
#   ├── open.bat (Windows launcher - opens index.html)
#   └── README.md
```

**Key Features:**
- **Flat Structure**: All HTML files at the same level (no nested folders per page)
- **Shared Data**: Data sources used by multiple pages are saved only once in common data/ folder
- **Format Override**: Specifying `dataformat` in `Pages` overrides all individual page formats
- **Easy Navigation**: Use `LinkList` on the coverpage with simple relative links (e.g., "page_1.html")
- **Launcher Scripts**: Generated scripts open the main page (coverpage) with proper browser permissions
