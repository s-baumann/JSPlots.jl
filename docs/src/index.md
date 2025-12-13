# JSPlots.jl

*Interactive JavaScript-based visualizations build in Julia.*

JSPlots is a Julia package for creating interactive JavaScript-based visualizations. It includes support for pivot tables (via PivotTableJS), line charts, 3D charts, scatter plots, and distribution plots using Plotly.js. You can embed your data into HTML pages and visualize them interactively.

## Key Features

- **Interactive Pivot Tables**: Wrapper over PivotTableJS with drag-and-drop interface
- **Multiple Plot Types**: Line charts, 3D surface plots, scatter plots, and distribution plots
- **Flexible Data Embedding**: Support for CSV, JSON, and Parquet formats (embedded or external)
- **Single File Output**: Create standalone HTML files with all dependencies embedded.
- **Multi-Chart Pages**: Combine multiple charts and tables on a single page

## Installation

```julia
using Pkg
Pkg.add("JSPlots")
```

## Quick Start

Here's a simple example:

```julia
using JSPlots, DataFrames, Dates

# Create sample data
df = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 31),
    temperature = randn(31) .+ 20,
    city = repeat(["NYC", "LA"], 16)[1:31]
)

# Create a line chart
chart = LineChart(:temp_chart, df, :df;
    x_col = :date,
    y_col = :temperature,
    color_col = :city,
    title = "Daily Temperature",
    x_label = "Date",
    y_label = "Temperature (°C)"
)

# Export to HTML
create_html(chart, df, "temperature.html")
```

## Plot Types

JSPlots provides multiple visualization types:

#### Tabular data and text

1. **[PivotTable](@ref)**: Interactive pivot tables with drag-and-drop functionality;
2. **[Table](@ref)**: Display DataFrames as HTML tables with CSV download capability;
3. **[TextBlock](@ref)**: HTML text blocks for annotations and documentation.

#### 2D Plotting

4. **[LineChart](@ref)**: Time series and sequential data visualization;
5. **[AreaChart](@ref)**: A Barchart (for discrete x domain) or Area chart (for continuous x domain);
6. **[ScatterPlot](@ref)**: Scatter plots with marginal distributions and interactive filtering;

#### Distributional Plots

7. **[DistPlot](@ref)**: Distribution visualization combining histogram, box plot, and rug plot;
8. **[KernelDensity](@ref)**: Kernel Density plots;

#### Three dimensional plots

9. **[Scatter3D](@ref)**: A 3D scatter plot;
10. **[Surface3D](@ref)**: A 3D plot showing multiple surfaces;
11. **[ScatterSurface3D](@ref)**: A 3D scatter plot together with a surface that approximates the data points;

#### Plots from other Julia packages

12. **[Picture](@ref)**: Display static images from anywhere as well as plots from other Julia plotting libraries;
13. **[Slides](@ref)**: Display slideshows and animations from a sequence of pictures/plots from other Julia plotting libraries;



## Data Format Options

JSPlots supports five different data embedding formats:

- **`:csv_embedded`** (default): Data embedded as CSV text in the HTML
- **`:json_embedded`**: Data embedded as JSON in the HTML
- **`:csv_external`**: Data saved as separate CSV files
- **`:json_external`**: Data saved as separate JSON files
- **`:parquet`**: Data saved as separate Parquet files (most efficient for large datasets)

See the [API documentation](api.md#Data-Format-Options) for detailed information on choosing the right format.

## Creating Multi-Chart Pages

You can combine multiple plots and text blocks on a single page:

```julia
# Create multiple visualizations
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

## Credits

The pivot table functionality is built on [PivotTable.js](https://pivottable.js.org/), similar to the [Python pivottablejs module](https://pypi.org/project/pivottablejs/). Other visualizations use [Plotly.js](https://plotly.com/javascript/).

---

```@contents
pages = ["index.md",
         "examples.md",
         "api.md"]
Depth = 2
```
