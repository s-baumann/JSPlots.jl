```@meta
CurrentModule = JSPlots
```

# API Reference

This page documents all public types and functions in the JSPlots package.

```@index
Pages = ["api.md"]
```

## Main Types

### JSPlotPage

```@docs
JSPlotPage
```

A container for a single HTML page with plots and data.

**Parameters:**
- `dataframes::Dict{Symbol,DataFrame}`: Dictionary mapping data labels to DataFrames
- `pivot_tables::Vector`: Vector of plot objects (charts, tables, text blocks, etc.)

**Keyword Arguments:**
- `tab_title::String`: Browser tab title (default: `"JSPlots.jl"`)
- `page_header::String`: Main page heading (default: `""`)
- `notes::String`: Page description or notes (default: `""`)
- `dataformat::Symbol`: Data storage format - `:csv_embedded`, `:json_embedded`, `:csv_external`, `:json_external`, or `:parquet` (default: `:csv_embedded`)

### Pages

```@docs
Pages
```

A container for multiple linked HTML pages with a coverpage, enabling multi-page reports with shared data.

**Parameters:**
- `coverpage::JSPlotPage`: The main landing page (index page) for the report
- `pages::Vector{JSPlotPage}`: Vector of additional pages to include

**Keyword Arguments:**
- `dataformat::Union{Nothing,Symbol}`: Optional data format override that applies to all pages (default: `nothing`, uses coverpage format)

**Features:**
- Creates a flat project folder structure with all HTML files at the same level
- Main page and numbered sub-pages (page_1.html, page_2.html, etc.) all in project root
- Shared data sources are saved only once in a common data/ subfolder
- Generates launcher scripts (open.sh, open.bat) at project root that open the coverpage
- Users navigate to sub-pages through simple relative links (e.g., "page_1.html")
- When `dataformat` is specified, it overrides all individual page dataformats
- No nested folder structure per page - everything at the same level for simplicity

**Example:**
```julia
# Create individual pages
page1 = JSPlotPage(dfs, [chart1], tab_title="Revenue Analysis")
page2 = JSPlotPage(dfs, [chart2], tab_title="Cost Analysis")

# Create navigation links for coverpage
links = LinkList([
    ("Revenue", "page_1.html", "Revenue analysis details"),
    ("Costs", "page_2.html", "Cost breakdown")
])

# Create coverpage with links
coverpage = JSPlotPage(Dict(), [links], tab_title="Home")

# Create multi-page report (data saved once as parquet)
report = Pages(coverpage, [page1, page2], dataformat=:parquet)
create_html(report, "report.html")
```

### LinkList

```@docs
LinkList
```

A styled list of hyperlinks for navigating between pages in a multi-page report.

**Parameters:**
- `lnks::Vector{Tuple{String,String,String}}`: Vector of link tuples, each containing:
  - `page_title::String`: Display name for the link
  - `link_url::String`: URL or path to the target page (e.g., "page_1.html")
  - `blurb::String`: Description text explaining what the page contains

**Keyword Arguments:**
- `chart_title::Symbol`: Unique identifier (default: `:link_list`)

**Features:**
- Renders as a styled bulleted list with bold titles and descriptions
- Works with the Pages struct to create navigable multi-page reports
- Has no data dependencies (data_label is `:no_data`)

**Example:**
```julia
links = LinkList([
    ("Sales Dashboard", "page_1.html", "Quarterly sales analysis and trends"),
    ("Customer Metrics", "page_2.html", "Customer satisfaction and retention"),
    ("Financial Summary", "page_3.html", "Revenue, costs, and profit margins")
])
```

### Plot Types

#### PivotTable

```@docs
PivotTable
```

