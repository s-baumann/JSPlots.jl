using JSPlots, DataFrames, Dates, Random

# Create sample data
Random.seed!(42)
df = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 31),
    value = randn(31) .* 10 .+ 50,
    category = rand(["A", "B", "C"], 31),
    score = rand(1:100, 31)
)

# Create a line chart
line_chart = LineChart(:timeseries, df, :df;
    x_col = :date,
    y_col = :value,
    color_col = :category,
    title = "Time Series Data",
    x_label = "Date",
    y_label = "Value"
)

# Example 1: JSON External format
println("Creating JSON external format example...")
page_json = JSPlotPage(
    Dict{Symbol,DataFrame}(:df => df),
    [line_chart],
    tab_title = "JSON External Format",
    dataformat = :json_external
)
create_html(page_json, "generated_html_examples/json_external_example.html")
println()

# Example 2: Parquet format
println("Creating Parquet format example...")
page_parquet = JSPlotPage(
    Dict{Symbol,DataFrame}(:df => df),
    [line_chart],
    tab_title = "Parquet Format",
    dataformat = :parquet
)
create_html(page_parquet, "generated_html_examples/parquet_example.html")
println()

# Example 3: Comparison - create the same visualization with all external formats
stock_data = DataFrame(
    date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 3, 31), inner=3),
    symbol = repeat(["AAPL", "GOOGL", "MSFT"], outer=91),
    price = rand(273) .* 100 .+ 100,
    volume = rand(273) .* 1_000_000
)

scatter_chart = ScatterPlot(:stock_scatter, stock_data, :stock_data;
    x_col = :volume,
    y_col = :price,
    color_col = :symbol,
    title = "Stock Price vs Volume",
    x_label = "Volume",
    y_label = "Price"
)

# CSV External
println("Creating CSV external format comparison...")
page_csv = JSPlotPage(
    Dict{Symbol,DataFrame}(:stock_data => stock_data),
    [scatter_chart],
    tab_title = "CSV External Format",
    dataformat = :csv_external
)
create_html(page_csv, "generated_html_examples/comparison_csv.html")

# JSON External
println("Creating JSON external format comparison...")
page_json_comp = JSPlotPage(
    Dict{Symbol,DataFrame}(:stock_data => stock_data),
    [scatter_chart],
    tab_title = "JSON External Format",
    dataformat = :json_external
)
create_html(page_json_comp, "generated_html_examples/comparison_json.html")

# Parquet
println("Creating Parquet format comparison...")
page_parquet_comp = JSPlotPage(
    Dict{Symbol,DataFrame}(:stock_data => stock_data),
    [scatter_chart],
    tab_title = "Parquet Format",
    dataformat = :parquet
)
create_html(page_parquet_comp, "generated_html_examples/comparison_parquet.html")

println("\n" * "="^70)
println("External format examples created successfully!")
println("="^70)
println("\nFormats created:")
println("  1. JSON External - data stored as .json files")
println("  2. Parquet - data stored as .parquet files (most efficient)")
println("  3. CSV External - data stored as .csv files (baseline)")
println("\nAll formats include launcher scripts (open.sh and open.bat)")
println("Use the launcher scripts to avoid CORS errors!")
println("\nFile size comparison:")
println("  - CSV: Human-readable, moderate size")
println("  - JSON: Human-readable, similar to CSV")
println("  - Parquet: Binary format, smallest size, fastest loading")
