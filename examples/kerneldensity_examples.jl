using JSPlots, DataFrames, Dates, Random, Distributions

println("Creating KernelDensity examples...")

Random.seed!(42)

# Prepare header
header = TextBlock("""
<h1>Kernel Density Plot Examples</h1>
<p>This page demonstrates kernel density estimation for visualizing continuous distributions.</p>
<ul>
    <li><strong>Smooth density curves:</strong> Non-parametric estimation of probability density</li>
    <li><strong>Multiple overlapping densities:</strong> Compare distributions across groups with transparency</li>
    <li><strong>Interactive filters:</strong> Slider controls for categorical and numeric ranges</li>
    <li><strong>Faceting:</strong> Split visualizations by one or two categorical variables</li>
</ul>
<p><em>Use sliders and multi-select controls to filter and explore the data!</em></p>
""")

# Example 1: Simple Single Distribution
n = 1000
df1 = DataFrame(
    value = randn(n) .* 10 .+ 50
)

kde1 = KernelDensity(:simple_kde, df1, :df1;
    value_cols = :value,
    title = "Simple Kernel Density",
    notes = "Basic kernel density estimation for a normal distribution"
)

# Example 2: Multiple Overlapping Groups
n = 500
df2 = DataFrame(
    value = vcat(
        randn(n) .* 5 .+ 100,  # Control group
        randn(n) .* 6 .+ 110,  # Treatment A
        randn(n) .* 4 .+ 95    # Treatment B
    ),
    group = repeat(["Control", "Treatment A", "Treatment B"], inner=n)
)

kde2 = KernelDensity(:multi_group_kde, df2, :df2;
    value_cols = :value,
    group_cols = :group,
    title = "Treatment Comparison - Overlapping Densities",
    density_opacity = 0.5,
    notes = "Compare distributions with overlapping density curves. Transparency allows visibility of all groups."
)

# Example 3: With Interactive Filters
n = 1200
df3 = DataFrame(
    score = abs.(randn(n) .* 15 .+ 70),
    age = rand(18:80, n),
    department = rand(["Engineering", "Sales", "Marketing", "HR"], n),
    region = rand(["North", "South", "East", "West"], n)
)

kde3 = KernelDensity(:filtered_kde, df3, :df3;
    value_cols = :score,
    group_cols = :department,
    filter_cols = [:age, :region],
    title = "Score Distribution by Department with Filters",
    notes = "Use age range slider and region multi-select to filter data dynamically and see how distributions change"
)

# Example 4: Faceting by One Variable
n = 400
df4 = DataFrame(
    measurement = vcat(
        randn(n) .* 8 .+ 100,
        randn(n) .* 7 .+ 110,
        randn(n) .* 9 .+ 95
    ),
    category = repeat(["Category A", "Category B", "Category C"], inner=n),
    phase = rand(["Phase 1", "Phase 2"], 3*n)
)

kde4 = KernelDensity(:facet_one_kde, df4, :df4;
    value_cols = :measurement,
    group_cols = :category,
    facet_cols = :phase,
    default_facet_cols = :phase,
    title = "Faceted Kernel Density - Single Variable",
    notes = "Faceting by phase shows separate density plots for each phase, with categories overlaid within each facet"
)

# Example 5: Faceting by Two Variables (Grid)
n = 300
df5 = DataFrame(
    value = vcat(
        randn(n) .* 10 .+ 100,
        randn(n) .* 12 .+ 110,
        randn(n) .* 8 .+ 105,
        randn(n) .* 11 .+ 95
    ),
    treatment = repeat(["Placebo", "Drug A"], inner=2*n),
    timepoint = repeat(["Baseline", "Post-Treatment", "Baseline", "Post-Treatment"], inner=n)
)

kde5 = KernelDensity(:facet_grid_kde, df5, :df5;
    value_cols = :value,
    facet_cols = [:treatment, :timepoint],
    default_facet_cols = [:treatment, :timepoint],
    title = "Faceted Grid - Two Variables",
    fill_density = true,
    notes = "Two-way faceting creates a grid showing all combinations of treatment and timepoint"
)

# Example 6: Bimodal Distribution
n = 800
df6 = DataFrame(
    value = vcat(
        randn(n÷2) .* 5 .+ 70,   # First mode
        randn(n÷2) .* 5 .+ 100   # Second mode
    ),
    condition = repeat(["Bimodal", "Bimodal"], inner=n÷2)
)

kde6 = KernelDensity(:bimodal_kde, df6, :df6;
    value_cols = :value,
    title = "Bimodal Distribution Detection",
    fill_density = true,
    notes = "Kernel density estimation excels at revealing complex distribution shapes like bimodality"
)

