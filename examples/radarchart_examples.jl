using JSPlots, DataFrames, Statistics, Random, StableRNGs

println("Creating RadarChart examples...")

# =============================================================================
# Example 1: Simple Radar Chart - Product Comparison
# =============================================================================

header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/radarchart_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>RadarChart - Multi-Dimensional Data Visualization</h1>
<p>The RadarChart (also known as spider chart or web chart) displays multivariate data on axes starting from the same point.
Each axis represents a different variable, and values are plotted as a polygon.</p>
<p><strong>Use cases:</strong></p>
<ul>
    <li><strong>Product comparison:</strong> Compare products across multiple features</li>
    <li><strong>Performance evaluation:</strong> Show strengths and weaknesses across different metrics</li>
    <li><strong>Nutritional analysis:</strong> Display nutritional content of foods</li>
    <li><strong>Skills assessment:</strong> Visualize competency levels across different skills</li>
    <li><strong>Portfolio analysis:</strong> Compare investment options across multiple criteria</li>
</ul>
<p><strong>Interactive features:</strong></p>
<ul>
    <li>Select specific items to display</li>
    <li>Filter variables to show</li>
    <li>Group related variables together</li>
    <li>Color by category</li>
    <li>Facet for comparison</li>
</ul>
""")

example1_text = TextBlock("""
<h2>Example 1: Smartphone Comparison</h2>
<p>Compare different smartphone models across key specifications.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Basic radar chart with multiple axes</li>
    <li>Multiple items displayed</li>
    <li>Item selector to choose which phones to compare</li>
</ul>
<p><strong>Try this:</strong> Select different phones to compare their specifications.</p>
""")

# Smartphone data (normalized scores 0-100)
phones_df = DataFrame(
    label = ["iPhone 15 Pro", "Samsung S24 Ultra", "Google Pixel 8 Pro", "OnePlus 12"],
    Battery = [85.0, 95.0, 80.0, 90.0],
    Camera = [95.0, 98.0, 92.0, 88.0],
    Performance = [98.0, 96.0, 90.0, 94.0],
    Display = [92.0, 98.0, 90.0, 95.0],
    Price_Value = [70.0, 65.0, 85.0, 90.0],
    Build_Quality = [95.0, 93.0, 88.0, 90.0]
)

radar1 = RadarChart(:phones_radar, :phones_data;
    value_cols = [:Battery, :Camera, :Performance, :Display, :Price_Value, :Build_Quality],
    label_col = :label,
    title = "Smartphone Specifications Comparison",
    notes = "Scores normalized to 0-100 scale. Higher values indicate better performance.",
    max_value = 100.0,
    default_color = "#2563eb"
)

# =============================================================================
# Example 2: Radar Chart with Grouping
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Food Nutritional Profile with Grouped Axes</h2>
<p>Analyze nutritional content of different foods with axes grouped by category (similar to the image in the request).</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Grouped axes (Nutrition, Sensory, Economics, Sustainability)</li>
    <li>Multiple food items</li>
    <li>Category-based coloring</li>
</ul>
<p><strong>Try this:</strong> Select different foods to see their nutritional and sustainability profiles.</p>
""")

