using JSPlots, DataFrames, Dates, StableRNGs, CategoricalArrays

rng = StableRNG(666)

println("Creating SanKey examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/sankey_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>SanKey (Alluvial Diagram) Examples</h1>
<p>This page demonstrates the interactive SanKey chart type in JSPlots.</p>
<ul>
    <li><strong>Flow visualization:</strong> Shows how entities transition between categories across time</li>
    <li><strong>Long-format panel data:</strong> Each row represents one entity at one time point</li>
    <li><strong>Switchable affiliations:</strong> Use dropdown to change which grouping to visualize</li>
    <li><strong>Weighted flows:</strong> Ribbon width represents volume/value flowing between categories</li>
    <li><strong>Interactive filtering:</strong> Filter data to focus on specific segments</li>
</ul>
""")

# =============================================================================
# Example 1: Voter Transitions Across Four Elections
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Voter Transitions (2012 → 2024)</h2>
<p>Track how individual voters changed their party affiliation, employment status, and education level across four presidential elections.</p>
<p>This rich example demonstrates:</p>
<ul>
    <li>Panel data: 2000 voters tracked across 4 elections (2012, 2016, 2020, 2024)</li>
    <li>Three switchable affiliations: Political party, Employment status, Education level</li>
    <li>Two value columns: Voter count and Weighted by turnout propensity</li>
    <li>Regional and age group filters for demographic analysis</li>
    <li>Realistic party switching patterns showing polarization trends</li>
</ul>
""")

# Create rich voter data with multiple demographics
n_voters = 2000
voter_data = []

regions = ["Northeast", "South", "Midwest", "West"]
age_groups = ["18-29", "30-44", "45-64", "65+"]
education_levels = ["High School", "Some College", "Bachelor's", "Graduate"]

for voter_id in 1:n_voters
    # Fixed demographics
    region = rand(rng, regions)
    age_group = rand(rng, age_groups)

    # 2012 status
    party_2012 = rand(rng, ["Democrat", "Republican", "Independent", "Other"])
    employment_2012 = rand(rng, ["Employed Full-time", "Employed Part-time", "Unemployed", "Student", "Retired"])
    education_2012 = rand(rng, education_levels)
    turnout_weight_2012 = Float64(rand(rng, 5:10)) / 10.0  # 0.5 to 1.0

    # 2016 - Obama to Trump transition (higher switching rates)
    party_2016 = if party_2012 == "Independent"
        rand(rng) < 0.4 ? rand(rng, ["Democrat", "Republican"]) : "Independent"
    elseif party_2012 == "Democrat" && region in ["Midwest", "South"]
        rand(rng) < 0.25 ? "Republican" : (rand(rng) < 0.15 ? "Independent" : "Democrat")
    elseif party_2012 == "Republican"
        rand(rng) < 0.12 ? "Independent" : "Republican"
    else
        rand(rng) < 0.2 ? rand(rng, ["Democrat", "Republican", "Independent", "Other"]) : party_2012
    end
    employment_2016 = rand(rng) < 0.15 ? rand(rng, ["Employed Full-time", "Employed Part-time", "Unemployed", "Retired"]) : employment_2012
    education_2016 = rand(rng) < 0.1 && education_2012 != "Graduate" ?
        education_levels[min(findfirst(==(education_2012), education_levels) + 1, length(education_levels))] : education_2012
    turnout_weight_2016 = turnout_weight_2012 * rand(rng, 0.85:0.01:1.15)

    # 2020 - High polarization, less switching
    party_2020 = if party_2016 == "Independent"
        rand(rng) < 0.35 ? rand(rng, ["Democrat", "Republican"]) : "Independent"
    else
        rand(rng) < 0.08 ? rand(rng, ["Democrat", "Republican", "Independent"]) : party_2016
    end
    employment_2020 = rand(rng) < 0.12 ? rand(rng, ["Employed Full-time", "Employed Part-time", "Unemployed", "Retired"]) : employment_2016
    education_2020 = rand(rng) < 0.08 && education_2016 != "Graduate" ?
        education_levels[min(findfirst(==(education_2016), education_levels) + 1, length(education_levels))] : education_2016
    turnout_weight_2020 = turnout_weight_2016 * rand(rng, 0.9:0.01:1.2)

    # 2024 - Continued polarization
    party_2024 = if party_2020 == "Independent"
        rand(rng) < 0.3 ? rand(rng, ["Democrat", "Republican"]) : "Independent"
    else
        rand(rng) < 0.07 ? rand(rng, ["Democrat", "Republican", "Independent"]) : party_2020
    end
    employment_2024 = rand(rng) < 0.1 ? rand(rng, ["Employed Full-time", "Employed Part-time", "Unemployed", "Retired"]) : employment_2020
    education_2024 = rand(rng) < 0.06 && education_2020 != "Graduate" ?
        education_levels[min(findfirst(==(education_2020), education_levels) + 1, length(education_levels))] : education_2020
    turnout_weight_2024 = turnout_weight_2020 * rand(rng, 0.9:0.01:1.15)

    for (year, party, employment, education, turnout) in [
        (2012, party_2012, employment_2012, education_2012, turnout_weight_2012),
        (2016, party_2016, employment_2016, education_2016, turnout_weight_2016),
        (2020, party_2020, employment_2020, education_2020, turnout_weight_2020),
        (2024, party_2024, employment_2024, education_2024, turnout_weight_2024)
    ]
        push!(voter_data, (
            voter_id = voter_id,
            year = year,
            party = party,
            employment = employment,
            education = education,
            region = region,
            age_group = age_group,
            count = 1,
            turnout_weighted = turnout
        ))
    end
