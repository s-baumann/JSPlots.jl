using JSPlots, DataFrames, StableRNGs

rng = StableRNG(666)

println("Creating RibbonPlot examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/ribbonplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>RibbonPlot (Alluvial Diagram) Examples</h1>
<p>This page demonstrates the interactive RibbonPlot chart type in JSPlots.</p>
<ul>
    <li><strong>Flow visualization:</strong> Shows how categories transition across multiple timestages</li>
    <li><strong>Weighted ribbons:</strong> Ribbon width represents volume/value flowing between categories</li>
    <li><strong>Multiple weighting options:</strong> Switch between different value columns to see different perspectives</li>
    <li><strong>Interactive filtering:</strong> Filter data to focus on specific segments</li>
    <li><strong>Hover details:</strong> See exact flow values on hover</li>
</ul>
""")

# =============================================================================
# Example 1: Customer Journey Flow
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Customer Journey Flow</h2>
<p>Track how customers move through different stages of a purchase funnel.</p>
<p>This example shows:</p>
<ul>
    <li>Three stages: Awareness, Consideration, Purchase</li>
    <li>Weighted by number of customers</li>
    <li>Visualize conversion paths</li>
</ul>
""")

# Create customer journey data
journey_data = DataFrame[]
for _ in 1:500
    awareness = rand(rng, ["Social Media", "Search", "Referral", "Direct"])
    consideration = rand(rng, ["Product Page", "Reviews", "Blog", "Comparison"])
    purchase = rand(rng, ["Buy Now", "Cart", "Abandoned", "Saved"])

    push!(journey_data, DataFrame(
        awareness = awareness,
        consideration = consideration,
        purchase = purchase,
        customers = rand(rng, 1:20)
    ))
end
df_journey = vcat(journey_data...)

ribbon1 = RibbonPlot(:journey, df_journey, :journey_data;
    timestage_cols = [:awareness, :consideration, :purchase],
    value_cols = :customers,
    title = "Customer Journey Flow",
    notes = "This ribbon plot shows how customers flow from awareness channels through consideration to purchase outcomes. Ribbon width represents the number of customers following each path."
)

# =============================================================================
# Example 2: Product Evolution with Multiple Weights
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Product Category Evolution</h2>
<p>See how products evolve through different categories over time.</p>
<p>Features:</p>
<ul>
    <li>Multiple value columns: sales and quantity</li>
    <li>Switch weighting using dropdown</li>
    <li>Compare volume vs revenue perspectives</li>
</ul>
""")

# Create product evolution data
product_data = DataFrame[]
for _ in 1:300
    q1_cat = rand(rng, ["Electronics", "Clothing", "Home", "Sports"])
    q2_cat = rand(rng, ["Electronics", "Clothing", "Home", "Sports", "New Category"])
    q3_cat = rand(rng, ["Electronics", "Clothing", "Home", "Sports", "New Category"])

    push!(product_data, DataFrame(
        q1_category = q1_cat,
        q2_category = q2_cat,
        q3_category = q3_cat,
        sales = rand(rng, 100:5000),
        quantity = rand(rng, 1:100)
    ))
end
df_products = vcat(product_data...)

ribbon2 = RibbonPlot(:products, df_products, :product_data;
    timestage_cols = [:q1_category, :q2_category, :q3_category],
    value_cols = [:sales, :quantity],
    title = "Product Category Evolution (Q1→Q2→Q3)",
    notes = "This ribbon plot shows how product categories evolve quarter over quarter. Use the 'Weight By' dropdown to switch between viewing by sales revenue or unit quantity."
)

# =============================================================================
# Example 3: Employee Career Progression with Filters
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Employee Career Progression</h2>
<p>Track employee movement through departments and roles over their career.</p>
<p>This example includes:</p>
<ul>
    <li>Four career stages: Entry, Mid-level, Senior, Leadership</li>
    <li>Regional filter to focus on specific offices</li>
    <li>Department filter for targeted analysis</li>
</ul>
""")

# Create career progression data
career_data = DataFrame[]
regions = ["North", "South", "East", "West"]
departments = ["Engineering", "Sales", "Marketing", "Operations"]

