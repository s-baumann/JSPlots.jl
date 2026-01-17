# t-SNE Plot Examples
# This file demonstrates the TSNEPlot visualization for dimensionality reduction

using JSPlots
using DataFrames
using Random
using LinearAlgebra

println("Creating TSNEPlot examples...")

# ============================================================================
# Example 1: Stock Similarity with Feature Columns
# ============================================================================
# Demonstrates using feature columns to compute distances in the browser

Random.seed!(42)

# Create synthetic stock data with various features
n_stocks = 50
sectors = ["Technology", "Finance", "Healthcare", "Consumer", "Energy"]
countries = ["US", "UK", "JP", "DE", "FR"]

stock_df = DataFrame(
    stock = ["STOCK_$(lpad(i, 2, '0'))" for i in 1:n_stocks],
    sector = [sectors[rand(1:length(sectors))] for _ in 1:n_stocks],
    country = [countries[rand(1:length(countries))] for _ in 1:n_stocks],
    returns_volatility = rand(n_stocks) .* 0.3 .+ 0.1,  # 10-40% volatility
    market_cap_log = rand(n_stocks) .* 4 .+ 8,  # Log market cap 8-12
    pe_ratio = rand(n_stocks) .* 30 .+ 5,  # P/E ratio 5-35
    dividend_yield = rand(n_stocks) .* 5,  # Dividend yield 0-5%
    beta = rand(n_stocks) .* 1.5 .+ 0.5  # Beta 0.5-2.0
)

# Add some cluster structure - stocks in same sector have similar features
for i in 1:nrow(stock_df)
    sector = stock_df.sector[i]
    if sector == "Technology"
        stock_df.returns_volatility[i] += 0.1
        stock_df.pe_ratio[i] += 10
    elseif sector == "Finance"
        stock_df.dividend_yield[i] += 1.5
        stock_df.beta[i] += 0.3
    elseif sector == "Healthcare"
        stock_df.pe_ratio[i] += 5
        stock_df.market_cap_log[i] += 0.5
    elseif sector == "Energy"
        stock_df.returns_volatility[i] += 0.05
        stock_df.dividend_yield[i] += 2
    end
end

chart1 = TSNEPlot(:stock_tsne, stock_df, :stock_data;
    entity_col = :stock,
    feature_cols = [:returns_volatility, :market_cap_log, :pe_ratio, :dividend_yield, :beta],
    color_cols = [:sector, :country],
    tooltip_cols = [:returns_volatility, :pe_ratio, :dividend_yield, :beta],
    perplexity = 15.0,
    learning_rate = 200.0,
    title = "Example 1: Stock Similarity (Feature-based t-SNE)",
    notes = "Stocks with similar financial characteristics should cluster together. Color by sector to see if the algorithm detects industry clusters."
)

# ============================================================================
# Example 2: Using a Pre-computed Distance/Correlation Matrix
# ============================================================================
# Demonstrates the distance matrix input format

# Create a correlation-based distance matrix between assets
n_assets = 25
asset_names = ["ASSET_$(lpad(i, 2, '0'))" for i in 1:n_assets]

# Generate synthetic correlation matrix with block structure
true_corr = Matrix{Float64}(I, n_assets, n_assets)
# Create 5 clusters of 5 assets each
for cluster in 1:5
    start_idx = (cluster - 1) * 5 + 1
    end_idx = cluster * 5
    for i in start_idx:end_idx
        for j in start_idx:end_idx
            if i != j
                true_corr[i, j] = 0.6 + rand() * 0.3  # High correlation within cluster
            end
        end
    end
end
# Add some cross-cluster correlations
for i in 1:n_assets
    for j in (i+1):n_assets
        if true_corr[i, j] == 0  # Not same cluster
            true_corr[i, j] = rand() * 0.3 - 0.1  # Low correlation between clusters
            true_corr[j, i] = true_corr[i, j]
        end
    end
end

# Convert correlation to distance: distance = 1 - |correlation|
distance_rows = []
for i in 1:n_assets
    for j in (i+1):n_assets
        push!(distance_rows, (
            entity1 = asset_names[i],
            entity2 = asset_names[j],
            distance = 1 - abs(true_corr[i, j])
        ))
    end
