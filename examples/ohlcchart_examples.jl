using JSPlots, DataFrames, Dates

# Example 1: Single stock with volume using Date type
println("Creating Example 1: Single stock with volume (Date type)...")

# Generate sample OHLC data for a single stock
dates = Date(2024, 1, 1):Day(1):Date(2024, 3, 31)
n = length(dates)

df1 = DataFrame(
    time_from = dates,
    time_to = dates,
    symbol = fill("AAPL", n),
    open = 150.0 .+ cumsum(randn(n)),
    high = 150.0 .+ cumsum(randn(n)) .+ rand(n) .* 5,
    low = 150.0 .+ cumsum(randn(n)) .- rand(n) .* 5,
    close = 150.0 .+ cumsum(randn(n)) .+ randn(n),
    volume = rand(1000000:5000000, n)
)

# Ensure high is highest and low is lowest
for i in 1:nrow(df1)
    vals = [df1.open[i], df1.close[i], df1.high[i], df1.low[i]]
    df1.high[i] = maximum(vals)
    df1.low[i] = minimum(vals)
end

chart1 = OHLCChart(
    :example1_ohlc,
    df1,
    :stock_data_1,
    time_from_col=:time_from,
    time_to_col=:time_to,
    symbol_col=:symbol,
    open_col=:open,
    high_col=:high,
    low_col=:low,
    close_col=:close,
    volume_col=:volume,
    title="Example 1: Single Stock with Volume (AAPL)",
    notes="Daily stock prices with volume bars. Use time sliders to zoom, toggle renormalization and volume display."
)

# Example 2: Multiple stocks comparison with renormalization
println("Creating Example 2: Multiple stocks with renormalization...")

# Generate data for 3 stocks with different price levels
stocks = ["AAPL", "GOOGL", "MSFT"]
dates2 = Date(2024, 1, 1):Day(1):Date(2024, 2, 29)
n2 = length(dates2)

df2_parts = []
base_prices = [150.0, 2800.0, 380.0]  # Different starting prices

for (stock, base) in zip(stocks, base_prices)
    prices = base .+ cumsum(randn(n2) .* 2)
    df_part = DataFrame(
        time_from = dates2,
        time_to = dates2,
        symbol = fill(stock, n2),
        open = prices,
        high = prices .+ rand(n2) .* 5,
        low = prices .- rand(n2) .* 5,
        close = prices .+ randn(n2),
        volume = rand(1000000:5000000, n2)
    )

    # Ensure high is highest and low is lowest
    for i in 1:nrow(df_part)
        vals = [df_part.open[i], df_part.close[i], df_part.high[i], df_part.low[i]]
        df_part.high[i] = maximum(vals)
        df_part.low[i] = minimum(vals)
    end

    push!(df2_parts, df_part)
end

df2 = vcat(df2_parts...)

chart2 = OHLCChart(
    :example2_ohlc,
    df2,
    :stock_data_2,
    time_from_col=:time_from,
    time_to_col=:time_to,
    symbol_col=:symbol,
    open_col=:open,
    high_col=:high,
    low_col=:low,
    close_col=:close,
    volume_col=:volume,
    display_mode="Overlay",
    title="Example 2: Multiple Stocks Comparison",
    notes="Compare stocks with vastly different prices. Enable renormalization to see relative performance (first bar open = 1). Switch between Overlay and Faceted display modes."
)

# Example 3: Integer time periods (quarters) without volume
println("Creating Example 3: Integer time periods without volume...")

# Generate data using integer time periods (quarters)
quarters = 1:12
companies = ["CompanyA", "CompanyB"]

df3_parts = []
for company in companies
    base = rand(50.0:100.0)
    prices = base .+ cumsum(randn(length(quarters)) .* 3)
    df_part = DataFrame(
        quarter = quarters,
        quarter_end = quarters,
        company = fill(company, length(quarters)),
        open_price = prices,
        high_price = prices .+ rand(length(quarters)) .* 4,
        low_price = prices .- rand(length(quarters)) .* 4,
        close_price = prices .+ randn(length(quarters))
    )

    # Ensure high is highest and low is lowest
    for i in 1:nrow(df_part)
        vals = [df_part.open_price[i], df_part.close_price[i], df_part.high_price[i], df_part.low_price[i]]
        df_part.high_price[i] = maximum(vals)
        df_part.low_price[i] = minimum(vals)
    end

    push!(df3_parts, df_part)
end

df3 = vcat(df3_parts...)

chart3 = OHLCChart(
    :example3_ohlc,
    df3,
    :company_data,
    time_from_col=:quarter,
    time_to_col=:quarter_end,
    symbol_col=:company,
    open_col=:open_price,
    high_col=:high_price,
    low_col=:low_price,
    close_col=:close_price,
    volume_col=nothing,  # No volume for this example
    display_mode="Faceted",
    chart_type="ohlc",  # Use OHLC bars instead of candlesticks
    title="Example 3: Quarterly Data Without Volume",
    notes="Quarterly company performance using integer time periods. No volume data. Using OHLC bar style instead of candlesticks. Faceted display shows each company separately."
)

# Create page with all examples
println("Creating HTML page...")
page = JSPlotPage(
    Dict(
        :stock_data_1 => df1,
        :stock_data_2 => df2,
        :company_data => df3
    ),
    [chart1, chart2, chart3];
    page_header="OHLC Chart Examples"
)

# Save to file
output_path = "generated_html_examples/ohlcchart_examples.html"
create_html(page, output_path)

println("✓ OHLCChart examples saved to: $output_path")
println("Open this file in a web browser to view the interactive examples.")