for region in regions
    for dept in departments
        for _ in 1:30
            entry_role = rand(rng, ["Junior $dept", "Associate $dept", "Intern"])
            mid_role = rand(rng, ["$dept Specialist", "Senior Associate", "$dept Analyst"])
            senior_role = rand(rng, ["Senior $dept", "Lead $dept", "$dept Manager"])
            leadership_role = rand(rng, ["Director", "VP $dept", "Stayed Senior"])

            push!(career_data, DataFrame(
                entry_level = entry_role,
                mid_level = mid_role,
                senior_level = senior_role,
                leadership_level = leadership_role,
                region = region,
                department = dept,
                employees = rand(rng, 1:10)
            ))
        end
    end
end
df_careers = vcat(career_data...)

ribbon3 = RibbonPlot(:careers, df_careers, :career_data;
    timestage_cols = [:entry_level, :mid_level, :senior_level, :leadership_level],
    value_cols = :employees,
    filters = Dict{Symbol,Any}(
        :region => ["North"],
        :department => ["Engineering"]
    ),
    title = "Employee Career Progression Paths",
    notes = "This ribbon plot tracks employee career paths from entry-level to leadership. Use region and department filters to focus on specific segments. Wider ribbons indicate more common career paths."
)

# =============================================================================
# Example 4: Equal Weighting (Count Mode)
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: Survey Response Flow (Equal Weighting)</h2>
<p>When no value column is specified, each observation is weighted equally.</p>
<p>This example shows:</p>
<ul>
    <li>Survey responses across three questions</li>
    <li>Equal weight per response</li>
    <li>Simple frequency-based flow visualization</li>
</ul>
""")

# Create survey data
survey_data = DataFrame[]
for _ in 1:400
    q1 = rand(rng, ["Strongly Agree", "Agree", "Neutral", "Disagree"])
    q2 = rand(rng, ["Very Satisfied", "Satisfied", "Neutral", "Unsatisfied"])
    q3 = rand(rng, ["Definitely", "Probably", "Maybe", "No"])

    push!(survey_data, DataFrame(
        question1 = q1,
        question2 = q2,
        question3 = q3
    ))
end
df_survey = vcat(survey_data...)

ribbon4 = RibbonPlot(:survey, df_survey, :survey_data;
    timestage_cols = [:question1, :question2, :question3],
    title = "Survey Response Pattern Flow",
    notes = "This ribbon plot shows survey response patterns across three questions. Each response is weighted equally, showing the frequency of different response paths."
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The RibbonPlot chart type provides:</p>
<ul>
    <li><strong>Alluvial visualization:</strong> Sankey-style flow diagrams showing transitions between categories</li>
    <li><strong>Multiple timestages:</strong> Visualize 2 or more sequential stages</li>
    <li><strong>Flexible weighting:</strong>
        <ul>
            <li>Equal weighting (count mode) when no value column specified</li>
            <li>Single value column for weighted flows</li>
            <li>Multiple value columns with dropdown to switch perspectives</li>
        </ul>
    </li>
    <li><strong>Interactive filtering:</strong> Filter data to focus on specific segments</li>
    <li><strong>Color coding:</strong> Colors distinguish different stages for easy reading</li>
    <li><strong>Hover details:</strong> See exact flow values when hovering over ribbons</li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li>Customer journey mapping and conversion funnel analysis</li>
    <li>Employee career progression and retention analysis</li>
    <li>Product category evolution over time</li>
    <li>Survey response patterns</li>
    <li>State transitions in processes or systems</li>
    <li>Migration flows between locations or categories</li>
    <li>Any multi-stage categorical transition analysis</li>
</ul>

<h3>Tips</h3>
<ul>
    <li>Use 2-5 timestages for best readability (too many stages can become cluttered)</li>
    <li>Provide multiple value columns to let users explore different perspectives</li>
    <li>Use filters to focus on specific segments when data is complex</li>
    <li>Ribbon width represents the total value flowing between categories</li>
    <li>Colors help distinguish different stages in the flow</li>
</ul>
""")

# =============================================================================
# Create the page
# =============================================================================

# Output to the main generated_html_examples directory
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end

# Create embedded format
page = JSPlotPage(
    Dict{Symbol, DataFrame}(
        :journey_data => df_journey,
        :product_data => df_products,
        :career_data => df_careers,
        :survey_data => df_survey
    ),
    [header, example1_text, ribbon1, example2_text, ribbon2,
     example3_text, ribbon3, example4_text, ribbon4, summary];
    dataformat=:csv_embedded
)

output_file = joinpath(output_dir, "ribbonplot_examples.html")
create_html(page, output_file)
println("Created: $output_file")

println("\nRibbonPlot examples complete!")
println("Open the HTML file in a browser to see the interactive ribbon plots.")
println("\nTry using the filters and value column dropdown to explore different views!")
