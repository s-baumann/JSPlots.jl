using JSPlots, DataFrames, Dates

# Example: Analyzing trade execution quality for large equity orders
println("Creating ExecutionPlot examples...")

# Example 1: Single large buy order executed across multiple venues
println("Creating Example 1: Multi-venue buy execution...")

# Generate top of book data (bid/ask prices over time)
start_time = DateTime(2024, 1, 15, 9, 30, 0)
time_points = [start_time + Second(i*30) for i in 0:120]  # Every 30 seconds for 1 hour

# Simulate realistic price movement with spread
base_price = 150.0
prices = base_price .+ cumsum(randn(length(time_points)) .* 0.05)
spread = 0.02  # 2 cent spread

tob_df = DataFrame(
    time = time_points,
    bid = prices .- spread/2,
    ask = prices .+ spread/2
)

# Generate volume data (market volume in 5-minute buckets)
volume_times = [start_time + Minute(i*5) for i in 0:11]
volume_df = DataFrame(
    time_from = volume_times[1:end-1],
    time_to = volume_times[2:end],
    volume = rand(50000:200000, length(volume_times)-1)
)

# Generate fills data - buying 10,000 shares across different venues
fill_times = sort(start_time .+ Second.(rand(300:3300, 25)))
fill_quantities = [300, 400, 500, 350, 450, 400, 350, 500, 400, 350,
                  450, 400, 500, 350, 400, 450, 350, 500, 400, 350,
                  450, 400, 500, 350, 400]
venues = rand(["NYSE", "NASDAQ", "BATS", "ARCA"], 25)
aggressiveness = rand(["Passive", "Aggressive", "Mid"], 25)

fills1_df = DataFrame(
    time = fill_times,
    quantity = fill_quantities,
    price = [tob_df[findfirst(t -> t >= ft, tob_df.time), :ask] + rand(-0.01:0.001:0.01)
             for ft in fill_times],  # Price near ask with some variation
    execution_name = fill("Execution_1", 25),
    venue = venues,
    aggressiveness = aggressiveness
)

# Metadata for the execution
metadata1_df = DataFrame(
    execution_name = ["Execution_1"],
    arrival_price = [150.0],
    side = ["buy"],
    desired_quantity = [10000]
)

chart1 = ExecutionPlot(
    :example1_exec,
    tob_df,
    volume_df,
    fills1_df,
    metadata1_df,
    (:tob_data1, :volume_data1, :fills_data1, :metadata1);
    color_cols=[:venue, :aggressiveness],
    title="Example 1: Multi-Venue Buy Execution",
    notes="Analyzing a large buy order (10,000 shares) executed across multiple venues. The implementation shortfall shows cost vs arrival price. VWAP shortfall shows performance vs execution VWAP. Spread crossing percentage indicates how aggressive fills were (0%=bid, 100%=ask). Click fills to exclude from analysis. Hover over table rows to highlight corresponding chart points."
)

# Example 2: Sell execution with no arrival price (uses first fill mid as benchmark)
println("Creating Example 2: Algorithmic sell execution...")

# New top of book data for different time period
start_time2 = DateTime(2024, 1, 15, 14, 0, 0)
time_points2 = [start_time2 + Second(i*20) for i in 0:180]
base_price2 = 75.0
prices2 = base_price2 .+ cumsum(randn(length(time_points2)) .* 0.03)
spread2 = 0.015

tob2_df = DataFrame(
    time = time_points2,
    bid = prices2 .- spread2/2,
    ask = prices2 .+ spread2/2
)

volume2_df = DataFrame(
    time_from = [start_time2 + Minute(i*3) for i in 0:19],
    time_to = [start_time2 + Minute(i*3) for i in 1:20],
    volume = rand(30000:150000, 20)
)

# Generate sells - more passive strategy
fill_times2 = sort(start_time2 .+ Second.(rand(180:3420, 30)))
fill_quantities2 = rand(200:600, 30)
strategies = rand(["TWAP", "VWAP", "POV", "Opportunistic"], 30)
fill_types = rand(["Limit", "Market", "Peg"], 30)

fills2_df = DataFrame(
    time = fill_times2,
    quantity = fill_quantities2,
    price = [tob2_df[findfirst(t -> t >= ft, tob2_df.time), :bid] + rand(-0.005:0.001:0.01)
             for ft in fill_times2],  # Price near bid for sells
    execution_name = fill("Execution_2", 30),
    strategy = strategies,
    fill_type = fill_types
)

# Metadata without arrival price - will use first fill mid as benchmark
metadata2_df = DataFrame(
    execution_name = ["Execution_2"],
    side = ["sell"],
    desired_quantity = [15000]
)