Interactive pivot table with drag-and-drop functionality using PivotTable.js.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `rows`: Column(s) to use as rows (default: `missing`)
- `cols`: Column(s) to use as columns (default: `missing`)
- `vals`: Column to aggregate (default: `missing`)
- `inclusions`: Dict of values to include in filtering (default: `missing`)
- `exclusions`: Dict of values to exclude from filtering (default: `missing`)
- `colour_map`: Custom color mapping for heatmaps (default: standard gradient)
- `aggregatorName`: Aggregation function (`:Sum`, `:Average`, `:Count`, etc.)
- `extrapolate_colours`: Whether to extrapolate color scale (default: `false`)
- `rendererName`: Renderer type (`:Table`, `:Heatmap`, `:Bar Chart`, etc.)
- `rendererOptions`: Custom renderer options (default: `missing`)
- `notes`: Descriptive text shown below the chart (default: `""`)

#### LineChart

```@docs
LineChart
```

Time series or sequential data visualization with interactive filtering.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `x_col::Symbol`: Column for x-axis values
- `y_col::Symbol`: Column for y-axis values
- `color_col`: Column for color grouping (default: `missing`)
- `filters`: Dict of default filter values (default: `Dict{Symbol,Any}()`)
- `title`: Chart title (default: `""`)
- `x_label`: X-axis label (default: `""`)
- `y_label`: Y-axis label (default: `""`)
- `notes`: Descriptive text shown below the chart (default: `""`)

#### AreaChart

```@docs
AreaChart
```

Area chart visualization with support for stacking modes and interactive controls. Automatically adapts between continuous areas (for dates/numeric x values) and stacked bars (for categorical x values).

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `x_cols::Vector{Symbol}`: Columns available for x-axis (default: `[:x]`)
- `y_cols::Vector{Symbol}`: Columns available for y-axis (default: `[:y]`)
- `group_cols::Vector{Symbol}`: Columns available for grouping/coloring areas (default: `Symbol[]`)
- `filters::Dict{Symbol, Any}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `stack_mode::String`: Stacking mode - `"unstack"`, `"stack"`, or `"normalised_stack"` (default: `"stack"`)
- `title::String`: Chart title (default: `"Area Chart"`)
- `fill_opacity::Float64`: Opacity of filled areas, 0.0-1.0 (default: `0.6`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

**Stacking Modes:**
- `"unstack"`: Areas are overlaid with transparency, allowing all to be visible simultaneously. Best for comparing individual trends.
- `"stack"`: Areas are stacked on top of each other, showing cumulative values. Best for showing total and component contributions.
- `"normalised_stack"`: Areas are stacked and normalized to 100%, showing relative proportions over time.

**Automatic Discrete/Continuous Detection:**
- **Continuous x values** (dates, floats, large numeric ranges): Creates smooth filled areas
- **Discrete x values** (strings, integers with <20 unique values): Creates stacked bars

**Features:**
- Dynamic x/y axis selection via dropdown menus
- Multiple grouping variable options for color/stacking
- Interactive filters with multi-select support
- Faceting support (1D facet wrap and 2D facet grid)
- Proper date handling with automatic formatting
- Group ordering preserved by first appearance in data

**Example:**
```julia
# Continuous area chart with dates
dates = Date(2024, 1, 1):Day(1):Date(2024, 6, 30)
df = DataFrame(
    Date = repeat(dates, 4),
    Sales = rand(length(dates) * 4) .* 10000,
    Region = repeat(["North", "South", "East", "West"], inner=length(dates))
)

area = AreaChart(:sales_chart, df, :sales_data,
    x_cols=[:Date],
    y_cols=[:Sales],
    group_cols=[:Region],
    stack_mode="stack",
    title="Regional Sales Over Time"
)

# Normalized stacking for proportions
area_norm = AreaChart(:market_share, df, :market_data,
    x_cols=[:Quarter],
    y_cols=[:MarketShare],
    group_cols=[:Category],
    stack_mode="normalised_stack",
    title="Market Share Distribution"
)

# Discrete (bar-style) for categorical x
df_cat = DataFrame(
    Department = repeat(["Eng", "Sales", "Marketing"], inner=3),
    Headcount = rand(1:30, 9),
    Team = repeat(["A", "B", "C"], 3)
)