end

df_voters = DataFrame(voter_data)

ribbon1 = SanKey(:voters, df_voters, :voter_data;
    id_col = :voter_id,
    time_col = :year,
    color_cols = [:party, :employment, :education],
    value_cols = [:count, :turnout_weighted],
    filters = [:region, :age_group],
    title = "Voter Transitions 2012-2024",
    notes = "This Sankey diagram shows voter transitions across four presidential elections (2012, 2016, 2020, 2024). Use the 'Affiliation' dropdown to switch between party, employment, or education views. Use 'Weight By' to see raw counts vs. turnout-weighted flows. Filter by region and age group to analyze demographic patterns. Notice the increased party switching in 2016 and subsequent polarization in 2020-2024."
)


# =============================================================================
# Example 1b: Choices vs Filters
# =============================================================================

example1b_text = TextBlock("""
<h2>Example 1b: Choices vs Filters</h2>
<p>Demonstrates the difference between choices (single-select) and filters (multi-select).</p>
""")

ribbon1b = SanKey(:voters_choices, df_voters, :voter_data;
    id_col = :voter_id,
    time_col = :year,
    color_cols = [:party, :employment],
    value_cols = [:count, :turnout_weighted],
    choices = Dict{Symbol,Any}(:region => "Northeast"),  # Single-select: user picks ONE region
    filters = Dict{Symbol,Any}(:age_group => ["18-29", "30-44", "45-64", "65+"]),  # Multi-select: can select multiple age groups
    title = "Voter Transitions (Single-Select Region)",
    notes = """
    This example demonstrates the difference between choices and filters:
    - **Region (choice)**: Single-select dropdown - pick exactly ONE region at a time
    - **Age Group (filter)**: Multi-select dropdown - can select multiple age groups

    Use choices when the user must select exactly one option (like comparing transitions region by region).
    """
)

# =============================================================================
# Example 2: Budget Flow Tracking
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Shopkeeper Budget Flow Analysis</h2>
<p>Track individual money flows from revenue sources through total budget to spending destinations.</p>
<p>This example demonstrates:</p>
<ul>
    <li>Flow tracking with explicit flow IDs (each dollar tracked from source to destination)</li>
    <li>Three stages: Revenue → Total Budget → Spending</li>
    <li>Legal vs illegal income streams (filter by tax return inclusion)</li>
    <li>Long format: Each flow represented by 3 rows (one per stage) sharing the same flow_id</li>
    <li>Shows how specific revenue sources fund specific expenses</li>