chart2 = ExecutionPlot(
    :example2_exec,
    tob2_df,
    volume2_df,
    fills2_df,
    metadata2_df,
    (:tob_data2, :volume_data2, :fills_data2, :metadata2);
    color_cols=[:strategy, :fill_type],
    title="Example 2: Algorithmic Sell Execution (No Arrival Price)",
    notes="Selling 15,000 shares using multiple algorithmic strategies. Since no arrival price is provided, the benchmark defaults to the mid price at the first fill. This is common when analyzing post-trade execution quality. The spread crossing shows how close to the bid (neartouch for sells) each fill was."
)

# Example 3: Multiple executions for comparison
println("Creating Example 3: Comparing two different executions...")

# Shared top of book and volume data
start_time3 = DateTime(2024, 1, 16, 10, 0, 0)
time_points3 = [start_time3 + Second(i*15) for i in 0:240]
base_price3 = 200.0
prices3 = base_price3 .+ cumsum(randn(length(time_points3)) .* 0.08)
spread3 = 0.025

tob3_df = DataFrame(
    time = time_points3,
    bid = prices3 .- spread3/2,
    ask = prices3 .+ spread3/2
)

volume3_df = DataFrame(
    time_from = [start_time3 + Minute(i*2) for i in 0:29],
    time_to = [start_time3 + Minute(i*2) for i in 1:30],
    volume = rand(80000:250000, 30)
)

# Execution A: Aggressive strategy (buys quickly)
exec_a_times = sort(start_time3 .+ Second.(rand(60:900, 20)))
exec_a_quantities = rand(400:600, 20)
fills_a = DataFrame(
    time = exec_a_times,
    quantity = exec_a_quantities,
    price = [tob3_df[findfirst(t -> t >= ft, tob3_df.time), :ask] + rand(0:0.001:0.02)
             for ft in exec_a_times],  # Aggressive - paying above ask
    execution_name = fill("Aggressive_Buy", 20),
    venue = rand(["NYSE", "NASDAQ", "ARCA"], 20),
    urgency = fill("High", 20)
)

# Execution B: Patient strategy (takes more time)
exec_b_times = sort(start_time3 .+ Second.(rand(300:3300, 35)))
exec_b_quantities = rand(250:400, 35)
fills_b = DataFrame(
    time = exec_b_times,
    quantity = exec_b_quantities,
    price = [tob3_df[findfirst(t -> t >= ft, tob3_df.time), :ask] - rand(0:0.001:0.015)
             for ft in exec_b_times],  # Patient - getting better prices
    execution_name = fill("Patient_Buy", 35),
    venue = rand(["NYSE", "NASDAQ", "ARCA", "BATS"], 35),
    urgency = fill("Low", 35)
)

# Combine fills
fills3_df = vcat(fills_a, fills_b)

# Metadata for both executions
metadata3_df = DataFrame(
    execution_name = ["Aggressive_Buy", "Patient_Buy"],
    arrival_price = [200.0, 200.0],
    side = ["buy", "buy"],
    desired_quantity = [10000, 12000]
)

chart3 = ExecutionPlot(
    :example3_exec,
    tob3_df,
    volume3_df,
    fills3_df,
    metadata3_df,
    (:tob_data3, :volume_data3, :fills_data3, :metadata3);
    color_cols=[:urgency, :venue],
    title="Example 3: Comparing Aggressive vs Patient Execution",
    notes="Compare two different execution strategies for buying the same stock. The aggressive execution (high urgency) completes faster but may have higher implementation shortfall. The patient execution takes longer but aims for better prices. Use the execution selector to switch between them and compare their performance metrics."
)

# Create page with all examples
println("Creating HTML page...")
page = JSPlotPage(
    Dict(
        :tob_data1 => tob_df,
        :volume_data1 => volume_df,
        :fills_data1 => fills1_df,
        :metadata1 => metadata1_df,
        :tob_data2 => tob2_df,
        :volume_data2 => volume2_df,
        :fills_data2 => fills2_df,
        :metadata2 => metadata2_df,
        :tob_data3 => tob3_df,
        :volume_data3 => volume3_df,
        :fills_data3 => fills3_df,
        :metadata3 => metadata3_df
    ),
    [chart1, chart2, chart3];
    page_header="Execution Markout Examples"
)

# Save to file
output_path = "generated_html_examples/executionplot_examples.html"
create_html(page, output_path)

println("✓ ExecutionPlot examples saved to: $output_path")
println("Open this file in a web browser to view the interactive examples.")
