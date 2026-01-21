using JSPlots, DataFrames, Dates, StableRNGs

println("Creating comprehensive ScatterPlot examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(111)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/scatterplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>ScatterPlot Examples</h1>
<p>This page demonstrates 2D scatter plots with marginal distributions in JSPlots.</p>
""")

# Example 1: Multi-dimensional scatter with dimensions parameter
n = 300
df1 = DataFrame(
    mass = randn(rng, n) .* 10 .+ 70,
    height = randn(rng, n) .* 10 .+ 170,
    age = rand(rng, 20:60, n),
    bmi = zeros(n),
    gender = rand(rng, ["Male", "Female"], n),
    activity = rand(rng, ["Low", "Medium", "High"], n),
    color = repeat(["default"], n)
)
df1.bmi = df1.mass ./ ((df1.height ./100) .^ 2)

scatter1 = ScatterPlot(:multi_dim, df1, :df1, [:mass, :height, :age, :bmi];
    color_cols = [:gender],
    title = "Multi-Dimensional Health Data",
    notes = "Use the X and Y dropdowns to explore different dimension combinations. " *
           "Try: mass vs height, age vs bmi, etc. Marginal distributions show on both axes."
)

# Example 2: Multiple styling options (color, point type, point size)
n = 400
df2 = DataFrame(
    x = randn(rng, n) .* 10,
    y = randn(rng, n) .* 10,
    region = rand(rng, ["North", "South", "East", "West"], n),
    category = rand(rng, ["A", "B", "C"], n),
    priority = rand(rng, ["Low", "Medium", "High"], n),
    size_group = rand(rng, ["Small", "Medium", "Large"], n)
)

scatter2 = ScatterPlot(:multi_style, df2, :df2, [:x, :y];
    color_cols = [:region, :category, :priority],
    title = "Multiple Styling Options",
    notes = "Use the Color dropdown to change visual encoding. " *
           "Try different combinations to highlight different aspects of the data."
)

# Example 3: Faceting with single facet (marginals disappear when faceted)
n = 500
df3 = DataFrame(
    temperature = randn(rng, n) .* 5 .+ 20,
    humidity = randn(rng, n) .* 10 .+ 60,
    season = rand(rng, ["Spring", "Summer", "Fall", "Winter"], n),
    location = rand(rng, ["Urban", "Rural", "Coastal"], n),
    color = repeat(["Measurement"], n)
)

scatter3 = ScatterPlot(:facet_single, df3, :df3, [:temperature, :humidity];
    color_cols = [:location],
    facet_cols = [:season, :location],
    title = "Faceting Example - Weather Data",
    notes = "Use the 'Facet by' dropdown to split the data. " *
           "Notice: Marginal distributions appear when no faceting is selected, " *
           "but disappear when a facet is applied to save space."
)

# Example 4: Two-dimensional faceting (facet grid)
n = 600
df4 = DataFrame(
    score1 = randn(rng, n) .* 15 .+ 75,
    score2 = randn(rng, n) .* 12 .+ 70,
    grade = rand(rng, ["Freshman", "Sophomore", "Junior", "Senior"], n),
    major = rand(rng, ["Science", "Arts", "Engineering"], n),
    semester = rand(rng, ["Fall", "Spring"], n),
    performance = rand(rng, ["Below Average", "Average", "Above Average"], n),
    color = repeat(["Student"], n)
)

scatter4 = ScatterPlot(:facet_grid, df4, :df4,  [:score1, :score2];
    color_cols = [:performance],
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
    var1 = randn(rng, n) .* 20,
    var2 = randn(rng, n) .* 25,
    var3 = randn(rng, n) .* 15 .+ 50,
    var4 = randn(rng, n) .* 30 .+ 100,
    group_A = rand(rng, ["Group1", "Group2", "Group3"], n),
    group_B = rand(rng, ["TypeX", "TypeY", "TypeZ"], n),
    group_C = rand(rng, ["Class1", "Class2"], n),
    intensity = rand(rng, ["Low", "Medium", "High"], n)
)

scatter5 = ScatterPlot(:complex, df5, :df5,  [:var1, :var2, :var3, :var4];
    color_cols = [:group_A, :group_B, :group_C],
    facet_cols = [:group_C, :group_B],
    title = "Complex Multi-Dimensional Exploration",
    notes = "Demonstrates all features together: " *
           "4 dimensions for X/Y axes, multiple color options, and faceting. " *
           "Explore different combinations to find interesting patterns."
)

# Example 6: Time series scatter with filters
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
n = length(dates)
df6 = DataFrame(
    date = repeat(dates, outer=3),
    value1 = vcat(
        cumsum(randn(rng, n)) .+ 100,
        cumsum(randn(rng, n)) .+ 120,
        cumsum(randn(rng, n)) .+ 110
    ),
    value2 = vcat(
        cumsum(randn(rng, n)) .+ 50,
        cumsum(randn(rng, n)) .+ 55,
        cumsum(randn(rng, n)) .+ 52
    ),
    portfolio = repeat(["Portfolio A", "Portfolio B", "Portfolio C"], inner=n),
    quarter = map(d -> Dates.quarter(d), repeat(dates, outer=3)),
    color = repeat(["Investment"], n*3)
)

scatter6 = ScatterPlot(:timeseries, df6, :df6, [:value1, :value2];
    color_cols = [:portfolio],
    filters = Dict{Symbol, Any}(:quarter => [3]),
    title = "Time Series Scatter with Filters",
    notes = "Use date and quarter filters to focus on specific time periods. " *
           "Points are colored by portfolio to show different investment trajectories."
)

# Example 7: Using a Struct as Data Source
# Demonstrates passing a struct containing DataFrames and referencing fields via dot notation

struct ExperimentData
    measurements::DataFrame
    metadata::DataFrame
end

# Create measurement data for the struct
measurement_df = DataFrame(
    x_position = randn(rng, 200) .* 10,
    y_position = randn(rng, 200) .* 10,
    z_position = randn(rng, 200) .* 5,
    intensity = abs.(randn(rng, 200)) .* 100,
    experiment = rand(rng, ["Exp A", "Exp B", "Exp C"], 200),
    batch = rand(rng, ["Batch 1", "Batch 2"], 200)
)

metadata_df = DataFrame(
    experiment = ["Exp A", "Exp B", "Exp C"],
    researcher = ["Dr. Smith", "Dr. Jones", "Dr. Lee"],
    date = [Date(2024, 1, 15), Date(2024, 2, 20), Date(2024, 3, 10)]
)

experiment_data = ExperimentData(measurement_df, metadata_df)

struct_intro = TextBlock("""
<h2>Struct Data Source Example</h2>
<p>This scatter plot uses data from a struct containing multiple DataFrames.
The <code>ExperimentData</code> struct holds both measurements and metadata.
Charts reference the measurements DataFrame using <code>Symbol("experiment.measurements")</code>.</p>
""")

scatter7 = ScatterPlot(:struct_scatter, experiment_data.measurements, Symbol("experiment.measurements"),
    [:x_position, :y_position, :z_position, :intensity];
    color_cols = [:experiment, :batch],
    title = "Experiment Measurements from Struct Data Source",
    notes = "This example shows how to use a struct as a data source. The ExperimentData struct " *
           "contains measurements and metadata DataFrames. Access struct fields via dot notation."
)

# Create the page
data_dict = Dict{Symbol,Any}(
    :df1 => df1,
    :df2 => df2,
    :df3 => df3,
    :df4 => df4,
    :df5 => df5,
    :df6 => df6,
    :experiment => experiment_data  # Struct data source
)

page = JSPlotPage(
    data_dict,
    [header, scatter1, scatter2, scatter3, scatter4, scatter5, scatter6, struct_intro, scatter7];
    dataformat = :csv_embedded
)

# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="scatterplot_examples.html",
                               description="ScatterPlot Examples", date=today(),
                               extra_columns=Dict(:chart_type => "2D Charts", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/scatterplot_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("\n" * "="^60)
println("ScatterPlot examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/scatterplot_examples.html")
println("\nThis page includes:")
println("  • Multi-dimensional exploration (dimensions parameter)")
println("  • Multiple styling options (color)")
println("  • Single faceting (marginals disappear)")
println("  • Two-dimensional faceting (grid layout)")
println("  • Complex multi-feature example")
println("  • Time series with date filters")
println("  • Struct data source (referencing struct fields via dot notation)")
println("\nKey features demonstrated:")
println("  ✓ dimensions parameter for X/Y selection")
println("  ✓ Multiple color options")
println("  ✓ Faceting (1D and 2D)")
println("  ✓ Marginal distributions (appear/disappear with faceting)")
println("  ✓ Inline controls to save space")
println("  ✓ Only showing dropdowns when there are multiple options")
