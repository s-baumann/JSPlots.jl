using JSPlots
using DataFrames
using Random
using Dates

# Example 1: Basic local correlation with synthetic data showing varying correlation regions
Random.seed!(42)
n = 500

# Create data where correlation structure varies spatially
# In the positive quadrant: strong positive correlation
# In the negative quadrant: strong negative correlation
# This demonstrates how local correlation can reveal structure hidden by global correlation

x1 = randn(n)
y1 = similar(x1)
for i in 1:n
    if x1[i] > 0.5
        # Strong positive correlation in upper region
        y1[i] = 0.9 * x1[i] + 0.3 * randn()
    elseif x1[i] < -0.5
        # Negative correlation in lower region
        y1[i] = -0.7 * x1[i] + 0.4 * randn()
    else
        # No correlation in middle region
        y1[i] = randn()
    end
end

df_varying = DataFrame(
    x = x1,
    y = y1,
    region = [x > 0.5 ? "Upper" : (x < -0.5 ? "Lower" : "Middle") for x in x1]
)

lgc_varying = LocalGaussianCorrelationPlot(:lgc_varying, df_varying, :varying_data,
    dimensions = [:x, :y],
    title = "Local Correlation: Varying by Region",
    notes = """
    This example shows how local correlation can reveal structure that global correlation misses.
    The data has positive correlation in the upper region (x > 0.5), negative correlation in
    the lower region (x < -0.5), and no correlation in the middle. The global correlation
    would be close to zero, but local correlation shows the true structure.

    **Try the Bootstrap t-statistic mode** to see which regions have statistically significant
    correlations. Values beyond ±1.96 indicate significance at p < 0.05.
    """
)

# Example 2: Financial returns - correlation varies during market stress
Random.seed!(123)
n = 400
dates = Date(2020, 1, 1) .+ Day.(0:n-1)

# Simulate market regime: normal periods vs crisis periods
is_crisis = [sin(i/50) > 0.8 for i in 1:n]

stock_returns = Float64[]
bond_returns = Float64[]

for i in 1:n
    if is_crisis[i]
        # Crisis: stocks and bonds become correlated (flight to safety disrupted)
        base_shock = randn()
        push!(stock_returns, -0.02 + 0.03 * base_shock + 0.01 * randn())
        push!(bond_returns, 0.01 + 0.02 * base_shock + 0.005 * randn())
    else
        # Normal: stocks and bonds are uncorrelated or slightly negative
        push!(stock_returns, 0.001 + 0.01 * randn())
        push!(bond_returns, 0.0005 - 0.2 * stock_returns[end] + 0.005 * randn())
    end
end

df_financial = DataFrame(
    date = dates,
    stock_return = stock_returns,
    bond_return = bond_returns,
    regime = [c ? "Crisis" : "Normal" for c in is_crisis]
)

lgc_financial = LocalGaussianCorrelationPlot(:lgc_financial, df_financial, :financial_data,
    dimensions = [:stock_return, :bond_return],
    filters = [:regime],
    bandwidth = 0.008,
    title = "Stock-Bond Local Correlation",
    notes = """
    Examine how the correlation between stock and bond returns varies.
    During normal markets, stocks and bonds may be uncorrelated or negatively correlated.
    During crisis periods, correlations can break down or become positive (contagion).
    Use the filter to compare regimes.
    """
)

# Example 3: Multi-dimensional exploration
Random.seed!(456)
n = 300

# Create correlated features
z = randn(n)
df_multi = DataFrame(
    feature_a = z .+ 0.5 .* randn(n),
    feature_b = 0.7 .* z .+ 0.5 .* randn(n),
    feature_c = -0.5 .* z .+ 0.6 .* randn(n),
    feature_d = randn(n),  # Independent
    sector = rand(["Tech", "Finance", "Healthcare", "Energy"], n)
)

lgc_multi = LocalGaussianCorrelationPlot(:lgc_multi, df_multi, :multi_data,
    dimensions = [:feature_a, :feature_b, :feature_c, :feature_d],
    filters = [:sector],
    grid_size = 25,
    title = "Multi-Feature Local Correlation Explorer",
    notes = """
    Explore local correlations between different feature pairs.
    Use the X and Y selectors to choose which features to analyze.
    Filter by sector to see if local correlation patterns differ across groups.
    Features A and B should show positive local correlation, A and C negative,
    while D is independent of all others.
    """
)

# Example 3b: Using choices (single-select) instead of filters (multi-select)
# Reuses the df_multi DataFrame from Example 3
lgc_choices = LocalGaussianCorrelationPlot(:lgc_choices, df_multi, :multi_data,
    dimensions = [:feature_a, :feature_b, :feature_c, :feature_d],
    choices = Dict{Symbol,Any}(:sector => "Tech"),  # Single-select: user picks ONE sector
    grid_size = 25,
    title = "Local Correlation with Single-Select Choice",
    notes = """
    This example demonstrates the difference between choices and filters:
    - **Sector (choice)**: Single-select dropdown - pick exactly ONE sector at a time

    Use choices when the user must select exactly one option. Compare this to Example 3
    above which uses a multi-select filter for sector instead.
    """
)

# Example 4: Non-linear relationship
Random.seed!(789)
n = 400
x_nl = randn(n) .* 2
# Y has a quadratic relationship with X, so linear correlation is weak
# but local correlation should be positive for x < 0 and negative for x > 0
y_nl = -0.5 .* x_nl.^2 .+ x_nl .+ 0.5 .* randn(n)

df_nonlinear = DataFrame(
    x = x_nl,
    y = y_nl
)

lgc_nonlinear = LocalGaussianCorrelationPlot(:lgc_nonlinear, df_nonlinear, :nonlinear_data,
    dimensions = [:x, :y],
    bandwidth = 0.5,
    grid_size = 35,
    title = "Local Correlation in Non-linear Relationships",
    notes = """
    When Y = -0.5X² + X + noise, the global correlation is weak.
    But local correlation reveals the underlying structure: positive correlation
    where the parabola is increasing (x < 1) and negative where it's decreasing (x > 1).
    """
)

# Create the HTML page
page_data = Dict(
    :varying_data => df_varying,
    :financial_data => df_financial,
    :multi_data => df_multi,
    :nonlinear_data => df_nonlinear
)

page = JSPlotPage(page_data, [lgc_varying, lgc_financial, lgc_multi, lgc_choices, lgc_nonlinear];
                  dataformat=:parquet)
create_html(page, joinpath(@__DIR__, "../generated_html_examples/localgaussiancorrelationplot_examples.html"))

println("LocalGaussianCorrelationPlot examples generated!")
