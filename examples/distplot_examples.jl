using JSPlots, DataFrames, Dates, Distributions, StableRNGs, TimeZones

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

# Example 6: Date/Time Filtering (Testing continuous filters for temporal types)
n = 100  # Need >20 unique values for each time column to trigger range sliders
base_date = Date(2024, 1, 1)
base_datetime = DateTime(2024, 1, 1, 0, 0, 0)
base_time = Time(0, 0, 0)

df6 = DataFrame(
    value = randn(rng, n) .* 20 .+ 100,
    date_col = [base_date + Day(i) for i in 1:n],  # 100 unique dates
    datetime_col = [base_datetime + Hour(i) for i in 1:n],  # 100 unique datetimes
    zoneddatetime_col = [ZonedDateTime(base_datetime + Hour(i), tz"UTC") for i in 1:n],  # 100 unique zoned datetimes
    time_col = [base_time + Minute(i*10) for i in 1:n],  # 100 unique times
    category = rand(rng, ["A", "B", "C"], n)
)

distplot6 = DistPlot(:datetime_filters, df6, :df6;
    value_cols = [:value],
    color_cols = [:category],
    filters = Dict(
        :date_col => df6.date_col[1:50],  # Default to first half of date range
        :datetime_col => df6.datetime_col,  # All datetimes selected by default
        :zoneddatetime_col => df6.zoneddatetime_col,  # All zoned datetimes
        :time_col => df6.time_col[26:75]  # Middle portion of time range
    ),
    show_controls = true,
    title = "Date/Time Filtering Test",
    notes = "This example tests continuous range filters for Date, DateTime, ZonedDateTime, and Time columns. All temporal types use range sliders for intuitive filtering. Try adjusting the range sliders to filter the data!"
)

# Example 7: Date/Time Range Sliders (Testing that all temporal types use sliders)
n = 140  # 140 rows but only 10 unique values per time column
base_date_cat = Date(2024, 1, 1)
base_datetime_cat = DateTime(2024, 1, 1, 0, 0, 0)
base_time_cat = Time(0, 0, 0)

# Create 10 unique values for each temporal type, repeated to make 140 rows
unique_dates = [base_date_cat + Day(i) for i in 1:10]
unique_datetimes = [base_datetime_cat + Hour(i*2) for i in 1:10]
unique_zoneddatetimes = [ZonedDateTime(base_datetime_cat + Hour(i*2), tz"UTC") for i in 1:10]
unique_times = [base_time_cat + Hour(i) for i in 1:10]

df7 = DataFrame(
    value = randn(rng, n) .* 15 .+ 90,
    date_cat = repeat(unique_dates, inner=14),  # 10 unique dates
    datetime_cat = repeat(unique_datetimes, inner=14),  # 10 unique datetimes
    zoneddatetime_cat = repeat(unique_zoneddatetimes, inner=14),  # 10 unique zoned datetimes
    time_cat = repeat(unique_times, inner=14),  # 10 unique times
    region = rand(rng, ["North", "South", "East", "West"], n)
)

distplot7 = DistPlot(:datetime_sliders, df7, :df7;
    value_cols = [:value],
    color_cols = [:region],
    filters = [:date_cat, :datetime_cat, :zoneddatetime_cat, :time_cat],  # All temporal types use sliders
    show_controls = true,
    title = "Date/Time Range Slider Filters Test",
    notes = "This example tests range slider filters for Date, DateTime, ZonedDateTime, and Time columns. All temporal types use range sliders regardless of the number of unique values, providing a consistent filtering experience."
)

# Example 8: Using a Struct as Data Source
# Demonstrates passing a struct containing DataFrames and referencing fields via dot notation

struct SurveyData
    responses::DataFrame
    demographics::DataFrame
end

# Create survey response data
n_responses = 400
survey_responses = DataFrame(
    satisfaction_score = randn(rng, n_responses) .* 15 .+ 70,
    recommendation_score = randn(rng, n_responses) .* 20 .+ 60,
    response_time = abs.(randn(rng, n_responses) .* 30 .+ 60),
    survey_type = rand(rng, ["Online", "Phone", "In-Person"], n_responses),
    age_group = rand(rng, ["18-25", "26-40", "41-60", "60+"], n_responses)
)

demographics_summary = DataFrame(
    age_group = ["18-25", "26-40", "41-60", "60+"],
    count = [120, 150, 90, 40]
)

# Create the struct
survey_data = SurveyData(survey_responses, demographics_summary)

struct_intro = TextBlock("""
<h2>Struct Data Source Example</h2>
<p>This distribution plot uses data from a struct containing multiple DataFrames.
The <code>SurveyData</code> struct holds both responses and demographics.
Charts reference the responses DataFrame using <code>Symbol("survey.responses")</code>.</p>
""")

distplot8 = DistPlot(:struct_dist, survey_data.responses, Symbol("survey.responses");
    value_cols = [:satisfaction_score, :recommendation_score, :response_time],
    color_cols = [:survey_type, :age_group],
    show_controls = true,
    title = "Survey Results from Struct Data Source",
    notes = "This example shows how to use a struct as a data source. The SurveyData struct " *
           "contains responses and demographics DataFrames. Access struct fields via dot notation."
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
# Note: survey_data struct is passed directly - JSPlotPage will extract its DataFrame fields
page = JSPlotPage(
    Dict{Symbol,Any}(
        :df1 => df1,
        :df2 => df2,
        :df3 => df3,
        :df4 => df4,
        :df5 => df5,
        :df6 => df6,
        :df7 => df7,
        :survey => survey_data  # Struct with responses and demographics
    ),
    [header, distplot1, distplot2, distplot3, distplot4, distplot5, distplot6, distplot7, struct_intro, distplot8, conclusion],
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
println("  • Date/Time filtering with range sliders (>20 unique values)")
println("  • Date/Time filtering with dropdown lists (<20 unique values)")
println("  • Struct data source (referencing struct fields via dot notation)")