# Example 7: Custom Bandwidth
n = 500
df7 = DataFrame(
    value = vcat(
        randn(n) .* 3 .+ 50,
        randn(n) .* 4 .+ 60,
        randn(n) .* 3.5 .+ 55
    ),
    group = repeat(["Group A", "Group B", "Group C"], inner=n)
)

kde7 = KernelDensity(:custom_bandwidth_kde, df7, :df7;
    value_cols = :value,
    group_cols = :group,
    bandwidth = 2.0,
    density_opacity = 0.7,
    title = "Custom Bandwidth Setting",
    notes = "Bandwidth controls smoothness: smaller values show more detail, larger values create smoother curves"
)

# Example 8: Multiple Value and Group Columns with Dropdowns
n = 800
df8 = DataFrame(
    height = randn(n) .* 10 .+ 170,
    weight = randn(n) .* 15 .+ 70,
    age_value = randn(n) .* 10 .+ 35,
    gender = rand(["Male", "Female"], n),
    country = rand(["USA", "UK", "Canada"], n),
    category = rand(["A", "B", "C"], n)
)

kde8 = KernelDensity(:multi_dropdown_kde, df8, :df8;
    value_cols = [:height, :weight, :age_value],
    group_cols = [:gender, :country, :category],
    density_opacity = 0.6,
    title = "Multi-Variable KDE with Dropdowns and Bandwidth Control",
    notes = "Select different variables and grouping columns using the dropdowns. Adjust bandwidth to control smoothness. Set bandwidth to 0 for automatic calculation."
)

# Example 9: Comprehensive - All Features Combined
n = 1500
df9 = DataFrame(
    measurement = vcat(
        randn(n÷3) .* 8 .+ 100,
        randn(n÷3) .* 9 .+ 110,
        randn(n÷3) .* 7 .+ 95
    ),
    score = abs.(randn(n) .* 15 .+ 70),
    age = rand(20:65, n),
    region = rand(["North", "South", "East", "West"], n),
    department = rand(["Engineering", "Sales", "Marketing"], n),
    experience_level = rand(["Junior", "Mid", "Senior"], n),
    project_type = rand(["Type A", "Type B"], n)
)

kde9 = KernelDensity(:comprehensive_kde, df9, :df9;
    value_cols = [:measurement, :score],
    group_cols = [:department, :experience_level],
    filter_cols = [:age, :region],
    facet_cols = [:project_type],
    default_facet_cols = :project_type,
    density_opacity = 0.6,
    bandwidth = 0.0,
    title = "Comprehensive Example - All Features Combined",
    notes = "This example demonstrates all KernelDensity features together: multiple value columns, grouping by color, filtering with sliders, and faceting. Use the controls to explore different combinations and see how distributions vary across departments, experience levels, and project types."
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Smooth density estimation:</strong> Non-parametric visualization of continuous distributions</li>
    <li><strong>Overlapping groups:</strong> Compare multiple distributions with transparency for visibility</li>
    <li><strong>Interactive filtering:</strong> Range sliders for numeric columns, multi-select for categorical</li>
    <li><strong>Flexible faceting:</strong> Split plots by one or two categorical variables</li>
    <li><strong>Bandwidth control:</strong> Interactive input to adjust smoothness (0 for automatic using Silverman's rule)</li>
    <li><strong>Variable selection:</strong> Dropdowns to switch between multiple value and group columns</li>
    <li><strong>Bimodality detection:</strong> Reveals complex distribution shapes that histograms might miss</li>
</ul>
<p><strong>Tip:</strong> Kernel density plots are particularly useful for comparing continuous distributions and detecting complex patterns!</p>
""")

# Create single combined page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :df1 => df1,
        :df2 => df2,
        :df3 => df3,
        :df4 => df4,
        :df5 => df5,
        :df6 => df6,
        :df7 => df7,
        :df8 => df8,
        :df9 => df9
    ),
    [header, kde1, kde2, kde3, kde4, kde5, kde6, kde7, kde8, kde9, conclusion],
    tab_title = "Kernel Density Examples"
)

create_html(page, "generated_html_examples/kerneldensity_examples.html")

println("\n" * "="^60)
println("Kernel Density examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/kerneldensity_examples.html")
println("\nThis page includes:")
println("  • Simple single distribution")
println("  • Multiple overlapping groups")
println("  • Interactive filters (numeric and categorical)")
println("  • Single and two-way faceting")
println("  • Bimodal distribution detection")
println("  • Custom bandwidth control")
println("  • Multiple value and group columns with dropdowns and bandwidth input")
println("  • Comprehensive example with all features combined")


