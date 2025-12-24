using JSPlots, DataFrames, Dates, Random, StableRNGs
rng = StableRNG(555)

println("Creating External Formats examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/external_formats_example.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>External Data Format Examples</h1>
<p>This page demonstrates different data storage formats available in JSPlots.</p>
<p>By default, data is embedded directly in the HTML file. For larger datasets, external formats can be more efficient.</p>
""")

format_explanation = TextBlock("""
<h2>Available Data Formats</h2>
<h3>JSON External (:json_external)</h3>
<p>Data is stored as .json files in a data/ subdirectory.</p>
<ul>
    <li><strong>Pros:</strong> Human-readable, widely compatible</li>
    <li><strong>Cons:</strong> Larger file size than Parquet</li>
</ul>

<h3>Parquet (:parquet)</h3>
<p>Data is stored as .parquet files in a data/ subdirectory.</p>
<ul>
    <li><strong>Pros:</strong> Binary format, smallest size, fastest loading</li>
    <li><strong>Cons:</strong> Not human-readable</li>
    <li><strong>Recommended:</strong> Best choice for production use</li>
</ul>

<h3>CSV External (:csv_external)</h3>
<p>Data is stored as .csv files in a data/ subdirectory.</p>
<ul>
    <li><strong>Pros:</strong> Human-readable, can be opened in spreadsheet applications</li>
    <li><strong>Cons:</strong> Moderate file size</li>
</ul>
""")

# Create sample data for time series
df = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 31),
    value = randn(rng, 31) .* 10 .+ 50,
    category = rand(rng, ["A", "B", "C"], 31),
    score = rand(rng, 1:100, 31)
)

# Create a line chart
line_chart = LineChart(:timeseries, df, :df;
    x_cols = [:date],
    y_cols = [:value],
    color_cols = [:category],
    title = "Time Series Data",
)

# Create stock data for scatter plot
stock_data = DataFrame(
    date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 3, 31), inner=3),
    symbol = repeat(["AAPL", "GOOGL", "MSFT"], outer=91),
    price = rand(rng, 273) .* 100 .+ 100,
    volume = rand(rng, 273) .* 1_000_000
)

scatter_chart = ScatterPlot(:stock_scatter, stock_data, :stock_data, [:volume, :price];
    color_cols = [:symbol],
    title = "Stock Price vs Volume"
)

usage_notes = TextBlock("""
<h2>Usage Notes</h2>
<p>This example uses Parquet format (the recommended format for production use).</p>
<p>To use external formats, simply set the <code>dataformat</code> parameter when creating a JSPlotPage:</p>
<pre><code>page = JSPlotPage(
    data_dict,
    plot_elements,
    dataformat = :parquet  # or :json_external, :csv_external
)</code></pre>
<p><strong>Important:</strong> When using external formats, you must use the provided launcher scripts (open.sh or open.bat) to avoid CORS errors when viewing files locally.</p>
""")

conclusion = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated external data formats:</p>
<ul>
    <li><strong>JSON External:</strong> Human-readable, widely compatible</li>
    <li><strong>Parquet:</strong> Binary format, smallest size, fastest loading (recommended)</li>
    <li><strong>CSV External:</strong> Human-readable, spreadsheet-compatible</li>
</ul>
<p><strong>File size comparison:</strong> Parquet is typically the smallest, followed by JSON, then CSV.</p>
<p><strong>Recommendation:</strong> Use Parquet format for production applications with larger datasets.</p>
""")

# Create single combined page using Parquet format (most efficient)
page = JSPlotPage(
    Dict{Symbol,DataFrame}(:df => df, :stock_data => stock_data),
    [header, format_explanation, line_chart, scatter_chart, usage_notes, conclusion],
    tab_title = "External Format Examples",
    dataformat = :parquet
)

create_html(page, "generated_html_examples/external_formats_examples.html")

println("\n" * "="^70)
println("External format examples created successfully!")
println("="^70)
println("\nFile created: generated_html_examples/external_formats_examples.html")
println("\nThis page demonstrates:")
println("  • Explanation of available formats (JSON, Parquet, CSV)")
println("  • Time series chart with external data")
println("  • Scatter plot with external data")
println("  • Usage notes and recommendations")
println("\nFormat used: Parquet (recommended for production)")
println("\nImportant: Use launcher scripts (open.sh or open.bat) to avoid CORS errors!")
println("\nFile size comparison:")
println("  - CSV: Human-readable, moderate size")
println("  - JSON: Human-readable, similar to CSV")
println("  - Parquet: Binary format, smallest size, fastest loading")
