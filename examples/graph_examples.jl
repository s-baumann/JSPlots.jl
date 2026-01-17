using JSPlots, DataFrames, Statistics, Random, StableRNGs, StatsBase

println("Creating Graph examples...")

# =============================================================================
# Helper Functions
# =============================================================================

"""
    create_graph_data_from_correlation(labels, correlation_matrix; attributes=nothing)

Convert a correlation matrix to graph edge data format.
"""
function create_graph_data_from_correlation(labels::Vector{String},
                                           correlation_matrix::Matrix{Float64};
                                           attributes::Union{Nothing, DataFrame} = nothing)
    n = length(labels)
    edges = []

    for i in 1:n
        for j in (i+1):n
            corr = correlation_matrix[i, j]

            edge_data = (
                node1 = labels[i],
                node2 = labels[j],
                strength = corr
            )

            # Add attributes if provided
            if !isnothing(attributes)
                # Get attributes for both nodes
                attrs_i = attributes[attributes.node .== labels[i], :]
                attrs_j = attributes[attributes.node .== labels[j], :]

                if nrow(attrs_i) > 0 && nrow(attrs_j) > 0
                    # Use attributes from first node (they should match for same attribute type)
                    row_dict = Dict(pairs(NamedTuple(attrs_i[1, :])))
                    delete!(row_dict, :node)  # Remove node column
                    edge_data = merge(edge_data, row_dict)
                end
            end

            push!(edges, edge_data)
        end
    end

    return DataFrame(edges)
end

"""
    create_graph_data_from_distance(labels, distance_matrix; attributes=nothing)

Convert a distance matrix to graph edge data format.
"""
function create_graph_data_from_distance(labels::Vector{String},
                                        distance_matrix::Matrix{Float64};
                                        attributes::Union{Nothing, DataFrame} = nothing)
    n = length(labels)
    edges = []

    for i in 1:n
        for j in (i+1):n
            dist = distance_matrix[i, j]

            edge_data = (
                node1 = labels[i],
                node2 = labels[j],
                strength = dist
            )

            # Add attributes if provided
            if !isnothing(attributes)
                attrs_i = attributes[attributes.node .== labels[i], :]
                attrs_j = attributes[attributes.node .== labels[j], :]

                if nrow(attrs_i) > 0 && nrow(attrs_j) > 0
                    row_dict = Dict(pairs(NamedTuple(attrs_i[1, :])))
                    delete!(row_dict, :node)
                    edge_data = merge(edge_data, row_dict)
                end
            end

            push!(edges, edge_data)
        end
    end

    return DataFrame(edges)
end

# =============================================================================
# Example 1: Stock Correlation Network
# =============================================================================

header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/graph_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Graph - Network Visualization Examples</h1>
<p>The Graph chart type displays interactive network graphs with nodes and edges. It can visualize:
<ul>
    <li><strong>Correlation networks:</strong> Show which variables are correlated</li>
    <li><strong>Distance networks:</strong> Display proximity relationships</li>
    <li><strong>Social networks:</strong> Visualize connections between entities</li>
    <li><strong>Any graph structure:</strong> Flexible node and edge data</li>
</ul>
</p>
<p><strong>Interactive features:</strong></p>
<ul>
    <li>Drag nodes to rearrange the layout</li>
    <li>Zoom and pan to explore large networks</li>
    <li>Toggle edge labels on/off</li>
    <li>Color nodes by categorical attributes</li>
    <li>Adjust connection strength cutoff</li>
    <li>Switch between different layout algorithms</li>
</ul>
""")

example1_text = TextBlock("""
<h2>Example 1: Stock Correlation Network with Multiple Scenarios</h2>
<p>This example shows correlations between stock returns across different time periods. Stocks are colored by sector to reveal industry clustering patterns.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Multiple scenarios (Short-term, Long-term, Volatility correlations)</li>
    <li>Scenario switching - edges update while nodes stay in place</li>
    <li>Correlation matrix input (high correlation = strong connection)</li>
    <li>Node coloring by sector</li>
    <li>Force-directed (COSE) layout</li>
    <li>Adjustable cutoff to filter weak correlations</li>
    <li>Smart cutoff calculation for optimal visualization</li>
