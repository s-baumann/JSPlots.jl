using JSPlots, DataFrames, Dates

println("Creating PivotTable and LineChart combined examples...")

# Prepare header
header = TextBlock("""
<h1>PivotTable and LineChart Combined Examples</h1>
<p>This page demonstrates combining PivotTables with LineCharts and 3D surface plots.</p>
<p>These examples show how different plot types can work together on a single page.</p>
""")

stockReturns = DataFrame(
    Symbol = ["RTX", "RTX", "RTX", "GOOG", "GOOG", "GOOG", "MSFT", "MSFT", "MSFT"],
    Date = Date.(["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03"]),
    Return = [10.01, -10.005, -0.5, 1.0, 0.01, -0.003, 0.008, 0.004, -0.002]
)   

correlations = DataFrame(
    Symbol1 = ["RTX", "RTX", "GOOG", "RTX", "GOOG", "MSFT", "GOOG", "MSFT", "MSFT",],
    Symbol2 = ["GOOG", "MSFT", "MSFT", "RTX", "GOOG", "MSFT", "RTX", "RTX", "GOOG",],
    Correlation = [-0.85, -0.75, 0.80, 1.0, 1.0, 1.0, -0.85, -0.75, 0.80]
)

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

pt2 = PivotTable(:Correlation_Matrix, :correlations;
    rows = [:Symbol1],
    cols = [:Symbol2],
    vals = :Correlation,
    colour_map = Dict{Float64,String}([-1.0, 0.0, 1.0] .=> ["#FF4545", "#ffffff", "#4F92FF"]),
    aggregatorName = :Average,
    rendererName = :Heatmap
)

subframe = allcombinations(DataFrame, x = collect(1:6), y = collect(1:6)); subframe[!, :group] .= "A";
sf2 = deepcopy(subframe); sf2[!, :group] .= "B"
sf3 = deepcopy(subframe); sf3[!, :group] .= "C"
sf4 = deepcopy(subframe); sf4[!, :group] .= "D"
subframe[!, :z] = cos.(sqrt.(subframe.x .^ 2 .+  subframe.y .^ 2))
sf2[!, :z] = cos.(sqrt.(sf2.x .^ 2 .+  sf2.y .^ 1)) .- 1.0
sf3[!, :z] = cos.(sqrt.(sf3.x .^ 2 .+  sf3.y .^ 0.5)) .+ 1.0
sf4[!, :z] = sqrt.(sf4.x) .- sqrt.(sf4.y)
subframe = reduce(vcat, [subframe, sf2, sf3, sf4])

pt3 = Surface3D(:threeD, subframe, :subframe;
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


df1 = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df1[!, :categ] .=  [ :B, :B, :B, :B, :B, :A, :A, :A, :A, :C]
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
            x_cols=[:x],
            y_cols=[:y],
            color_cols=[:color],
            filters=Dict(:categ => :A, :categ22 => "Category_A"),
            title="Line Chart with Filters",
            x_label="This is the x axis",
            y_label="This is the y axis",
            notes="Interactive line chart with dropdown filters")

conclusion = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated combining different plot types:</p>
<ul>
    <li><strong>PivotTable:</strong> Stock returns heatmap with exclusions</li>
    <li><strong>LineChart:</strong> Time series with interactive filters</li>
    <li><strong>PivotTable Heatmap:</strong> Correlation matrix with custom color scale</li>
    <li><strong>3D Surface Chart:</strong> Mathematical surfaces grouped by type</li>
</ul>
<p><strong>Tip:</strong> You can combine any plot types on a single page using JSPlotPage!</p>
""")

# Create single combined page with all plot types
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :stockReturns => stockReturns,
        :correlations => correlations,
        :subframe => subframe,
        :df => df
    ),
    [header, pt, pt00, pt2, pt3, conclusion],
    dataformat = :parquet,
    tab_title = "Combined Examples"
)

create_html(page, "generated_html_examples/pivottable_linechart_examples.html")

println("\n" * "="^60)
println("Combined examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/pivottable_linechart_examples.html")
println("\nThis page includes:")
println("  • PivotTable with stock returns heatmap")
println("  • LineChart with interactive filters")
println("  • Correlation matrix heatmap")
println("  • 3D surface charts")
println("\nDemonstrates combining multiple plot types on one page!")