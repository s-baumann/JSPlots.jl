using JSPlots, DataFrames, Dates, StableRNGs
rng = StableRNG(555)

println("Creating Waterfall examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/waterfall_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Waterfall Chart Examples</h1>
<p>This page demonstrates the interactive Waterfall chart type in JSPlots.</p>
<ul>
    <li><strong>Automatic cumulative sum calculation:</strong> Enter category and value data, waterfall handles the rest</li>
    <li><strong>Side-by-side calculation table:</strong> See exact values and running totals</li>
    <li><strong>Click-to-remove interaction:</strong> Click on bars or table rows to temporarily exclude from calculation</li>
    <li><strong>Reset functionality:</strong> Restore all removed segments with one click</li>
    <li><strong>Color coding:</strong> Green for positive values, red for negative, black for totals. Or switch to category-based coloring</li>
    <li><strong>Filtering:</strong> Switch between different datasets using single-select dropdowns</li>
</ul>
""")

# =============================================================================
# Example 1: Financial P&L Statement
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Profit & Loss Statement</h2>
<p>A classic use case for waterfall charts: showing how revenue flows through various expenses to net income.</p>
<p>Features demonstrated:</p>
<ul>
    <li>Positive values (Revenue, Gross Profit) in green</li>
    <li>Negative values (Costs, Expenses) in red</li>
    <li>Running total displayed in the table</li>
    <li>Click on any bar or table row to exclude from calculation</li>
    <li>Reset button to restore all segments</li>
</ul>
""")

df_pnl = DataFrame(
    item = ["Revenue", "COGS", "Gross Profit", "Marketing", "R&D", "Admin", "EBIT", "Profit Taxes", "Death Tax", "Deficit Tax", "Other Taxes"],
    category = ["PnL", "PnL", "PnL", "PnL", "PnL", "PnL", "PnL", "Taxation", "Taxation", "Taxation", "Taxation"],
    value = [10000, -4000, 6000, -1500, -800, -700, 3000, -600, -200, -300, -200]
)
df_pnl_gaap = deepcopy(df_pnl)
df_pnl_gaap[!, :value] .= df_pnl_gaap.value .* (0.9 .+ 0.2 .* rand(rng, length(df_pnl_gaap.value)))  # Slightly different values for GAAP
df_pnl_gaap[!, :accounting] .= "GAAP"
df_pnl[!, :accounting] .= "Non-GAAP"
df_pnl = vcat(df_pnl, df_pnl_gaap)
usd_accounting = deepcopy(df_pnl)
usd_accounting[!, :value] .= usd_accounting.value .* 1.1
usd_accounting[!, :currency] .= "USD"
df_pnl[!, :currency] .= "EUR"
df_pnl = vcat(df_pnl, usd_accounting)

wf1 = Waterfall(:pnl, df_pnl, :pnl_data;
    item_col = :item,
    color_cols = [:category],
    value_col = :value,
    filters = Dict{Symbol,Any}(:accounting => ["Non-GAAP"], :currency => ["EUR"]),
    title = "Profit & Loss Statement",
    notes = "Click on bars or table rows to exclude items from the calculation. Use Reset to restore.",
    show_table = true,
    show_totals = false  # Net Income is already the total
)

# =============================================================================
# Example 2: Cash Flow Bridge
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Cash Flow Bridge</h2>
<p>Show how cash position changes from opening to closing balance through operating, investing, and financing activities.</p>
<p>This example demonstrates:</p>
<ul>
    <li>Mix of positive and negative cash flows</li>
    <li>Total bar showing final cash position</li>
    <li>Interactive removal to see "what-if" scenarios</li>
</ul>
""")

df_cashflow = DataFrame(
    item = ["Opening Cash", "Operating CF", "Investing CF", "Financing CF"],
    category = ["Cash Flow", "Cash Flow", "Cash Flow", "Cash Flow"],
    value = [5000, 3000, -1500, 1000]
)

wf2 = Waterfall(:cashflow, df_cashflow, :cash_data;
    item_col = :item,
    color_cols = [:category],
    value_col = :value,
    title = "Cash Flow Bridge - Q1 2024",
    notes = "Waterfall showing cash flow changes. Total bar shows ending cash position.",
    show_table = true,
    show_totals = true  # Show final cash total
)

# =============================================================================
# Example 3: Sales Variance Analysis with Filters
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Sales Variance Analysis with Filters</h2>
<p>Analyze sales variance by breaking down the impact of price, volume, and mix changes.</p>
<p>This example includes:</p>
<ul>
    <li>Multiple regions selectable via filters</li>
    <li>Variance analysis showing positive and negative impacts</li>
    <li>Side-by-side table for detailed calculation review</li>
    <li>Click-to-remove to isolate specific variance drivers</li>
</ul>
<p><strong>Try this:</strong> Select different regions to see how variance components differ across markets!</p>
""")

