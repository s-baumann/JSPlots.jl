using JSPlots, DataFrames, Dates, StableRNGs

println("Creating DrawdownPlot examples...")

# Use stable RNG for reproducible examples
rng = StableRNG(456)

# Create strategy performance data with drawdowns
# 8 strategies with different risk profiles over 2 years
strategies = ["Momentum", "Value", "Growth", "Quality", "Size", "Volatility", "Carry", "Trend"]
dates = collect(Date(2022, 1, 1):Day(1):Date(2023, 12, 31))
n_days = length(dates)

strategy_df = DataFrame()
for (idx, strategy) in enumerate(strategies)
    # Each strategy has different characteristics
    base_return = randn(rng) * 0.0002
    volatility = 0.008 + rand(rng) * 0.015

    # Daily PnL with some drawdown periods
    daily_pnl = base_return .+ volatility .* randn(rng, n_days)
    daily_pnl_gross = daily_pnl .+ abs.(randn(rng, n_days) .* 0.001)  # Gross before costs
    daily_return = 1 .+ daily_pnl  # For cumprod

    # Add specific drawdown events for some strategies
    if idx == 1  # Momentum - big drawdown in middle
        daily_pnl[300:350] .-= 0.02
        daily_pnl_gross[300:350] .-= 0.02
    elseif idx == 2  # Value - sustained drawdown at end
        daily_pnl[600:end] .-= 0.008
        daily_pnl_gross[600:end] .-= 0.008
    elseif idx == 3  # Growth - early drawdown
        daily_pnl[50:100] .-= 0.015
        daily_pnl_gross[50:100] .-= 0.015
    end

    append!(strategy_df, DataFrame(
        date = dates,
        daily_pnl = daily_pnl,
        daily_pnl_gross = daily_pnl_gross,
        daily_return = daily_return,
        strategy = fill(strategy, n_days),
        style = fill(idx <= 4 ? "Factor" : "Alternative", n_days),
        region = fill(idx <= 2 ? "US" : (idx <= 4 ? "Europe" : (idx <= 6 ? "Asia" : "Global")), n_days),
        risk_level = fill(idx % 3 == 0 ? "High" : (idx % 3 == 1 ? "Medium" : "Low"), n_days),
        day_of_week = dayname.(dates)
    ))
end

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/drawdownplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>DrawdownPlot Examples</h1>
<p>DrawdownPlot visualizes strategy drawdowns from peak cumulative performance. Key features:</p>
<ul>
    <li><strong>Drawdown calculation:</strong> Shows how far below peak cumulative PnL each strategy is</li>
    <li><strong>Zero line:</strong> When at a new high (no drawdown), the line is at zero</li>
    <li><strong>Negative values:</strong> When in drawdown, shows the magnitude below peak</li>
    <li><strong>Max drawdown:</strong> Hover over any line to see the maximum drawdown for that window</li>
    <li><strong>Window navigation:</strong> Step through time periods to analyze drawdowns in different regimes</li>
    <li><strong>Multiple metrics:</strong> Switch between different PnL columns with cumulative or cumprod transforms</li>
    <li><strong>Faceting:</strong> Split charts by category columns for comparison</li>
