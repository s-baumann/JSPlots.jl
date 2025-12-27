using StatsBase: corspearman

"""
    CorrelationScenario

Structure to hold a correlation analysis scenario.

# Fields
- `name::String`: Name of this scenario (e.g., "Price Returns", "Volume")
- `pearson::Matrix{Float64}`: Pearson correlation matrix
- `spearman::Matrix{Float64}`: Spearman correlation matrix
- `hc::Clustering.Hclust`: Hierarchical clustering result
- `var_labels::Vector{String}`: Variable names
"""
struct CorrelationScenario
    name::String
    pearson::Matrix{Float64}
    spearman::Matrix{Float64}
    hc::Clustering.Hclust
    var_labels::Vector{String}

    function CorrelationScenario(name::String, pearson::Matrix{Float64},
                                spearman::Matrix{Float64}, hc::Clustering.Hclust,
                                var_labels::Vector{String})
        n = length(var_labels)
        if size(pearson) != (n, n)
            error("Pearson matrix must be $(n)x$(n) to match $(n) variable labels")
        end
        if size(spearman) != (n, n)
            error("Spearman matrix must be $(n)x$(n) to match $(n) variable labels")
        end
        if length(hc.order) != n
            error("Dendrogram order must have $(n) elements to match $(n) variables")
        end
        new(name, pearson, spearman, hc, var_labels)
    end
end

"""
    compute_correlations(df::DataFrame, var_cols::Vector{Symbol})

Convenience function to compute both Pearson and Spearman correlation matrices.

Returns a named tuple `(pearson=..., spearman=...)` containing both correlation matrices.

# Arguments
- `df::DataFrame`: DataFrame containing the variables
- `var_cols::Vector{Symbol}`: Columns to include in correlation analysis

# Example
```julia
cors = compute_correlations(df, [:x1, :x2, :x3, :x4])
# Returns: (pearson = 4×4 Matrix, spearman = 4×4 Matrix)
```
"""
function compute_correlations(df::DataFrame, var_cols::Vector{Symbol})
    # Extract numeric data and remove missing values
    data_matrix = Matrix{Float64}(undef, nrow(df), length(var_cols))

    for (j, col) in enumerate(var_cols)
        data_matrix[:, j] = Float64.(df[!, col])
    end

    # Remove rows with any NaN or missing
    valid_rows = vec(all(!isnan, data_matrix, dims=2))
    clean_data = data_matrix[valid_rows, :]

    if size(clean_data, 1) < 2
        error("Need at least 2 valid observations for correlation")
    end

    # Compute correlations
    pearson = cor(clean_data)
    spearman = corspearman(clean_data)

    return (pearson = pearson, spearman = spearman)
end

"""
    cluster_from_correlation(corr_matrix::Matrix{Float64}; linkage::Symbol=:ward)

Perform hierarchical clustering based on a correlation matrix.

Converts correlation to distance using: dist = sqrt(0.5 * (1 - corr))
Then performs hierarchical clustering with the specified linkage method.

# Arguments
- `corr_matrix::Matrix{Float64}`: Correlation matrix
- `linkage::Symbol`: Linkage method (:ward, :average, :single, :complete). Default: :ward

# Returns
- `Clustering.Hclust`: Hierarchical clustering result containing dendrogram structure

# Example
```julia
cors = compute_correlations(df, [:x1, :x2, :x3])
hc = cluster_from_correlation(cors.pearson, linkage=:ward)
```
"""
function cluster_from_correlation(corr_matrix::Matrix{Float64}; linkage::Symbol=:ward)
    # Convert correlation to distance matrix
    dist_matrix = pairwise(Euclidean(), sqrt.(0.5 .* (1 .- corr_matrix)))

    # Perform hierarchical clustering
    hc = hclust(dist_matrix, linkage=linkage)

    return hc
end