</ul>
""")

# Create budget data in LONG format where each flow is tracked with an id
# Each row represents a unit of money at a particular stage
# The flow_id tracks money from source → total → destination

flows = DataFrame[]

# Legal income flows
push!(flows, DataFrame(
    flow_id = fill("beer_to_rent", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling beer", "Declared Revenue", "Rent"],
    Value = fill(60.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("beer_to_food", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling beer", "Declared Revenue", "Food"],
    Value = fill(40.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("wine_to_food", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling wine", "Declared Revenue", "Food"],
    Value = fill(150.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("spirits_to_rent", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling spirits", "Declared Revenue", "Rent"],
    Value = fill(200.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("cocktails_to_education", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling cocktails", "Declared Revenue", "Home Education"],
    Value = fill(210.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("cocktails_to_rent", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling cocktails", "Declared Revenue", "Rent"],
    Value = fill(40.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("softdrinks_to_food", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling soft drinks", "Declared Revenue", "Food"],
    Value = fill(160.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("softdrinks_to_beer", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling soft drinks", "Declared Revenue", "Buying Beer"],
    Value = fill(20.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("snacks_to_rent", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling snacks", "Declared Revenue", "Rent"],
    Value = fill(50.0, 3),
    income_type = fill("Legal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("snacks_to_beer", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling snacks", "Declared Revenue", "Buying Beer"],
    Value = fill(40.0, 3),
    income_type = fill("Legal", 3)
))

# Illegal income flows (weed → undeclared revenue → various)
push!(flows, DataFrame(
    flow_id = fill("weed_to_weed_purchase", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling weed", "Undeclared Revenue", "Buying weed"],
    Value = fill(100.0, 3),
    income_type = fill("Illegal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("weed_to_bitcoin", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Selling weed", "Undeclared Revenue", "Put into Bitcoin"],
    Value = fill(100.0, 3),
    income_type = fill("Illegal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("loansharking_to_bitcoin", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Interest earned while loansharking", "Undeclared Revenue", "Put into Bitcoin"],
    Value = fill(300.0, 3),
    income_type = fill("Illegal", 3)
))

push!(flows, DataFrame(
    flow_id = fill("loansharking_to_rent", 3),
    stage = ["Revenue", "Total Budget", "Spending"],
    Product = ["Interest earned while loansharking", "Undeclared Revenue", "Rent"],
    Value = fill(50.0, 3),
    income_type = fill("Illegal", 3)
))

# Combine all flows
shopkeeper_budget = reduce(vcat, flows)

# IMPORTANT: Convert stage to ordered categorical with explicit levels
shopkeeper_budget[!, :stage] = categorical(
    shopkeeper_budget.stage,
    levels=["Revenue", "Total Budget", "Spending"],
    ordered=true
)

ribbon2 = SanKey(:budget, shopkeeper_budget, :shopkeeper_budget;
    id_col = :flow_id,  # Track flows across stages
    time_col = :stage,
    color_cols = [:Product],
    value_cols = [:Value],
    filters = [:income_type],
    title = "Shopkeeper Budget Flows",
    notes = "This Sankey diagram shows money flows in a shopkeeper's budget. Each ribbon tracks specific money from its source (left) through total revenue (middle) to final destination (right). Use the filter to toggle between Legal and Illegal income streams. Notice how illegal income flows to Bitcoin and cash purchases while legal income pays regular expenses."
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The SanKey chart type provides:</p>
<ul>
    <li><strong>Panel data visualization:</strong> Track entities across time periods</li>
    <li><strong>Long-format data:</strong> Each row = one entity at one time point</li>
    <li><strong>Required parameters:</strong>
        <ul>
            <li><code>id_col</code>: Column identifying each entity</li>
            <li><code>time_col</code>: Column indicating time/stage (Date, Number, or OrderedCategorical)</li>
            <li><code>color_cols</code>: Column(s) for group affiliation</li>
        </ul>
    </li>
    <li><strong>Optional features:</strong>
        <ul>
            <li><code>value_cols</code>: Weight the flows (default: equal weighting)</li>
            <li>Multiple color/value columns with dropdown switchers</li>
            <li>Filters to focus on segments</li>
        </ul>
    </li>
    <li><strong>Interactive controls:</strong> Switch affiliations and weights on the fly</li>
    <li><strong>Automatic flow calculation:</strong> Tracks transitions between consecutive time periods</li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li>Voter behavior analysis (party switching, demographic changes)</li>
    <li>Customer journey mapping and conversion funnel analysis</li>
    <li>Employee career progression and retention analysis</li>
    <li>Product lifecycle and market share evolution</li>
    <li>Patient health state transitions in medical studies</li>
    <li>Student progression through education levels</li>
    <li>Any entity-based transition analysis over time</li>
</ul>

<h3>Data Format Tips</h3>
<ul>
    <li>Each entity must have observations at each time point you want to include</li>
    <li>Missing time points = entity disappears from flow at that stage</li>
    <li>Time values are automatically sorted (works with dates, numbers, ordered categories)</li>
    <li>Use filters to focus on specific cohorts or segments</li>
    <li>Multiple affiliation columns let users explore different grouping perspectives</li>
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
    Dict{Symbol, Any}(
        :voter_data => df_voters,
        :shopkeeper_budget => shopkeeper_budget
    ),
    [header, example1_text, ribbon1, example1b_text, ribbon1b, example2_text, ribbon2, summary];
    dataformat=:csv_embedded
)

output_file = joinpath(output_dir, "sankey_examples.html")
# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="sankey_examples.html",
                               description="SanKey Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Situational Charts", :page_type => "Chart Tutorial"))
create_html(page, output_file;
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)
println("Created: $output_file")

println("\nSanKey examples complete!")
println("Open the HTML file in a browser to see the interactive Sankey diagrams.")
println("\nTry using the 'Affiliation' and 'Weight By' dropdowns to explore different perspectives!")
