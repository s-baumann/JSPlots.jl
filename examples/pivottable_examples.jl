using JSPlots, DataFrames, Dates, StableRNGs, TimeZones

println("Creating PivotTable examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(444)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/pivottable_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
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

# Example 9: Dataset Selection with Struct containing DataFrames
# This demonstrates the new feature where PivotTable can switch between multiple datasets

# Define a struct with DataFrame fields (including Union{Missing, DataFrame})
struct ExampleFrame
    aa::DataFrame
    bb::Union{Missing, DataFrame}
end

# Create the struct with two DataFrames
struct_df_aa = DataFrame(
    Category = repeat(["Electronics", "Clothing", "Food", "Sports"], 3),
    Quarter = repeat(["Q1", "Q2", "Q3"], inner=4),
    Sales = rand(rng, 5000:20000, 12),
    Units = rand(rng, 100:500, 12)
)

struct_df_bb = DataFrame(
    Department = repeat(["HR", "Engineering", "Sales", "Marketing"], 3),
    Month = repeat(["Jan", "Feb", "Mar"], inner=4),
    Headcount = rand(rng, 10:100, 12),
    Budget = rand(rng, 50000:200000, 12)
)

example_struct = ExampleFrame(struct_df_aa, struct_df_bb)

# Create a third standalone DataFrame
standalone_df = DataFrame(
    Region = repeat(["North", "South", "East", "West"], 4),
    Product = repeat(["Widget", "Gadget", "Gizmo", "Thingamajig"], inner=4),
    Revenue = rand(rng, 10000:50000, 16),
    Profit = rand(rng, 1000:10000, 16)
)

# Create PivotTable with dataset selection dropdown
# The three datasets are: example_struct.aa (→ Symbol("multi_data.aa")), example_struct.bb (→ Symbol("multi_data.bb")), and standalone_df
pivot9 = PivotTable(:dataset_selector_demo, [Symbol("multi_data.aa"), Symbol("multi_data.bb"), :standalone_data];
    rows = [:Category],  # Will work with first dataset only.
    aggregatorName = :Sum,
    rendererName = :Heatmap,
    notes = "Dataset selection demo - use the dropdown above to switch between three different datasets. The pivot table will reload with the new data while preserving your row/column selections where possible."
)

dataset_selection_text = TextBlock("""
<h2>Dataset Selection Feature</h2>
<p>This example demonstrates the new <strong>dataset selection</strong> feature in PivotTable. When multiple datasets are provided, a dropdown appears allowing you to switch between them dynamically.</p>
<h3>How it works:</h3>
<ul>
    <li><strong>Struct with DataFrames:</strong> We defined a struct <code>ExampleFrame</code> with fields <code>aa::DataFrame</code> and <code>bb::Union{Missing,DataFrame}</code></li>
    <li><strong>Automatic extraction:</strong> When you pass the struct to JSPlotPage, the DataFrames are automatically extracted with dot-prefixed names (e.g., <code>Symbol("multi_data.aa")</code>, <code>Symbol("multi_data.bb")</code>)</li>
    <li><strong>Multiple datasets:</strong> The PivotTable accepts a <code>Vector{Symbol}</code> of dataset labels instead of a single Symbol</li>
    <li><strong>Dynamic switching:</strong> Changing the dataset reloads the pivot table while preserving your current configuration</li>
</ul>
<p><em>Try switching between the three datasets using the dropdown above the pivot table!</em></p>
""")

# Example 10: Boxing Match Data with Date/DateTime/ZonedDateTime Columns
# This demonstrates handling of temporal columns in PivotTable
boxing_df = DataFrame(
    boxer1 = ["Tyson Fury", "Canelo Alvarez", "Oleksandr Usyk", "Naoya Inoue", "Terence Crawford",
              "Tyson Fury", "Canelo Alvarez", "Oleksandr Usyk", "Naoya Inoue", "Terence Crawford",
              "Gervonta Davis", "Shakur Stevenson", "Devin Haney", "Ryan Garcia", "Tank Davis"],
    boxer2 = ["Anthony Joshua", "Jermall Charlo", "Daniel Dubois", "Luis Nery", "Errol Spence",
              "Deontay Wilder", "Dmitry Bivol", "Tyson Fury", "Stephen Fulton", "Israil Madrimov",
              "Frank Martin", "Edwin De Los Santos", "Ryan Garcia", "Devin Haney", "Rolando Romero"],
    city = ["Riyadh", "Las Vegas", "London", "Tokyo", "Las Vegas",
            "Las Vegas", "Las Vegas", "Riyadh", "Tokyo", "Los Angeles",
            "Las Vegas", "Newark", "Las Vegas", "Las Vegas", "Brooklyn"],
    ticketsales = [85.5e6, 25.3e6, 32.1e6, 18.7e6, 45.2e6,
                   38.9e6, 28.4e6, 92.3e6, 15.2e6, 22.8e6,
                   19.5e6, 8.7e6, 35.6e6, 42.1e6, 16.3e6],
    date_announced = [Date(2024, 8, 15), Date(2024, 6, 1), Date(2024, 7, 20), Date(2024, 3, 10), Date(2024, 5, 5),
                      Date(2023, 8, 1), Date(2022, 3, 15), Date(2024, 10, 1), Date(2024, 1, 8), Date(2024, 6, 25),
                      Date(2024, 4, 15), Date(2024, 2, 28), Date(2023, 11, 1), Date(2024, 1, 20), Date(2023, 3, 10)],
    datetime_fight_starts = [DateTime(2024, 12, 21, 22, 0, 0), DateTime(2024, 9, 14, 20, 0, 0),
                             DateTime(2024, 9, 21, 21, 0, 0), DateTime(2024, 5, 6, 17, 0, 0),
                             DateTime(2024, 7, 29, 21, 0, 0), DateTime(2024, 3, 9, 20, 0, 0),
                             DateTime(2022, 5, 7, 21, 0, 0), DateTime(2024, 12, 21, 22, 0, 0),
                             DateTime(2024, 5, 6, 18, 0, 0), DateTime(2024, 8, 3, 21, 0, 0),
                             DateTime(2024, 6, 15, 22, 0, 0), DateTime(2024, 4, 13, 21, 0, 0),
                             DateTime(2023, 4, 22, 21, 0, 0), DateTime(2024, 4, 20, 21, 0, 0),
                             DateTime(2023, 5, 28, 21, 0, 0)],
    time_of_stoppage = [ZonedDateTime(DateTime(2024, 12, 21, 23, 45, 32), tz"Asia/Riyadh"),
                        ZonedDateTime(DateTime(2024, 9, 15, 0, 12, 18), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2024, 9, 21, 23, 28, 45), tz"Europe/London"),
                        ZonedDateTime(DateTime(2024, 5, 6, 18, 52, 11), tz"Asia/Tokyo"),
                        ZonedDateTime(DateTime(2024, 7, 29, 23, 18, 33), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2024, 3, 9, 21, 45, 0), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2022, 5, 8, 0, 35, 22), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2024, 12, 22, 0, 15, 0), tz"Asia/Riyadh"),
                        ZonedDateTime(DateTime(2024, 5, 6, 19, 28, 44), tz"Asia/Tokyo"),
                        ZonedDateTime(DateTime(2024, 8, 4, 0, 5, 17), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2024, 6, 16, 1, 22, 8), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2024, 4, 14, 0, 8, 55), tz"America/New_York"),
                        ZonedDateTime(DateTime(2023, 4, 23, 0, 45, 0), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2024, 4, 21, 0, 32, 19), tz"America/Los_Angeles"),
                        ZonedDateTime(DateTime(2023, 5, 29, 0, 18, 42), tz"America/New_York")]
)

