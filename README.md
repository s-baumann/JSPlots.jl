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