</ul>
<p><strong>Try this:</strong> Switch between scenarios to see how correlations change across different time periods.
Notice how nodes stay in place while edges change - this makes it easy to identify robust correlations.
Adjust the cutoff slider to filter weak correlations. Stocks in the same sector (same color) often cluster together.</p>
""")

# Generate stock returns data
rng = StableRNG(42)
n_days = 250
stocks = [
    ("AAPL", "Technology"), ("MSFT", "Technology"), ("GOOGL", "Technology"),
    ("AMZN", "Technology"), ("TSLA", "Technology"),
    ("JPM", "Finance"), ("BAC", "Finance"), ("GS", "Finance"), ("WFC", "Finance"),
    ("JNJ", "Healthcare"), ("PFE", "Healthcare"), ("UNH", "Healthcare"),
    ("XOM", "Energy"), ("CVX", "Energy"), ("COP", "Energy")
]

stock_names = [s[1] for s in stocks]
sectors = [s[2] for s in stocks]
n_stocks = length(stocks)

# Generate correlated returns within sectors
returns = zeros(n_days, n_stocks)
for day in 1:n_days
    # Sector-specific factors
    tech_factor = randn(rng) * 0.02
    finance_factor = randn(rng) * 0.015
    health_factor = randn(rng) * 0.01
    energy_factor = randn(rng) * 0.018

    for (i, (name, sector)) in enumerate(stocks)
        sector_factor = sector == "Technology" ? tech_factor :
                       sector == "Finance" ? finance_factor :
                       sector == "Healthcare" ? health_factor : energy_factor

        returns[day, i] = sector_factor + randn(rng) * 0.01
    end
end

# Compute correlation matrices for different time periods
# Short-term correlations (daily returns, last 60 days)
short_term_returns = returns[end-59:end, :]
corr_short_term = cor(short_term_returns)

# Long-term correlations (all 250 days)
corr_long_term = cor(returns)

# Volatility correlations (correlation of absolute returns as proxy for volatility)
vol_returns = abs.(returns)
corr_volatility = cor(vol_returns)

# Create node attributes
stock_attrs = DataFrame(
    node = stock_names,
    sector = sectors
)

# Create graph data for all three scenarios
graph_data1 = DataFrame(
    node1 = String[],
    node2 = String[],
    strength = Float64[],
    sector = String[],
    scenario = String[]
)

# Add short-term scenario
short_edges = create_graph_data_from_correlation(stock_names, corr_short_term; attributes = stock_attrs)
short_edges[!, :scenario] .= "Short-term (60 days)"
append!(graph_data1, short_edges)

# Add long-term scenario
long_edges = create_graph_data_from_correlation(stock_names, corr_long_term; attributes = stock_attrs)
long_edges[!, :scenario] .= "Long-term (250 days)"
append!(graph_data1, long_edges)

# Add volatility scenario
vol_edges = create_graph_data_from_correlation(stock_names, corr_volatility; attributes = stock_attrs)
vol_edges[!, :scenario] .= "Volatility Correlations"
append!(graph_data1, vol_edges)

# Add correlation_method column for Graph (required)
graph_data1[!, :correlation_method] .= "pearson"

# Create graph with multiple scenarios
graph1 = Graph(:stock_network, graph_data1, :stock_graph_data;
    title = "Stock Correlation Network - Multiple Scenarios",
    cutoff = 0.5,
    color_cols = [:sector],
    show_edge_labels = false,
    layout = :cose,
    scenario_col = :scenario,
    default_scenario = "Short-term (60 days)"
)

# =============================================================================
# Example 2: Geographic City Network
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: City Proximity Network with Correlation Methods</h2>
<p>This example shows similarity between cities based on their economic indicators, with both Pearson and Spearman correlations available.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Correlation method selector (Pearson vs Spearman)</li>
    <li>Node coloring by geographic region</li>
    <li>Circle layout showing regional grouping</li>
    <li>Dynamic edge filtering based on selected method</li>
</ul>
<p><strong>Try this:</strong> Switch between Pearson and Spearman correlation methods to see how the network changes.
Pearson measures linear relationships while Spearman measures rank-based relationships.</p>
""")

# Cities with regions
cities = [
    ("New York", "Northeast"),
    ("Boston", "Northeast"),
    ("Philadelphia", "Northeast"),
    ("Washington DC", "Northeast"),
    ("Chicago", "Midwest"),
    ("Detroit", "Midwest"),
    ("Minneapolis", "Midwest"),
    ("Los Angeles", "West"),
    ("San Francisco", "West"),
    ("Seattle", "West"),
    ("Portland", "West"),
    ("Miami", "Southeast"),
    ("Atlanta", "Southeast"),
    ("Houston", "Southeast")
]

city_names = [c[1] for c in cities]
regions = [c[2] for c in cities]
n_cities = length(cities)

# Generate economic indicator data for cities
# Each city has time series of: GDP growth, unemployment rate, housing prices, tech jobs
rng_cities = StableRNG(999)
n_quarters = 40

city_indicators = zeros(n_quarters, n_cities, 4)  # 4 indicators per city
for i in 1:n_cities
    region = regions[i]

    # Regional economic factors
    if region == "Northeast"
        base_gdp = 2.5
        base_unemp = 4.0
        base_housing = 1.8
        base_tech = 3.0
    elseif region == "Midwest"
        base_gdp = 2.0
        base_unemp = 4.5
        base_housing = 1.2
        base_tech = 2.0
    elseif region == "West"
        base_gdp = 3.0
        base_unemp = 3.5
        base_housing = 2.5
        base_tech = 4.0
    else  # Southeast
        base_gdp = 2.8
        base_unemp = 4.2
        base_housing = 2.0
        base_tech = 2.5
    end

    for q in 1:n_quarters
        city_indicators[q, i, 1] = base_gdp + randn(rng_cities) * 0.5  # GDP growth
        city_indicators[q, i, 2] = base_unemp + randn(rng_cities) * 0.8  # Unemployment
        city_indicators[q, i, 3] = base_housing + randn(rng_cities) * 0.6  # Housing price growth
        city_indicators[q, i, 4] = base_tech + randn(rng_cities) * 0.7  # Tech job growth
    end
