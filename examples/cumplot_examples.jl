using JSPlots, DataFrames, Dates, StableRNGs

println("Creating CumPlot examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(789)

# Create comprehensive strategy performance data
# 10 strategies with multiple metrics over 2 years
strategies = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa"]
dates = collect(Date(2022, 1, 1):Day(1):Date(2023, 12, 31))
n_days = length(dates)

strategy_df = DataFrame()
for (idx, strategy) in enumerate(strategies)
    # Each strategy has different characteristics
    base_return = randn(rng) * 0.0001
    volatility = 0.01 + rand(rng) * 0.02

    # Multiple PnL metrics
    daily_pnl = base_return .+ volatility .* randn(rng, n_days)
    daily_pnl_gross = daily_pnl .+ abs.(randn(rng, n_days) .* 0.001)  # Gross before costs
    daily_return = 1 .+ daily_pnl  # For cumprod

    # Add regime changes
    if idx <= 3
        daily_pnl[1:div(n_days, 2)] .*= 1.5
        daily_pnl_gross[1:div(n_days, 2)] .*= 1.5
    elseif idx <= 6
        daily_pnl[div(n_days, 2)+1:end] .*= 1.5
        daily_pnl_gross[div(n_days, 2)+1:end] .*= 1.5
    end

    append!(strategy_df, DataFrame(
        date = dates,
        daily_pnl = daily_pnl,
        daily_pnl_gross = daily_pnl_gross,
        daily_return = 1 .+ daily_pnl,
        strategy = fill(strategy, n_days),
        asset_class = fill(idx <= 5 ? "Equities" : "Fixed Income", n_days),
        region = fill(idx <= 3 ? "US" : (idx <= 6 ? "Europe" : (idx <= 8 ? "Asia" : "Global")), n_days),
        risk_level = fill(idx % 3 == 0 ? "High" : (idx % 3 == 1 ? "Medium" : "Low"), n_days)
    ))
end

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/cumplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>CumPlot Examples</h1>
<p>CumPlot is designed for comparing cumulative performance of multiple strategies over time.</p>
<ul>
    <li><strong>Normalized view:</strong> All lines start at 1 at the selected start date</li>
    <li><strong>Initial view:</strong> Shows entire data range on page load</li>
    <li><strong>Step Forward/Back:</strong> Navigate through intervals of specified duration</li>
    <li><strong>Reset:</strong> Return to full data view</li>
    <li><strong>Metrics:</strong> Each metric includes its transform (cumulative or cumprod)</li>
</ul>
""")

# Example 1: Basic strategy comparison
example1_intro = TextBlock("""
<h2>Example 1: Basic Strategy Comparison</h2>
<p>Simple example with strategies colored by name, using cumulative sum of daily PnL.</p>
""")

chart1 = CumPlot(:strategy_comparison, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy],
    title = "Strategy Performance Comparison",
    notes = "Compare 10 different strategies. Use Step Forward/Back to see performance over different periods. " *
            "All lines are normalized to start at 1 at the beginning of the selected range."
)

# Example 2: Multiple metrics with different transforms
example2_intro = TextBlock("""
<h2>Example 2: Multiple Metrics</h2>
<p>Choose between different PnL metrics with appropriate transforms: cumulative for PnL, cumprod for returns.</p>
""")

chart2 = CumPlot(:multi_y_vars, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [
        (:daily_pnl, "cumulative"),
        (:daily_pnl_gross, "cumulative"),
        (:daily_return, "cumprod")
    ],
    color_cols = [:strategy],
    title = "Strategy Performance - Multiple Metrics",
    notes = "Use the Metric dropdown to switch between daily_pnl (cumulative), daily_pnl_gross (cumulative), " *
            "or daily_return (cumprod for wealth growth)."
)

# Example 3: Multiple color column options
example3_intro = TextBlock("""
<h2>Example 3: Multiple Color Options</h2>
<p>Color by strategy name, asset class, region, or risk level.</p>
""")

chart3 = CumPlot(:multi_color_cols, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy, :asset_class, :region, :risk_level],
    title = "Performance by Different Groupings",
    notes = "Use the 'Color by' dropdown to group strategies by: strategy name, asset_class (Equities vs Fixed Income), " *
            "region (US, Europe, Asia, Global), or risk_level (High, Medium, Low)."
)

# Example 4: With faceting
example4_intro = TextBlock("""
<h2>Example 4: Faceted View</h2>
<p>Split the chart by asset class or region using faceting.</p>
""")

chart4 = CumPlot(:faceted_view, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative"), (:daily_pnl_gross, "cumulative")],
    color_cols = [:strategy, :risk_level],
    facet_cols = [:asset_class, :region],
    title = "Faceted Strategy Performance",
    notes = "Use Facet 1 and Facet 2 dropdowns to create subplots. Try faceting by asset_class to see " *
            "Equities vs Fixed Income side by side."
)

# Example 5: With filters and custom colors
example5_intro = TextBlock("""
<h2>Example 5: With Filters and Custom Colors</h2>
<p>Filter strategies by asset class or region. Custom color mapping for risk levels.</p>
""")

chart5 = CumPlot(:filtered_strategies, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative"), (:daily_pnl_gross, "cumulative")],
    color_cols = [
        (:strategy, :default),
        (:risk_level, Dict("High" => "#ff0000", "Medium" => "#ffaa00", "Low" => "#00aa00"))
    ],
    filters = [:asset_class, :region],
    title = "Filtered Strategy Performance",
    notes = "Custom colors: risk_level uses red for High, orange for Medium, green for Low. " *
            "Use the filter dropdowns to select only certain asset classes or regions."
)

# Example 6: Full featured with custom colors
example6_intro = TextBlock("""
<h2>Example 6: All Features Combined</h2>
<p>Multiple metrics with transforms, multiple color options (some with custom colors), faceting, and filters.</p>
""")

chart6 = CumPlot(:full_featured, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [
        (:daily_pnl, "cumulative"),
        (:daily_pnl_gross, "cumulative"),
        (:daily_return, "cumprod")
    ],
    color_cols = [
        (:strategy, :default),
        (:asset_class, Dict("Equities" => "#1f77b4", "Fixed Income" => "#b027d6")),
        (:region, :default),
        (:risk_level, Dict("High" => "#ff0000", "Low" => "#00aa00"))
    ],
    facet_cols = [:asset_class, :region, :risk_level],
    filters = [:asset_class, :region, :risk_level],
    title = "Full Featured Cumulative Chart",
    notes = "All options available: metric selection, color by options (asset_class and risk_level have custom colors), " *
            "faceting, and filters. Experiment with different combinations."
)

# Conclusion
conclusion = TextBlock("""
<h2>Key Features</h2>
<ul>
    <li><strong>Renormalization:</strong> When stepping through intervals, all lines
        are renormalized so they start at 1.0 at the interval start date. This lets you compare
        relative performance from any starting point.</li>
    <li><strong>Navigation:</strong>
        <ul>
            <li><strong>Reset:</strong> Show the entire data range</li>
            <li><strong>Step Forward:</strong> Move to next interval (first click switches from full view to interval mode)</li>
            <li><strong>Step Back:</strong> Move to previous interval</li>
            <li><strong>Duration:</strong> Adjust the interval width in time units</li>
            <li><strong>Step:</strong> Adjust how far each step moves</li>
        </ul>
    </li>
    <li><strong>Metric transforms:</strong>
        <ul>
            <li><code>cumulative</code>: Sum daily PnL to see total profit/loss over time</li>
            <li><code>cumprod</code>: Multiply daily returns (1 + r) to see wealth growth</li>
        </ul>
    </li>
</ul>
""")

# Create the page
page = JSPlotPage(
    Dict(
        :strategy_data => strategy_df
    ),
    [header,
     example1_intro, chart1,
     example2_intro, chart2,
     example3_intro, chart3,
     example4_intro, chart4,
     example5_intro, chart5,
     example6_intro, chart6,
     conclusion],
    tab_title = "CumPlot Examples"
)

# Create HTML
create_html(page, "generated_html_examples/cumplot_examples.html")

println("\n" * "="^60)
println("CumPlot examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/cumplot_examples.html")
println("\nExamples included:")
println("  1. Basic strategy comparison")
println("  2. Multiple Y variables (daily_pnl, daily_pnl_gross, daily_return)")
println("  3. Multiple color options (strategy, asset_class, region, risk_level)")
println("  4. Faceted view")
println("  5. With filters")
println("  6. All features combined")
