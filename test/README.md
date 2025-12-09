# JSPlots Test Suite

This directory contains the test suite for JSPlots.jl. The tests are organized into separate files for better maintainability and faster test execution.

## Test Structure

### Main Test Runner
- `runtests.jl` - Main test runner that includes all test files

### Test Files (in `chart_tests/` directory)

#### Shared Test Data
- `test_data.jl` - Common test data used across multiple test files

#### Chart Type Tests
- `test_linechart.jl` - Tests for LineChart functionality
- `test_surface3d.jl` - Tests for Surface3D plots
- `test_scatter3d.jl` - Tests for 3D scatter plots
- `test_scatterplot.jl` - Tests for 2D scatter plots
- `test_distplot.jl` - Tests for distribution plots
- `test_kerneldensity.jl` - Tests for kernel density estimation plots
- `test_pivottable.jl` - Tests for pivot table functionality

#### Component Tests
- `test_textblock.jl` - Tests for TextBlock components
- `test_picture.jl` - Tests for Picture/image embedding
- `test_table.jl` - Tests for Table components
- `test_linklist.jl` - Tests for LinkList components
- `test_pages.jl` - Tests for multi-page report generation

#### System Tests
- `test_dataformats.jl` - Tests for different data formats (CSV, JSON, Parquet, embedded vs external)
- `test_misc.jl` - Miscellaneous tests including JSPlotPage creation, HTML validation, and edge cases

## Running Tests

### Run all tests
```julia
using Pkg
Pkg.test("JSPlots")
```

### Run specific test file
```julia
include("test/chart_tests/test_linechart.jl")
```

### Run specific test set
```julia
using Test
include("test/chart_tests/test_linechart.jl")
# Individual test sets will run automatically
```

## Test Coverage

The test suite includes **249 tests** covering:
- Chart creation and rendering
- Data format handling (embedded and external)
- HTML generation and validation
- Edge cases (empty data, missing values, special characters)
- Multi-page report generation
- Error handling and validation
- File I/O operations

## Adding New Tests

When adding new tests:

1. Determine which test file is most appropriate
2. If adding a new chart type, create a new test file following the naming convention `test_<charttype>.jl`
3. Add the new test file to `runtests.jl`
4. Use the shared test data from `test_data.jl` when possible
5. Ensure all tests clean up temporary files using `mktempdir() do ... end`

## Test Guidelines

- Always use `mktempdir()` for file I/O tests to avoid polluting the filesystem
- Include both positive and negative test cases
- Test edge cases (empty data, missing values, special characters)
- Verify both the structure and content of generated HTML
- Check for common JavaScript errors in generated code
