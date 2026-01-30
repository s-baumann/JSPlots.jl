# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mandatory Rules (Always Follow)

### Chart Type Examples
- **One examples file per chart type**: Each chart type must have exactly one examples file at `examples/<charttype>_examples.jl` (e.g., `examples/linechart_examples.jl`, `examples/scatterplot_examples.jl`)
- **Demonstrate all optional arguments**: The examples file must include at least one example demonstrating each optional keyword argument for the chart type. This ensures users can see how every feature works.
- When creating or modifying a chart type, verify its examples file covers all kwargs in the docstring

### General Tutorial (z_general_tutorial.jl)
- **Every chart type appears exactly once** in `examples/z_general_tutorial.jl`
- **Show ALL optional capabilities**: The tutorial example for each chart must demonstrate all optional features/arguments
- **Include informal description**: Each chart in the tutorial must have a brief, informal description in the `notes` field explaining what the chart does and how to use it. Match the conversational writing style of existing descriptions (e.g., "Try this:", "Key Features:", practical tips)
- When adding a new chart type, also add it to the appropriate page in z_general_tutorial.jl and update the LinkList entries

## Build and Test Commands

```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run a specific test file (include test_data.jl first for shared test utilities)
julia --project=. -e 'using Test, JSPlots, DataFrames, Dates; include("test/chart_tests/test_data.jl"); include("test/chart_tests/test_linechart.jl")'

# Run an example file to generate HTML output
julia --project=. examples/scatterplot_examples.jl

# Run the comprehensive tutorial (generates multi-page report)
julia --project=. examples/z_general_tutorial.jl

# Precompile the package after changes
julia --project=. -e 'using Pkg; Pkg.precompile()'
```

## Architecture Overview

JSPlots.jl generates standalone, interactive HTML visualizations from Julia DataFrames. The generated HTML files require no server - they work directly in any browser with embedded JavaScript (Plotly.js, D3.js, PivotTable.js, etc.).

### Core Flow

1. **Chart Type Structs** (`src/*.jl`): Each chart type (LineChart, ScatterPlot, etc.) is a struct implementing `JSPlotsType`. The constructor:
   - Validates input DataFrame columns
   - Generates `functional_html` (JavaScript code for the chart)
   - Generates `appearance_html` (HTML controls: filters, dropdowns, sliders)

2. **Page Assembly** (`src/Pages.jl`): `JSPlotPage` combines multiple charts with shared data:
   - Extracts DataFrames from the data dictionary
   - Supports struct data sources (e.g., `Symbol("mystruct.field")`)
   - Handles multi-page reports with shared data deduplication

3. **HTML Generation** (`src/make_html.jl`): `create_html()` assembles the final HTML:
   - Collects JS dependencies from all charts via `js_dependencies()`
   - Embeds or externalizes data based on `dataformat` (`:csv_embedded`, `:json_embedded`, `:parquet`, etc.)
   - Includes centralized JavaScript for data loading, filtering, and expression parsing

### Key Abstractions

- **`html_controls.jl`**: Unified HTML control generation (dropdowns, range sliders, faceting)
- **`normalize_filters()`**: Converts filter specs (Vector{Symbol} or Dict) to standard format
- **`build_color_maps_extended()`**: Handles categorical and continuous color scales
- **Expression Parser** (in `make_html.jl`): Client-side expression evaluation for ScatterPlot's `expression_mode`, supporting functions like `z()`, `q()`, `r()`, `f()`, `c()`, `PCA1()`, `PCA2()`

### Data Format Options

- `:csv_embedded` / `:json_embedded` - Data embedded in HTML (single file)
- `:csv_external` / `:json_external` - Data in separate files (enables deduplication)
- `:parquet` - Compressed binary format (smallest size, uses parquet-wasm)

### Adding a New Chart Type

1. Create `src/newchart.jl` with a struct extending `JSPlotsType`
2. Implement constructor that builds `functional_html` and `appearance_html`
3. Implement `dependencies(chart)` returning data labels used
4. Implement `js_dependencies(chart)` returning required JS libraries (use `JS_DEP_*` constants)
5. Add `include()` and `export` in `src/JSPlots.jl`
6. Create test file `test/chart_tests/test_newchart.jl`
7. Create example file `examples/newchart_examples.jl`
8. Add to `examples/z_general_tutorial.jl` in the appropriate section page
9. Add to the LinkList in z_general_tutorial.jl
10. Add to README.md under the appropriate chart category

### Common Patterns

- **Filters**: Use `normalize_filters()` then `build_filter_dropdowns()` from html_controls.jl
- **Color columns**: Accept `ColorColSpec` type for flexible categorical/continuous color specs
- **Faceting**: Use `normalize_and_validate_facets()` and `generate_facet_dropdowns_html()`
- **Axis transforms**: Use `build_axis_controls_html()` for log/z-score/quantile transforms
- **Chart titles**: Always sanitize with `sanitize_chart_title()` for JS function names

### JavaScript in Generated HTML

Each chart's `functional_html` is wrapped in an IIFE. Common JS functions are defined once in `make_html.jl`:
- `loadDataset()` - Unified data loading across all formats
- `applyFiltersWithCounting()` - Centralized filtering with observation counts
- `applyAxisTransform()` - Log, z-score, quantile, inverse_cdf transforms
- `evaluateExpressionString()` - Expression parser for ScatterPlot expression_mode
- `computeCumulativeSum()` / `computeCumulativeProduct()` - For CumPlot
- `computeDrawdown()` - For DrawdownPlot

### ColorColSpec Type

The `ColorColSpec` type allows flexible color column specifications:
```julia
ColorColSpec = Union{Vector{Symbol}, Vector{<:Tuple{Symbol, Any}}}
```

Usage patterns:
- `[:col1, :col2]` - Simple column list with default colors
- `[(:col1, :default), (:col2, Dict("A" => "#ff0000", "B" => "#00ff00"))]` - Mixed default and custom colors
- `[(:col1, Dict(0 => "#blue", 100 => "#red"))]` - Continuous color interpolation with numeric keys

Use `build_color_maps_extended()` to process ColorColSpec, which returns `(color_maps, color_scales, valid_cols)`.