</ul>
""")

# Example 1: Basic drawdown comparison
example1_intro = TextBlock("""
<h2>Example 1: Basic Drawdown Comparison</h2>
<p>Compare drawdowns across multiple strategies. Hover over lines to see maximum drawdown for each strategy.</p>
""")

chart1 = DrawdownPlot(:basic_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy],
    title = "Strategy Drawdowns",
    notes = "Compare drawdown profiles of 8 strategies. The Momentum strategy shows a significant drawdown mid-period. " *
            "Hover over any line to see its maximum drawdown value."
)

# Example 2: Multiple metrics with transforms
example2_intro = TextBlock("""
<h2>Example 2: Multiple Metrics with Transforms</h2>
<p>Select between different PnL metrics, each with its own transform (cumulative or cumprod).</p>
""")

chart2 = DrawdownPlot(:multi_metric_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [
        (:daily_pnl, "cumulative"),
        (:daily_pnl_gross, "cumulative"),
        (:daily_return, "cumprod")
    ],
    color_cols = [:strategy, :style],
    title = "Multi-Metric Drawdown Analysis",
    notes = "Use the 'Metric' dropdown to switch between daily_pnl (cumulative sum), daily_pnl_gross (cumulative sum), " *
            "or daily_return (cumulative product for wealth drawdown). The drawdown is computed from the cumulative result."
)

# Example 3: Group by investment style
example3_intro = TextBlock("""
<h2>Example 3: Drawdowns by Style</h2>
<p>Group strategies by investment style (Factor vs Alternative) to see aggregate drawdown behavior.</p>
""")

chart3 = DrawdownPlot(:style_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:style, :strategy],
    title = "Drawdowns by Investment Style",
    notes = "Use the 'Color by' dropdown to switch between viewing individual strategies or aggregated by style. " *
            "Factor strategies tend to have correlated drawdowns while Alternatives provide diversification."
)

# Example 4: With filters
example4_intro = TextBlock("""
<h2>Example 4: With Filters</h2>
<p>Filter to specific regions or risk levels to focus analysis.</p>
""")

chart4 = DrawdownPlot(:filtered_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy, :risk_level],
    filters = [:region, :style],
    title = "Filtered Drawdown Analysis",
    notes = "Use filters to select specific regions or styles. Compare how high vs low risk strategies " *
            "behave during drawdown periods."
)

# Example 4b: Using choices (single-select) instead of filters (multi-select)
example4b_intro = TextBlock("""
<h2>Example 4b: Choices vs Filters</h2>
<p>Demonstrates the difference between choices (single-select) and filters (multi-select).</p>
""")

chart4b = DrawdownPlot(:choices_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy, :risk_level],
    choices = Dict{Symbol,Any}(:region => "US"),  # Single-select: user picks ONE region
    filters = Dict{Symbol,Any}(:style => ["Factor", "Alternative"]),  # Multi-select: can select multiple styles
    title = "Drawdowns with Single-Select Region",
    notes = """
    This example demonstrates the difference between choices and filters:
    - **Region (choice)**: Single-select dropdown - pick exactly ONE region at a time
    - **Style (filter)**: Multi-select dropdown - can select multiple styles

    Use choices when the user must select exactly one option (like comparing drawdowns region by region).
    """
)

# Example 5: With faceting
example5_intro = TextBlock("""
<h2>Example 5: Faceted View</h2>
<p>Split the view by region or style to see drawdowns in separate panels.</p>
""")

chart5 = DrawdownPlot(:faceted_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative"), (:daily_pnl_gross, "cumulative")],
    color_cols = [:strategy, :risk_level],
    facet_cols = [:style, :region],
    title = "Faceted Drawdown Analysis",
    notes = "Use Facet dropdowns to split the view. Try faceting by style to compare Factor vs Alternative drawdowns. " *
            "The Metric dropdown lets you switch between daily_pnl and daily_pnl_gross."
)

# Example 6: Custom colors for risk levels
example6_intro = TextBlock("""
<h2>Example 6: Custom Color Mapping</h2>
<p>Use custom colors to highlight risk levels - red for high risk, green for low risk.</p>
""")

chart6 = DrawdownPlot(:custom_colors_dd, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [
        (:strategy, :default),
        (:risk_level, Dict("High" => "#e74c3c", "Medium" => "#f39c12", "Low" => "#27ae60"))
    ],
    title = "Drawdowns with Custom Risk Colors",
    notes = "When coloring by risk_level, High risk is shown in red, Medium in orange, and Low in green. " *
            "This makes it easy to visually identify which risk profiles have the deepest drawdowns."
)

# Example 7: Without fill (lines only)
example7_intro = TextBlock("""
<h2>Example 7: Line-Only View</h2>
<p>View drawdowns as lines without fill area for cleaner visualization with many strategies.</p>
""")

chart7 = DrawdownPlot(:nofill_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy],
    fill = false,
    line_width = 2,
    title = "Drawdowns (No Fill)",
    notes = "Without fill, it's easier to distinguish overlapping drawdown profiles. " *
            "Useful when analyzing many strategies simultaneously."
)

# Example 8: Filter by day of week
example8_intro = TextBlock("""
<h2>Example 8: Filter by Day of Week</h2>
<p>Subset data to specific days of the week. The max drawdown is recalculated based only on the selected days.
This is useful for analyzing day-of-week effects or comparing weekday vs weekend performance.</p>
""")

chart8 = DrawdownPlot(:day_filter_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy],
    filters = [:day_of_week],
    title = "Drawdowns by Day of Week",
    notes = "Filter to specific days using the dropdown. For example, select only Monday and Friday to see " *
            "drawdowns calculated from just those days' PnL. The max drawdown shown on hover reflects only " *
            "the filtered subset."
)

# Example 9: Day of week with default selection
example9_intro = TextBlock("""
<h2>Example 9: Weekdays Only Analysis</h2>
<p>Pre-filter to weekdays only (Monday-Friday). This demonstrates setting default filter values
to exclude weekends from the drawdown calculation.</p>
""")

chart9 = DrawdownPlot(:weekday_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative"), (:daily_return, "cumprod")],
    color_cols = [:strategy, :style],
    filters = Dict(
        :day_of_week => ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    ),
    title = "Weekday Drawdowns Only",
    notes = "Pre-filtered to weekdays. Saturday and Sunday are excluded from the drawdown calculation. " *
            "You can adjust the filter to include/exclude specific days. Use the Metric dropdown to switch " *
            "between cumulative PnL and wealth (cumprod) drawdowns."
)

# Example 10: Day of week with color and faceting
example10_intro = TextBlock("""
<h2>Example 10: Day Filtering with Style Comparison</h2>
<p>Combine day-of-week filtering with faceting by investment style. This lets you compare
how Factor vs Alternative strategies perform on specific days.</p>
""")

chart10 = DrawdownPlot(:day_style_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_pnl, "cumulative")],
    color_cols = [:strategy, :risk_level],
    filters = [:day_of_week, :region],
    facet_cols = [:style],
    title = "Day-Filtered Drawdowns by Style",
    notes = "Filter by day of week to see how drawdowns differ. Try selecting only Monday to see " *
            "'Monday effect' drawdowns, or compare Tuesday vs Thursday performance. " *
            "The faceted view separates Factor and Alternative strategies."
)

# Example 11: Cumprod drawdown (wealth-based)
example11_intro = TextBlock("""
<h2>Example 11: Wealth-Based Drawdown (Cumprod)</h2>
<p>For return-based data, use cumprod to compute cumulative wealth, then show drawdown from peak wealth.</p>
""")

chart11 = DrawdownPlot(:wealth_drawdown, strategy_df, :strategy_data,
    x_col = :date,
    y_transforms = [(:daily_return, "cumprod")],
    color_cols = [:strategy],
    title = "Wealth Drawdown (Cumprod)",
    notes = "When using daily_return with cumprod transform, the chart shows drawdown from peak wealth. " *
            "This is the standard way to measure drawdown for return series: compute cumulative wealth " *
            "(product of 1+r), then measure how far below the running maximum."
)

# Conclusion
conclusion = TextBlock("""
<h2>Understanding Drawdowns</h2>
<ul>
    <li><strong>What is drawdown?</strong> The decline from a previous peak in cumulative PnL. A drawdown of -0.05 means
        the strategy is 5% (or 5 units) below its previous high water mark.</li>
    <li><strong>Zero = new high:</strong> When the drawdown line is at zero, the strategy is at or above its previous peak
        (making new highs).</li>
    <li><strong>Max drawdown:</strong> The tooltip shows the maximum drawdown for the visible window. This is the worst
        peak-to-trough decline during that period.</li>
    <li><strong>Window analysis:</strong> Use Step Forward/Back to analyze drawdowns during specific market regimes
        (e.g., 2022 rate hikes, 2023 recovery).</li>
    <li><strong>Cumulative vs Cumprod:</strong> Use "cumulative" for PnL in dollar terms, "cumprod" for return series
        where you want to see wealth drawdown.</li>