area_bars = AreaChart(:headcount, df_cat, :headcount_data,
    x_cols=[:Department],
    y_cols=[:Headcount],
    group_cols=[:Team],
    stack_mode="stack"
)
```

#### ScatterPlot

```@docs
ScatterPlot
```

Scatter plot with optional marginal distributions and interactive filtering.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `x_col::Symbol`: Column for x-axis values
- `y_col::Symbol`: Column for y-axis values
- `color_col`: Column for color grouping (default: `missing`)
- `slider_col`: Column(s) for filter sliders (default: `missing`)
- `marker_size`: Size of scatter points (default: `5`)
- `marker_opacity`: Transparency of points (default: `0.7`)
- `show_marginals`: Show marginal histograms (default: `true`)
- `title`: Chart title (default: `""`)
- `x_label`: X-axis label (default: `""`)
- `y_label`: Y-axis label (default: `""`)
- `notes`: Descriptive text shown below the chart (default: `""`)

#### DistPlot

```@docs
DistPlot
```

Distribution visualization combining histogram, box plot, and rug plot.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `value_col::Symbol`: Column containing values to plot
- `group_col`: Column for group comparison (default: `missing`)
- `slider_col`: Column(s) for filter sliders (default: `missing`)
- `histogram_bins`: Number of histogram bins (default: `30`)
- `show_histogram`: Display histogram (default: `true`)
- `show_box`: Display box plot (default: `true`)
- `show_rug`: Display rug plot (default: `true`)
- `box_opacity`: Transparency of box plot (default: `0.6`)
- `title`: Chart title (default: `""`)
- `value_label`: Value axis label (default: `""`)
- `notes`: Descriptive text shown below the chart (default: `""`)

### 3D Plots

#### Surface3D

```@docs
Surface3D
```

Three-dimensional surface plot visualization using Plotly.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `x_col::Symbol`: Column for x-axis values (default: `:x`)
- `y_col::Symbol`: Column for y-axis values (default: `:y`)
- `z_col::Symbol`: Column for z-axis (height) values (default: `:z`)
- `group_col`: Column for grouping multiple surfaces (default: `nothing`)
- `slider_col`: Column(s) for filter sliders (default: `nothing`)
- `height::Int`: Plot height in pixels (default: `600`)
- `title`: Chart title (default: `"3D Chart"`)
- `notes`: Descriptive text shown below the chart (default: `""`)

**Example:**
```julia
surf = Surface3D(:surface_chart, df, :data,
    x_col=:x,
    y_col=:y,
    z_col=:z,
    group_col=:category,
    title="3D Surface Plot"
)
```

#### Scatter3D

```@docs
Scatter3D
```

Three-dimensional scatter plot with PCA eigenvectors and interactive filtering.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary
- `dimensions::Vector{Symbol}`: Vector of at least 3 dimension columns for x, y, and z axes

**Keyword Arguments:**
- `color_cols::Vector{Symbol}`: Columns available for color grouping (default: `[:color]`)
- `slider_col`: Column(s) for filter sliders (default: `nothing`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `show_eigenvectors::Bool`: Display PCA eigenvectors (default: `true`)
- `shared_camera::Bool`: Synchronize camera view across facets (default: `true`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points (default: `0.6`)
- `title`: Chart title (default: `"3D Scatter Plot"`)
- `notes`: Descriptive text shown below the chart (default: `""`)

**Example:**
```julia
scatter = Scatter3D(:scatter_3d, df, :data, [:x, :y, :z],
    color_cols=[:category],
    show_eigenvectors=true,
    marker_size=6,
    title="3D Point Cloud"
)
```

#### ScatterSurface3D

```@docs
ScatterSurface3D
```

Three-dimensional scatter plot with automatically fitted surfaces for each group using non-parametric regression.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

**Keyword Arguments:**
- `x_col::Symbol`: Column for x-axis values (default: `:x`)
- `y_col::Symbol`: Column for y-axis values (default: `:y`)
- `z_col::Symbol`: Column for z-axis (height) values (default: `:z`)
- `group_cols::Vector{Symbol}`: Columns for grouping data into separate point clouds and surfaces (default: `Symbol[]`)
- `facet_cols::Vector{Symbol}`: Columns for faceting (default: `Symbol[]`)
- `slider_cols::Vector{Symbol}`: Columns for filter sliders (default: `Symbol[]`)
- `surface_fitter::Union{Function, Nothing}`: Custom surface fitting function (default: `nothing`, uses kernel smoothing)
- `smoothing_params::Vector{Float64}`: Smoothing parameters to pre-compute (default: `[0.1, 0.5, 1.0, 5.0]`)
- `default_smoothing::Dict{String, Float64}`: Group-specific default smoothing parameters (default: `Dict{String, Float64}()`)
- `grid_size::Int`: Resolution of fitted surface grids (default: `20`)
- `marker_size::Int`: Size of scatter points (default: `4`)
- `marker_opacity::Float64`: Transparency of points, 0.0-1.0 (default: `0.6`)
- `height::Int`: Plot height in pixels (default: `600`)
- `title::String`: Chart title (default: `"3D Scatter with Surfaces"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

