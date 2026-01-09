using JSPlots, DataFrames, Dates

# Example 1: Investment strategies ranking over time periods
println("Creating Example 1: Investment strategies ranking...")

# Generate sample ranking data for investment strategies
periods = 1:12
strategies = ["Growth", "Value", "Momentum", "Quality", "Income"]

df1_parts = []
for strategy in strategies
    # Generate performance scores that vary over time
    base_perf = rand(50.0:100.0)
    performance = base_perf .+ cumsum(randn(length(periods)) .* 5)

    df_part = DataFrame(
        period = periods,
        strategy = fill(strategy, length(periods)),
        performance = performance,
        volatility = rand(5.0:20.0, length(periods))
    )
    push!(df1_parts, df_part)
end

df1 = vcat(df1_parts...)

chart1 = BumpChart(
    :example1_bump,
    df1,
    :strategy_data,
    x_col=:period,
    performance_cols=[:performance, :volatility],
    entity_col=:strategy,
    y_mode="Ranking",
    title="Example 1: Investment Strategy Rankings",
    notes="Rankings of investment strategies over time. Hover over a line to highlight it across all facets. Switch between performance metrics. Toggle between ranking and absolute values.",
    line_width=3
)

# Example 2: Product sales with regional faceting
println("Creating Example 2: Product sales with regional faceting...")

# Generate sales data for products across regions
quarters = ["Q1", "Q2", "Q3", "Q4"]
products = ["Product A", "Product B", "Product C", "Product D"]
regions = ["North", "South", "East", "West"]

df2_parts = []
for region in regions
    for product in products
        base_sales = rand(100:500)
        sales = [base_sales + rand(-50:50) for _ in 1:length(quarters)]
        market_share = rand(10.0:40.0, length(quarters))

        df_part = DataFrame(
            quarter = quarters,
            product = fill(product, length(quarters)),
            region = fill(region, length(quarters)),
            sales = sales,
            market_share = market_share
        )
        push!(df2_parts, df_part)
    end
end

df2 = vcat(df2_parts...)

chart2 = BumpChart(
    :example2_bump,
    df2,
    :product_data,
    x_col=:quarter,
    performance_cols=[:sales, :market_share],
    entity_col=:product,
    filters=Dict(:region => regions),  # Allow filtering by region
    facet_cols=[:region],
    default_facet_cols=:region,
    y_mode="Ranking",
    title="Example 2: Product Rankings by Region",
    notes="Product performance rankings faceted by region. Filter regions using the dropdown. Hover to highlight a product across all regions. Dense ranking used: ties get the same rank, next rank continues without gaps.",
    line_width=2
)

# Example 3: Absolute values mode (not ranked)
println("Creating Example 3: Absolute values mode...")

# Generate time series data for companies
dates = Date(2024, 1, 1):Month(1):Date(2024, 12, 1)
companies = ["Alpha Corp", "Beta Inc", "Gamma LLC", "Delta Co"]

df3_parts = []
for company in companies
    base_revenue = rand(100:300)
    revenues = base_revenue .+ cumsum(randn(length(dates)) .* 10)
    profit_margins = rand(5.0:25.0, length(dates))

    df_part = DataFrame(
        month = dates,
        company = fill(company, length(dates)),
        revenue = revenues,
        profit_margin = profit_margins
    )
    push!(df3_parts, df_part)
end

df3 = vcat(df3_parts...)

chart3 = BumpChart(
    :example3_bump,
    df3,
    :company_performance,
    x_col=:month,
    performance_cols=[:revenue, :profit_margin],
    entity_col=:company,
    filters=Dict(:company => companies),
    y_mode="Absolute",  # Use absolute values instead of rankings
    title="Example 3: Company Performance (Absolute Values)",
    notes="Company metrics shown as absolute values rather than rankings. Toggle Y-axis mode to switch to rankings. Select which companies to display using the filter.",
    line_width=2
)

# Create page with all examples
println("Creating HTML page...")
page = JSPlotPage(
    Dict(
        :strategy_data => df1,
        :product_data => df2,
        :company_performance => df3
    ),
    [chart1, chart2, chart3];
    page_header="Bump Chart Examples"
)

# Save to file
output_path = "generated_html_examples/bumpchart_examples.html"
create_html(page, output_path)

println("✓ BumpChart examples saved to: $output_path")
println("Open this file in a web browser to view the interactive examples.")
