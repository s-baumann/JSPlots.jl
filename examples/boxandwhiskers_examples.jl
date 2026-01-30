using JSPlots, DataFrames, Dates, Random, StableRNGs

rng = StableRNG(888)

println("Creating BoxAndWhiskers examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/boxandwhiskers_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Box and Whiskers Plot Examples</h1>
<p>This page demonstrates the interactive Box and Whiskers plot type in JSPlots.</p>
<ul>
    <li><strong>Horizontal box and whiskers:</strong> Shows min, Q1, median, Q3, and max for each group</li>
    <li><strong>Mean and standard deviation overlay:</strong> Red diamond markers with error bars show mean ± stdev</li>
    <li><strong>Interactive grouping:</strong> Organize groups by different categorical variables</li>
    <li><strong>Color coding:</strong> Groups can be colored by different attributes</li>
    <li><strong>Filtering:</strong> Filter data using interactive dropdowns</li>
    <li><strong>Multiple value columns:</strong> Switch between different numeric variables</li>
</ul>
""")

# =============================================================================
# Example 1: Basic Distribution Comparison
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Basic Distribution Comparison</h2>
<p>A simple example showing distributions for three groups with different means and spreads.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Box shows interquartile range (Q1 to Q3) with median line</li>
    <li>Whiskers extend to min and max values</li>
    <li>Red diamond markers show mean with error bars for ± 1 standard deviation</li>
    <li>Each group labeled on the left side</li>
</ul>
""")

Random.seed!(rng, 123)
df_basic = DataFrame(
    group = vcat(
        fill("Group A", 100),
        fill("Group B", 100),
        fill("Group C", 100)
    ),
    value = vcat(
        randn(rng, 100) .* 2 .+ 10,  # Mean ~10, SD ~2
        randn(rng, 100) .* 3 .+ 15,  # Mean ~15, SD ~3
        randn(rng, 100) .* 1.5 .+ 8  # Mean ~8, SD ~1.5
    )
)

bw1 = BoxAndWhiskers(:basic_bw, df_basic, :basic_data;
    x_cols = [:value],
    group_col = :group,
    title = "Basic Distribution Comparison",
    notes = "Compare distributions across three groups. Red diamonds show mean ± standard deviation."
)

# =============================================================================
# Example 2: With Color Grouping
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Color-Coded Groups</h2>
<p>Groups can be colored by categorical variables to visually distinguish different categories.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Color by dropdown to choose coloring variable</li>
    <li>Groups with same color attribute share the same color</li>
    <li>Useful for showing nested grouping structures</li>
</ul>
""")

Random.seed!(rng, 456)
df_colored = DataFrame(
    group = repeat(["A", "B", "C", "D", "E", "F"], inner = 80),
    value = vcat(
        randn(rng, 80) .+ 5,
        randn(rng, 80) .+ 7,
        randn(rng, 80) .+ 9,
        randn(rng, 80) .+ 6,
        randn(rng, 80) .+ 8,
        randn(rng, 80) .+ 10
    ),
    region = repeat(["North", "North", "South", "South", "East", "East"], inner = 80),
    industry = repeat(["Tech", "Finance", "Tech", "Finance", "Tech", "Finance"], inner = 80)
)

bw2 = BoxAndWhiskers(:colored_bw, df_colored, :colored_data;
    x_cols = [:value],
    color_cols = [:region, :industry],
    group_col = :group,
    title = "Color-Coded Distributions",
    notes = "Use the 'Color by' dropdown to color groups by different attributes."
)

# =============================================================================
# Example 3: With Grouping Organization
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Organized by Grouping Variable</h2>
<p>Groups can be organized and visually separated by categorical variables.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Group by dropdown to choose organizational variable</li>
    <li>Extra spacing between different grouping categories</li>
    <li>Bold section labels on the left showing grouping categories</li>
    <li>Automatic sorting within each section</li>
</ul>
""")

Random.seed!(rng, 789)
df_grouped = DataFrame(
    group = repeat(["A", "B", "C", "D", "E", "F", "G", "H", "I"], inner = 50),
    value = vcat(
        randn(rng, 50) .+ 2,
        randn(rng, 50) .+ 5,
        randn(rng, 50) .+ 8,
        randn(rng, 50) .+ 3,
        randn(rng, 50) .+ 6,
        randn(rng, 50) .+ 9,
        randn(rng, 50) .+ 4,
        randn(rng, 50) .+ 7,
        randn(rng, 50) .+ 10
    ),
    country = repeat(["Australia", "Australia", "Brazil", "USA", "USA", "USA", "Suriname", "Argentina", "Argentina"], inner = 50),
    industry = repeat(["Coal", "Tourism", "Coal", "Tourism", "Tourism", "Coal", "Tourism", "Coal", "Tourism"], inner = 50)
)