end

# Reshape data for correlation calculation (quarters x cities)
# Stack all 4 indicators together for each city
city_data_matrix = zeros(n_quarters * 4, n_cities)
for i in 1:n_cities
    city_data_matrix[:, i] = vec(city_indicators[:, i, :])
end

# Calculate Pearson correlation
pearson_corr = cor(city_data_matrix)

# Calculate Spearman correlation (rank-based)
# Convert each column to ranks
city_data_ranks = zeros(size(city_data_matrix))
for i in 1:n_cities
    city_data_ranks[:, i] = ordinalrank(city_data_matrix[:, i])
end
spearman_corr = cor(city_data_ranks)

# Create graph data with BOTH correlation methods
graph_data2 = DataFrame(
    node1 = String[],
    node2 = String[],
    strength = Float64[],
    region = String[],
    correlation_method = String[],
    scenario = String[]
)

# Add Pearson correlations
for i in 1:n_cities
    for j in (i+1):n_cities
        push!(graph_data2, (
            node1 = city_names[i],
            node2 = city_names[j],
            strength = pearson_corr[i, j],
            region = regions[i],  # Use first node's region
            correlation_method = "pearson",
            scenario = "Economic Indicators"
        ))
    end
end

# Add Spearman correlations
for i in 1:n_cities
    for j in (i+1):n_cities
        push!(graph_data2, (
            node1 = city_names[i],
            node2 = city_names[j],
            strength = spearman_corr[i, j],
            region = regions[i],  # Use first node's region
            correlation_method = "spearman",
            scenario = "Economic Indicators"
        ))
    end
end

graph2 = Graph(:city_network, graph_data2, :city_graph_data;
    title = "City Economic Similarity Network",
    cutoff = 0.5,
    color_cols = [:region],
    show_edge_labels = false,
    layout = :circle,
    scenario_col = :scenario,
    default_scenario = "Economic Indicators"
)

# =============================================================================
# Example 3: Social Network with Multiple Attributes
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Social Network with Demographics</h2>
<p>This example shows a social network where people are connected based on similarity.
You can color nodes by different demographic attributes.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Multiple node coloring options (Department, Team, Location)</li>
    <li>Concentric layout organizing by centrality</li>
    <li>Edge labels showing connection strength</li>
    <li>Complex multi-attribute data</li>
</ul>
<p><strong>Try this:</strong> Switch between coloring by Department, Team, and Location to see different community patterns.</p>
""")

# Generate social network data
people = [
    ("Alice", "Engineering", "Backend", "NYC"),
    ("Bob", "Engineering", "Backend", "NYC"),
    ("Carol", "Engineering", "Frontend", "NYC"),
    ("Dave", "Engineering", "Frontend", "SF"),
    ("Eve", "Engineering", "Backend", "SF"),
    ("Frank", "Marketing", "Digital", "NYC"),
    ("Grace", "Marketing", "Digital", "LA"),
    ("Henry", "Marketing", "Content", "LA"),
    ("Iris", "Sales", "Enterprise", "NYC"),
    ("Jack", "Sales", "Enterprise", "SF"),
    ("Kate", "Sales", "SMB", "LA"),
    ("Leo", "Engineering", "DevOps", "SF")
]

person_names = [p[1] for p in people]
departments = [p[2] for p in people]
teams = [p[3] for p in people]
locations = [p[4] for p in people]
n_people = length(people)

# Generate similarity-based connections
rng_social = StableRNG(123)
similarity_matrix = zeros(n_people, n_people)
for i in 1:n_people
    for j in (i+1):n_people
        # Base similarity
        sim = 0.3 + rand(rng_social) * 0.3

        # Increase similarity if same department
        if departments[i] == departments[j]
            sim += 0.2
        end

        # Increase similarity if same team
        if teams[i] == teams[j]
            sim += 0.15
        end

        # Increase similarity if same location
        if locations[i] == locations[j]
            sim += 0.1
        end

        similarity_matrix[i, j] = similarity_matrix[j, i] = min(sim, 1.0)
    end
end

# Create node attributes
person_attrs = DataFrame(
    node = person_names,
    Department = departments,
    Team = teams,
    Location = locations
)

# Create graph data
graph_data3 = create_graph_data_from_correlation(person_names, similarity_matrix;
                                                 attributes = person_attrs)

# Add required columns
graph_data3[!, :scenario] .= "Social Connections"
graph_data3[!, :correlation_method] .= "similarity"

graph3 = Graph(:social_network, graph_data3, :social_graph_data;
    title = "Social Network - Connection Patterns",
    cutoff = 0.5,
    color_cols = [:Department, :Team, :Location],
    show_edge_labels = true,
    layout = :concentric,
    scenario_col = :scenario,
    default_scenario = "Social Connections"
)

# =============================================================================
# Example 4: Scientific Collaboration Network
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: Research Collaboration Network</h2>
<p>This example shows collaboration patterns between researchers across different institutions and fields.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Breadth-first layout showing hierarchical structure</li>
    <li>Multiple coloring attributes (Institution and Field)</li>
    <li>Dense network with many connections</li>
    <li>Different cutoff sensitivity</li>
</ul>
<p><strong>Observation:</strong> Researchers at the same institution (same color) often collaborate more,
but there are also strong cross-institutional collaborations visible in the network.</p>
""")