**Surface Fitting Algorithm:**

ScatterSurface3D fits smooth surfaces through 3D point clouds using kernel-based non-parametric regression. Two fitting methods are available: L2 minimization (weighted mean) and L1 minimization (weighted median).

**L2 Minimization (Nadaraya-Watson Estimator):**

The default L2 fitter implements the Nadaraya-Watson kernel regression estimator (Nadaraya, 1964; Watson, 1964), which estimates the surface height at each grid point (xᵢ, yⱼ) as a locally weighted average:

```
ẑ(xᵢ, yⱼ) = Σₖ wₖ(xᵢ, yⱼ) · zₖ / Σₖ wₖ(xᵢ, yⱼ)
```

where the weights are computed using a Gaussian (radial basis function) kernel:

```
wₖ(xᵢ, yⱼ) = exp(-dₖ² / (2h²))
dₖ² = (xₖ - xᵢ)² + (yₖ - yⱼ)²
```

Here, h is the smoothing parameter (bandwidth) that controls the kernel width. Smaller values produce surfaces that follow the data more closely, while larger values produce smoother surfaces.

**L1 Minimization (Weighted Median):**

The L1 fitter uses a weighted median instead of weighted mean, making it robust to outliers (Eddy, 1977; Härdle & Steiger, 1995). For each grid point, the surface height is estimated as:

```
ẑ(xᵢ, yⱼ) = weighted_median({z₁, z₂, ..., zₙ}, {w₁, w₂, ..., wₙ})
```

where the weighted median is the value at which the cumulative sum of weights reaches 50% of the total weight. The same Gaussian kernel is used for computing weights.

**Grid Construction:**

Surfaces are evaluated on a regular 20×20 grid spanning the data range with a 10% extension beyond the observed min/max values in each dimension to ensure complete coverage.

**Default Smoothing Parameter Selection:**

When `default_smoothing` is not specified, the system selects the median value from the provided `smoothing_params` vector. This provides a balanced default that works well for most datasets. Users can override this by providing a `Dict{String, Float64}` mapping each group name to its optimal smoothing parameter.

For optimal bandwidth selection in practice, consider:
- **Cross-validation:** Leave-one-out or k-fold CV to minimize prediction error (Härdle et al., 2004)
- **Visual inspection:** Use the interactive smoothing slider to find the best visual fit
- **Rule of thumb:** Start with h ≈ 0.1-1.0 times the data range, adjusting based on data density

**Custom Surface Fitters:**

You can provide a custom fitter function with signature:
```julia
function custom_fitter(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64},
                      smoothing_param::Float64)
    # Return: (x_grid::Vector, y_grid::Vector, z_grid::Matrix)
end
```

**References:**

