using RefinedSlippage, LinearAlgebra, DataFrames, DataFramesMeta, Random, HighFrequencyCovariance, StableRNGs, Statistics, Distributions, Dates

# =============================================================================
# Configuration
# =============================================================================
const NUM_EXECUTIONS = 20  # Number of executions to generate
const FILLS_PER_EXECUTION = 10  # Number of fills per execution
const TICKS_BETWEEN_EXECUTIONS = 500  # Time gap between execution windows

# =============================================================================
# Generate price data
# =============================================================================
dims = 8
# Need enough ticks: each execution needs TICKS_BETWEEN_EXECUTIONS unique times
# With synchronous data, ticks parameter = number of unique times
# We multiply by dims because generate_random_path with syncronous=true generates ticks/dims unique times
ticks = (NUM_EXECUTIONS + 2) * TICKS_BETWEEN_EXECUTIONS * dims  # Ensure enough for all executions
brownian_corr_matrix = Hermitian(0.5 .+ 0.5*I(dims))
twister = StableRNG(42)

ts, true_covar, true_micro_noise, true_update_rates = HighFrequencyCovariance.generate_random_path(
    dims, ticks; syncronous=true, brownian_corr_matrix=brownian_corr_matrix,
    vol_dist = Distributions.Uniform(0.0005, 0.001), micro_noise_dist = Distributions.Uniform(0, 0.0000000001),
)
assets = true_covar.labels

# Create bidask dataframe
bidask = copy(ts.df)
bidask[!, :Value] .= exp.(bidask.Value)
rename!(bidask, Dict(:Time => :time, :Name => :symbol, :Value => :bid_price))
bidask[:, :ask_price] = bidask[:, :bid_price] .* (1.0025 .+ (0.0025 .* rand(twister, size(bidask,1))))

# Create volume data for all assets
volume_times = unique(bidask.time[1:50:end])
n_intervals = length(volume_times) - 1
volume_dfs = DataFrame[]
for asset in assets
    push!(volume_dfs, DataFrame(
        time_from = volume_times[1:end-1],
        time_to = volume_times[2:end],
        symbol = fill(asset, n_intervals),
        volume = rand(twister, 50000:200000, n_intervals)
    ))
end
volume_df = reduce(vcat, volume_dfs)

# =============================================================================
# Generate executions - each uses a different time window (different realization)
# =============================================================================
function generate_executions(bidask, assets, num_executions, fills_per_exec, ticks_between, rng)
    allfills = DataFrame[]
    metadata = DataFrame[]

    unique_times = sort(unique(bidask.time))

    for exec_idx in 1:num_executions
        # Each execution trades a random asset (cycle through assets)
        asset = assets[mod1(exec_idx, length(assets))]

        # Get time window for this execution (different realization of price)
        start_tick = 1 + (exec_idx - 1) * ticks_between
        end_tick = min(start_tick + ticks_between - 1, length(unique_times))

        if end_tick <= start_tick + fills_per_exec
            @warn "Not enough ticks for execution $exec_idx, skipping"
            continue
        end

        exec_times = unique_times[start_tick:end_tick]

        # Filter bidask for this asset and time window
        subframe = bidask[(bidask.symbol .== asset) .& (bidask.time .>= exec_times[1]) .& (bidask.time .<= exec_times[end]), :]

        if nrow(subframe) < fills_per_exec
            @warn "Not enough data for execution $exec_idx, skipping"
            continue
        end

        # Generate fills at evenly spaced intervals
        fill_indices = round.(Int, range(1, nrow(subframe), length=fills_per_exec))
        fill_times = subframe.time[fill_indices]
        fill_prices = [subframe.bid_price[i] + rand(rng) * (subframe.ask_price[i] - subframe.bid_price[i])
                       for i in fill_indices]
        fill_quantities = rand(rng, 100:500, fills_per_exec)

        exec_name = "Execution_$(exec_idx)_$(asset)"

        # Add categorical columns for coloring
        order_types = rand(rng, ["limit", "market"], fills_per_exec)
        exchanges = rand(rng, ["NYSE", "NASDAQ", "BATS", "ARCA"], fills_per_exec)

        subdf = DataFrame(
            time = fill_times,
            quantity = fill_quantities,
            price = fill_prices,
            execution_name = fill(exec_name, fills_per_exec),
            asset = fill(asset, fills_per_exec),
            order_type = order_types,
            exchange = exchanges
        )
        push!(allfills, subdf)

        # Metadata
        arrival_price = (subframe.bid_price[1] + subframe.ask_price[1]) / 2
        side = rand(rng, ["buy", "sell"])

        meta = DataFrame(
            execution_name = [exec_name],
            arrival_price = [arrival_price],
            side = [side],
            desired_quantity = [sum(fill_quantities)]
        )
        push!(metadata, meta)
    end

    fills = reduce(vcat, allfills)
    metadata_df = reduce(vcat, metadata)

    return fills, metadata_df
