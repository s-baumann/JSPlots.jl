# JSPlots.jl

| Build | Coverage | Documentation |
|-------|----------|---------------|
| [![Build status](https://github.com/s-baumann/JSPlots.jl/workflows/CI/badge.svg)](https://github.com/s-baumann/JSPlots.jl/actions) | [![codecov](https://codecov.io/gh/s-baumann/JSPlots.jl/graph/badge.svg?token=d2Io7pTUtr)](https://codecov.io/gh/s-baumann/JSPlots.jl) | [![docs-latest-img](https://img.shields.io/badge/docs-latest-blue.svg)](https://s-baumann.github.io/JSPlots.jl/dev/index.html) |

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

#### Tabular Data and Text
- **PivotTable** - Interactive drag-and-drop pivot tables (via PivotTable.js)
- **Table** - Interactive data tables with CSV download capability
- **TextBlock** - Rich text and HTML content for annotations
- **LinkList** - Styled lists of hyperlinks for multi-page navigation

#### 2D Plotting
- **LineChart** - Time series and trend visualization with faceting
- **AreaChart** - Stacked area charts or bar charts (auto-detects continuous vs discrete x-axis)
- **ScatterPlot** - 2D scatter plots with marginal distributions
- **Path** - Trajectory visualization showing ordered paths through 2D space with direction arrows

#### Distributional Plots
- **DistPlot** - Distribution visualization combining histogram, box plot, and rug plot
- **KernelDensity** - Smooth kernel density estimation for distributions

#### Three-Dimensional Plots
- **Scatter3D** - 3D scatter plots with PCA eigenvectors
- **Surface3D** - 3D surface visualization
- **ScatterSurface3D** - 3D scatter plots with fitted surfaces (L1/L2 minimization)

#### Plots from Other Julia Packages
- **Picture** - Display static images or plots from VegaLite.jl, Plots.jl, Makie.jl
- **Slides** - Slideshows and animations from sequences of images or generated plots

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