- Nadaraya, E. A. (1964). "On Estimating Regression". *Theory of Probability & Its Applications*, 9(1), 141-142.
- Watson, G. S. (1964). "Smooth Regression Analysis". *Sankhyā: The Indian Journal of Statistics, Series A*, 26(4), 359-372.
- Eddy, W. F. (1977). "A New Convex Hull Algorithm for Planar Sets". *ACM Transactions on Mathematical Software*, 3(4), 398-403.
- Härdle, W., & Steiger, W. (1995). "Algorithm AS 296: Optimal Median Smoothing". *Journal of the Royal Statistical Society. Series C (Applied Statistics)*, 44(2), 258-264.
- Härdle, W., Müller, M., Sperlich, S., & Werwatz, A. (2004). *Nonparametric and Semiparametric Models*. Springer.

**Interactive Controls:**
- **Global toggles:** Show/hide all surfaces or all points independently
- **Group toggles:** Click colored buttons to toggle individual groups (both points and surface)
- **X/Y range filters:** Adjust visible data range with number inputs
- **Smoothing selector:** Switch between pre-computed smoothing levels or use group-specific defaults

**Features:**
- Automatic surface fitting for each group using kernel smoothing
- Multiple smoothing parameters with interactive selection
- Group-specific default smoothing for optimal fit per group
- Color-coded groups with matching points and surfaces
- Pre-computation of all surfaces for instant switching
- Supports custom surface fitting algorithms
- Interactive range filtering and group visibility controls

**Use Cases:**
- Non-parametric regression visualization
- Comparing fitted surfaces across different groups
- Exploring optimal smoothing parameters interactively
- Visualizing complex 3D relationships in data

**Examples:**
```julia
# Basic usage with default kernel smoother
df = DataFrame(
    x = randn(200),
    y = randn(200),
    z = randn(200),
    group = repeat(["A", "B"], 100)
)

chart = ScatterSurface3D(:scatter_surf, df, :data,
    x_col=:x,
    y_col=:y,
    z_col=:z,
    group_cols=[:group],
    smoothing_params=[0.5, 1.0, 2.0],
    title="3D Scatter with Fitted Surfaces"
)

# Custom surface fitter with group-specific defaults
function custom_smoother(x::Vector{Float64}, y::Vector{Float64},
                        z::Vector{Float64}, bandwidth::Float64)
    grid_size = 15
    x_grid = range(extrema(x)..., length=grid_size)
    y_grid = range(extrema(y)..., length=grid_size)
    z_grid = zeros(grid_size, grid_size)

    for (i, xi) in enumerate(x_grid)
        for (j, yj) in enumerate(y_grid)
            weights = exp.(-((x .- xi).^2 .+ (y .- yj).^2) ./ (2 * bandwidth^2))
            z_grid[i, j] = sum(weights .* z) / sum(weights)
        end
    end

    return (collect(x_grid), collect(y_grid), z_grid)
end

chart_custom = ScatterSurface3D(:custom_surf, df, :data,
    x_col=:x,
    y_col=:y,
    z_col=:z,
    group_cols=[:group],
    surface_fitter=custom_smoother,
    smoothing_params=[0.3, 0.7, 1.5],
    default_smoothing=Dict("A" => 1.5, "B" => 0.7),
    marker_size=6,
    title="Custom Surface Fitting"
)
```

### Tables and Data Display

#### Picture

```@docs
Picture
```

Display static images or plots from other Julia plotting libraries.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this picture
- `image_path::String` OR `chart_object + save_function`: Either a path to an image file, or a chart object with a save function

**Keyword Arguments:**
- `format::Symbol`: Output format (`:png`, `:svg`, `:jpeg`) - only for chart objects (default: `:png`)
- `notes::String`: Optional descriptive text shown below the image

**Supported Image Formats:**
- PNG (`.png`)
- SVG (`.svg`)
- JPEG/JPG (`.jpg`, `.jpeg`)

**Auto-Detected Plotting Libraries:**
- VegaLite.jl
- Plots.jl
- Makie.jl / CairoMakie.jl