# Food nutrition data
foods_df = DataFrame(
    label = ["Organic Apple", "Conventional Apple", "Organic Banana", "Conventional Banana",
             "Organic Broccoli", "Conventional Broccoli"],
    category = ["Fruit", "Fruit", "Fruit", "Fruit", "Vegetable", "Vegetable"],
    # Nutrition group
    Vitamin_C = [8.0, 6.0, 10.0, 9.0, 95.0, 85.0],
    Fiber = [4.0, 4.0, 3.0, 2.6, 5.0, 4.5],
    Antioxidants = [7.5, 5.0, 6.0, 4.5, 9.0, 7.0],
    # Sensory group
    Sweetness = [8.0, 7.5, 9.0, 8.5, 2.0, 2.5],
    Aroma = [7.0, 6.0, 6.5, 6.0, 5.0, 4.5],
    Acidity = [6.0, 6.5, 2.0, 2.5, 3.0, 3.5],
    Juiciness = [8.5, 8.0, 4.0, 4.5, 3.0, 3.0],
    Firmness = [7.0, 6.5, 4.0, 4.5, 8.0, 7.5],
    Smoothness = [9.0, 8.5, 8.0, 7.5, 4.0, 4.5],
    # Economics group
    Affordability = [5.0, 8.0, 6.0, 9.0, 4.0, 7.0],
    Price = [4.0, 7.0, 5.0, 8.0, 3.0, 6.0],
    Yield = [6.0, 7.0, 7.0, 8.0, 5.0, 6.0],
    # Sustainability group
    CO2e = [8.0, 6.0, 7.0, 5.0, 9.0, 7.0],
    Water_use = [7.0, 5.0, 6.0, 4.0, 8.0, 6.0],
    Pesticides = [9.0, 3.0, 8.5, 2.5, 9.5, 3.5],
    Biodiversity = [8.5, 4.0, 8.0, 3.5, 9.0, 4.5]
)

# Define grouping
food_groups = Dict{Symbol, String}(
    :Vitamin_C => "Nutrition",
    :Fiber => "Nutrition",
    :Antioxidants => "Nutrition",
    :Sweetness => "Sensory",
    :Aroma => "Sensory",
    :Acidity => "Sensory",
    :Juiciness => "Sensory",
    :Firmness => "Sensory",
    :Smoothness => "Sensory",
    :Affordability => "Economics",
    :Price => "Economics",
    :Yield => "Economics",
    :CO2e => "Sustainability",
    :Water_use => "Sustainability",
    :Pesticides => "Sustainability",
    :Biodiversity => "Sustainability"
)

radar2 = RadarChart(:foods_radar, :foods_data;
    value_cols = [:Vitamin_C, :Fiber, :Antioxidants, :Sweetness, :Aroma, :Acidity,
                  :Juiciness, :Firmness, :Smoothness, :Affordability, :Price, :Yield,
                  :CO2e, :Water_use, :Pesticides, :Biodiversity],
    label_col = :label,
    group_mapping = food_groups,
    color_col = :category,
    title = "Food Nutritional and Sustainability Profile",
    notes = "Axes are grouped by category: Nutrition, Sensory, Economics, and Sustainability. Higher values are better.",
    max_value = 100.0,
    show_legend = true
)

# =============================================================================
# Example 3: Variable Selector
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Skills Assessment with Variable Selector</h2>
<p>Evaluate employee skills across different competencies with the ability to select which skills to display.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Variable selector for choosing which axes to display</li>
    <li>Many variables available (only subset shown at once)</li>
    <li>Department-based coloring</li>