"""
    CorrPlot(chart_title::Symbol, pearson::Matrix{Float64}, spearman::Matrix{Float64},
             hc::Clustering.Hclust, var_labels::Vector{String}; kwargs...)

Create an interactive correlation plot with hierarchical clustering dendrogram.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `pearson::Matrix{Float64}`: Pearson correlation matrix
- `spearman::Matrix{Float64}`: Spearman correlation matrix
- `hc::Clustering.Hclust`: Hierarchical clustering result from `cluster_from_correlation`
- `var_labels::Vector{String}`: Variable names for labeling

# Keyword Arguments
- `title::String`: Chart title (default: `"Correlation Plot with Dendrogram"`)
- `notes::String`: Descriptive text (default: `""`)

# Example
```julia
# Compute correlations and clustering
vars = [:revenue, :cost, :profit, :units]
cors = compute_correlations(df, vars)
hc = cluster_from_correlation(cors.pearson, linkage=:ward)

# Create plot
corrplot = CorrPlot(:correlations, cors.pearson, cors.spearman, hc,
                    string.(vars);
                    title="Business Metrics Correlation")
```

# Interactive Features
- Dendrogram shows hierarchical clustering of variables
- Heatmap displays correlation matrix:
  - Top-right triangle: Pearson correlation coefficients
  - Bottom-left triangle: Spearman (rank) correlation coefficients
- Hover for detailed correlation values
- Variables automatically reordered by clustering for clearer patterns
"""
struct CorrPlot <: JSPlotsType
    chart_title::Symbol
    functional_html::String
    appearance_html::String

    function CorrPlot(chart_title::Symbol,
                      pearson::Matrix{Float64},
                      spearman::Matrix{Float64},
                      hc::Clustering.Hclust,
                      var_labels::Vector{String};
                      title::String = "Correlation Plot with Dendrogram",
                      notes::String = "")

        n = length(var_labels)

        # Validate inputs
        if size(pearson) != (n, n)
            error("Pearson matrix must be $(n)x$(n) to match $(n) variable labels")
        end
        if size(spearman) != (n, n)
            error("Spearman matrix must be $(n)x$(n) to match $(n) variable labels")
        end
        if length(hc.order) != n
            error("Dendrogram order must have $(n) elements to match $(n) variables")
        end

        # Reorder variables according to dendrogram
        ordered_indices = hc.order
        ordered_labels = var_labels[ordered_indices]

        # Reorder correlation matrices
        pearson_ordered = pearson[ordered_indices, ordered_indices]
        spearman_ordered = spearman[ordered_indices, ordered_indices]

        # Build JSON data for correlations (asymmetric matrix)
        corr_data = []
        for i in 1:n
            for j in 1:n
                if i == j
                    push!(corr_data, Dict(
                        "var1" => ordered_labels[i],
                        "var2" => ordered_labels[j],
                        "correlation" => 1.0,
                        "type" => "diagonal"
                    ))
                elseif i < j
                    # Upper triangle: Pearson
                    push!(corr_data, Dict(
                        "var1" => ordered_labels[i],
                        "var2" => ordered_labels[j],
                        "correlation" => pearson_ordered[i, j],
                        "type" => "Pearson"
                    ))
                else
                    # Lower triangle: Spearman
                    push!(corr_data, Dict(
                        "var1" => ordered_labels[i],
                        "var2" => ordered_labels[j],
                        "correlation" => spearman_ordered[i, j],
                        "type" => "Spearman"
                    ))
                end
            end
        end

        # Extract dendrogram structure
        # Build merge tree to draw dendrogram
        dendro_data = extract_dendrogram_structure(hc, ordered_labels)

        chart_title_str = string(chart_title)

        # Build appearance HTML
        appearance_html = """
        <div class="corrplot-container">
            <h2>$title</h2>
            <p>$notes</p>
            <div id="dendrogram_$chart_title_str" style="width: 100%; height: 300px;"></div>
            <div id="corrmatrix_$chart_title_str" style="width: 100%; height: 600px;"></div>
        </div>
        """

        # Build functional HTML (JavaScript)
        corr_json = JSON.json(corr_data)
        dendro_json = JSON.json(dendro_data)
        labels_json = JSON.json(ordered_labels)

        functional_html = """
        (function() {
            const corrData = $corr_json;
            const dendroData = $dendro_json;
            const labels = $labels_json;
            const n = labels.length;

            // Build correlation matrix for heatmap
            const zValues = [];
            const textValues = [];
            const hoverText = [];

            for (let i = 0; i < n; i++) {
                zValues[i] = [];
                textValues[i] = [];
                hoverText[i] = [];
                for (let j = 0; j < n; j++) {
                    const item = corrData.find(d => d.var1 === labels[i] && d.var2 === labels[j]);
                    const corr = item.correlation;
                    zValues[i][j] = corr;

                    if (item.type === 'diagonal') {
                        textValues[i][j] = '1.00';
                        hoverText[i][j] = labels[i];
                    } else if (item.type === 'Pearson') {
                        textValues[i][j] = 'P: ' + corr.toFixed(2);
                        hoverText[i][j] = labels[i] + ' vs ' + labels[j] + '<br>Pearson: ' + corr.toFixed(3);
                    } else {
                        textValues[i][j] = 'S: ' + corr.toFixed(2);
                        hoverText[i][j] = labels[i] + ' vs ' + labels[j] + '<br>Spearman: ' + corr.toFixed(3);
                    }
                }
            }

            // Create correlation heatmap
            const heatmapTrace = {
                z: zValues,
                x: labels,
                y: labels,
                type: 'heatmap',
                colorscale: [
                    [0, '#ff0000'],    // -1: red
                    [0.5, '#ffffff'],  //  0: white
                    [1, '#0000ff']     //  1: blue
                ],
                zmin: -1,
                zmax: 1,
                text: hoverText,
                hovertemplate: '%{text}<extra></extra>',
                colorbar: {
                    title: 'Correlation',
                    titleside: 'right'
                }
            };

            const heatmapLayout = {
                xaxis: { side: 'bottom', tickangle: -45 },
                yaxis: { autorange: 'reversed' },
                annotations: [],
                margin: { l: 150, r: 50, b: 150, t: 50 }
            };

            // Add text annotations to cells
            for (let i = 0; i < n; i++) {
                for (let j = 0; j < n; j++) {
                    heatmapLayout.annotations.push({
                        x: labels[j],
                        y: labels[i],
                        text: textValues[i][j],
                        showarrow: false,
                        font: {
                            size: 10,
                            color: Math.abs(zValues[i][j]) > 0.5 ? 'white' : 'black'
                        }
                    });
                }
            }

            Plotly.newPlot('corrmatrix_$chart_title_str', [heatmapTrace], heatmapLayout, {responsive: true});

            // Draw dendrogram
            if (dendroData.shapes && dendroData.shapes.length > 0) {
                const leafTrace = {
                    x: dendroData.leafPositions,
                    y: Array(n).fill(0),
                    mode: 'text',
                    type: 'scatter',
                    text: dendroData.leafLabels,
                    textposition: 'bottom center',
                    textfont: { size: 10 },
                    hoverinfo: 'text',
                    showlegend: false
                };

                const dendroLayout = {
                    title: 'Hierarchical Clustering Dendrogram',
                    xaxis: {
                        visible: false,
                        range: [-0.5, n - 0.5]
                    },
                    yaxis: {
                        title: 'Height',
                        range: [0, dendroData.maxHeight * 1.15]
                    },
                    margin: { l: 80, r: 50, b: 120, t: 50 },
                    showlegend: false,
                    shapes: dendroData.shapes
                };

                Plotly.newPlot('dendrogram_$chart_title_str', [leafTrace], dendroLayout, {responsive: true});
            }
        })();
        """

        new(chart_title, functional_html, appearance_html)
    end

    # Simple inner constructor for direct construction (used by advanced CorrPlot)
    function CorrPlot(chart_title::Symbol, functional_html::String, appearance_html::String)
        new(chart_title, functional_html, appearance_html)
    end