**Examples:**
```julia
# From file path
pic1 = Picture(:saved_plot, "myplot.png")

# With VegaLite (auto-detected)
using VegaLite
vl_plot = data |> @vlplot(:bar, x=:category, y=:value)
pic2 = Picture(:vegalite_chart, vl_plot; format=:svg)

# With Plots.jl (auto-detected)
using Plots
p = plot(1:10, rand(10))
pic3 = Picture(:plots_chart, p; format=:png)

# With custom save function
mock_chart = Dict(:data => [1, 2, 3])
pic4 = Picture(:custom, mock_chart, (obj, path) -> write(path, "data"); format=:png)
```

**Data Format Behavior:**
- Embedded formats (`:csv_embedded`, `:json_embedded`): Images are base64-encoded into HTML
- External formats (`:csv_external`, `:json_external`, `:parquet`): Images are copied to `pictures/` subdirectory
- SVG files are embedded as XML (not base64) for better quality and smaller size

#### Table

```@docs
Table
```

Display a DataFrame as an HTML table with a download CSV button.

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this table
- `df::DataFrame`: The DataFrame to display
- `notes::String`: Optional descriptive text shown above the table

**Features:**
- Self-contained (no separate data storage needed)
- HTML table with sortable headers
- Download as CSV button included
- Automatic HTML escaping for security
- Missing values displayed as empty cells

**Example:**
```julia
df = DataFrame(
    name = ["Alice", "Bob", "Charlie"],
    age = [25, 30, 35],
    city = ["NYC", "LA", "Chicago"]
)

table = Table(:employees, df; notes="Employee information")
create_html(table, "employees.html")
```

#### TextBlock

```@docs
TextBlock
```

HTML text block for adding formatted text and tables to plot pages.

**Parameters:**
- `html_content::String`: HTML content to display

**Supported HTML Elements:**
- Headings: `<h1>` through `<h6>`
- Paragraphs: `<p>`
- Lists: `<ul>`, `<ol>`, `<li>`
- Tables: `<table>`, `<tr>`, `<td>`, `<th>`
- Text formatting: `<strong>`, `<em>`, `<code>`, `<pre>`
- Links: `<a>`
- Blockquotes: `<blockquote>`
- Divisions: `<div>`, `<span>`

#### Slides

```@docs
Slides
```

Interactive slideshow with filtering, playback controls, and keyboard navigation.

**Constructor 1: From Directory Pattern**

Load existing images from a directory following the naming pattern: `prefix!group1!group2!...!slidenum.extension`

**Parameters:**
- `chart_title::Symbol`: Unique identifier for this slideshow
- `directory::String`: Directory containing slide images
- `prefix::String`: Filename prefix to match
- `filetype::String`: File extension (`"png"`, `"jpg"`, `"jpeg"`, `"pdf"`)

**Keyword Arguments:**
- `default_filters::Dict{Symbol,Any}`: Default values for filters (default: `Dict{Symbol,Any}()`)
- `title::String`: Slideshow title (default: `"Slides"`)
- `notes::String`: Descriptive text (default: `""`)
- `autoplay::Bool`: Start in autoplay mode (default: `false`)
- `delay::Float64`: Seconds between slides in autoplay (default: `2.0`)

**File Naming Pattern:**
- Files must follow: `prefix!group1!group2!...!slidenum.extension`
- Groups are optional filtering dimensions
- All files must have the same number of group segments
- `slidenum` must be an integer
- Supported extensions: `png`, `jpg`, `jpeg`, `pdf`

**Example:**
```julia
# Files in directory:
# sales!North!Q1!1.png
# sales!North!Q1!2.png
# sales!South!Q1!1.png
# sales!South!Q2!1.png

slides = Slides(:sales_slides, "charts", "sales", "png";
    default_filters = Dict{Symbol,Any}(:group_1 => "North", :group_2 => "Q1"),
    title = "Sales Analysis Slideshow"
)
```

**Constructor 2: From Function**

Generate slides dynamically by calling a function for each combination of groups and slide numbers.

```julia
Slides(chart_title::Symbol, df::DataFrame, data_label::Symbol,
       group_cols::Vector{Symbol}, slide_col::Symbol,
       chart_function::Function; kwargs...)
```

