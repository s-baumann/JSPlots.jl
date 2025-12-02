# JSPlots

This is a Julia package for creating interactive JavaScript-based visualizations. It includes support for pivot tables (via PivotTableJS), line charts, 3D charts, scatter plots, and distribution plots using Plotly.js. You can embed your data into HTML pages and visualize them interactively.

The pivot table functionality is a wrapper over PivotTableJS (examples: https://pivottable.js.org/examples/index.html), similar to the [python module](https://pypi.org/project/pivottablejs/). You can put multiple different charts and tables onto the same page (either sharing or not sharing data sources). It is also easy to change the colour mapping for use in HeatMap.

As an example see the following. This produces the file pivottable.html

```

using JSPlots, DataFrames, Dates

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
            x_col=:x,
            y_col=:y,
            color_col=:color,
            filters=Dict(:categ => :A, :categ22 => "Category_A"),
            title="Line Chart",
            x_label="This is the x axis",
            y_label="This is the y axis")


# To plot both of these together we can do:
pge = JSPlotPage(Dict{Symbol,DataFrame}(:stockReturns => stockReturns, :correlations => correlations, :subframe => subframe, :df => df), [pt, pt00, pt2, pt3])
create_html(pge,"pivottable.html")


# Or if you are only charting one single pivottable you dont have to make a JSPlotPage, you can simply do:
create_html(pt, stockReturns, "only_one.html")


```

## Data Format Options

JSPlots supports five different data embedding formats, which you can specify using the `dataformat` parameter when creating a `JSPlotPage`:

### 1. `:csv_embedded` (Default)

Data is embedded directly into the HTML file as CSV text within `<script>` tags.

**Advantages:**
- Single self-contained HTML file
- No external dependencies
- Easy to share and distribute
- Works when opened directly in a browser

**Disadvantages:**
- Large datasets result in very large HTML files
- Slower initial page load for large datasets
- Higher memory usage in browser

**Usage:**
```julia
page = JSPlotPage(dataframes, plots, dataformat=:csv_embedded)
create_html(page, "output.html")
```

### 2. `:json_embedded`

Data is embedded directly into the HTML file as JSON within `<script>` tags.

**Advantages:**
- Single self-contained HTML file
- Often slightly more compact than CSV for complex data structures
- Preserves data types more reliably
- Works when opened directly in a browser

**Disadvantages:**
- Large datasets result in very large HTML files
- May be slower to parse than CSV for simple tabular data

**Usage:**
```julia
page = JSPlotPage(dataframes, plots, dataformat=:json_embedded)
create_html(page, "output.html")
```

### 3. `:csv_external`

Data is saved as separate CSV files in a `data/` subdirectory, and the HTML references these files.

**Advantages:**
- Much smaller HTML file size
- Faster page load for large datasets
- Easier to inspect and edit data separately
- Better for version control (can diff data and HTML separately)
- CSV files can be reused by other tools

**Disadvantages:**
- Requires multiple files (HTML + CSV files + launcher scripts)
- Browsers block local file access by default (CORS)
- Must use provided launcher scripts to open with proper browser flags

**Usage:**
```julia
page = JSPlotPage(dataframes, plots, dataformat=:csv_external)
create_html(page, "output_dir/myplots.html")
```

**Output structure:**
When you specify `"output_dir/myplots.html"`, it creates a project folder structure:
```
output_dir/
└── myplots/              # Project folder (named after HTML file)
    ├── myplots.html      # Main HTML file
    ├── open.bat          # Windows launcher script
    ├── open.sh           # Linux/macOS launcher script
    └── data/             # Data subdirectory
        ├── dataset1.csv
        ├── dataset2.csv
        └── dataset3.csv
```

**Opening the HTML:**

⚠️ **IMPORTANT:** Do NOT open the HTML file directly! You will get CORS errors. Always use the launcher scripts.

- **Windows:** Double-click `open.bat` or run it from command prompt
- **Linux/macOS:** Run `./open.sh` from terminal (the script is automatically made executable)

The launcher scripts will try to open the HTML in the following order:
1. Brave Browser (with `--allow-file-access-from-files` flag)
2. Google Chrome (with `--allow-file-access-from-files` flag)
3. Firefox
4. System default browser

**Note:** The `--allow-file-access-from-files` flag is required for Chromium-based browsers to allow the HTML to load local CSV files. Firefox doesn't require special flags for local file access.

### 4. `:json_external`

Data is saved as separate JSON files in a `data/` subdirectory, and the HTML references these files.

**Advantages:**
- Much smaller HTML file size
- Faster page load for large datasets
- JSON preserves data types better than CSV
- Better for version control (can diff data and HTML separately)
- JSON files can be easily consumed by other tools and languages

**Disadvantages:**
- Requires multiple files (HTML + JSON files + launcher scripts)
- Browsers block local file access by default (CORS)
- Must use provided launcher scripts to open with proper browser flags
- Slightly larger file size than Parquet for large datasets

**Usage:**
```julia
page = JSPlotPage(dataframes, plots, dataformat=:json_external)
create_html(page, "output_dir/myplots.html")
```

**Output structure:**
```
output_dir/
└── myplots/              # Project folder (named after HTML file)
    ├── myplots.html      # Main HTML file
    ├── open.bat          # Windows launcher script
    ├── open.sh           # Linux/macOS launcher script
    └── data/             # Data subdirectory
        ├── dataset1.json
        ├── dataset2.json
        └── dataset3.json
```

### 5. `:parquet`

Data is saved as separate Parquet files in a `data/` subdirectory, and the HTML references these files. Parquet is a columnar binary format optimized for analytics workloads.

**Advantages:**
- **Smallest file size** - Highly compressed binary format
- **Fastest loading** - Efficient binary parsing
- Much smaller HTML file size
- Industry-standard format used by data engineering tools
- Excellent for very large datasets
- Better for version control

**Disadvantages:**
- Requires multiple files (HTML + Parquet files + launcher scripts)
- Browsers block local file access by default (CORS)
- Must use provided launcher scripts to open with proper browser flags
- Binary format (not human-readable)
- Requires parquet-wasm library to be loaded in browser

**Usage:**
```julia
page = JSPlotPage(dataframes, plots, dataformat=:parquet)
create_html(page, "output_dir/myplots.html")
```

**Output structure:**
```
output_dir/
└── myplots/              # Project folder (named after HTML file)
    ├── myplots.html      # Main HTML file
    ├── open.bat          # Windows launcher script
    ├── open.sh           # Linux/macOS launcher script
    └── data/             # Data subdirectory
        ├── dataset1.parquet
        ├── dataset2.parquet
        └── dataset3.parquet
```

**Note:** Parquet format requires DuckDB.jl for writing files and uses parquet-wasm for reading in the browser.

## Choosing a Data Format

**Use `:csv_embedded` when:**
- You want a single file to share
- Your datasets are small to medium sized (< 10MB total)
- You need maximum portability
- You're emailing or uploading to web hosting

**Use `:json_embedded` when:**
- You want a single file to share
- Your data has complex nested structures
- You need precise data type preservation
- Your datasets are small to medium sized

**Use `:csv_external` when:**
- You have large datasets (> 10MB)
- You want to keep HTML and data separate
- You're using version control
- You need to frequently update data without regenerating HTML
- You want to inspect or edit the data with text editors or spreadsheet tools
- Human readability of data files is important

**Use `:json_external` when:**
- You have large datasets (> 10MB)
- You want to keep HTML and data separate
- Data type preservation is critical (dates, numbers, booleans)
- You need to share data with other JavaScript/web applications
- You're using version control
- Human readability of data files is important

**Use `:parquet` when:**
- You have very large datasets (> 50MB)
- File size and loading speed are critical
- You're working with data engineering/analytics pipelines
- You don't need human-readable data files
- You want the best compression and performance
- You're using version control (smallest diffs for data changes)

## Plot Types Reference

JSPlots provides six different plot types, each designed for specific visualization needs.

### PivotTable

Interactive pivot table using PivotTable.js library. Allows dynamic reorganization and aggregation of data.

**Constructor:**
```julia
PivotTable(chart_title::Symbol, data_label::Symbol;
    rows = missing,              # Column(s) for rows
    cols = missing,              # Column(s) for columns
    vals = missing,              # Column for values
    inclusions = missing,        # Dict of values to include
    exclusions = missing,        # Dict of values to exclude
    colour_map = Dict(...),      # Custom color mapping for heatmaps
    aggregatorName = :Average,   # Aggregation function
    extrapolate_colours = false, # Extrapolate color scale
    rendererName = :Heatmap,     # Renderer type
    rendererOptions = missing,   # Custom renderer options
    notes = ""                   # Description text
)
```

**Example:**
```julia
df = DataFrame(
    Product = ["A", "A", "B", "B"],
    Region = ["North", "South", "North", "South"],
    Sales = [100, 150, 200, 175]
)

pt = PivotTable(:sales_pivot, :df;
    rows = [:Product],
    cols = [:Region],
    vals = :Sales,
    aggregatorName = :Sum,
    rendererName = :Heatmap
)
```

**Features:**
- Interactive drag-and-drop interface
- Multiple aggregation functions (Sum, Average, Count, etc.)
- Various renderers (Table, Heatmap, Bar Chart, Line Chart)
- Custom color scales for heatmaps
- Filtering with inclusions/exclusions

---

### LineChart

Time series or sequential data visualization with line plots.

**Constructor:**
```julia
LineChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
    x_col::Symbol,               # X-axis column
    y_col::Symbol,               # Y-axis column
    color_col = missing,         # Column for color grouping
    filters = Dict{Symbol,Any}(), # Default filter values
    title = "",                  # Chart title
    x_label = "",                # X-axis label
    y_label = "",                # Y-axis label
    notes = ""                   # Description text
)
```

**Example:**
```julia
df = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 31),
    temperature = randn(31) .+ 20,
    city = repeat(["NYC", "LA"], 16)[1:31]
)

chart = LineChart(:temp_chart, df, :df;
    x_col = :date,
    y_col = :temperature,
    color_col = :city,
    title = "Daily Temperature",
    x_label = "Date",
    y_label = "Temperature (°C)"
)
```

**Features:**
- Multiple line series with color grouping
- Interactive filtering with dropdown menus
- Automatic legend generation
- Hover tooltips showing data points
- Responsive sizing

---

### Chart3d

Three-dimensional surface plots for visualizing functions of two variables.

**Constructor:**
```julia
Chart3d(chart_title::Symbol, data_label::Symbol;
    x_col::Symbol,           # X-axis column
    y_col::Symbol,           # Y-axis column
    z_col::Symbol,           # Z-axis (height) column
    group_col = missing,     # Column for multiple surfaces
    title = "",              # Chart title
    x_label = "",            # X-axis label
    y_label = "",            # Y-axis label
    z_label = "",            # Z-axis label
    notes = ""               # Description text
)
```

**Example:**
```julia
df = allcombinations(DataFrame, x = 1:20, y = 1:20)
df[!, :z] = sin.(sqrt.(df.x.^2 .+ df.y.^2))

chart = Chart3d(:surface, :df;
    x_col = :x,
    y_col = :y,
    z_col = :z,
    title = "3D Surface Plot",
    x_label = "X",
    y_label = "Y",
    z_label = "Z = sin(√(x²+y²))"
)
```

**Features:**
- Interactive 3D rotation and zoom
- Multiple surface groups with distinct colors
- Automatic color gradient assignment
- Surface interpolation from scattered points
- Configurable axes labels

---

### ScatterPlot

Scatter plots with optional marginal distributions and interactive filtering.

**Constructor:**
```julia
ScatterPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
    x_col::Symbol,                    # X-axis column
    y_col::Symbol,                    # Y-axis column
    color_col = missing,              # Column for color grouping
    slider_col = missing,             # Column(s) for filter sliders
    marker_size = 5,                  # Point size
    marker_opacity = 0.7,             # Point transparency
    show_marginals = true,            # Show marginal histograms
    title = "",                       # Chart title
    x_label = "",                     # X-axis label
    y_label = "",                     # Y-axis label
    notes = ""                        # Description text
)
```

**Example:**
```julia
df = DataFrame(
    height = randn(500) .* 10 .+ 170,
    weight = randn(500) .* 15 .+ 70,
    gender = rand(["Male", "Female"], 500),
    age = rand(20:60, 500)
)

scatter = ScatterPlot(:height_weight, df, :df;
    x_col = :height,
    y_col = :weight,
    color_col = :gender,
    slider_col = [:age, :gender],
    title = "Height vs Weight",
    x_label = "Height (cm)",
    y_label = "Weight (kg)"
)
```

**Features:**
- Interactive range and category sliders
- Multiple slider types (continuous, categorical, date)
- Marginal distribution histograms
- Color-coded groups
- Customizable marker appearance
- Real-time filtering

---

### DistPlot

Distribution visualization combining histogram, box plot, and rug plot.

**Constructor:**
```julia
DistPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
    value_col::Symbol,              # Column with values to plot
    group_col = missing,            # Column for group comparison
    slider_col = missing,           # Column(s) for filter sliders
    histogram_bins = 30,            # Number of histogram bins
    show_histogram = true,          # Show histogram
    show_box = true,                # Show box plot
    show_rug = true,                # Show rug plot
    box_opacity = 0.6,              # Box plot transparency
    title = "",                     # Chart title
    value_label = "",               # Value axis label
    notes = ""                      # Description text
)
```

**Example:**
```julia
df = DataFrame(
    score = vcat(randn(300) .* 10 .+ 75, randn(200) .* 8 .+ 85),
    group = vcat(fill("Control", 300), fill("Treatment", 200)),
    age_group = rand(["18-30", "31-50", "51+"], 500)
)

dist = DistPlot(:score_dist, df, :df;
    value_col = :score,
    group_col = :group,
    slider_col = [:group, :age_group],
    histogram_bins = 40,
    title = "Test Score Distribution",
    value_label = "Score"
)
```

**Features:**
- Three complementary visualizations (histogram, box, rug)
- Group comparison with overlaid distributions
- Interactive filtering
- Configurable bin counts
- Toggle individual plot components
- Outlier detection via box plots

---

### TextBlock

HTML text block for adding formatted text, tables, and documentation to plot pages.

**Constructor:**
```julia
TextBlock(html_content::String)
```

**Example:**
```julia
intro = TextBlock("""
<h2>Analysis Report</h2>
<p>This report presents findings from our study conducted in Q1 2024.</p>
<ul>
    <li>Sample size: 1,000 participants</li>
    <li>Duration: 3 months</li>
    <li>Methods: Double-blind randomized trial</li>
</ul>
""")

summary = TextBlock("""
<h2>Key Findings</h2>
<table>
    <tr><th>Metric</th><th>Control</th><th>Treatment</th></tr>
    <tr><td>Mean</td><td>72.3</td><td>78.9</td></tr>
    <tr><td>Std Dev</td><td>8.2</td><td>7.1</td></tr>
</table>
""")
```

**Supported HTML:**
- Headings (`<h1>` to `<h6>`)
- Paragraphs (`<p>`)
- Lists (`<ul>`, `<ol>`, `<li>`)
- Tables (`<table>`, `<tr>`, `<td>`, `<th>`)
- Text formatting (`<strong>`, `<em>`, `<code>`)
- Links (`<a>`)
- Blockquotes (`<blockquote>`)

**Features:**
- No data dependencies (doesn't require DataFrame)
- Full HTML support with automatic styling
- Mix with plots on the same page
- Ideal for annotations, explanations, and summaries

---

## Combining Multiple Plots

You can combine multiple plot types and text blocks on a single page:

```julia
# Create plots
line = LineChart(:trends, df1, :df1; x_col=:date, y_col=:value)
scatter = ScatterPlot(:correlation, df2, :df2; x_col=:x, y_col=:y)
pivot = PivotTable(:summary, :df3; rows=[:category], vals=:amount)
intro = TextBlock("<h1>Analysis Dashboard</h1><p>Overview of results</p>")

# Combine into single page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(:df1 => df1, :df2 => df2, :df3 => df3),
    [intro, line, scatter, pivot],
    tab_title = "My Analysis"
)

create_html(page, "dashboard.html")
```

The plots will appear in the order specified in the array, with each properly spaced and labeled.