# Create variance data for multiple regions
regions = ["North", "South", "East", "West"]
variance_data = DataFrame()

for region in regions
    base = region == "North" ? 10000 : region == "South" ? 8000 : region == "East" ? 12000 : 9000
    price_impact = region == "North" ? 500 : region == "South" ? -200 : region == "East" ? 800 : 200
    volume_impact = region == "North" ? -300 : region == "South" ? 400 : region == "East" ? -500 : 300
    mix_impact = region == "North" ? 200 : region == "South" ? 100 : region == "East" ? 300 : -100

    region_df = DataFrame(
        item = ["Base Sales", "Price Impact", "Volume Impact", "Mix Impact", "Actual Sales"],
        category = ["Variance", "Variance", "Variance", "Variance", "Variance"],
        value = [base, price_impact, volume_impact, mix_impact, base + price_impact + volume_impact + mix_impact],
        region = repeat([region], 5)
    )
    global variance_data = vcat(variance_data, region_df)
end

wf3 = Waterfall(:variance, variance_data, :variance_data;
    item_col = :item,
    color_cols = [:category],
    value_col = :value,
    filters = Dict{Symbol,Any}(:region => ["North"]),
    title = "Sales Variance Analysis by Region",
    notes = "Use the region filter to switch between markets. Click on variance components to see impact on actual sales.",
    show_table = true,
    show_totals = false
)

# =============================================================================
# Example 4: Budget vs Actuals Comparison
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: Budget vs Actuals Comparison</h2>
<p>Compare budgeted vs actual expenses across departments with multiple filters.</p>
<p>Features:</p>
<ul>
    <li>Department filter to focus on specific areas</li>
    <li>Year filter for historical comparison</li>
    <li>Both positive and negative variances</li>
    <li>Table shows running variance total</li>
</ul>
""")

# Create budget variance data
departments = ["Sales", "Marketing", "Engineering", "Operations"]
years = [2023, 2024]
budget_data = DataFrame()

for dept in departments
    for year in years
        budget = dept == "Sales" ? 1000 : dept == "Marketing" ? 500 : dept == "Engineering" ? 1500 : 800
        actual = budget + (rand(rng) - 0.5) * 200  # Random variance
        variance = actual - budget

        dept_df = DataFrame(
            item = ["Budget", "Actual Spending", "Variance"],
            category = ["Budget Analysis", "Budget Analysis", "Budget Analysis"],
            value = [budget, actual - budget, variance],
            department = repeat([dept], 3),
            year = repeat([year], 3)
        )
        global budget_data = vcat(budget_data, dept_df)
    end
end

wf4 = Waterfall(:budget, budget_data, :budget_data;
    item_col = :item,
    color_cols = [:category],
    value_col = :value,
    filters = Dict{Symbol,Any}(
        :department => ["Sales"],
        :year => [2024]
    ),
    title = "Budget vs Actuals - Department Variance",
    notes = "Filter by department and year to see specific variances. Red indicates over-budget, green under-budget.",
    show_table = true,
    show_totals = true
)

# =============================================================================
# Example 5: Waterfall Without Table
# =============================================================================

example5_text = TextBlock("""
<h2>Example 5: Waterfall Chart Without Table</h2>
<p>Sometimes you just want the visual without the detailed calculations.</p>
<p>This example shows a waterfall chart with the table disabled (show_table=false).</p>
""")

df_simple = DataFrame(
    item = ["Starting Value", "Increase 1", "Increase 2", "Decrease 1", "Decrease 2"],
    category = ["Simple", "Simple", "Simple", "Simple", "Simple"],
    value = [1000, 300, 200, -150, -100]
)

wf5 = Waterfall(:simple, df_simple, :simple_data;
    item_col = :item,
    color_cols = [:category],
    value_col = :value,
    title = "Simple Waterfall - Chart Only",
    notes = "This waterfall chart has show_table=false, so only the visualization is displayed.",
    show_table = false,
    show_totals = true
)

# =============================================================================
# Example 6: Multiple Color Columns
# =============================================================================

example6_text = TextBlock("""
<h2>Example 6: Multiple Color Column Options</h2>
<p>This example demonstrates the ability to switch between different category columns.</p>
<p>The same data can be viewed through different lenses - by financial category OR by department.</p>
<p>Features:</p>
<ul>
    <li>Color Column dropdown to switch between category perspectives</li>
    <li>Same underlying data, different groupings</li>
    <li>Useful for multi-dimensional analysis</li>
