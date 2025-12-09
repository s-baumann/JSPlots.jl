using JSPlots, DataFrames

println("Testing chart titles with spaces...")

# Create test data
n = 300
df = DataFrame(
    x = randn(n) .* 2,
    y = randn(n) .* 1.5,
    z = randn(n),
    category = rand(["Group A", "Group B", "Group C"], n)
)

# Test Scatter3D with spaces in chart title
chart = Scatter3D(Symbol("My 3D Chart - Test"), df, :test_data, [:x, :y, :z];
    color_cols = [:category],
    show_eigenvectors = true,
    title = "Testing Chart Title with Spaces",
    notes = "This chart title contains spaces, hyphens, and special characters"
)

page = JSPlotPage(
    Dict(:test_data => df),
    [chart],
    tab_title = "Space Test"
)

create_html(page, "generated_html_examples/space_test.html")

println("✓ Chart with spaces in title created successfully!")
println("  Chart title symbol: 'My 3D Chart - Test'")
println("  Sanitized for JS: 'My_3D_Chart___Test'")
println("\nFile: generated_html_examples/space_test.html")