end
distance_df = DataFrame(distance_rows)

chart2 = TSNEPlot(:asset_correlation_tsne, distance_df, :distance_data;
    distance_matrix = true,
    perplexity = 8.0,
    learning_rate = 150.0,
    title = "Example 2: Asset Correlation Clusters (Distance Matrix)",
    notes = "Assets are positioned based on correlation distances. Highly correlated assets should cluster together. The underlying data has 5 distinct correlation clusters."
)

# ============================================================================
# Example 3: World Cities with Geographic and Economic Features
# ============================================================================

cities_df = DataFrame(
    city = ["New York", "London", "Tokyo", "Paris", "Singapore",
            "Hong Kong", "Sydney", "Toronto", "Frankfurt", "Dubai",
            "Shanghai", "Mumbai", "Sao Paulo", "Mexico City", "Seoul",
            "Los Angeles", "Chicago", "Boston", "San Francisco", "Seattle"],
    region = ["North America", "Europe", "Asia", "Europe", "Asia",
              "Asia", "Oceania", "North America", "Europe", "Middle East",
              "Asia", "Asia", "South America", "North America", "Asia",
              "North America", "North America", "North America", "North America", "North America"],
    financial_center_rank = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    population_millions = [8.3, 9.0, 14.0, 2.1, 5.5, 7.5, 5.3, 2.9, 0.75, 3.3,
                          26.0, 20.0, 12.0, 21.0, 10.0, 4.0, 2.7, 0.7, 0.9, 0.7],
    gdp_per_capita = [75000, 55000, 42000, 45000, 65000, 50000, 60000, 52000, 55000, 45000,
                     25000, 7000, 15000, 10000, 35000, 70000, 65000, 80000, 95000, 85000],
    timezone_offset = [-5, 0, 9, 1, 8, 8, 10, -5, 1, 4, 8, 5.5, -3, -6, 9, -8, -6, -5, -8, -8],
    english_proficiency = [1.0, 1.0, 0.4, 0.6, 0.9, 0.85, 1.0, 1.0, 0.7, 0.8, 0.3, 0.6, 0.3, 0.3, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0]
)

chart3 = TSNEPlot(:cities_tsne, cities_df, :cities_data;
    entity_col = :city,
    feature_cols = [:financial_center_rank, :population_millions, :gdp_per_capita, :timezone_offset, :english_proficiency],
    color_cols = [:region],
    tooltip_cols = [:population_millions, :gdp_per_capita, :financial_center_rank],
    perplexity = 5.0,
    learning_rate = 100.0,
    title = "Example 3: World Financial Centers (Multi-feature)",
    notes = "Cities positioned by financial characteristics, population, GDP, and timezone. Color by region to see geographic patterns."
)

# ============================================================================
# Example 4: Random High-Dimensional Data with Known Clusters
# ============================================================================
# Tests the algorithm on data with clear cluster structure

Random.seed!(123)
n_points_per_cluster = 20
n_clusters = 4
n_dims = 10

# Generate clustered high-dimensional data
cluster_centers = [randn(n_dims) .* 5 for _ in 1:n_clusters]
cluster_labels = String[]
point_data = []

for (c, center) in enumerate(cluster_centers)
    for i in 1:n_points_per_cluster
        point_features = center .+ randn(n_dims) .* 0.5  # Points near cluster center
        point_dict = Dict{Symbol, Any}(
            :point_id => "C$(c)_P$(i)",
            :cluster => "Cluster_$(c)"
        )
        for d in 1:n_dims
            point_dict[Symbol("dim_$(d)")] = point_features[d]
        end
        push!(point_data, point_dict)
    end
end

highdim_df = DataFrame(point_data)