end

fills, metadata_df = generate_executions(bidask, assets, NUM_EXECUTIONS, FILLS_PER_EXECUTION, TICKS_BETWEEN_EXECUTIONS, twister)









println("Generated $(length(unique(fills.execution_name))) executions with $(nrow(fills)) total fills")

# =============================================================================
# Create ExecutionData with peers (refined slippage)
# =============================================================================
println("\n" * "=" ^ 80)
println("Creating ExecutionData with covariance matrix (refined slippage)")
println("=" ^ 80)

exec_data = ExecutionData(fills, metadata_df, bidask, true_covar; volume=volume_df)
calculate_slippage!(exec_data)

# =============================================================================
# Create ExecutionPlot visualization
# =============================================================================
println("\nCreating ExecutionPlot visualization...")

using JSPlots

# Create the ExecutionPlot
exec_plot = ExecutionPlot(:execution_analysis, exec_data, :exec_data;
    title = "Order Execution Analysis",
    notes = "Interactive execution analysis showing bid/ask spreads, fills, counterfactual prices, and slippage metrics. Use the top panel buttons to switch between views: Bid/Ask shows market spread with fills, Mid+CF shows counterfactual prices, +Peers adds peer asset lines, Progress shows execution completion over time, Spread Pos shows where fills occurred within the spread. The bottom panel shows cumulative slippage (Classical, vs VWAP, Refined), spread crossing percentage, or volume distribution."
)

# Get the prepared data dictionary for the page
exec_data_dict = get_execution_data_dict(exec_plot)

# Create the page
page = JSPlotPage(
    exec_data_dict,
    [exec_plot];
    tab_title = "Execution Analysis",
    page_header = "Trading Execution Analysis",
    notes = "Analyze execution quality across multiple orders with refined slippage methodology.",
    dataformat = :parquet
)

# Generate the HTML
# Note: create_html with parquet dataformat creates a folder structure:
# generated_html_examples/execution_analysis/
#   ├── execution_analysis.html
#   ├── data/exec_data/
#   │   ├── fills.parquet, tob.parquet, summary.parquet, etc.
#   └── open.sh, open.bat, README.md
output_dir = "generated_html_examples"
mkpath(output_dir)
# Manifest entry for report index
manifest_entry = ManifestEntry(path="../execution_analysis", html_filename="execution_analysis.html",
                               description="ExecutionPlot Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Financial Charts", :page_type => "Chart Tutorial"))
create_html(page, joinpath(output_dir, "execution_analysis.html");
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("\n" * "=" ^ 80)
println("ExecutionPlot example created successfully!")
println("=" ^ 80)
println("\nFolder created: $output_dir/execution_analysis/")
println("\nThis visualization includes:")
println("  - Dropdown to select individual executions")
println("  - Dropdown to color fills by categorical attributes")
println("  - Summary table with key execution metrics")
println("  - 6 switchable views:")
println("    1. Bid/Ask + Fills (with volume bars on by default)")
println("    2. Mid + Counterfactual price")
println("    3. + Peer asset price lines")
println("    4. Execution progress (% completed over time)")
println("    5. Spread position (normalized 0-1)")
println("    6. Cumulative slippage (Classical, vs VWAP, Refined)")
println("  - Data source documentation below the chart")