end

"""
Extract dendrogram structure from Hclust object for plotting.
"""
function extract_dendrogram_structure(hc::Clustering.Hclust, labels::Vector{String})
    n = length(labels)

    # Map from cluster index to x-position
    # Initial leaves are at positions 0, 1, 2, ..., n-1 (in dendrogram order)
    positions = Dict{Int, Float64}()
    for (i, leaf_idx) in enumerate(hc.order)
        positions[leaf_idx] = Float64(i - 1)
    end

    # Track heights for each cluster
    heights = Dict{Int, Float64}()
    for i in 1:n
        heights[i] = 0.0
    end

    shapes = []
    max_height = 0.0

    # Process merges
    for (merge_idx, (left, right)) in enumerate(zip(hc.merges[:, 1], hc.merges[:, 2]))
        # Get indices (negative means leaf, positive means previous merge)
        left_idx = left < 0 ? -left : n + left
        right_idx = right < 0 ? -right : n + right

        x1 = positions[left_idx]
        x2 = positions[right_idx]
        y1 = heights[left_idx]
        y2 = heights[right_idx]

        new_height = hc.heights[merge_idx]
        max_height = max(max_height, new_height)
        new_x = (x1 + x2) / 2

        # Draw U-shaped connection
        # Left vertical line
        push!(shapes, Dict(
            "type" => "line",
            "x0" => x1, "y0" => y1,
            "x1" => x1, "y1" => new_height,
            "line" => Dict("color" => "#636efa", "width" => 2)
        ))

        # Horizontal line
        push!(shapes, Dict(
            "type" => "line",
            "x0" => x1, "y0" => new_height,
            "x1" => x2, "y1" => new_height,
            "line" => Dict("color" => "#636efa", "width" => 2)
        ))

        # Right vertical line
        push!(shapes, Dict(
            "type" => "line",
            "x0" => x2, "y0" => new_height,
            "x1" => x2, "y1" => y2,
            "line" => Dict("color" => "#636efa", "width" => 2)
        ))

        # Store new cluster position and height
        new_cluster_idx = n + merge_idx
        positions[new_cluster_idx] = new_x
        heights[new_cluster_idx] = new_height
    end

    # Build leaf positions for plotting
    leaf_positions = collect(0:(n-1))
    leaf_labels = labels

    return Dict(
        "shapes" => shapes,
        "maxHeight" => max_height,
        "leafPositions" => leaf_positions,
        "leafLabels" => leaf_labels
    )
end

# Dependencies function for CorrPlot
function dependencies(x::CorrPlot)
    return []  # Uses Plotly.js which is already included in the base template
end

# Export the new functions and structs
export CorrelationScenario, compute_correlations, cluster_from_correlation