**Parameters:**
- `chart_title::Symbol`: Unique identifier
- `df::DataFrame`: Data for generating charts
- `data_label::Symbol`: Data reference symbol
- `group_cols::Vector{Symbol}`: Columns to use as filter groups
- `slide_col::Symbol`: Column containing slide numbers
- `chart_function::Function`: Function with signature `(df, group_values..., slide_num) -> chart_object`

**Keyword Arguments:**
- `default_filters::Dict{Symbol,Any}`: Default filter values
- `output_format::Symbol`: Chart output format - `:png`, `:svg`, `:jpeg` (default: `:png`)
- `title::String`: Slideshow title
- `notes::String`: Descriptive text
- `autoplay::Bool`: Start in autoplay mode
- `delay::Float64`: Seconds between slides

**Example (VegaLite.jl):**
```julia
using VegaLite

function make_chart_vegalite(df, region, quarter, slide_num)
    filtered = df[(df.Region .== region) .& (df.Quarter .== quarter), :]

    # Create and return VegaLite chart object
    chart = filtered |> @vlplot(
        :bar,
        title = "$(region) - $(quarter) - Slide $(slide_num)",
        x = :Month,
        y = :Sales,
        color = {value = "#2196F3"}
    )

    return chart  # Chart is automatically saved by Slides
end

slides = Slides(:generated_slides, df, :sales_data,
    [:Region, :Quarter], :SlideNum, make_chart_vegalite;
    output_format = :svg,  # VegaLite charts work best as SVG
    title = "Generated Sales Slides"
)
```

**Example (Plots.jl):**
```julia
using Plots

function make_chart_plots(df, region, quarter, slide_num)
    filtered = df[(df.Region .== region) .& (df.Quarter .== quarter), :]
    return plot(filtered.Month, filtered.Sales, title="Slide $slide_num")
end

slides = Slides(:generated_slides, df, :sales_data,
    [:Region, :Quarter], :SlideNum, make_chart_plots;
    output_format = :png,
    title = "Generated Sales Slides"
)
```

**Supported Chart Libraries:**
- **VegaLite.jl**: Auto-detected and saved (recommended for SVG output)
- **Plots.jl**: Auto-detected and saved using `savefig`
- **Makie.jl / CairoMakie**: Auto-detected and saved using `CairoMakie.save`
- **Custom objects**: Any object with a `.save(filepath)` method

**Features:**
- Interactive playback controls (play/pause, previous/next)
- Adjustable playback speed with log scale slider (0.05s to 5s per slide)
- Keyboard shortcuts (← → for navigation, Space for play/pause)
- Filter dropdowns for group dimensions
- Automatic looping in autoplay mode
- Support for PNG, JPEG, SVG, and PDF images

**Data Format Behavior:**
- Embedded formats (`:csv_embedded`, `:json_embedded`): Images are embedded directly in HTML
  - SVG files are embedded as XML for best quality
  - PNG/JPEG files are base64-encoded
  - PDF files show placeholder text (limited browser support)
- External formats (`:csv_external`, `:json_external`, `:parquet`): Images are copied to `slides/` subdirectory
- Function-generated slides create temporary files that are cleaned up after HTML generation

## Output Functions

### create_html

```@docs
create_html
```

Creates an HTML file from a JSPlotPage or a single plot.

**Single Plot Usage:**
```julia
create_html(plot, dataframe, "output.html")
```

**Multiple Plots Usage:**
```julia
page = JSPlotPage(dataframes_dict, plots_array)
create_html(page, "output.html")
```

## Data Format Options

### Embedded Formats

**`:csv_embedded` (Default)**

Data is embedded directly in the HTML as CSV text within `<script>` tags. Best for small to medium datasets that you want to share as a single file.

**`:json_embedded`**

Data is embedded directly in the HTML as JSON within `<script>` tags. Better than CSV for preserving data types and handling complex structures.

### External Formats

**`:csv_external`**

Data is saved as separate CSV files in a `data/` subdirectory. The HTML file loads these via JavaScript. Creates launcher scripts (`open.sh` and `open.bat`) to handle browser permissions for local file access.