bw3 = BoxAndWhiskers(:grouped_bw, df_grouped, :grouped_data;
    x_cols = [:value],
    color_cols = [:industry, :country],
    grouping_cols = [:country, :industry],
    group_col = :group,
    title = "Organized by Grouping Variable",
    notes = "Use 'Group by' dropdown to organize groups. Notice the bold section labels and spacing between categories."
)

# =============================================================================
# Example 4: Multiple Value Columns
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: Multiple Value Columns</h2>
<p>Switch between different numeric variables to compare distributions.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Value dropdown to switch between different metrics</li>
    <li>Each metric has different scale and distribution</li>
    <li>Useful for exploring different aspects of the data</li>
</ul>
""")

Random.seed!(rng, 101)
df_multi = DataFrame(
    group = repeat(["Product A", "Product B", "Product C", "Product D"], inner = 75),
    revenue = vcat(
        abs.(randn(rng, 75) .* 5000 .+ 25000),
        abs.(randn(rng, 75) .* 8000 .+ 35000),
        abs.(randn(rng, 75) .* 3000 .+ 18000),
        abs.(randn(rng, 75) .* 6000 .+ 28000)
    ),
    units_sold = vcat(
        abs.(randn(rng, 75) .* 20 .+ 150),
        abs.(randn(rng, 75) .* 35 .+ 200),
        abs.(randn(rng, 75) .* 15 .+ 100),
        abs.(randn(rng, 75) .* 25 .+ 175)
    ),
    customer_satisfaction = vcat(
        randn(rng, 75) .* 0.5 .+ 4.2,
        randn(rng, 75) .* 0.3 .+ 4.5,
        randn(rng, 75) .* 0.7 .+ 3.8,
        randn(rng, 75) .* 0.4 .+ 4.0
    ),
    category = repeat(["Electronics", "Electronics", "Home", "Home"], inner = 75)
)

bw4 = BoxAndWhiskers(:multi_value_bw, df_multi, :multi_data;
    x_cols = [:revenue, :units_sold, :customer_satisfaction],
    color_cols = [:category],
    grouping_cols = [:category],
    group_col = :group,
    title = "Multiple Metrics Comparison",
    notes = "Switch between Revenue, Units Sold, and Customer Satisfaction using the Value dropdown."
)

# =============================================================================
# Example 5: With Filtering
# =============================================================================

example5_text = TextBlock("""
<h2>Example 5: Interactive Filtering</h2>
<p>Filter data by categorical variables to focus on specific subsets.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Multi-select filters to include/exclude data</li>
    <li>Observation count updates show % remaining after filtering</li>
    <li>Filters work together with color and grouping controls</li>
    <li>Chart dynamically updates based on filtered data</li>
</ul>
""")

Random.seed!(rng, 202)
df_filtered = DataFrame(
    group = repeat(["Team 1", "Team 2", "Team 3", "Team 4", "Team 5", "Team 6"], inner = 60),
    score = vcat(
        randn(rng, 60) .* 8 .+ 75,
        randn(rng, 60) .* 10 .+ 82,
        randn(rng, 60) .* 7 .+ 68,
        randn(rng, 60) .* 9 .+ 79,
        randn(rng, 60) .* 11 .+ 85,
        randn(rng, 60) .* 6 .+ 72
    ),
    region = repeat(["North", "North", "South", "South", "East", "West"], inner = 60),
    division = repeat(["A", "B", "A", "B", "A", "A"], inner = 60),
    quarter = repeat(vcat(fill("Q1", 15), fill("Q2", 15), fill("Q3", 15), fill("Q4", 15)), 6)
)

bw5 = BoxAndWhiskers(:filtered_bw, df_filtered, :filtered_data;
    x_cols = [:score],
    color_cols = [:region, :division],
    grouping_cols = [:region, :division],
    group_col = :group,
    filters = Dict(:quarter => ["Q1", "Q2", "Q3", "Q4"], :region => ["North", "South", "East", "West"]),
    title = "Team Performance with Filtering",
    notes = "Use filters to focus on specific quarters or regions. Watch the observation count update."
)

# =============================================================================
# Example 5b: Using choices (single-select) instead of filters (multi-select)
# =============================================================================

example5b_text = TextBlock("""
<h2>Example 5b: Single-Select Choices vs Multi-Select Filters</h2>
<p>Demonstrates the difference between choices (single-select) and filters (multi-select).</p>
<p>Features demonstrated:</p>
<ul>
    <li><strong>Choices:</strong> Single-select dropdown - user picks exactly ONE value at a time</li>
    <li><strong>Filters:</strong> Multi-select dropdown - user can select multiple values</li>
    <li>Use choices when comparison should be one value at a time</li>