</ul>
<h3>Use Cases</h3>
<ul>
    <li><strong>Risk management:</strong> Identify which strategies have the deepest drawdowns</li>
    <li><strong>Correlation analysis:</strong> See if strategies draw down together (correlated risk)</li>
    <li><strong>Recovery analysis:</strong> Observe how quickly strategies recover from drawdowns</li>
    <li><strong>Regime analysis:</strong> Compare drawdown behavior across different market conditions</li>
    <li><strong>Day-of-week effects:</strong> Filter to specific days to analyze trading day patterns</li>
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
     example4b_intro, chart4b,
     example5_intro, chart5,
     example6_intro, chart6,
     example7_intro, chart7,
     example8_intro, chart8,
     example9_intro, chart9,
     example10_intro, chart10,
     example11_intro, chart11,
     conclusion],
    tab_title = "DrawdownPlot Examples"
)

# Create HTML
manifest_entry = ManifestEntry(path="..", html_filename="drawdownplot_examples.html",
                               description="DrawdownPlot Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Time Series Charts", :page_type => "Chart Tutorial"))
create_html(page, "generated_html_examples/drawdownplot_examples.html";
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("\n" * "="^60)
println("DrawdownPlot examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/drawdownplot_examples.html")
println("\nExamples included:")
println("  1. Basic drawdown comparison")
println("  2. Multiple metrics with transforms")
println("  3. Drawdowns by investment style")
println("  4. With filters")
println("  4b. Choices vs Filters (single-select vs multi-select)")
println("  5. Faceted view")
println("  6. Custom color mapping")
println("  7. Line-only view (no fill)")
println("  8. Filter by day of week")
println("  9. Weekdays only analysis")
println("  10. Day filtering with style comparison")
println("  11. Wealth-based drawdown (cumprod)")