# Generate researcher network
researchers = [
    ("Dr. Smith", "MIT", "AI"),
    ("Dr. Johnson", "MIT", "AI"),
    ("Dr. Williams", "Stanford", "AI"),
    ("Dr. Brown", "Stanford", "Robotics"),
    ("Dr. Jones", "Berkeley", "AI"),
    ("Dr. Garcia", "Berkeley", "Networks"),
    ("Dr. Miller", "CMU", "Robotics"),
    ("Dr. Davis", "CMU", "AI"),
    ("Dr. Rodriguez", "Caltech", "Physics"),
    ("Dr. Martinez", "Caltech", "Physics"),
    ("Dr. Hernandez", "MIT", "Networks"),
    ("Dr. Lopez", "Stanford", "Networks")
]

researcher_names = [r[1] for r in researchers]
institutions = [r[2] for r in researchers]
fields = [r[3] for r in researchers]
n_researchers = length(researchers)

# Generate collaboration strength based on institution and field
rng_research = StableRNG(456)
collab_matrix = zeros(n_researchers, n_researchers)
for i in 1:n_researchers
    for j in (i+1):n_researchers
        # Base collaboration
        collab = 0.2 + rand(rng_research) * 0.2

        # Strong collaboration if same institution
        if institutions[i] == institutions[j]
            collab += 0.4
        end

        # Strong collaboration if same field
        if fields[i] == fields[j]
            collab += 0.3
        end

        collab_matrix[i, j] = collab_matrix[j, i] = min(collab, 1.0)
    end
end

# Create node attributes
researcher_attrs = DataFrame(
    node = researcher_names,
    Institution = institutions,
    Field = fields
)

# Create graph data
graph_data4 = create_graph_data_from_correlation(researcher_names, collab_matrix;
                                                 attributes = researcher_attrs)

# Add required columns
graph_data4[!, :scenario] .= "Research Collaborations"
graph_data4[!, :correlation_method] .= "collaboration"

graph4 = Graph(:research_network, graph_data4, :research_graph_data;
    title = "Research Collaboration Network",
    cutoff = 0.4,
    color_cols = [:Institution, :Field],
    show_edge_labels = false,
    layout = :breadthfirst,
    scenario_col = :scenario,
    default_scenario = "Research Collaborations"
)

# =============================================================================
# Example 5: Grid Layout Network
# =============================================================================

example5_text = TextBlock("""
<h2>Example 5: Product Similarity Network with Grid Layout</h2>
<p>This example demonstrates the grid layout option, organizing nodes in a regular grid pattern.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li>Grid layout for organized visualization</li>
    <li>Product categorization</li>
    <li>Lower cutoff showing more connections</li>
</ul>
<p><strong>Use case:</strong> Grid layouts are useful when you want a clean, organized view
of all nodes with connections overlaid.</p>
""")

# Product network
products = [
    ("Laptop", "Electronics"), ("Mouse", "Electronics"), ("Keyboard", "Electronics"),
    ("Monitor", "Electronics"), ("Desk", "Furniture"), ("Chair", "Furniture"),
    ("Lamp", "Furniture"), ("Notebook", "Stationery"), ("Pen", "Stationery"),
    ("Stapler", "Stationery"), ("Coffee Mug", "Kitchen"), ("Water Bottle", "Kitchen")
]

product_names = [p[1] for p in products]
categories = [p[2] for p in products]
n_products = length(products)

# Generate purchase co-occurrence matrix
rng_products = StableRNG(789)
cooccur_matrix = zeros(n_products, n_products)
for i in 1:n_products
    for j in (i+1):n_products
        # Base co-occurrence
        cooccur = rand(rng_products) * 0.4

        # Higher if same category
        if categories[i] == categories[j]
            cooccur += 0.3 + rand(rng_products) * 0.2
        end

        cooccur_matrix[i, j] = cooccur_matrix[j, i] = min(cooccur, 1.0)
    end
end

# Create node attributes
product_attrs = DataFrame(
    node = product_names,
    Category = categories
)

