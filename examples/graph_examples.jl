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

# Create GraphScenarios
scenario_short = GraphScenario("Short-term (60 days)", true, stock_names)
scenario_long = GraphScenario("Long-term (250 days)", true, stock_names)
scenario_vol = GraphScenario("Volatility Correlations", true, stock_names)

# Calculate smart cutoff for the default scenario
smart_cutoff_stocks = calculate_smart_cutoff(graph_data1, "Short-term (60 days)", true, 0.15)

# Create graph with multiple scenarios
graph1 = Graph(:stock_network, [scenario_short, scenario_long, scenario_vol], :stock_graph_data;
    title = "Stock Correlation Network - Multiple Scenarios",
    cutoff = smart_cutoff_stocks,
    color_cols = [:sector],
    default_color_col = :sector,
    show_edge_labels = false,
    layout = :cose,
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

# Calculate smart cutoff using Pearson correlations only
pearson_data2 = filter(r -> r.correlation_method == "pearson", graph_data2)
smart_cutoff_cities = calculate_smart_cutoff(pearson_data2, "Economic Indicators", true, 0.15)

# Create GraphScenario
scenario2 = GraphScenario("Economic Indicators", true, city_names)

graph2 = Graph(:city_network, [scenario2], :city_graph_data;
    title = "City Economic Similarity Network",
    cutoff = smart_cutoff_cities,
    color_cols = [:region],
    default_color_col = :region,
    show_edge_labels = false,
    layout = :circle
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

# Add scenario column
graph_data3[!, :scenario] .= "Social Connections"

# Create GraphScenario
scenario3 = GraphScenario("Social Connections", true, person_names)

graph3 = Graph(:social_network, [scenario3], :social_graph_data;
    title = "Social Network - Connection Patterns",
    cutoff = 0.5,
    color_cols = [:Department, :Team, :Location],
    default_color_col = :Department,
    show_edge_labels = true,
    layout = :concentric
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

# Add scenario column
graph_data4[!, :scenario] .= "Research Collaborations"

# Create GraphScenario
scenario4 = GraphScenario("Research Collaborations", true, researcher_names)

graph4 = Graph(:research_network, [scenario4], :research_graph_data;
    title = "Research Collaboration Network",
    cutoff = 0.4,
    color_cols = [:Institution, :Field],
    default_color_col = :Institution,
    show_edge_labels = false,
    layout = :breadthfirst
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

# Add scenario column
graph_data5[!, :scenario] .= "Product Co-occurrence"

# Create GraphScenario
scenario5 = GraphScenario("Product Co-occurrence", true, product_names)

graph5 = Graph(:product_network, [scenario5], :product_graph_data;
    title = "Product Purchase Co-occurrence Network",
    cutoff = 0.25,
    color_cols = [:Category],
    default_color_col = :Category,
    show_edge_labels = false,
    layout = :grid
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
    <li><strong>Node coloring:</strong> Color by categorical attributes</li>
    <li><strong>Layout selection:</strong> Switch between different layouts</li>
    <li><strong>Drag nodes:</strong> Manually rearrange network</li>
    <li><strong>Zoom & pan:</strong> Explore large networks</li>
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
    :product_graph_data => graph_data5
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