</ul>
<p><strong>Try this:</strong> Use the variable selector to choose which skills to compare. You need to select at least 3 variables.</p>
""")

# Employee skills data
employees_df = DataFrame(
    label = ["Alice (Eng)", "Bob (Eng)", "Carol (Marketing)", "Dave (Sales)", "Eve (Product)"],
    department = ["Engineering", "Engineering", "Marketing", "Sales", "Product"],
    # Technical skills
    Programming = [95.0, 90.0, 30.0, 20.0, 60.0],
    System_Design = [85.0, 80.0, 25.0, 15.0, 70.0],
    Data_Analysis = [75.0, 85.0, 60.0, 55.0, 80.0],
    # Business skills
    Communication = [70.0, 65.0, 95.0, 90.0, 85.0],
    Presentation = [65.0, 60.0, 90.0, 95.0, 80.0],
    Negotiation = [50.0, 55.0, 75.0, 95.0, 70.0],
    # Management skills
    Leadership = [60.0, 55.0, 80.0, 75.0, 85.0],
    Project_Management = [75.0, 70.0, 85.0, 65.0, 90.0],
    Team_Building = [65.0, 70.0, 90.0, 80.0, 85.0],
    # Domain knowledge
    Product_Knowledge = [80.0, 75.0, 85.0, 90.0, 95.0],
    Market_Knowledge = [40.0, 35.0, 90.0, 95.0, 85.0],
    Technical_Writing = [85.0, 80.0, 70.0, 40.0, 75.0]
)

radar3 = RadarChart(:skills_radar, :skills_data;
    value_cols = [:Programming, :System_Design, :Data_Analysis, :Communication,
                  :Presentation, :Negotiation, :Leadership, :Project_Management,
                  :Team_Building, :Product_Knowledge, :Market_Knowledge, :Technical_Writing],
    label_col = :label,
    color_col = :department,
    variable_selector = true,
    max_variables = 5,
    title = "Employee Skills Assessment",
    notes = "Select which skills to compare. Colored by department.",
    max_value = 100.0,
    show_legend = true
)

# =============================================================================
# Example 4: Faceting Support
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: University Rankings with Faceting</h2>
<p>Compare universities across different metrics with faceting by region and type.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Faceting by region (geographic location)</li>
    <li>Faceting by type (public/private)</li>
    <li>Multiple universities displayed simultaneously</li>
</ul>
<p><strong>Try this:</strong> Use the facet selectors to filter universities by region and type.</p>
""")

# University rankings data
universities_df = DataFrame(
    label = ["MIT", "Stanford", "Harvard", "Berkeley", "Caltech",
             "Oxford", "Cambridge", "ETH Zurich", "Tokyo", "NUS"],
    region = ["North America", "North America", "North America", "North America", "North America",
              "Europe", "Europe", "Europe", "Asia", "Asia"],
    type = ["Private", "Private", "Private", "Public", "Private",
            "Public", "Public", "Public", "Public", "Public"],
    Academic_Reputation = [100.0, 98.0, 99.0, 96.0, 97.0, 98.0, 97.0, 95.0, 93.0, 92.0],
    Research_Output = [99.0, 98.0, 97.0, 95.0, 96.0, 96.0, 95.0, 94.0, 91.0, 88.0],
    Faculty_Quality = [98.0, 99.0, 98.0, 94.0, 99.0, 97.0, 96.0, 95.0, 90.0, 87.0],
    Industry_Connections = [95.0, 100.0, 92.0, 90.0, 94.0, 88.0, 85.0, 92.0, 85.0, 90.0],
    International_Outlook = [88.0, 90.0, 85.0, 82.0, 87.0, 95.0, 94.0, 98.0, 75.0, 100.0],
    Student_Satisfaction = [92.0, 94.0, 90.0, 88.0, 91.0, 93.0, 92.0, 90.0, 85.0, 87.0]
)

radar4 = RadarChart(:universities_radar, :universities_data;
    value_cols = [:Academic_Reputation, :Research_Output, :Faculty_Quality,
                  :Industry_Connections, :International_Outlook, :Student_Satisfaction],
    label_col = :label,
    facet_x = :region,
    facet_y = :type,
    color_col = :region,
    title = "University Rankings Comparison",
    notes = "Compare top universities across key metrics. Use facet selectors to filter by region and type.",
    max_value = 100.0,
    show_legend = true
)

# =============================================================================
# Example 5: Investment Portfolio Analysis
# =============================================================================

example5_text = TextBlock("""
<h2>Example 5: Investment Portfolio Analysis</h2>
<p>Analyze different investment options across risk, return, and other factors.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Financial metrics visualization</li>
    <li>Risk/return tradeoffs</li>
    <li>Asset class coloring</li>
</ul>
<p><strong>Try this:</strong> Compare different investment options to understand their risk/return profiles.</p>
""")

