using JSPlots, DataFrames, Dates, Random

Random.seed!(42)

println("Creating comprehensive ScatterPlot examples...")

# Example 1: Multi-dimensional scatter with dimensions parameter
n = 300
df1 = DataFrame(
    mass = randn(n) .* 10 .+ 70,
    height = randn(n) .* 10 .+ 170,
    age = rand(20:60, n),
    bmi = zeros(n),
    gender = rand(["Male", "Female"], n),
    activity = rand(["Low", "Medium", "High"], n),
    color = repeat(["default"], n)
)
df1.bmi = df1.mass ./ ((df1.height ./100) .^ 2)

scatter1 = ScatterPlot(:multi_dim, df1, :df1, [:mass, :height, :age, :bmi];
    color_cols = [:color],
    pointtype_cols = [:color],
    pointsize_cols = [:color],
    title = "Multi-Dimensional Health Data",
    notes = "Use the X and Y dropdowns to explore different dimension combinations. " *
           "Try: mass vs height, age vs bmi, etc. Marginal distributions show on both axes."
)

# Example 2: Multiple styling options (color, point type, point size)
n = 400
df2 = DataFrame(
    x = randn(n) .* 10,
    y = randn(n) .* 10,
    region = rand(["North", "South", "East", "West"], n),
    category = rand(["A", "B", "C"], n),
    priority = rand(["Low", "Medium", "High"], n),
    size_group = rand(["Small", "Medium", "Large"], n)
)

scatter2 = ScatterPlot(:multi_style, df2, :df2, [:x, :y];
    color_cols = [:region, :category, :priority],
    pointtype_cols = [:region, :category, :priority],
    pointsize_cols = [:region, :size_group, :priority],
    title = "Multiple Styling Options",
    notes = "Use the Color, Point type, and Point size dropdowns to change visual encoding. " *
           "Try different combinations to highlight different aspects of the data."
)

# Example 3: Faceting with single facet (marginals disappear when faceted)
n = 500
df3 = DataFrame(
    temperature = randn(n) .* 5 .+ 20,
    humidity = randn(n) .* 10 .+ 60,
    season = rand(["Spring", "Summer", "Fall", "Winter"], n),
    location = rand(["Urban", "Rural", "Coastal"], n),
    color = repeat(["Measurement"], n)
)

scatter3 = ScatterPlot(:facet_single, df3, :df3, [:temperature, :humidity];
    color_cols = [:color],
    pointtype_cols = [:color],
    pointsize_cols = [:color],
    facet_cols = [:season, :location],
    title = "Faceting Example - Weather Data",
    notes = "Use the 'Facet by' dropdown to split the data. " *
           "Notice: Marginal distributions appear when no faceting is selected, " *
           "but disappear when a facet is applied to save space."
)

# Example 4: Two-dimensional faceting (facet grid)
n = 600
df4 = DataFrame(
    score1 = randn(n) .* 15 .+ 75,
    score2 = randn(n) .* 12 .+ 70,
    grade = rand(["Freshman", "Sophomore", "Junior", "Senior"], n),
    major = rand(["Science", "Arts", "Engineering"], n),
    semester = rand(["Fall", "Spring"], n),
    performance = rand(["Below Average", "Average", "Above Average"], n),
    color = repeat(["Student"], n)
)

scatter4 = ScatterPlot(:facet_grid, df4, :df4,  [:score1, :score2];
    color_cols = [:color],
    pointtype_cols = [:color],
    pointsize_cols = [:color],
    facet_cols = [:grade, :major, :semester],
    default_facet_cols = [:grade, :major],
    title = "Two-Dimensional Faceting - Student Performance",
    notes = "Uses Facet 1 and Facet 2 to create a grid of subplots. " *
           "Default shows grade × major. Try different combinations like semester × major. " *
           "Set either facet to 'None' to reduce to single facet or no faceting."
)

# Example 5: Complex multi-everything example
n = 800
df5 = DataFrame(
    var1 = randn(n) .* 20,
    var2 = randn(n) .* 25,
    var3 = randn(n) .* 15 .+ 50,
    var4 = randn(n) .* 30 .+ 100,
    group_A = rand(["Group1", "Group2", "Group3"], n),
    group_B = rand(["TypeX", "TypeY", "TypeZ"], n),
    group_C = rand(["Class1", "Class2"], n),
    intensity = rand(["Low", "Medium", "High"], n)
)

scatter5 = ScatterPlot(:complex, df5, :df5,  [:var1, :var2, :var3, :var4];
    color_cols = [:group_A, :group_B, :group_C],
    pointtype_cols = [:group_A, :group_B, :intensity],
    pointsize_cols = [:group_A, :intensity],
    facet_cols = [:group_C, :group_B],
    title = "Complex Multi-Dimensional Exploration",
    notes = "Demonstrates all features together: " *
           "4 dimensions for X/Y axes, multiple color/shape/size options, and faceting. " *
           "Explore different combinations to find interesting patterns."
)

# Example 6: Time series scatter with filters
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
n = length(dates)
df6 = DataFrame(
    date = repeat(dates, outer=3),
    value1 = vcat(
        cumsum(randn(n)) .+ 100,
        cumsum(randn(n)) .+ 120,
        cumsum(randn(n)) .+ 110
    ),
    value2 = vcat(
        cumsum(randn(n)) .+ 50,
        cumsum(randn(n)) .+ 55,
        cumsum(randn(n)) .+ 52
    ),
    portfolio = repeat(["Portfolio A", "Portfolio B", "Portfolio C"], inner=n),
    quarter = map(d -> Dates.quarter(d), repeat(dates, outer=3)),
    color = repeat(["Investment"], n*3)
)

scatter6 = ScatterPlot(:timeseries, df6, :df6, [:value1, :value2];
    color_cols = [:portfolio, :color],
    pointtype_cols = [:portfolio, :color],
    pointsize_cols = [:portfolio, :color],
    slider_col = [:date, :quarter],
    title = "Time Series Scatter with Filters",
    notes = "Use date range slider and quarter filter to focus on specific time periods. " *
           "Switch between viewing by portfolio or as aggregate using the color dropdown."
)

# Create the page
data_dict = Dict{Symbol,DataFrame}(
    :df1 => df1,
    :df2 => df2,
    :df3 => df3,
    :df4 => df4,
    :df5 => df5,
    :df6 => df6
)

page = JSPlotPage(
    data_dict,
    [scatter1, scatter2, scatter3, scatter4, scatter5, scatter6];
    dataformat = :parquet
)

create_html(page, "generated_html_examples/scatterplot_examples.html")

println("\n" * "="^60)
println("ScatterPlot examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/scatterplot_examples.html")
println("\nThis page includes:")
println("  • Multi-dimensional exploration (dimensions parameter)")
println("  • Multiple styling options (color, point type, point size)")
println("  • Single faceting (marginals disappear)")
println("  • Two-dimensional faceting (grid layout)")
println("  • Complex multi-feature example")
println("  • Time series with date filters")
println("\nKey features demonstrated:")
println("  ✓ dimensions parameter for X/Y selection")
println("  ✓ Multiple options for color, point type, and point size")
println("  ✓ Faceting (1D and 2D)")
println("  ✓ Marginal distributions (appear/disappear with faceting)")
println("  ✓ Inline controls to save space")
println("  ✓ Only showing dropdowns when there are multiple options")