# Create graph data
graph_data5 = create_graph_data_from_correlation(product_names, cooccur_matrix;
                                                 attributes = product_attrs)

# Add required columns
graph_data5[!, :scenario] .= "Product Co-occurrence"
graph_data5[!, :correlation_method] .= "cooccurrence"

graph5 = Graph(:product_network, graph_data5, :product_graph_data;
    title = "Product Purchase Co-occurrence Network",
    cutoff = 0.25,
    color_cols = [:Category],
    show_edge_labels = false,
    layout = :grid,
    scenario_col = :scenario,
    default_scenario = "Product Co-occurrence"
)

# =============================================================================
# Example 6: Trading Strategies with Continuous Coloring (Global Gradient)
# =============================================================================

example6_text = TextBlock("""
<h2>Example 6: Trading Strategy Network with Sharpe Ratio Coloring (Global Gradient)</h2>
<p>This example demonstrates <strong>continuous color mapping</strong> with a global gradient.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li><strong>Continuous color mapping:</strong> Nodes colored by Sharpe Ratio using a continuous gradient</li>
    <li><strong>Global gradient specification:</strong> Single color gradient applied to all continuous variables</li>
    <li><strong>No extrapolation (default):</strong> Extreme values clamp to min/max gradient colors instead of getting darker</li>
    <li>Gradient stops: -2.5 (red) → -1 (light red) → 0 (white) → 1 (light green) → 2.5 (blue)</li>
</ul>
<p><strong>Use case:</strong> Trading strategies are nodes, connected by correlation in returns.
Sharpe Ratio is visualized with a continuous color gradient to show performance at a glance.</p>
<p><strong>Color extrapolation:</strong> By default, <code>extrapolate_colors=false</code>, which means values beyond the gradient stops
(e.g., Sharpe Ratio < -2.5 or > 2.5) will use the min/max gradient color. This prevents colors from becoming too dark
for extreme values. Set <code>extrapolate_colors=true</code> to continue the gradient beyond the stops.</p>
<p><strong>Try this:</strong>
<ul>
    <li>Select "sharpe_ratio (continuous)" from the color dropdown to see the gradient</li>
    <li>Compare with "strategy_type (discrete)" to see the difference</li>
    <li>Notice how strategies with extreme Sharpe ratios use the min/max gradient colors (no extrapolation)</li>
</ul>
</p>
""")

# Trading strategies
strategies = [
    ("Momentum", "STRAT_001", "Equity", 1.8),
    ("Mean Reversion", "STRAT_002", "Equity", 1.2),
    ("Trend Following", "STRAT_003", "Equity", 0.9),
    ("Pairs Trading", "STRAT_004", "Equity", 1.5),
    ("Statistical Arbitrage", "STRAT_005", "Equity", 2.1),
    ("Market Making", "STRAT_006", "Options", -0.3),
    ("Volatility Arbitrage", "STRAT_007", "Options", 1.1),
    ("Delta Hedging", "STRAT_008", "Options", 0.5),
    ("Credit Spread", "STRAT_009", "Fixed Income", 1.6),
    ("Yield Curve", "STRAT_010", "Fixed Income", 0.8),
    ("Carry Trade", "STRAT_011", "FX", 1.3),
    ("Breakout", "STRAT_012", "Futures", -0.5)
]

strategy_names = [s[1] for s in strategies]
strategy_codes = [s[2] for s in strategies]
strategy_types = [s[3] for s in strategies]
sharpe_ratios = [s[4] for s in strategies]
n_strategies = length(strategies)

# Generate correlation matrix based on strategy type
rng_strat = StableRNG(321)
strat_corr_matrix = zeros(n_strategies, n_strategies)
for i in 1:n_strategies
    strat_corr_matrix[i, i] = 1.0
    for j in (i+1):n_strategies
        # Base correlation
        corr = -0.2 + rand(rng_strat) * 0.4

        # Higher correlation if same strategy type
        if strategy_types[i] == strategy_types[j]
            corr += 0.5
        end

        strat_corr_matrix[i, j] = strat_corr_matrix[j, i] = clamp(corr, -1.0, 1.0)
    end
end

# Create graph data with sharpe ratios
graph_data6_rows = []
for i in 1:n_strategies
    for j in (i+1):n_strategies
        push!(graph_data6_rows, (
            node1 = strategy_names[i],
            node2 = strategy_names[j],
            strength = strat_corr_matrix[i, j],
            strategy_type = strategy_types[i],  # Discrete column
            sharpe_ratio = sharpe_ratios[i],    # Continuous column
            scenario = "Strategy Correlations",
            correlation_method = "pearson"
        ))
    end
end

graph_data6 = DataFrame(graph_data6_rows)