chart4 = TSNEPlot(:highdim_tsne, highdim_df, :highdim_data;
    entity_col = :point_id,
    feature_cols = [Symbol("dim_$(d)") for d in 1:n_dims],
    color_cols = [:cluster],
    perplexity = 10.0,
    learning_rate = 200.0,
    title = "Example 4: High-Dimensional Clusters (10D -> 2D)",
    notes = "80 points in 4 distinct 10-dimensional clusters. t-SNE should clearly separate the clusters in 2D."
)

# ============================================================================
# Example 5: Minimal Example - Few Points
# ============================================================================
# Simple example for testing basic functionality

minimal_df = DataFrame(
    item = ["A", "B", "C", "D", "E", "F"],
    category = ["Group1", "Group1", "Group2", "Group2", "Group3", "Group3"],
    feature1 = [1.0, 1.2, 5.0, 5.5, 9.0, 9.2],
    feature2 = [2.0, 2.1, 6.0, 5.8, 1.0, 1.3]
)

chart5 = TSNEPlot(:minimal_tsne, minimal_df, :minimal_data;
    entity_col = :item,
    feature_cols = [:feature1, :feature2],
    color_cols = [:category],
    tooltip_cols = [:feature1, :feature2],
    perplexity = 2.0,  # Low perplexity for few points
    learning_rate = 50.0,
    title = "Example 5: Minimal Example (6 points)",
    notes = "Simple test case with 6 points in 3 obvious groups. Good for testing drag-and-drop and basic algorithm behavior."
)

# ============================================================================
# Create Pages
# ============================================================================

page1 = JSPlotPage(
    Dict{Symbol, Any}(:stock_data => stock_df),
    [chart1];
    tab_title = "Stock Similarity",
    page_header = "t-SNE: Stock Feature Similarity",
    dataformat = :csv_external
)

page2 = JSPlotPage(
    Dict{Symbol, Any}(:distance_data => distance_df),
    [chart2];
    tab_title = "Correlation Clusters",
    page_header = "t-SNE: Asset Correlation Distances",
    dataformat = :csv_external
)

page3 = JSPlotPage(
    Dict{Symbol, Any}(:cities_data => cities_df),
    [chart3];
    tab_title = "World Cities",
    page_header = "t-SNE: Financial Centers",
    dataformat = :csv_external
)

page4 = JSPlotPage(
    Dict{Symbol, Any}(:highdim_data => highdim_df),
    [chart4];
    tab_title = "High-Dimensional Clusters",
    page_header = "t-SNE: 10D to 2D Projection",
    dataformat = :csv_external
)

page5 = JSPlotPage(
    Dict{Symbol, Any}(:minimal_data => minimal_df),
    [chart5];
    tab_title = "Minimal Example",
    page_header = "t-SNE: Simple Test Case",
    dataformat = :csv_external
)

# Create multi-page report
report = Pages(
    [TextBlock("""
    <h1>t-SNE Visualization Examples</h1>
    <p>These examples demonstrate the interactive t-SNE visualization capabilities of JSPlots.jl.</p>
    <p><strong>t-SNE (t-Distributed Stochastic Neighbor Embedding)</strong> is a dimensionality reduction
    technique that maps high-dimensional data to 2D while preserving local structure.</p>
    <h3>Interactive Features:</h3>
    <ul>
        <li><strong>Randomize:</strong> Reset to random initial positions</li>
        <li><strong>Step:</strong> Run one iteration of the algorithm</li>
        <li><strong>Run to Convergence:</strong> Automatically iterate until the specified threshold</li>
        <li><strong>Drag nodes:</strong> Manually reposition any point, then continue optimization</li>
        <li><strong>Color by:</strong> Change node coloring without affecting positions</li>
        <li><strong>Perplexity:</strong> Controls local vs global structure (lower = more local)</li>
        <li><strong>Learning Rate:</strong> Controls step size (higher = faster but less stable)</li>
    </ul>
    """)],
    [page1, page2, page3, page4, page5];
    tab_title = "t-SNE Examples",
    page_header = "t-SNE Visualization Examples",
    dataformat = :csv_external
)

# Generate HTML
output_path = "generated_html_examples/tsneplot_examples.html"
create_html(report, output_path)

println("TSNEPlot examples created at: $output_path")
println("Done!")
