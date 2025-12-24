using JSPlots, DataFrames, Dates, Distributions, StableRNGs

println("Creating DistPlot examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(222)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/distplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>DistPlot Examples</h1>
<p>This page demonstrates distribution visualization combining histogram, box plot, and rug plot.</p>
<ul>
    <li><strong>Single distribution:</strong> Basic histogram + box plot + rug plot</li>
    <li><strong>Group comparison:</strong> Compare distributions across multiple groups</li>
    <li><strong>Interactive filters:</strong> Multi-select dropdown controls for categorical and numeric variables</li>
    <li><strong>Customization:</strong> Toggle histogram, box, and rug plot visibility</li>
</ul>
<p><em>Use multi-select dropdown controls to filter and explore the data!</em></p>
""")

# Example 1: Simple Distribution - Single Group
n = 1000
df1 = DataFrame(
    value = randn(rng,n) .* 10 .+ 50
)

distplot1 = DistPlot(:simple_dist, df1, :df1;
    value_cols = [:value],
    title = "Simple Distribution Plot",
    show_controls = true,
    notes = "Basic distribution showing histogram, box plot, and rug plot for a normal distribution"
)

# Example 2: Multiple Groups Comparison
n = 500
df2 = DataFrame(
    value = vcat(
        randn(rng,n) .* 5 .+ 100,  # Control group
        randn(rng,n) .* 6 .+ 110,  # Treatment A
        randn(rng,n) .* 4 .+ 95    # Treatment B
    ),
    group = repeat(["Control", "Treatment A", "Treatment B"], inner=n)
)

distplot2 = DistPlot(:multi_group_dist, df2, :df2;
    value_cols = [:value],
    color_cols = [:group],
    title = "Treatment Effect Comparison",
    notes = "Compare distributions across different treatment groups using color_cols"
)

# Example 3: Interactive Filters
n = 1200
df3 = DataFrame(
    score = abs.(randn(rng,n) .* 15 .+ 70),
    age = rand(rng,18:80, n),
    department = rand(rng,["Engineering", "Sales", "Marketing", "HR"], n)
)

distplot3 = DistPlot(:filtered_dist, df3, :df3;
    value_cols = [:score],
    filters = [:age, :department],
    histogram_bins = 40,
    title = "Score Distribution with Interactive Filters",
    notes = "Use age and department filters to filter data dynamically"
)

# Example 4: Multiple Value and Group Columns with Dropdowns
n = 800
df4 = DataFrame(
    height = randn(rng,n) .* 10 .+ 170,
    weight = randn(rng,n) .* 15 .+ 70,
    age_value = randn(rng,n) .* 10 .+ 35,
    gender = rand(rng,["Male", "Female"], n),
    country = rand(rng,["USA", "UK", "Canada"], n),
    category = rand(rng,["A", "B", "C"], n)
)

distplot4 = DistPlot(:multi_dropdown, df4, :df4;
    value_cols = [:height, :weight, :age_value],
    color_cols = [:gender, :country, :category],
    show_controls = true,
    title = "Multi-Variable Distribution with Dropdowns",
    notes = "Select different variables and grouping columns using the dropdowns above. This example demonstrates the full flexibility of the DistPlot."
)

# Example 5: Customized Appearance
n = 600
df5 = DataFrame(
    measurement = vcat(
        randn(rng,n÷5) .* 8 .+ 100,
        randn(rng,n÷5) .* 7 .+ 105,
        randn(rng,n÷5) .* 6 .+ 108,
        randn(rng,n÷5) .* 6 .+ 110,
        randn(rng,n÷5) .* 5 .+ 112
    ),
    time_point = repeat(["Baseline", "Week 1", "Week 2", "Week 3", "Week 4"], inner=n÷5)
)

distplot5 = DistPlot(:custom_appearance, df5, :df5;
    value_cols = [:measurement],
    color_cols = [:time_point],
    show_histogram = true,
    show_box = true,
    show_rug = false,
    box_opacity = 0.8,
    histogram_bins = 30,
    title = "Customized DistPlot - Longitudinal Study",
    notes = "Demonstrates customization options: rug plot hidden, increased box opacity, custom bin count"
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Three-in-one visualization:</strong> Histogram, box plot, and rug plot combined</li>
    <li><strong>Group comparison:</strong> Overlay distributions for different groups with color coding</li>
    <li><strong>Interactive filtering:</strong> Multi-select dropdown filters for both numeric and categorical columns</li>
    <li><strong>Customization options:</strong> Control visibility and appearance of each component</li>
    <li><strong>Statistical insight:</strong> See shape, central tendency, spread, and outliers at once</li>
</ul>
<p><strong>Tip:</strong> The rug plot (tick marks at the bottom) shows individual data points!</p>
""")

# Create single combined page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :df1 => df1,
        :df2 => df2,
        :df3 => df3,
        :df4 => df4,
        :df5 => df5
    ),
    [header, distplot1, distplot2, distplot3, distplot4, distplot5, conclusion],
    tab_title = "DistPlot Examples"
)

create_html(page, "generated_html_examples/distplot_examples.html")

println("\n" * "="^60)
println("DistPlot examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/distplot_examples.html")
println("\nThis page includes:")
println("  • Simple single-group distribution")
println("  • Multiple groups comparison")
println("  • Interactive filters (numeric and categorical)")
println("  • Multiple value and group columns with dropdowns")
println("  • Customized appearance options")