# Create global color gradient (applies to all continuous variables)
global_gradient = Dict{Float64,String}(
    -2.5 => "#FF9999",  # Light red for very low Sharpe
    -1.0 => "#FFFF99",  # Light yellow for low Sharpe
    0.0 => "#FFFFFF",   # White for neutral
    1.0 => "#99FF99",   # Light green for good Sharpe
    2.5 => "#99CCFF"    # Light blue for excellent Sharpe
)

graph6 = Graph(:strategy_network_global, graph_data6, :strategy_graph_data_global;
    title = "Trading Strategy Network - Continuous Color (Global Gradient)",
    cutoff = 0.3,
    color_cols = [:strategy_type, :sharpe_ratio],  # Both discrete and continuous columns
    colour_map = global_gradient,  # Global gradient
    extrapolate_colors = false,  # Default: clamp to min/max colors (prevents too-dark colors for extreme values)
                                 # Set to true to extrapolate beyond gradient stops
    show_edge_labels = false,
    layout = :cose,
    scenario_col = :scenario,
    default_scenario = "Strategy Correlations"
)

# =============================================================================
# Example 7: Trading Strategies with Per-Variable Gradients
# =============================================================================

example7_text = TextBlock("""
<h2>Example 7: Strategy Network with Per-Variable Gradients and Tooltips</h2>
<p>This example demonstrates <strong>per-variable color gradients</strong> with multiple continuous metrics and <strong>interactive tooltips</strong>.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li><strong>Multiple continuous variables:</strong> Sharpe Ratio, Return (%), Volatility (%)</li>
    <li><strong>Per-variable gradients:</strong> Each continuous variable has its own color scale</li>
    <li><strong>Interactive tooltips:</strong> Hover over nodes to see all metrics</li>
    <li><strong>Sharpe:</strong> Red-white-green-blue scale (performance-based)</li>
    <li><strong>Return:</strong> Red-white-blue scale (negative-neutral-positive)</li>
    <li><strong>Volatility:</strong> Green-yellow-red scale (low-medium-high risk)</li>
</ul>
<p><strong>Use case:</strong> When analyzing strategies with multiple metrics, each metric can have
its own intuitive color scale. Low volatility is green (good), high volatility is red (risky).
Tooltips show all metric values at once for easy comparison.</p>
<p><strong>Try this:</strong>
<ul>
    <li>Switch between different continuous variables in the color dropdown</li>
    <li>Notice how each uses a different, contextually appropriate color gradient</li>
    <li><strong>Hover over any node</strong> to see a tooltip with all metrics (strategy type, Sharpe ratio, return %, volatility %)</li>
</ul>
</p>
""")

# Add more metrics to strategies
strategy_returns = [12.5, 8.3, 6.1, 10.2, 15.8, -2.1, 7.5, 3.8, 11.0, 5.5, 9.2, -3.5]
strategy_volatility = [15.0, 12.5, 18.0, 14.5, 11.2, 22.0, 16.5, 19.0, 13.5, 17.5, 14.0, 25.0]

# Create graph data with multiple continuous metrics
graph_data7_rows = []
for i in 1:n_strategies
    for j in (i+1):n_strategies
        push!(graph_data7_rows, (
            node1 = strategy_names[i],
            node2 = strategy_names[j],
            strength = strat_corr_matrix[i, j],
            strategy_type = strategy_types[i],
            sharpe_ratio = sharpe_ratios[i],
            return_pct = strategy_returns[i],
            volatility_pct = strategy_volatility[i],
            scenario = "Multi-Metric Analysis",
            correlation_method = "pearson"
        ))
    end
end

graph_data7 = DataFrame(graph_data7_rows)

# Create per-variable gradients
per_variable_gradients = Dict{String,Dict{Float64,String}}(
    "sharpe_ratio" => Dict{Float64,String}(
        -2.5 => "#FF9999",  # Light red
        -1.0 => "#FFFF99",  # Light yellow
        0.0 => "#FFFFFF",   # White
        1.0 => "#99FF99",   # Light green
        2.5 => "#99CCFF"    # Light blue
    ),
    "return_pct" => Dict{Float64,String}(
        -5.0 => "#FF6666",   # Red for negative returns
        0.0 => "#FFFFFF",    # White for zero
        5.0 => "#6666FF",    # Blue for positive returns (different from Sharpe)
        20.0 => "#0000AA"    # Dark blue for very high returns
    ),
    "volatility_pct" => Dict{Float64,String}(
        10.0 => "#00FF00",   # Green for low volatility (good)
        15.0 => "#FFFF00",   # Yellow for medium volatility
        20.0 => "#FF8800",   # Orange for high volatility
        30.0 => "#FF0000"    # Red for very high volatility (risky)
    )
)

graph7 = Graph(:strategy_network_pervariable, graph_data7, :strategy_graph_data_pervariable;
    title = "Trading Strategy Network - Per-Variable Gradients",
    cutoff = 0.3,
    color_cols = [:strategy_type, :sharpe_ratio, :return_pct, :volatility_pct],
    colour_map = per_variable_gradients,
    extrapolate_colors = false,  # Clamp to gradient boundaries (prevents too-dark colors)
    show_edge_labels = false,
    layout = :cose,
    scenario_col = :scenario,
    default_scenario = "Multi-Metric Analysis"
)