# Investment data
investments_df = DataFrame(
    label = ["US Stocks", "International Stocks", "Bonds", "Real Estate", "Commodities", "Cash"],
    asset_class = ["Equity", "Equity", "Fixed Income", "Alternative", "Alternative", "Cash"],
    Expected_Return = [8.0, 7.5, 3.5, 6.0, 5.0, 1.5],
    Risk_Adjusted_Return = [6.5, 6.0, 3.0, 5.5, 4.0, 1.5],
    Liquidity = [9.5, 9.0, 8.0, 4.0, 7.0, 10.0],
    Diversification = [8.0, 9.0, 6.0, 7.0, 8.5, 0.0],
    Tax_Efficiency = [6.0, 5.5, 7.0, 8.0, 6.5, 9.0],
    Inflation_Protection = [7.0, 7.5, 3.0, 8.0, 9.0, 1.0]
)

radar5 = RadarChart(:investments_radar, :investments_data;
    value_cols = [:Expected_Return, :Risk_Adjusted_Return, :Liquidity,
                  :Diversification, :Tax_Efficiency, :Inflation_Protection],
    label_col = :label,
    color_col = :asset_class,
    title = "Investment Options Analysis",
    notes = "Compare investment options across multiple criteria. Higher values are better.",
    max_value = 10.0,
    show_legend = true
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The RadarChart provides powerful multi-dimensional visualization with these key capabilities:</p>

<h3>Data Requirements</h3>
<ul>
    <li><strong>Row structure:</strong> Each row represents one item (product, person, entity)</li>
    <li><strong>Value columns:</strong> Numeric columns that become radar axes</li>
    <li><strong>Label column:</strong> Identifies each item</li>
    <li><strong>Optional categorical columns:</strong> For coloring and faceting</li>
</ul>

<h3>Key Features</h3>
<ul>
    <li><strong>Grouped axes:</strong> Group related metrics together with labels</li>
    <li><strong>Variable selector:</strong> Choose which axes to display</li>
    <li><strong>Item selector:</strong> Choose which items to compare</li>
    <li><strong>Faceting:</strong> Filter by categorical variables</li>
    <li><strong>Color coding:</strong> Color items by category</li>
    <li><strong>Flexible scaling:</strong> Auto-scale or specify maximum value</li>
</ul>

<h3>Best Practices</h3>
<ul>
    <li><strong>3-12 axes:</strong> Too few is uninformative, too many is cluttered</li>
    <li><strong>Similar scales:</strong> Works best when all metrics are on similar scales</li>
    <li><strong>Normalized data:</strong> Consider normalizing to 0-100 or 0-10 for clarity</li>
    <li><strong>Limited items:</strong> Show 1-4 items per chart for readability</li>
    <li><strong>Meaningful grouping:</strong> Group related axes together</li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li>Product comparison and competitive analysis</li>
    <li>Performance evaluation and skill assessment</li>
    <li>Nutritional analysis and food comparison</li>
    <li>Investment portfolio analysis</li>
    <li>Survey results visualization</li>
    <li>Quality metrics and KPI tracking</li>
</ul>
""")

# =============================================================================
# Create the page
# =============================================================================

# Collect all data
data_dict = Dict{Symbol, DataFrame}(
    :phones_data => phones_df,
    :foods_data => foods_df,
    :skills_data => employees_df,
    :universities_data => universities_df,
    :investments_data => investments_df
)

# Create page
page = JSPlotPage(
    data_dict,
    [header,
     example1_text, radar1,
     example2_text, radar2,
     example3_text, radar3,
     example4_text, radar4,
     example5_text, radar5,
     summary];
    dataformat = :csv_embedded
)

# Output
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end

output_file = joinpath(output_dir, "radarchart_examples.html")
create_html(page, output_file)
println("Created: $output_file")

println("\nRadarChart examples complete!")
println("Open the HTML file in a browser to see interactive radar charts.")
println("\nExplore variable selection, faceting, and color coding!")