</ul>
""")

bw5b = BoxAndWhiskers(:choice_bw, df_filtered, :filtered_data;
    x_cols = [:score],
    color_cols = [:region, :division],
    grouping_cols = [:region, :division],
    group_col = :group,
    choices = Dict{Symbol,Any}(:quarter => "Q1"),  # Single-select
    filters = Dict{Symbol,Any}(:division => ["A", "B"]),  # Multi-select for comparison
    title = "Example 5b: BoxAndWhiskers with Single-Select Choice",
    notes = """
    This example demonstrates the difference between choices and filters:
    - **quarter (choice)**: Single-select dropdown - pick exactly ONE quarter at a time
    - **division (filter)**: Multi-select dropdown - can select multiple divisions

    Use choices when the user must select exactly one option (e.g., viewing one quarter at a time).
    """
)

# =============================================================================
# Example 6: Wide Range of Values
# =============================================================================

example6_text = TextBlock("""
<h2>Example 6: Handling Wide Value Ranges</h2>
<p>Box and whiskers plots work well with data that has wide ranges or outliers.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Whiskers extend to min/max showing full data range</li>
    <li>Box (IQR) shows where bulk of data lies</li>
    <li>Mean can be quite different from median in skewed distributions</li>
    <li>Red error bars show standard deviation clearly</li>
</ul>
""")

Random.seed!(rng, 303)
df_wide = DataFrame(
    group = repeat(["Startup", "Small Biz", "Mid-Size", "Enterprise", "Corporation"], inner = 80),
    annual_revenue = vcat(
        abs.(randn(rng, 80) .* 50 .+ 100) .^ 2,      # Wide range for startups
        abs.(randn(rng, 80) .* 200 .+ 500) .^ 1.5,   # Moderate range
        abs.(randn(rng, 80) .* 800 .+ 2000) .^ 1.3,  # Getting larger
        abs.(randn(rng, 80) .* 2000 .+ 10000) .^ 1.2,
        abs.(randn(rng, 80) .* 5000 .+ 50000)
    ),
    sector = repeat(["Tech", "Finance", "Manufacturing", "Retail", "Services"], inner = 80)
)

bw6 = BoxAndWhiskers(:wide_range_bw, df_wide, :wide_data;
    x_cols = [:annual_revenue],
    color_cols = [:sector],
    group_col = :group,
    title = "Company Revenue Distributions",
    notes = "Notice how box and whiskers effectively shows the different scales and spreads across company sizes."
)

# =============================================================================
# Example 7: Aspect Ratio Control
# =============================================================================

example7_text = TextBlock("""
<h2>Example 7: Adjustable Aspect Ratio</h2>
<p>Control the height-to-width ratio of the chart for optimal viewing.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Aspect ratio slider adjusts chart height dynamically</li>
    <li>Useful for fitting many groups or adjusting for screen size</li>
    <li>Height automatically scales with number of groups</li>
</ul>
""")

Random.seed!(rng, 404)
df_aspect = DataFrame(
    group = repeat(string.('A':'O'), inner = 40),  # 15 groups
    value = vcat([randn(rng, 40) .+ i*2 for i in 1:15]...),
    type = repeat(reduce(vcat, [["Type 1", "Type 2", "Type 3"] for i in 1:200]))[1:600]
)

bw7 = BoxAndWhiskers(:aspect_bw, df_aspect, :aspect_data;
    x_cols = [:value],
    color_cols = [:type],
    grouping_cols = [:type],
    group_col = :group,
    title = "Many Groups - Adjustable Height",
    notes = "Use the Aspect Ratio slider below to adjust chart height for better visibility of all groups."
)

# =============================================================================
# Create Page
# =============================================================================

# Create data dictionary
data_dict = Dict{Symbol, Any}(
    :basic_data => df_basic,
    :colored_data => df_colored,
    :grouped_data => df_grouped,
    :multi_data => df_multi,
    :filtered_data => df_filtered,
    :wide_data => df_wide,
    :aspect_data => df_aspect
)

# Create page with all examples
page = JSPlotPage(
    data_dict,
    [
        header,
        example1_text,
        bw1,
        example2_text,
        bw2,
        example3_text,
        bw3,
        example4_text,
        bw4,
        example5_text,
        bw5,
        example5b_text,
        bw5b,
        example6_text,
        bw6,
        example7_text,
        bw7
    ]
)

# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="boxandwhiskers_examples.html",
                               description="BoxAndWhiskers Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Distributional Charts", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/boxandwhiskers_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("BoxAndWhiskers examples created successfully!")
println("Open generated_html_examples/boxandwhiskers_examples.html in a web browser to view.")