pivot10 = PivotTable(:boxing_matches, :boxing_data;
    rows = [:city],
    cols = [:boxer1],
    vals = :ticketsales,
    aggregatorName = :Sum,
    rendererName = :Heatmap,
    colour_map = Dict{Float64,String}([0.0, 25e6, 50e6, 75e6, 100e6] .=>
                                      ["#f7fbff", "#9ecae1", "#4292c6", "#2171b5", "#084594"]),
    notes = "Boxing match data with Date, DateTime, and ZonedDateTime columns. Drag date_announced, datetime_fight_starts, or time_of_stoppage into rows/cols to pivot by temporal data."
)

boxing_text = TextBlock("""
<h2>Temporal Data in PivotTables</h2>
<p>This example demonstrates handling of different temporal column types in PivotTable:</p>
<ul>
    <li><strong>Date</strong> (<code>date_announced</code>): Simple date without time component</li>
    <li><strong>DateTime</strong> (<code>datetime_fight_starts</code>): Date with time, no timezone</li>
    <li><strong>ZonedDateTime</strong> (<code>time_of_stoppage</code>): Date with time and timezone information</li>
</ul>
<p>Try dragging the temporal columns into the Rows or Columns area to see how they are displayed and aggregated.</p>
""")

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Drag-and-drop interface:</strong> Reorganize data dynamically by dragging fields</li>
    <li><strong>Multiple renderers:</strong> Table, Heatmap, Bar Chart, Line Chart, and more</li>
    <li><strong>Custom color scales:</strong> Define your own color gradients for heatmaps</li>
    <li><strong>Aggregation functions:</strong> Sum, Average, Count, Median, Min, Max, etc.</li>
    <li><strong>Data filtering:</strong> Include or exclude specific values</li>
    <li><strong>Multi-level grouping:</strong> Use multiple row or column dimensions</li>
    <li><strong>Dataset selection:</strong> Switch between multiple datasets with a dropdown</li>
    <li><strong>Struct support:</strong> Automatically extract DataFrames from structs</li>
    <li><strong>Integration:</strong> Combine PivotTables with LineCharts, 3D plots, and more</li>
</ul>
<p><strong>Tip:</strong> Try dragging unused fields from the top into Rows or Columns!</p>
""")

# Create single combined page
# Note: example_struct is passed directly - its DataFrames are automatically extracted
# as :multi_data_aa and :multi_data_bb
page = JSPlotPage(
    Dict{Symbol,Any}(
        :sales_data => sales_df,
        :performance_data => performance_df,
        :product_data => product_data,
        :customer_data => customer_df,
        :survey_data => survey_df,
        :transaction_data => transactions_df,
        :stockReturns => stockReturns,
        :correlations => correlations,
        :multi_data => example_struct,  # Struct with DataFrames - extracted as :multi_data_aa, :multi_data_bb
        :standalone_data => standalone_df,
        :boxing_data => boxing_df
    ),
    [header, pivot1, pivot2, pivot3, pivot4, pivot5, pivot6, pivot7, pivot8, dataset_selection_text, pivot9, boxing_text, pivot10, conclusion],
    tab_title = "PivotTable Examples",
    dataformat = :csv_embedded
)

# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="pivottable_examples.html",
                               description="PivotTable Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Tables", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/pivottable_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

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
println("  • Dataset selection with struct containing DataFrames")
println("  • Boxing match data with Date/DateTime/ZonedDateTime columns")