</ul>
""")

# Create data with two possible category columns
df_multi_color = DataFrame(
    item = ["Revenue", "Direct Costs", "Overhead", "Marketing", "Net Income"],
    financial_category = ["Income", "Expense", "Expense", "Expense", "Net"],
    department = ["Sales", "Operations", "Admin", "Marketing", "All Depts"],
    value = [5000, -2000, -800, -600, 1600]
)

wf6 = Waterfall(:multi_color, df_multi_color, :multi_color_data;
    item_col = :item,
    color_cols = [:financial_category, :department],
    value_col = :value,
    title = "Multi-Perspective Waterfall Analysis",
    notes = "Use the Color Column dropdown to switch between financial and departmental views of the same data.",
    show_table = true,
    show_totals = false
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The Waterfall chart type provides:</p>
<ul>
    <li><strong>Automatic calculation:</strong> Just provide categories and values, cumulative sums are calculated automatically</li>
    <li><strong>Side-by-side table:</strong> Optional calculation table showing each step and running total, grouped by category</li>
    <li><strong>Interactive removal:</strong> Click on bars or table rows to temporarily exclude from calculation</li>
    <li><strong>Category grouping:</strong> Toggle entire categories on/off using category checkboxes in the table</li>
    <li><strong>Reset functionality:</strong> Restore all removed segments with the reset button</li>
    <li><strong>Color coding:</strong>
        <ul>
            <li>Value mode: Green for positive values, Red for negative values</li>
            <li>Category mode: Different color for each category from the color palette</li>
            <li>Total bar: Always black regardless of color mode</li>
        </ul>
    </li>
    <li><strong>Filtering:</strong> Single-select filters to switch between datasets</li>
    <li><strong>Customization:</strong>
        <ul>
            <li><code>item_col</code>: Column containing item labels for the x-axis</li>
            <li><code>color_cols</code>: Column(s) for grouping items by category</li>
            <li><code>value_col</code>: Column containing numeric values</li>
            <li><code>show_table</code>: Toggle calculation table display</li>
            <li><code>show_totals</code>: Add a total bar at the end (toggleable from table)</li>
        </ul>
    </li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li>Financial analysis (P&L, cash flow, variance analysis)</li>
    <li>Budget vs actual comparisons</li>
    <li>Sequential process flows showing cumulative impact</li>
    <li>Inventory or population change analysis</li>
    <li>Revenue bridge analysis</li>
    <li>Cost breakdown and attribution</li>
</ul>

<h3>Tips</h3>
<ul>
    <li>Click on any bar or table row to see the impact of removing that component</li>
    <li>Click category checkboxes to toggle entire groups on/off</li>
    <li>Use the Color By dropdown to switch between value-based and category-based coloring</li>
    <li>Use the Reset button to quickly restore all segments</li>
    <li>Combine with filters to compare waterfalls across different dimensions</li>
    <li>Set <code>show_totals=false</code> when your last item is already a total</li>
    <li>The total bar can be toggled on/off by clicking its row in the table</li>
</ul>
""")

# =============================================================================
# Create the page
# =============================================================================

# Output to the main generated_html_examples directory (not in examples/)
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end

# Create embedded format (single HTML file with all data included)
page = JSPlotPage(
    Dict{Symbol, Any}(
        :pnl_data => df_pnl,
        :cash_data => df_cashflow,
        :variance_data => variance_data,
        :budget_data => budget_data,
        :simple_data => df_simple,
        :multi_color_data => df_multi_color
    ),
    [header, example1_text, wf1, example2_text, wf2, example3_text, wf3,
     example4_text, wf4, example5_text, wf5, example6_text, wf6, summary];
    dataformat=:csv_embedded
)

output_file = joinpath(output_dir, "waterfall_examples.html")
# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="waterfall_examples.html",
                               description="Waterfall Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Situational Charts", :page_type => "Chart Tutorial"))
create_html(page, output_file;
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)
println("Created: $output_file")

println("\nWaterfall examples complete!")
println("Open the HTML file in a browser to see the interactive waterfall charts.")
println("\nTry clicking on bars or table rows to remove them from the calculation!")
println("Use the Reset button to restore all segments.")
