using JSPlots, DataFrames, Dates, StableRNGs

println("Creating PivotTable examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(444)

# Prepare header
header = TextBlock("""
<h1>PivotTable Examples</h1>
<p>This page demonstrates the key features of interactive PivotTable plots in JSPlots.</p>
<ul>
    <li><strong>Basic pivot:</strong> Simple data aggregation with drag-and-drop</li>
    <li><strong>Custom heatmaps:</strong> Color-coded matrices with custom color scales</li>
    <li><strong>Different renderers:</strong> Table, Bar Chart, Line Chart, and more</li>
    <li><strong>Data filtering:</strong> Inclusions and exclusions to focus on specific data</li>
    <li><strong>Aggregations:</strong> Sum, Average, Count, and other aggregation functions</li>
    <li><strong>Combined with other plots:</strong> Mix PivotTables with LineCharts and 3D plots</li>
</ul>
<p><em>Tip: Drag and drop fields between Rows, Columns, and Values to reorganize!</em></p>
""")

# Example 1: Basic Sales Data Pivot Table
sales_df = DataFrame(
    Region = repeat(["North", "South", "East", "West"], inner=12),
    Month = repeat(["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], outer=4),
    Product = rand(rng, ["Widget", "Gadget", "Gizmo"], 48),
    Sales = rand(rng, 10000:50000, 48),
    Units = rand(rng, 50:200, 48)
)

pivot1 = PivotTable(:sales_pivot, :sales_data;
    rows = [:Region],
    cols = [:Month],
    vals = :Sales,
    aggregatorName = :Sum,
    rendererName = :Table,
    notes = "Basic pivot table - drag fields to reorganize rows and columns"
)

# Example 2: Heatmap with Custom Colors
performance_df = DataFrame(
    Employee = repeat(["Alice", "Bob", "Charlie", "Diana", "Eve"], inner=4),
    Quarter = repeat(["Q1", "Q2", "Q3", "Q4"], outer=5),
    Score = randn(rng, 20) .* 10 .+ 75,  # Scores around 75 with some variation
    Department = repeat(["Sales", "Engineering", "Sales", "Marketing", "Engineering"], inner=4)
)

pivot2 = PivotTable(:performance_heatmap, :performance_data;
    rows = [:Employee],
    cols = [:Quarter],
    vals = :Score,
    aggregatorName = :Average,
    rendererName = :Heatmap,
    colour_map = Dict{Float64,String}([50.0, 65.0, 75.0, 85.0, 100.0] .=>
                                      ["#d73027", "#fee08b", "#ffffbf", "#d9ef8b", "#1a9850"]),
    notes = "Custom color scale heatmap - green indicates good performance, red needs improvement"
)

# Example 3: Pivot Table with Bar Chart Renderer
product_data = DataFrame(
    Category = repeat(["Electronics", "Clothing", "Home", "Sports", "Books"], 20),
    Brand = rand(rng, ["Brand A", "Brand B", "Brand C", "Brand D"], 100),
    Revenue = rand(rng, 1000:10000, 100),
    Quarter = repeat(["Q1", "Q2", "Q3", "Q4"], 25)
)

pivot3 = PivotTable(:revenue_by_category, :product_data;
    rows = [:Category],
    cols = [:Quarter],
    vals = :Revenue,
    aggregatorName = :Sum,
    rendererName = Symbol("Bar Chart"),
    notes = "Bar chart renderer - switch renderer in the dropdown to see other visualizations"
)

# Example 4: Pivot Table with Exclusions
customer_df = DataFrame(
    Country = rand(rng, ["USA", "UK", "Germany", "France", "Japan", "Test"], 120),
    ProductType = rand(rng, ["Premium", "Standard", "Budget"], 120),
    Channel = rand(rng, ["Online", "Retail", "Wholesale"], 120),
    Revenue = rand(rng, 500:5000, 120),
    Year = repeat([2022, 2023, 2024], 40)
)

pivot4 = PivotTable(:customer_revenue, :customer_data;
    rows = [:Country],
    cols = [:ProductType],
    vals = :Revenue,
    exclusions = Dict(:Country => [:Test]),  # Exclude test data
    aggregatorName = :Sum,
    rendererName = :Heatmap,
    notes = "Exclusions feature - 'Test' country data is automatically filtered out"
)

# Example 5: Pivot with Inclusions
survey_df = DataFrame(
    Age_Group = rand(rng, ["18-25", "26-35", "36-45", "46-55", "56+"], 200),
    Gender = rand(rng, ["Male", "Female", "Other", "Prefer not to say"], 200),
    Satisfaction = rand(rng, 1:10, 200),
    Product = rand(rng, ["Product A", "Product B", "Product C"], 200),
    Region = rand(rng, ["North", "South", "East", "West"], 200)
)

pivot5 = PivotTable(:survey_results, :survey_data;
    rows = [:Age_Group, :Gender],
    cols = [:Product],
    vals = :Satisfaction,
    inclusions = Dict(:Age_Group => [Symbol("18-25"), Symbol("26-35"), Symbol("36-45")]),
    aggregatorName = :Average,
    rendererName = Symbol("Table Barchart"),
    notes = "Inclusions feature - only showing ages 18-45, filtering out older demographics"
)

# Example 6: Count Aggregation
transactions_df = DataFrame(
    Transaction_Type = rand(rng, ["Purchase", "Refund", "Exchange", "Cancel"], 500),
    Customer_Type = rand(rng, ["New", "Returning", "VIP"], 500),
    Payment_Method = rand(rng, ["Credit Card", "PayPal", "Bank Transfer", "Cash"], 500),
    Store = rand(rng, ["Store 1", "Store 2", "Store 3"], 500),
    Amount = rand(rng, 10:500, 500)
)

pivot6 = PivotTable(:transaction_analysis, :transaction_data;
    rows = [:Customer_Type],
    cols = [:Transaction_Type],
    vals = :Amount,
    aggregatorName = :Count,
    rendererName = :Heatmap,
    colour_map = Dict{Float64,String}([0.0, 50.0, 100.0, 150.0] .=>
                                      ["#f7fbff", "#9ecae1", "#4292c6", "#08519c"]),
    notes = "Count aggregation - showing transaction counts rather than sums or averages"
)

# Example 7: Stock Returns with Correlation Matrix
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

pivot7 = PivotTable(:Returns_Over_Last_Few_Days, :stockReturns;
    rows = [:Symbol],
    cols = [:Date],
    vals = :Return,
    exclusions = Dict(:Symbol => [:MSFT]),
    aggregatorName = :Average,
    rendererName = :Heatmap,
    notes = "Stock returns heatmap with MSFT excluded"
)

pivot8 = PivotTable(:Correlation_Matrix, :correlations;
    rows = [:Symbol1],
    cols = [:Symbol2],
    vals = :Correlation,
    colour_map = Dict{Float64,String}([-1.0, 0.0, 1.0] .=> ["#FF4545", "#ffffff", "#4F92FF"]),
    aggregatorName = :Average,
    rendererName = :Heatmap,
    notes = "Correlation matrix with custom red-white-blue color scale"
)

# Example 8: Combined with LineChart
df_line = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(rng, 10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df_line[!, :categ] .=  [ :B, :B, :B, :B, :B, :A, :A, :A, :A, :C]
df_line[!, :categ22] .= "Category_A"

df_line2 = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(rng, 10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df_line2[!, :categ] .= [:A, :A, :A, :A, :A, :B, :B, :B, :B, :C]
df_line2[!, :categ22] .= "Category_B"
df_combined = vcat(df_line, df_line2)

linechart = LineChart(:pchart, df_combined, :df_combined;
            x_cols=[:x],
            y_cols=[:y],
            color_cols=[:color],
            filters=Dict(:categ => :A, :categ22 => "Category_A"),
            title="Line Chart with Filters",
            notes="Interactive line chart with dropdown filters - combine with PivotTables!")

# Example 9: Combined with 3D Surface
subframe = allcombinations(DataFrame, x = collect(1:6), y = collect(1:6)); subframe[!, :group] .= "A";
sf2 = deepcopy(subframe); sf2[!, :group] .= "B"
sf3 = deepcopy(subframe); sf3[!, :group] .= "C"
sf4 = deepcopy(subframe); sf4[!, :group] .= "D"
subframe[!, :z] = cos.(sqrt.(subframe.x .^ 2 .+  subframe.y .^ 2))
sf2[!, :z] = cos.(sqrt.(sf2.x .^ 2 .+  sf2.y .^ 1)) .- 1.0
sf3[!, :z] = cos.(sqrt.(sf3.x .^ 2 .+  sf3.y .^ 0.5)) .+ 1.0
sf4[!, :z] = sqrt.(sf4.x) .- sqrt.(sf4.y)
subframe = reduce(vcat, [subframe, sf2, sf3, sf4])

surface3d = Surface3D(:threeD, subframe, :subframe;
        x_col = :x,
        y_col = :y,
        z_col = :z,
        group_col = :group,
        title = "3D Surface Chart",
        notes = "3D surface visualization grouped by mathematical functions"
    )

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Drag-and-drop interface:</strong> Reorganize data dynamically by dragging fields</li>
    <li><strong>Multiple renderers:</strong> Table, Heatmap, Bar Chart, Line Chart, and more</li>
    <li><strong>Custom color scales:</strong> Define your own color gradients for heatmaps</li>
    <li><strong>Aggregation functions:</strong> Sum, Average, Count, Median, Min, Max, etc.</li>
    <li><strong>Data filtering:</strong> Include or exclude specific values</li>
    <li><strong>Multi-level grouping:</strong> Use multiple row or column dimensions</li>
    <li><strong>Integration:</strong> Combine PivotTables with LineCharts, 3D plots, and more</li>
</ul>
<p><strong>Tip:</strong> Try dragging unused fields from the top into Rows or Columns!</p>
""")

# Create single combined page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :sales_data => sales_df,
        :performance_data => performance_df,
        :product_data => product_data,
        :customer_data => customer_df,
        :survey_data => survey_df,
        :transaction_data => transactions_df,
        :stockReturns => stockReturns,
        :correlations => correlations,
        :df_combined => df_combined,
        :subframe => subframe
    ),
    [header, pivot1, pivot2, pivot3, pivot4, pivot5, pivot6, pivot7, pivot8, linechart, surface3d, conclusion],
    tab_title = "PivotTable Examples",
    dataformat = :csv_embedded
)

create_html(page, "generated_html_examples/pivottable_examples.html")

println("\n" * "="^60)
println("PivotTable examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/pivottable_examples.html")
println("\nThis page includes:")
println("  • Basic pivot table with drag-and-drop")
println("  • Custom color scale heatmaps")
println("  • Different renderers (Table, Bar Chart)")
println("  • Data filtering with exclusions and inclusions")
println("  • Count aggregation")
println("  • Stock returns and correlation matrices")
println("  • Combined with LineChart and 3D Surface plots")
