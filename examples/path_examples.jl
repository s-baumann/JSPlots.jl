using JSPlots, DataFrames, DataFramesMeta, Dates, StableRNGs

println("Creating Path chart examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(123)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/path_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Path Chart Examples</h1>
<p>This page demonstrates the key features of Path charts in JSPlots.</p>
<ul>
    <li><strong>Trajectory visualization:</strong> Show evolution of metrics over time or sequence</li>
    <li><strong>Direction indicators:</strong> Arrows or alpha gradients indicating path direction</li>
    <li><strong>Multiple paths:</strong> Compare different entities with color grouping</li>
    <li><strong>Interactive dimensions:</strong> Swap x and y axes dynamically from the HTML</li>
    <li><strong>Faceting:</strong> Facet wrap (1 variable) and facet grid (2 variables)</li>
    <li><strong>Order control:</strong> Connect points according to any ordering column</li>
</ul>
""")

# Example 1: Trading Strategy Evolution with Arrows
println("  Creating Example 1: Trading Strategy Evolution (with arrows)")

strategies_data = []
for strategy in [:momentum, :carry, :value]
    for year in 2015:2024
        push!(strategies_data, (
            strategy = strategy,
            year = year,
            Sharpe = 0.3 + rand(rng) * 0.8 + (year - 2015) * 0.02,
            volatility = 0.08 + rand(rng) * 0.08,
            max_drawdown = 0.05 + rand(rng) * 0.15,
            returns = 5 + rand(rng) * 15
        ))
    end
end
df1 = DataFrame(strategies_data)

chart1 = Path(:strategy_evolution_arrows, df1, :strategy_data;
    x_cols = [:volatility, :Sharpe, :returns],
    y_cols = [:Sharpe, :returns, :max_drawdown],
    order_col = :year,
    color_cols = [:strategy],
    title = "Trading Strategy Evolution (2015-2024) - With Arrows",
    notes = "Arrows show the direction of evolution over time. Swap dimensions using dropdowns.",
    show_arrows = true,
    line_width = 2,
    marker_size = 8
)

# Example 2: Same Data with Alpha Gradient (transparency range)
println("  Creating Example 2: Trading Strategy Evolution (with alpha gradient)")

chart2 = Path(:strategy_evolution_alpha, df1, :strategy_data;
    x_cols = [:volatility, :Sharpe, :returns],
    y_cols = [:Sharpe, :returns, :max_drawdown],
    order_col = :year,
    color_cols = [:strategy],
    title = "Trading Strategy Evolution (2015-2024) - With Alpha Gradient",
    notes = "Transparency gradient from 0.3 (early years) to 1.0 (recent years) shows direction without arrows.",
    show_arrows = false,
    use_alpharange = true,
    line_width = 2,
    marker_size = 8
)

# Example 3: Regional Strategy Analysis (3 regions, 3 paths)
println("  Creating Example 3: Regional Strategy Analysis")

regional_data = []
for strategy in [:momentum, :carry, :value]
    for region in [:US, :Europe, :Asia]
        for year in 2015:2024
            push!(regional_data, (
                strategy = strategy,
                region = region,
                year = year,
                Sharpe = 0.4 + rand(rng) * 0.6 + (year - 2015) * 0.01,
                volatility = 0.08 + rand(rng) * 0.08,
                drawdown = 0.05 + rand(rng) * 0.12,
                winrate = 0.50 + rand(rng) * 0.20
            ))
        end
    end
end
df_regional = DataFrame(regional_data)

chart3 = Path(:regional_paths, df_regional, :regional_data;
    x_cols = [:volatility, :Sharpe, :winrate],
    y_cols = [:Sharpe, :drawdown, :winrate],
    order_col = :year,
    color_cols = [:strategy, :region],
    filters = Dict{Symbol,Any}(:region => "US"),  # Default: show only US (3 strategies)
    title = "Regional Strategy Analysis (2015-2024)",
    notes = "Default shows 3 strategies in US region. Use filters to explore other regions. Alpha gradient shows time progression.",
    show_arrows = false,
    use_alpharange = true,
    line_width = 2,
    marker_size = 7
)

# Example 4: Asset Class Comparison (3 asset classes)
println("  Creating Example 4: Asset Class Performance")

asset_data = []
for asset_class in ["Equity", "Bonds", "Commodities"]
    for year in 2016:2024
        push!(asset_data, (
            asset_class = asset_class,
            year = year,
            volatility = asset_class == "Bonds" ? 0.04 + rand(rng) * 0.04 :
                        asset_class == "Equity" ? 0.12 + rand(rng) * 0.08 : 0.15 + rand(rng) * 0.10,
            returns = asset_class == "Bonds" ? 0.02 + rand(rng) * 0.03 :
                     asset_class == "Equity" ? 0.06 + rand(rng) * 0.10 : 0.03 + rand(rng) * 0.12,
            Sharpe = (0.5 + rand(rng) * 0.8) + (year - 2016) * 0.02
        ))
    end
end
df_assets = DataFrame(asset_data)

chart4 = Path(:asset_performance, df_assets, :asset_data;
    x_cols = [:volatility, :Sharpe],
    y_cols = [:returns, :Sharpe],
    order_col = :year,
    color_cols = [:asset_class],
    title = "Asset Class Risk-Return Evolution (2016-2024)",
    notes = "Three major asset classes. Notice how bonds have lower volatility but also lower returns. Alpha gradient shows recent years are bolder.",
    show_arrows = false,
    use_alpharange = true,
    line_width = 3,
    marker_size = 8
)

# Example 5: Facet by Region (3 facets, 3 paths each)
println("  Creating Example 5: Facet by Region")

chart5 = Path(:facet_by_region, df_regional, :regional_data;
    x_cols = [:volatility, :Sharpe],
    y_cols = [:Sharpe, :drawdown],
    order_col = :year,
    color_cols = [:strategy],
    facet_cols = [:region, :strategy],
    default_facet_cols = [:region],
    title = "Strategy Performance by Region (Faceted)",
    notes = "Each panel shows one region with 3 strategies. Faceting allows clear comparison across regions. Arrows show direction.",
    show_arrows = true,
    use_alpharange = false,
    line_width = 2,
    marker_size = 6
)

# Example 6: Product Development Lifecycle
println("  Creating Example 6: Product Development Metrics")

products_data = []
for product in ["Product A", "Product B", "Product C"]
    for quarter in 1:12
        push!(products_data, (
            product = product,
            quarter = quarter,
            development_cost = 100 + quarter * 20 + rand(rng) * 50,
            features_completed = quarter * 3 + rand(rng) * 5,
            user_satisfaction = 60 + quarter * 3 + rand(rng) * 10,
            bug_count = max(0, 50 - quarter * 3 + rand(rng) * 20)
        ))
    end
end
df_products = DataFrame(products_data)

chart6 = Path(:product_development, df_products, :product_data;
    x_cols = [:development_cost, :features_completed, :bug_count],
    y_cols = [:user_satisfaction, :features_completed, :development_cost],
    order_col = :quarter,
    color_cols = [:product],
    title = "Product Development Lifecycle (12 Quarters)",
    notes = "Track how products evolved. Combining arrows AND alpha gradient for maximum clarity.",
    show_arrows = true,
    use_alpharange = true,
    line_width = 3,
    marker_size = 10
)

# Example 7: Portfolio Optimization Journey
println("  Creating Example 7: Portfolio Optimization Path")

optimization_data = []
for iteration in 1:30
    push!(optimization_data, (
        iteration = iteration,
        portfolio_risk = 0.20 - (iteration / 30) * 0.10 + rand(rng) * 0.02,
        portfolio_return = 0.08 + (iteration / 30) * 0.05 + rand(rng) * 0.01,
        diversification = 0.3 + (iteration / 30) * 0.5 + rand(rng) * 0.05,
        transaction_cost = 0.01 + rand(rng) * 0.005,
        stage = iteration <= 10 ? "Initial" : (iteration <= 20 ? "Refinement" : "Final")
    ))
end
df_optimization = DataFrame(optimization_data)

chart7 = Path(:optimization_path, df_optimization, :optimization_data;
    x_cols = [:portfolio_risk, :diversification, :transaction_cost],
    y_cols = [:portfolio_return, :portfolio_risk, :diversification],
    order_col = :iteration,
    color_cols = [:stage],
    title = "Portfolio Optimization Journey (30 Iterations)",
    notes = "30 iterations of optimization. Alpha gradient shows progression from initial (faint) to final (bold).",
    show_arrows = false,
    use_alpharange = true,
    line_width = 2,
    marker_size = 7
)

# Example 8: Date-based Ordering
println("  Creating Example 8: Business Metrics Over Time")

date_data = []
start_date = Date(2023, 1, 1)
for month_offset in 0:23
    current_date = start_date + Month(month_offset)
    push!(date_data, (
        date = current_date,
        customer_acquisition_cost = 50 + month_offset * 2 + rand(rng) * 10,
        customer_lifetime_value = 300 + month_offset * 5 + rand(rng) * 50,
        churn_rate = max(0.01, 0.10 - month_offset * 0.002 + rand(rng) * 0.02),
        monthly_revenue = 100 + month_offset * 8 + rand(rng) * 20,
        company = "Company"
    ))
end
df_business = DataFrame(date_data)

chart8 = Path(:business_metrics, df_business, :business_data;
    x_cols = [:customer_acquisition_cost, :churn_rate, :monthly_revenue],
    y_cols = [:customer_lifetime_value, :monthly_revenue, :customer_acquisition_cost],
    order_col = :date,
    color_cols = [:company],
    title = "Business Metrics Evolution (24 Months)",
    notes = "Path ordered by date. Both arrows and alpha gradient enabled for clear directional visualization.",
    show_arrows = true,
    use_alpharange = true,
    line_width = 2,
    marker_size = 8
)

# Combine all examples into a page
data_dict = Dict(
    :strategy_data => df1,
    :regional_data => df_regional,
    :asset_data => df_assets,
    :product_data => df_products,
    :optimization_data => df_optimization,
    :business_data => df_business
)

plots = [
    header,
    chart1,
    chart2,
    chart3,
    chart4,
    chart5,
    chart6,
    chart7,
    chart8
]

page = JSPlotPage(
    data_dict,
    plots,
    tab_title = "Path Chart Examples"
)

# Manifest entry for report index
manifest_entry = ManifestEntry(path="..", html_filename="path_examples.html",
                               description="Path Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Situational Charts", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/path_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("\n" * "="^60)
println("Path chart examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/path_examples.html")
println("\nThis page includes:")
println("  • Path with arrows (directional indicators)")
println("  • Path with alpha gradient (transparency range 0.3 to 1.0)")
println("  • Typically 3 paths per chart for clarity")
println("  • Filters to explore different subsets")
println("  • Faceting for multi-panel comparisons")
println("  • Both arrows AND alpha gradient combined")
println("  • Portfolio optimization paths")
println("  • Date-based ordering")
println("  • Product development lifecycle tracking")
