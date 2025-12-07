# JSPlots

| Build | Coverage | Documentation |
|-------|----------|---------------|
| [![Build status](https://github.com/s-baumann/JSPlots.jl/workflows/CI/badge.svg)](https://github.com/s-baumann/JSPlots.jl/actions) | [![codecov](https://codecov.io/gh/s-baumann/JSPlots.jl/branch/master/graph/badge.svg?token=YT0LsEsBjw)](https://codecov.io/gh/s-baumann/JSPlots.jl) | [![docs-latest-img](https://img.shields.io/badge/docs-latest-blue.svg)](https://s-baumann.github.io/JSPlots.jl/dev/index.html) |

This is a Julia package for creating interactive JavaScript-based visualizations. It includes support for pivot tables (via PivotTableJS), line charts, 3D charts, scatter plots, and distribution plots using Plotly.js. You can embed your data into HTML pages and visualize them interactively.

The pivot table functionality is a wrapper over PivotTableJS (examples: https://pivottable.js.org/examples/index.html), similar to the [python module](https://pypi.org/project/pivottablejs/). You can put multiple different charts and tables onto the same page (either sharing or not sharing data sources). There are also Plotly javascript plots that are supported. Pull requests welcome if you implement anything else. Just try to copy the coding style.

For examples see the examples folder (These were vibecoded with Claude to a large extent so if the examples seem a bit wierd that is why). For the resultant htmls see generated_html_examples.