**Output Structure:**
```
output_dir/
└── myplots/
    ├── myplots.html
    ├── open.bat
    ├── open.sh
    └── data/
        ├── dataset1.csv
        └── dataset2.csv
```

**`:json_external`**

Data is saved as separate JSON files in a `data/` subdirectory. Similar to CSV external but preserves data types better.

**`:parquet`**

Data is saved as separate Parquet files in a `data/` subdirectory. Most efficient format for large datasets (> 50MB). Uses DuckDB.jl for writing and parquet-wasm for browser reading.

### Choosing a Format

| Format | File Size | Performance | Portability | Human Readable | Best For |
|--------|-----------|-------------|-------------|----------------|----------|
| `:csv_embedded` | Medium | Good | Excellent | No (in HTML) | Small datasets, single-file sharing |
| `:json_embedded` | Medium | Good | Excellent | No (in HTML) | Small datasets, type preservation |
| `:csv_external` | Small HTML | Good | Good | Yes | Medium datasets, version control |
| `:json_external` | Small HTML | Good | Good | Yes | Medium datasets, type preservation |
| `:parquet` | Smallest | Excellent | Fair | No | Large datasets (>50MB) |

## Utility Functions

### sanitize_filename

```@docs
sanitize_filename
```

### Data Format Conversion

JSPlots internally handles conversion between Julia DataFrames and JavaScript-compatible formats (CSV, JSON, Parquet).

### Color Mapping

For PivotTable heatmaps, you can specify custom color mappings:

```julia
colour_map = Dict{Float64,String}(
    [-1.0, 0.0, 1.0] .=> ["#FF0000", "#FFFFFF", "#0000FF"]
)
```

The package will interpolate colors between the specified values.

### Aggregation Functions

Available aggregators for PivotTable:

- `:Count`: Count of records
- `:Count Unique Values`: Count of distinct values
- `:List Unique Values`: List all distinct values
- `:Sum`: Sum of values
- `:Integer Sum`: Sum rounded to integer
- `:Average`: Mean of values
- `:Median`: Median value
- `:Sample Variance`: Sample variance
- `:Sample Standard Deviation`: Sample standard deviation
- `:Minimum`: Minimum value
- `:Maximum`: Maximum value
- `:First`: First value
- `:Last`: Last value
- `:Sum over Sum`: Ratio of sums
- `:Sum as Fraction of Total`: Sum divided by grand total
- `:Sum as Fraction of Rows`: Sum divided by row total
- `:Sum as Fraction of Columns`: Sum divided by column total
- `:Count as Fraction of Total`: Count divided by grand total
- `:Count as Fraction of Rows`: Count divided by row total
- `:Count as Fraction of Columns`: Count divided by column total

### Renderer Types

Available renderers for PivotTable:

- `:Table`: Standard table view
- `:Table Barchart`: Table with inline bar charts
- `:Heatmap`: Color-coded heatmap
- `:Row Heatmap`: Heatmap colored by row
- `:Col Heatmap`: Heatmap colored by column
- `:Line Chart`: Line chart
- `:Bar Chart`: Bar chart
- `:Stacked Bar Chart`: Stacked bar chart
- `:Area Chart`: Area chart
- `:Scatter Chart`: Scatter plot

## Browser Compatibility

JSPlots generates HTML that works in all modern browsers:

- Chrome/Chromium (version 90+)
- Firefox (version 88+)
- Safari (version 14+)
- Edge (version 90+)

For external data formats (CSV, JSON, Parquet), use the provided launcher scripts to ensure proper file access permissions.

## Dependencies

JSPlots bundles the following JavaScript libraries:

- [PivotTable.js](https://pivottable.js.org/) (v2.23.0) - Interactive pivot tables
- [Plotly.js](https://plotly.com/javascript/) (v2.x) - Scientific charting
- [Papa Parse](https://www.papaparse.com/) - CSV parsing
- [parquet-wasm](https://github.com/kylebarron/parquet-wasm) - Parquet file reading

All dependencies are embedded in the generated HTML files, so no internet connection is required to view the visualizations.
