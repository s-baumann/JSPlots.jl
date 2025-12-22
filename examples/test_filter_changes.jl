using JSPlots, DataFrames

println("Testing new filter functionality...")

# Create test data
df = DataFrame(
    x = 1:100,
    y = rand(100),
    country = rand(["Australia", "Bangladesh", "Canada", "Denmark"], 100),
    region = rand(["North", "South", "East", "West"], 100),
    category = rand(["A", "B", "C"], 100)
)

println("\n1. Testing Vector{Symbol} filter format (all values selected by default):")
lc1 = LineChart(:test_vector, df, :test_data,
    x_cols = [:x],
    y_cols = [:y],
    filters = [:country, :region],  # NEW: Vector format
    title = "Test Vector Filter Format"
)
println("   ✓ LineChart with [:country, :region] created successfully")

println("\n2. Testing Dict with Vector values (specific defaults):")
lc2 = LineChart(:test_dict_vec, df, :test_data,
    x_cols = [:x],
    y_cols = [:y],
    filters = Dict(:country => ["Australia", "Bangladesh"]),  # Specific defaults
    title = "Test Dict with Vector"
)
println("   ✓ LineChart with Dict(:country => [\"Australia\", \"Bangladesh\"]) created successfully")

println("\n3. Testing Dict with single value (wrapped to vector):")
lc3 = LineChart(:test_dict_single, df, :test_data,
    x_cols = [:x],
    y_cols = [:y],
    filters = Dict(:country => "Australia"),  # Single value
    title = "Test Dict with Single Value"
)
println("   ✓ LineChart with Dict(:country => \"Australia\") created successfully")

println("\n4. Testing Dict with nothing (all values):")
lc4 = LineChart(:test_dict_nothing, df, :test_data,
    x_cols = [:x],
    y_cols = [:y],
    filters = Dict(:country => nothing, :region => nothing),  # All values
    title = "Test Dict with Nothing"
)
println("   ✓ LineChart with Dict(:country => nothing) created successfully")

println("\n5. Testing with Scatter3D:")
sc3d = Scatter3D(:test_3d, df, :test_data, [:x, :y, :category],
    color_cols = [:country],
    filters = [:region, :category],  # NEW: Vector format
    title = "Test 3D with Vector Filters"
)
println("   ✓ Scatter3D with vector filters created successfully")

println("\n6. Testing with AreaChart:")
ac = AreaChart(:test_area, df, :test_data,
    x_cols = [:x],
    y_cols = [:y],
    filters = Dict(:country => ["Australia", "Canada"]),
    title = "Test AreaChart"
)
println("   ✓ AreaChart with dict filters created successfully")

# Create test page
page = JSPlotPage(
    Dict(:test_data => df),
    [lc1, lc2, lc3, lc4, sc3d, ac],
    tab_title = "Filter Test",
    page_header = "Testing New Filter Functionality"
)

create_html(page, "generated_html_examples/test_filters.html")

println("\n" * "="^60)
println("All filter tests passed! ✓")
println("="^60)
println("\nGenerated: generated_html_examples/test_filters.html")
println("\nNew filter features:")
println("  1. Vector{Symbol} format: filters = [:country, :region]")
println("     → Creates filters with ALL unique values selected by default")
println("\n  2. Dict{Symbol, Any} format still supported:")
println("     - Vector values: Dict(:country => [\"Australia\", \"Bangladesh\"])")
println("     - Single value: Dict(:country => \"Australia\")")
println("     - All values: Dict(:country => nothing)")
println("="^60)