# =============================================================================
# Example 8: Graph with Additional Tooltip Information
# =============================================================================

example8_text = TextBlock("""
<h2>Example 8: Market Network with Rich Tooltips</h2>
<p>This example demonstrates the <strong>tooltip_cols parameter</strong> for adding extra information to node tooltips.</p>
<p><strong>Features demonstrated:</strong></p>
<ul>
    <li><strong>color_cols:</strong> Variables shown in color dropdown AND tooltips (Industry, Returns %)</li>
    <li><strong>tooltip_cols:</strong> Additional variables shown ONLY in tooltips (GDP Growth, Population, Market Cap)</li>
    <li><strong>Information separation:</strong> Keep color dropdown clean while showing rich details on hover</li>
</ul>
<p><strong>How it works:</strong></p>
<ul>
    <li>The color dropdown only shows <code>color_cols</code> options (Industry and Returns %)</li>
    <li>Hovering over a node shows ALL information from <code>union(color_cols, tooltip_cols)</code></li>
    <li>This keeps the UI clean while providing detailed context on demand</li>
</ul>
<p><strong>Try this:</strong> Hover over any market node to see:
<ul>
    <li>Market name (node label)</li>
    <li>Industry (from color_cols)</li>
    <li>Returns % (from color_cols)</li>
    <li>GDP Growth % (from tooltip_cols - not in color dropdown)</li>
    <li>Population millions (from tooltip_cols - not in color dropdown)</li>
    <li>Market Cap billions (from tooltip_cols - not in color dropdown)</li>
</ul>
</p>
<p><strong>Use case:</strong> When you have many attributes but only want to color by a few key ones,
use tooltip_cols to provide additional context without cluttering the color selection dropdown.</p>
""")

# African markets example with detailed attributes
markets = [
    ("Kenya", "Mixed Economy", 7.2, 6.1, 54.0, 115.0),
    ("Rwanda", "Tourism & Services", 5.8, 8.2, 13.0, 12.5),
    ("Tanzania", "Agriculture & Mining", 6.5, 6.8, 60.0, 75.0),
    ("Uganda", "Agriculture", 4.9, 6.2, 46.0, 45.0),
    ("Ethiopia", "Agriculture & Manufacturing", 8.1, 7.5, 120.0, 95.0),
    ("Nigeria", "Oil & Services", 3.2, 5.8, 220.0, 440.0),
    ("South Africa", "Diversified", 4.5, 4.2, 60.0, 380.0),
    ("Ghana", "Mining & Agriculture", 5.4, 5.9, 32.0, 75.0)
]

market_names = [m[1] for m in markets]
industries = [m[2] for m in markets]
returns = [m[3] for m in markets]
gdp_growth = [m[4] for m in markets]
populations = [m[5] for m in markets]
market_caps = [m[6] for m in markets]
n_markets = length(markets)

# Generate economic correlation matrix (markets with similar returns correlate)
rng_markets = StableRNG(888)
market_corr_matrix = zeros(n_markets, n_markets)
for i in 1:n_markets
    market_corr_matrix[i, i] = 1.0
    for j in (i+1):n_markets
        # Base correlation
        corr = 0.2 + rand(rng_markets) * 0.3

        # Higher correlation if similar returns
        return_diff = abs(returns[i] - returns[j])
        if return_diff < 1.5
            corr += 0.3
        elseif return_diff < 3.0
            corr += 0.15
        end

        # Higher correlation if same industry type
        if industries[i] == industries[j]
            corr += 0.2
        end

        market_corr_matrix[i, j] = market_corr_matrix[j, i] = min(corr, 1.0)
    end
end

# Create graph data with all attributes
graph_data8_rows = []
for i in 1:n_markets
    for j in (i+1):n_markets
        push!(graph_data8_rows, (
            node1 = market_names[i],
            node2 = market_names[j],
            strength = market_corr_matrix[i, j],
            industry = industries[i],           # color_cols - shown in dropdown AND tooltips
            returns = returns[i],               # color_cols - shown in dropdown AND tooltips
            gdp_growth = gdp_growth[i],        # tooltip_cols - ONLY in tooltips
            population = populations[i],        # tooltip_cols - ONLY in tooltips
            market_cap = market_caps[i],       # tooltip_cols - ONLY in tooltips
            scenario = "African Markets 2025",
            correlation_method = "economic"
        ))
    end
end

graph_data8 = DataFrame(graph_data8_rows)

