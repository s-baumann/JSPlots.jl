using JSPlots, DataFrames, StableRNGs

println("Creating PieChart examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(888)

# Prepare header
header = TextBlock("""
<h1>PieChart Examples</h1>
<p>This page demonstrates the key features of PieChart plots in JSPlots.</p>
<ul>
    <li><strong>Basic pie chart:</strong> Simple proportional visualization</li>
    <li><strong>Donut charts:</strong> Pie charts with hollow centers</li>
    <li><strong>Interactive filters:</strong> Dropdown menus to filter data dynamically</li>
    <li><strong>Faceting:</strong> Facet wrap (1 variable) and facet grid (2 variables)</li>
    <li><strong>Aggregation:</strong> Automatic aggregation of values by label</li>
    <li><strong>Color consistency:</strong> Same labels always get same colors</li>
</ul>
""")

# Example 1: Basic Pie Chart - Market Share
market_share_df = DataFrame(
    company = ["Company A", "Company B", "Company C", "Company D", "Company E"],
    revenue = [45000, 32000, 18000, 12000, 8000],
    units = [1200, 900, 600, 400, 250]
)

pie1 = PieChart(:market_share, market_share_df, :market_data;
    value_cols = [:revenue, :units],
    label_cols = [:company],
    title = "Example 1: Market Share by Revenue",
    notes = "Basic pie chart showing relative market share. Toggle between revenue and units sold using the dropdown."
)

# Example 2: Donut Chart - Budget Allocation
budget_df = DataFrame(
    category = ["Salaries", "Marketing", "R&D", "Operations", "Infrastructure", "Other"],
    amount = [250000, 80000, 120000, 65000, 45000, 20000]
)

pie2 = PieChart(:budget_donut, budget_df, :budget_data;
    value_cols = [:amount],
    label_cols = [:category],
    hole = 0.4,
    title = "Example 2: Budget Allocation (Donut Chart)",
    notes = "Donut chart (hole=0.4) showing budget distribution across categories"
)

# Example 3: Pie Chart with Filters
sales_df = DataFrame()
regions = ["North", "South", "East", "West"]
products = ["Product A", "Product B", "Product C"]
years = ["2022", "2023", "2024"]

for region in regions
    for product in products
        for year in years
            push!(sales_df, (
                region = region,
                product = product,
                year = year,
                sales = abs(10000 + randn(rng) * 3000)
            ))
        end
    end
end

pie3 = PieChart(:sales_filtered, sales_df, :sales_data;
    value_cols = [:sales],
    label_cols = [:product],
    filters = Dict{Symbol,Any}(:region => "North", :year => "2024"),
    title = "Example 3: Product Sales with Filters",
    notes = "Interactive filters allow you to select different regions and years. Try selecting multiple options!"
)

# Example 4: Facet Wrap (1 variable) - Sales by Region
pie4 = PieChart(:sales_by_region, sales_df, :sales_data;
    value_cols = [:sales],
    label_cols = [:product],
    facet_cols = [:region],
    default_facet_cols = :region,
    filters = Dict{Symbol,Any}(:year => "2024"),
    title = "Example 4: Product Sales Faceted by Region",
    notes = "Facet wrap creates a grid of pie charts, one for each region. Note single facet dropdown!"
)

# Example 5: Facet Grid (2 variables) - Demographics
demo_df = DataFrame()
age_groups = ["18-25", "26-35", "36-45", "46+"]
genders = ["Male", "Female"]
preferences = ["Mobile", "Desktop", "Tablet"]

for age in age_groups
    for gender in genders
        for pref in preferences
            push!(demo_df, (
                age_group = age,
                gender = gender,
                preference = pref,
                count = rand(rng, 50:200)
            ))
        end
    end
end

pie5 = PieChart(:demographics_grid, demo_df, :demo_data;
    value_cols = [:count],
    label_cols = [:preference],
    facet_cols = [:age_group, :gender],
    default_facet_cols = [:age_group, :gender],
    title = "Example 5: Device Preference by Age and Gender (Facet Grid)",
    notes = "2D facet grid showing device preferences across age groups (rows) and gender (columns)"
)

# Example 6: Department Expenses with Multiple Categories
expense_df = DataFrame()
departments = ["Engineering", "Sales", "Marketing", "Operations", "HR"]
expense_types = ["Salaries", "Equipment", "Travel", "Training", "Supplies"]
quarters = ["Q1", "Q2", "Q3", "Q4"]

for dept in departments
    for exp_type in expense_types
        for quarter in quarters
            push!(expense_df, (
                department = dept,
                expense_type = exp_type,
                quarter = quarter,
                amount = abs(5000 + randn(rng) * 2000)
            ))
        end
    end
end

pie6 = PieChart(:dept_expenses, expense_df, :expense_data;
    value_cols = [:amount],
    label_cols = [:expense_type, :department],
    facet_cols = [:department],
    default_facet_cols = :department,
    filters = Dict{Symbol,Any}(:quarter => "Q1"),
    title = "Example 6: Department Expenses by Type",
    notes = "Expenses broken down by type for each department. Try switching slice grouping to see department distribution!"
)

# Example 7: Customer Segments
segment_df = DataFrame(
    segment = ["Enterprise", "Mid-Market", "Small Business", "Startup", "Individual"],
    revenue_contribution = [55, 25, 12, 6, 2]
)

pie7 = PieChart(:customer_segments, segment_df, :segment_data;
    value_cols = [:revenue_contribution],
    label_cols = [:segment],
    hole = 0.3,
    title = "Example 7: Revenue Contribution by Customer Segment (%)",
    notes = "Donut chart showing percentage revenue contribution from different customer segments"
)

# Example 8: Multiple Stores Comparison with Faceting
store_df = DataFrame()
stores = ["Store A", "Store B", "Store C"]
categories = ["Electronics", "Clothing", "Home & Garden", "Food", "Books"]

for store in stores
    for category in categories
        push!(store_df, (
            store = store,
            category = category,
            sales = abs(15000 + randn(rng) * 5000)
        ))
    end
end

pie8 = PieChart(:store_comparison, store_df, :store_data;
    value_cols = [:sales],
    label_cols = [:category],
    facet_cols = [:store],
    default_facet_cols = :store,
    title = "Example 8: Category Sales by Store",
    notes = "Compare product category distribution across different store locations (single facet variable)"
)

# Example 9: Dynamic Faceting Example
traffic_df = DataFrame()
countries = ["USA", "UK", "Germany", "France"]
browsers = ["Chrome", "Firefox", "Safari", "Edge"]
devices = ["Desktop", "Mobile", "Tablet"]

for country in countries
    for browser in browsers
        for device in devices
            push!(traffic_df, (
                country = country,
                browser = browser,
                device = device,
                visitors = rand(rng, 1000:10000)
            ))
        end
    end
end

pie9 = PieChart(:traffic_analysis, traffic_df, :traffic_data;
    value_cols = [:visitors],
    label_cols = [:browser, :device],
    facet_cols = [:country, :device],
    default_facet_cols = nothing,
    title = "Example 9: Website Traffic Analysis - Dynamic Faceting",
    notes = "Use the facet dropdowns to explore traffic patterns. Try: no faceting, facet by country only, or facet by both. Also try switching slice grouping!"
)

# Example 10: Comprehensive Example - All Features Combined
println("  Creating Example 10: Comprehensive Sales Analysis (All Features)")

comprehensive_df = DataFrame()
products = ["Laptop", "Phone", "Tablet", "Headphones", "Monitor"]
regions = ["North America", "Europe", "Asia", "South America"]
channels = ["Online", "Retail", "Wholesale"]
quarters = ["Q1-2024", "Q2-2024", "Q3-2024", "Q4-2024"]

for product in products
    for region in regions
        for channel in channels
            for quarter in quarters
                push!(comprehensive_df, (
                    product = product,
                    region = region,
                    channel = channel,
                    quarter = quarter,
                    revenue = abs(50000 + randn(rng) * 20000),
                    units_sold = rand(rng, 100:1000),
                    profit = abs(15000 + randn(rng) * 8000),
                    customer_count = rand(rng, 50:500)
                ))
            end
        end
    end
end

pie10 = PieChart(:comprehensive_sales, comprehensive_df, :comprehensive_data;
    value_cols = [:revenue, :units_sold, :profit, :customer_count],
    label_cols = [:product, :channel, :region],
    facet_cols = [:region, :channel, :quarter],
    default_facet_cols = nothing,
    filters = Dict{Symbol,Any}(:quarter => "Q4-2024"),
    title = "Example 10: Comprehensive Sales Analysis - All Features Combined",
    notes = "This example demonstrates ALL PieChart features: (1) Multiple slice size options (revenue, units, profit, customers), (2) Multiple grouping options (by product, channel, or region), (3) Flexible faceting (choose 0, 1, or 2 facet variables), (4) Interactive filters (select quarters). Try different combinations!"
)

conclusion = TextBlock("""
<h2>Key Features Summary</h2>
<ul>
    <li><strong>Automatic aggregation:</strong> Values are automatically summed by label</li>
    <li><strong>Donut charts:</strong> Set hole parameter (0 = pie, >0 = donut)</li>
    <li><strong>Color consistency:</strong> Same labels always get the same colors across facets</li>
    <li><strong>Interactive filters:</strong> Multi-select dropdowns for dynamic data filtering</li>
    <li><strong>Variable selection:</strong> Choose which columns to use for slice sizes and groupings</li>
    <li><strong>Faceting support:</strong> Create small multiples with 1 or 2 faceting variables</li>
    <li><strong>Smart facet controls:</strong> Single dropdown when only one facet variable is available</li>
    <li><strong>Flexible layout:</strong> Facet wrap automatically arranges charts in a grid</li>
    <li><strong>Hover details:</strong> See exact values and percentages on hover</li>
</ul>
<p><strong>Tip:</strong> Hover over slices to see exact values and percentages. Use faceting to compare distributions across categories. Try switching between different value and label columns!</p>
""")

# Create single combined page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(
        :market_data => market_share_df,
        :budget_data => budget_df,
        :sales_data => sales_df,
        :demo_data => demo_df,
        :expense_data => expense_df,
        :segment_data => segment_df,
        :store_data => store_df,
        :traffic_data => traffic_df,
        :comprehensive_data => comprehensive_df
    ),
    [header, pie1, pie2, pie3, pie4, pie5, pie6, pie7, pie8, pie9, pie10, conclusion],
    tab_title = "PieChart Examples"
)

create_html(page, "generated_html_examples/piechart_examples.html")

println("\n" * "="^60)
println("PieChart examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/piechart_examples.html")
println("\nThis page includes:")
println("  • Basic pie chart with variable selection")
println("  • Donut chart (with hole parameter)")
println("  • Interactive filters (now working!)")
println("  • Facet wrap (1 variable) - single dropdown")
println("  • Facet grid (2 variables)")
println("  • Multiple value and label column selection")
println("  • Dynamic faceting controls")
println("  • Consistent formatting with other chart types")
println("  • COMPREHENSIVE EXAMPLE with all features combined!")
