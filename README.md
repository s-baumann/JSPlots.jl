# JSPlots.jl

| Build | Coverage | Documentation |
|-------|----------|---------------|
| [![Build status](https://github.com/s-baumann/JSPlots.jl/workflows/CI/badge.svg)](https://github.com/s-baumann/JSPlots.jl/actions) | [![codecov](https://codecov.io/gh/s-baumann/JSPlots.jl/branch/master/graph/badge.svg?token=YT0LsEsBjw)](https://codecov.io/gh/s-baumann/JSPlots.jl) | [![docs-latest-img](https://img.shields.io/badge/docs-latest-blue.svg)](https://s-baumann.github.io/JSPlots.jl/dev/index.html) |

**Interactive JavaScript-based visualizations for Julia**

JSPlots.jl creates interactive, standalone HTML visualizations that work in any browser. Build line charts, scatter plots, 3D visualizations, pivot tables, and more - all from Julia, no JavaScript knowledge required.

## Quick Start

```julia
using JSPlots, DataFrames

# Create your data
df = DataFrame(
    date = Date(2024,1,1):Day(1):Date(2024,12,31),
    revenue = cumsum(randn(365) .* 1000 .+ 50000),
    region = rand(["North", "South", "East", "West"], 365)
)

# Create an interactive line chart
chart = LineChart(:revenue, df, :mydata;
    x_cols = [:date],
    y_cols = [:revenue],
    color_cols = [:region],
    title = "Revenue by Region"
)

# Export to standalone HTML
page = JSPlotPage(Dict(:mydata => df), [chart])
create_html(page, "dashboard.html")
```

## Plot Types

- **LineChart** - Time series and trend visualization with faceting
- **ScatterPlot** - 2D scatter plots with marginal distributions
- **PivotTable** - Interactive drag-and-drop pivot tables (via PivotTable.js)
- **KernelDensity** - Smooth density estimation for distributions
- **DistPlot** - Histograms and distribution plots
- **Scatter3D** - Three-dimensional scatter plots
- **Surface3D** - 3D surface plots
- **Table** - Interactive data tables
- **Picture** - Embed images
- **TextBlock** - Rich text and HTML content

## Examples

All examples are in the `examples/` folder. Each can be run standalone to generate an HTML file:

```bash
julia examples/linechart_examples.jl
julia examples/scatterplot_examples.jl
julia examples/pivottable_examples.jl
# etc.
```

## About

The pivot table functionality wraps [PivotTable.js](https://pivottable.js.org/), similar to the [Python pivottablejs module](https://pypi.org/project/pivottablejs/). Plotly visualizations use [Plotly.js](https://plotly.com/javascript/). Credit to Claude code for doing all of the testing, documentation and a couple of the chart types.