graph8 = Graph(:market_network_tooltips, graph_data8, :market_graph_data;
    title = "African Markets Network - Rich Tooltips Example",
    cutoff = 0.4,
    color_cols = [:industry, :returns],  # These appear in color dropdown AND tooltips
    tooltip_cols = [:gdp_growth, :population, :market_cap],  # These appear ONLY in tooltips
    show_edge_labels = false,
    layout = :cose,
    scenario_col = :scenario,
    default_scenario = "African Markets 2025"
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The Graph chart type provides flexible network visualization with these key capabilities:</p>

<h3>Input Formats</h3>
<ul>
    <li><strong>Correlation matrices:</strong> High correlation = strong connection</li>
    <li><strong>Distance matrices:</strong> Low distance = strong connection</li>
    <li><strong>Any edge list:</strong> Flexible node-node-strength format</li>
</ul>

<h3>Layout Algorithms</h3>
<ul>
    <li><strong>COSE (Force-directed):</strong> Organizes nodes based on connection strength</li>
    <li><strong>Circle:</strong> Arranges nodes in a circle</li>
    <li><strong>Grid:</strong> Regular grid pattern</li>
    <li><strong>Concentric:</strong> Organizes by node centrality</li>
    <li><strong>Breadth-first:</strong> Hierarchical tree-like layout</li>
</ul>

<h3>Interactive Controls</h3>
<ul>
    <li><strong>Cutoff slider:</strong> Filter connections by strength</li>
    <li><strong>Edge labels:</strong> Show/hide connection strengths</li>
    <li><strong>Node coloring:</strong> Color by categorical (discrete) or numeric (continuous) attributes</li>
    <li><strong>Continuous coloring:</strong> Use custom color gradients for numeric variables</li>
    <li><strong>Interactive tooltips:</strong> Hover over nodes to see detailed information</li>
    <li><strong>Layout selection:</strong> Switch between different layouts</li>
    <li><strong>Drag nodes:</strong> Manually rearrange network</li>
    <li><strong>Zoom & pan:</strong> Explore large networks</li>
</ul>

<h3>Advanced Coloring</h3>
<ul>
    <li><strong>Discrete coloring:</strong> Categorical attributes (sector, department, etc.)</li>
    <li><strong>Continuous coloring:</strong> Numeric variables with gradient interpolation</li>
    <li><strong>Global gradient:</strong> Single gradient for all continuous variables</li>
    <li><strong>Per-variable gradients:</strong> Different color scales for each metric</li>
    <li><strong>Gradient customization:</strong> Define custom color stops for intuitive visualization</li>
    <li><strong>Color extrapolation control:</strong> Choose whether extreme values clamp to gradient boundaries (default) or extrapolate beyond them</li>
</ul>

<h3>Color Gradient Options</h3>
<ul>
    <li><strong>extrapolate_colors=false (default):</strong> Values beyond gradient stops use min/max colors (prevents too-dark colors)</li>
    <li><strong>extrapolate_colors=true:</strong> Colors continue to extrapolate beyond gradient stops for extreme values</li>
    <li><strong>Example:</strong> With gradient -2.5→2.5 and value=5.0, clamping uses the 2.5 color, extrapolation continues the trend</li>
</ul>

<h3>Tooltips</h3>
<ul>
    <li><strong>color_cols:</strong> Variables shown in color dropdown AND in tooltips when hovering over nodes</li>
    <li><strong>tooltip_cols:</strong> Additional variables shown ONLY in tooltips (not in color dropdown)</li>
    <li><strong>Automatic formatting:</strong> Numbers formatted with appropriate precision, column names capitalized</li>
    <li><strong>Use case:</strong> Keep color selection UI clean while providing rich contextual information on hover</li>
    <li><strong>Display:</strong> Tooltips show union(color_cols, tooltip_cols) for comprehensive node information</li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li>Stock correlation analysis</li>
    <li>Social network analysis</li>
    <li>Geographic proximity networks</li>
    <li>Collaboration networks</li>
    <li>Product recommendation networks</li>
    <li>Any relationship data</li>
</ul>
""")

# =============================================================================
# Create the page
# =============================================================================

# Collect all data
data_dict = Dict{Symbol, DataFrame}(
    :stock_graph_data => graph_data1,
    :city_graph_data => graph_data2,
    :social_graph_data => graph_data3,
    :research_graph_data => graph_data4,
    :product_graph_data => graph_data5,
    :strategy_graph_data_global => graph_data6,
    :strategy_graph_data_pervariable => graph_data7,
    :market_graph_data => graph_data8
)

# Create page
page = JSPlotPage(
    data_dict,
    [header,
     example1_text, graph1,
     example2_text, graph2,
     example3_text, graph3,
     example4_text, graph4,
     example5_text, graph5,
     example6_text, graph6,
     example7_text, graph7,
     example8_text, graph8,
     summary];
    dataformat = :csv_embedded
)

# Output
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end

output_file = joinpath(output_dir, "graph_examples.html")
create_html(page, output_file)
println("Created: $output_file")

println("\nGraph examples complete!")
println("Open the HTML file in a browser to see interactive network graphs.")
println("\nExplore different layouts, adjust cutoffs, and color nodes by attributes!")
