using StatsBase: corspearman
using Clustering: hclust, cutree
using Distances: pairwise, Euclidean

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
    prepare_corrplot_data(pearson::AbstractMatrix, spearman::AbstractMatrix,
                          var_labels::Vector; scenario::String="default")

Helper function to create the correlation DataFrame needed for CorrPlot.

Returns a DataFrame with columns:
- `node1::String`: First variable name
- `node2::String`: Second variable name
- `strength::Float64`: Correlation coefficient (-1 to 1)
- `scenario::String`: Scenario name
- `correlation_method::String`: "pearson" or "spearman"

# Example
```julia
cors = compute_correlations(df, [:x1, :x2, :x3])
corr_df = prepare_corrplot_data(cors.pearson, cors.spearman, [:x1, :x2, :x3])
corrplot = CorrPlot(:corr_plot, corr_df, :corr_data)
```
"""
function prepare_corrplot_data(pearson::AbstractMatrix{<:Real},
                               spearman::AbstractMatrix{<:Real},
                               var_labels::Union{Vector{String}, Vector{Symbol}};
                               scenario::String="default")
    # Convert to standard types
    pearson_mat = Matrix{Float64}(pearson)
    spearman_mat = Matrix{Float64}(spearman)
    labels = string.(var_labels)
    n = length(labels)

    # Build DataFrame - only store unique pairs (upper triangle excluding diagonal)
    node1_vec = String[]
    node2_vec = String[]
    strength_vec = Float64[]
    scenario_vec = String[]
    correlation_method_vec = String[]

    for i in 1:n
        for j in (i+1):n  # Only upper triangle, excluding diagonal
            # Pearson
            push!(node1_vec, labels[i])
            push!(node2_vec, labels[j])
            push!(strength_vec, pearson_mat[i, j])
            push!(scenario_vec, scenario)
            push!(correlation_method_vec, "pearson")

            # Spearman
            push!(node1_vec, labels[i])
            push!(node2_vec, labels[j])
            push!(strength_vec, spearman_mat[i, j])
            push!(scenario_vec, scenario)
            push!(correlation_method_vec, "spearman")
        end
    end

    return DataFrame(
        node1 = node1_vec,
        node2 = node2_vec,
        strength = strength_vec,
        scenario = scenario_vec,
        correlation_method = correlation_method_vec
    )
end

"""
    compute_dendrogram_data(corr_matrix::Matrix{Float64}, var_labels::Vector{String})

Compute variable orderings and dendrogram tree structures from hierarchical clustering.

Returns a Dict with keys :ward, :average, :single, :complete, each containing:
- ordering: Vector of variable names in dendrogram order
- tree: Tree structure for drawing dendrogram (merges, heights)
"""
function compute_dendrogram_data(corr_matrix::Matrix{Float64}, var_labels::Vector{String})
    n = size(corr_matrix, 1)

    if n < 2
        # Return trivial data if less than 2 variables
        trivial_tree = Dict("merges" => [], "heights" => [], "labels" => var_labels, "order" => collect(1:n))
        return Dict(
            :ward => Dict("ordering" => var_labels, "tree" => trivial_tree),
            :average => Dict("ordering" => var_labels, "tree" => trivial_tree),
            :single => Dict("ordering" => var_labels, "tree" => trivial_tree),
            :complete => Dict("ordering" => var_labels, "tree" => trivial_tree)
        )
    end

    # Convert correlation to distance: distance = sqrt(0.5 * (1 - abs(cor)))
    # This ensures highly correlated items are close (low distance)
    dist_matrix = zeros(n, n)
    for i in 1:n
        for j in 1:n
            dist_matrix[i, j] = sqrt(max(0.0, 0.5 * (1 - abs(corr_matrix[i, j]))))
        end
    end

    # Perform hierarchical clustering with different linkage methods
    dendro_data = Dict{Symbol, Dict{String, Any}}()

    for linkage in [:ward, :average, :single, :complete]
        try
            # Perform clustering
            hc = hclust(dist_matrix, linkage=linkage, branchorder=:optimal)

            # Extract leaf order
            order_indices = hc.order
            ordering = var_labels[order_indices]

            # Build tree structure for JavaScript
            # Convert merge matrix to JSON-friendly format
            # hc.merges is an (n-1) x 2 matrix where each row shows which two clusters merge
            # Negative indices are leaves (original items), positive are clusters
            merges = []
            for i in 1:size(hc.merges, 1)
                push!(merges, [hc.merges[i, 1], hc.merges[i, 2]])
            end

            tree = Dict(
                "merges" => merges,
                "heights" => collect(hc.heights),
                "labels" => var_labels,
                "order" => collect(hc.order)
            )

            dendro_data[linkage] = Dict("ordering" => ordering, "tree" => tree)
        catch e
            # If clustering fails, use original order
            @warn "Clustering with $linkage linkage failed: $e"
            trivial_tree = Dict("merges" => [], "heights" => [], "labels" => var_labels, "order" => collect(1:n))
            dendro_data[linkage] = Dict("ordering" => var_labels, "tree" => trivial_tree)
        end
    end

    return dendro_data
end

"""
    CorrPlot(chart_title::Symbol, corr_df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive correlation plot with hierarchical clustering dendrogram.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `corr_df::DataFrame`: Correlation data (will be validated)
- `data_label::Symbol`: Label for the correlation data in external storage

# Keyword Arguments
- `title::String`: Chart title (default: `"Correlation Plot with Dendrogram"`)
- `notes::String`: Descriptive text (default: `""`)
- `scenario_col::Union{Symbol, Nothing}`: Column name for scenarios (default: `nothing`)
- `default_scenario::Union{String, Nothing}`: Name of default scenario (default: first scenario)
- `default_variables::Union{Vector{String}, Nothing}`: Default selected variables (default: all)
- `allow_manual_order::Bool`: Enable manual drag-drop reordering (default: `true`)

# Data Format
The correlation DataFrame should have columns:
- `node1::String`: First variable in pair
- `node2::String`: Second variable in pair
- `strength::Float64`: Correlation coefficient
- `correlation_method::String`: "pearson" or "spearman"
- Optional: scenario column if specified via `scenario_col`

# Example
```julia
# Compute correlations
vars = [:revenue, :cost, :profit, :units]
cors = compute_correlations(df, vars)

# Prepare data
corr_df = prepare_corrplot_data(cors.pearson, cors.spearman, vars)

# Create plot
corrplot = CorrPlot(:correlations, corr_df, :corr_data;
                    title="Business Metrics Correlation")

# Create page
page = JSPlotPage(Dict(:corr_data => corr_df), [corrplot])
```

# Interactive Features
- Variable selection: Multi-select to choose which variables to display
- Correlation method: Switch between Pearson and Spearman
- Dendrogram ordering: Hierarchical clustering performed in browser
- Linkage method: Choose clustering linkage (ward, average, single, complete)
- Manual ordering: Drag-drop to reorder variables (shows only selected variables)
- Alphabetical ordering: Sort variables alphabetically
- Heatmap displays:
  - Upper-right triangle: Pearson correlation coefficients
  - Lower-left triangle: Spearman (rank) correlation coefficients
- Hover for detailed correlation values
"""
struct CorrPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function CorrPlot(chart_title::Symbol,
                      corr_df::DataFrame,
                      data_label::Symbol;
                      title::String = "Correlation Plot with Dendrogram",
                      notes::String = "",
                      scenario_col::Union{Symbol, Nothing} = nothing,
                      default_scenario::Union{String, Nothing} = nothing,
                      default_variables::Union{Vector{String}, Nothing} = nothing,
                      allow_manual_order::Bool = true)

        # Validate DataFrame structure
        required_cols = [:node1, :node2, :strength, :correlation_method]
        df_col_names = Symbol.(names(corr_df))
        for col in required_cols
            if !(col in df_col_names)
                error("DataFrame must have column: $col")
            end
        end

        # Extract scenarios
        scenarios = if !isnothing(scenario_col)
            if !(scenario_col in df_col_names)
                error("Scenario column $scenario_col not found in DataFrame")
            end
            unique(corr_df[!, scenario_col])
        else
            ["default"]
        end

        # Determine default scenario
        default_scenario_name = if isnothing(default_scenario)
            scenarios[1]
        else
            if !(default_scenario in scenarios)
                error("Default scenario '$default_scenario' not found in data")
            end
            default_scenario
        end

        # Extract all variable names
        all_vars = unique(vcat(corr_df.node1, corr_df.node2))

        # Determine default variables
        default_vars = if isnothing(default_variables)
            all_vars
        else
            # Validate default variables exist
            for var in default_variables
                if !(var in all_vars)
                    error("Default variable '$var' not found in data")
                end
            end
            default_variables
        end

        chart_title_str = string(chart_title)

        # Compute hierarchical clustering orderings for each scenario/method combination
        dendro_orderings = Dict{String, Dict{String, Dict{Symbol, Dict{String, Any}}}}()

        for scenario in scenarios
            dendro_orderings[scenario] = Dict{String, Dict{Symbol, Dict{String, Any}}}()

            # Filter data for this scenario
            scenario_df = if !isnothing(scenario_col)
                filter(row -> row[scenario_col] == scenario, corr_df)
            else
                corr_df
            end

            # Compute for both pearson and spearman
            for corr_method in ["pearson", "spearman"]
                # Filter for this correlation method
                method_df = filter(row -> row.correlation_method == corr_method, scenario_df)

                if nrow(method_df) == 0
                    # No data for this combination, use default order
                    n = length(all_vars)
                    trivial_tree = Dict("merges" => [], "heights" => [], "labels" => all_vars, "order" => collect(1:n))
                    dendro_orderings[scenario][corr_method] = Dict(
                        :ward => Dict("ordering" => all_vars, "tree" => trivial_tree),
                        :average => Dict("ordering" => all_vars, "tree" => trivial_tree),
                        :single => Dict("ordering" => all_vars, "tree" => trivial_tree),
                        :complete => Dict("ordering" => all_vars, "tree" => trivial_tree)
                    )
                    continue
                end

                # Reconstruct correlation matrix from edge list
                var_indices = Dict(v => i for (i, v) in enumerate(all_vars))
                n = length(all_vars)
                corr_matrix = Matrix{Float64}(I, n, n)  # Initialize with identity matrix

                for row in eachrow(method_df)
                    i = var_indices[row.node1]
                    j = var_indices[row.node2]
                    corr_matrix[i, j] = row.strength
                    corr_matrix[j, i] = row.strength  # Symmetric
                end

                # Compute dendrogram data (orderings and tree structures)
                dendro_orderings[scenario][corr_method] = compute_dendrogram_data(corr_matrix, all_vars)
            end
        end

        # Build appearance HTML
        appearance_html = build_corrplot_appearance_html(
            chart_title_str, title, notes, scenarios, scenario_col,
            default_scenario_name, allow_manual_order
        )

        # Build functional HTML
        functional_html = build_corrplot_functional_html(
            chart_title_str, data_label, scenarios, scenario_col,
            default_scenario_name, default_vars, allow_manual_order, dendro_orderings
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

# Add dependencies function for CorrPlot
dependencies(cp::CorrPlot) = [cp.data_label]
js_dependencies(::CorrPlot) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)

function build_corrplot_appearance_html(chart_title_str, title, notes, scenarios,
                                        scenario_col, default_scenario_name, allow_manual_order)

    # Scenario selector (if scenarios exist)
    scenario_selector_html = if !isnothing(scenario_col) && length(scenarios) > 1
        options = join(["""<option value="$s" $(s == default_scenario_name ? "selected" : "")>$s</option>"""
                       for s in scenarios], "\n                ")
        """
        <div style="margin-bottom: 15px;">
            <label for="scenario_select_$chart_title_str"><strong>Scenario:</strong></label>
            <select id="scenario_select_$chart_title_str" onchange="updateChart_$chart_title_str()">
                $options
            </select>
        </div>
        """
    else
        ""
    end

    # Variable selector
    variable_selector_html = """
    <div style="margin-bottom: 15px;">
        <label for="var_select_$chart_title_str"><strong>Select Variables:</strong></label><br>
        <select id="var_select_$chart_title_str" multiple size="8" style="width: 300px;" onchange="updateChart_$chart_title_str()">
        </select>
    </div>
    """

    # Correlation method selector (for dendrogram ordering)
    corr_method_html = """
    <div style="margin-bottom: 15px;">
        <label for="corr_method_select_$chart_title_str"><strong>Correlation method for dendrogram:</strong></label>
        <select id="corr_method_select_$chart_title_str" onchange="updateChart_$chart_title_str()">
            <option value="pearson" selected>Pearson</option>
            <option value="spearman">Spearman</option>
        </select>
    </div>
    """

    # Order mode selector
    order_toggle_html = if allow_manual_order
        """
        <div style="margin-bottom: 15px;">
            <label for="order_mode_$chart_title_str"><strong>Variable ordering:</strong></label>
            <select id="order_mode_$chart_title_str" onchange="updateChart_$chart_title_str()">
                <option value="dendrogram" selected>Order by dendrogram</option>
                <option value="alphabetical">Order alphabetically</option>
                <option value="manual">Order manually</option>
            </select>
        </div>
        """
    else
        ""
    end

    # Linkage method selector (for dendrogram) - shown only when dendrogram ordering is selected
    linkage_html = """
    <div id="linkage_container_$chart_title_str" style="margin-bottom: 15px; display: none;">
        <label for="linkage_select_$chart_title_str"><strong>Clustering linkage:</strong></label>
        <select id="linkage_select_$chart_title_str" onchange="updateChart_$chart_title_str()">
            <option value="ward" selected>Ward</option>
            <option value="average">Average</option>
            <option value="single">Single</option>
            <option value="complete">Complete</option>
        </select>
    </div>
    """

    # Manual order container
    manual_order_html = if allow_manual_order
        """
        <div id="manual_order_$chart_title_str" style="margin-bottom: 15px; display: none;">
            <label><strong>Drag to Reorder:</strong></label>
            <div id="sortable_vars_$chart_title_str" style="padding: 10px; border: 1px solid #ccc; min-height: 50px;">
            </div>
        </div>
        """
    else
        ""
    end

    # Styles for manual ordering
    manual_order_styles = if allow_manual_order
        """
        <style>
        #sortable_vars_$chart_title_str .sortable-item {
            padding: 5px 10px;
            margin: 2px;
            background-color: #f0f0f0;
            border: 1px solid #ccc;
            cursor: move;
            display: inline-block;
        }
        #sortable_vars_$chart_title_str .sortable-item:hover {
            background-color: #e0e0e0;
        }
        </style>
        """
    else
        ""
    end

    # Include external libraries (just Sortable for manual ordering)
    libraries = allow_manual_order ? """<script src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/Sortable.min.js"></script>""" : ""

    return """
    $libraries
    <div class="corrplot-container">
        <h2>$title</h2>
        <p>$notes</p>
        $scenario_selector_html
        $variable_selector_html
        $corr_method_html
        $order_toggle_html
        $linkage_html
        $manual_order_html
        <div id="dendrogram_$chart_title_str" style="width: 100%; height: 400px;"></div>
        <div id="corrmatrix_$chart_title_str" style="width: 100%; height: 600px;"></div>
    </div>
    $manual_order_styles
    """
end

function build_corrplot_functional_html(chart_title_str, data_label, scenarios,
                                        scenario_col, default_scenario_name,
                                        default_vars, allow_manual_order, dendro_orderings)

    has_scenarios = !isnothing(scenario_col) && length(scenarios) > 1
    scenarios_json = JSON.json(scenarios)
    default_vars_json = JSON.json(default_vars)
    dendro_orderings_json = JSON.json(dendro_orderings)

    return """
    (function() {
        const scenarios = $scenarios_json;
        const hasScenarios = $has_scenarios;
        let currentScenario = "$default_scenario_name";
        let selectedVars = $default_vars_json;
        let manualOrder = [];
        let corrDataRaw = null;
        let allVars = [];
        const dendroOrderings = $dendro_orderings_json;

        // Load correlation data
        loadDataset('$(data_label)').then(function(data) {
            corrDataRaw = data;
            allVars = [...new Set(corrDataRaw.map(d => d.node1).concat(corrDataRaw.map(d => d.node2)))].sort();
            populateVarSelector_$chart_title_str();
            updateChart_$chart_title_str();
        }).catch(function(error) {
            console.error('Failed to load correlation data:', error);
            document.getElementById('corrmatrix_$chart_title_str').innerHTML =
                '<p style="color: red;">Error loading correlation data: ' + error.message + '</p>';
        });

        function populateVarSelector_$chart_title_str() {
            const select = document.getElementById('var_select_$chart_title_str');
            select.innerHTML = '';
            allVars.forEach(v => {
                const option = document.createElement('option');
                option.value = v;
                option.text = v;
                option.selected = selectedVars.includes(v);
                select.appendChild(option);
            });
        }

        function initializeSortable_$chart_title_str() {
            const container = document.getElementById('sortable_vars_$chart_title_str');
            if (!container) return;

            container.innerHTML = '';

            // Only show currently selected variables in manual order
            const varsToShow = manualOrder.length > 0 ?
                manualOrder.filter(v => selectedVars.includes(v)) :
                selectedVars;

            varsToShow.forEach(v => {
                const div = document.createElement('div');
                div.className = 'sortable-item';
                div.textContent = v;
                div.setAttribute('data-var', v);
                container.appendChild(div);
            });

            if (typeof Sortable !== 'undefined') {
                Sortable.create(container, {
                    animation: 150,
                    onEnd: function() {
                        manualOrder = Array.from(container.children).map(el => el.getAttribute('data-var'));
                        updateChart_$chart_title_str();
                    }
                });
            }
        }

        window.updateChart_$chart_title_str = function() {
            if (!corrDataRaw || corrDataRaw.length === 0) {
                console.warn('Correlation data not loaded yet');
                return;
            }

            // Update scenario (if applicable)
            if (hasScenarios) {
                const scenarioSelect = document.getElementById('scenario_select_$chart_title_str');
                if (scenarioSelect) {
                    currentScenario = scenarioSelect.value;
                }
            }

            // Update selected variables
            const varSelect = document.getElementById('var_select_$chart_title_str');
            const newSelectedVars = Array.from(varSelect.selectedOptions).map(opt => opt.value);

            // Check if new variables were added
            const addedVars = newSelectedVars.filter(v => !selectedVars.includes(v));
            if (addedVars.length > 0 && manualOrder.length > 0) {
                // Add new variables to end of manual order
                addedVars.forEach(v => {
                    if (!manualOrder.includes(v)) {
                        manualOrder.push(v);
                    }
                });
            }

            selectedVars = newSelectedVars;

            if (selectedVars.length < 2) {
                console.warn('Select at least 2 variables');
                return;
            }

            // Get correlation method
            const corrMethod = document.getElementById('corr_method_select_$chart_title_str').value;

            // Get order mode
            const orderModeSelect = document.getElementById('order_mode_$chart_title_str');
            const orderMode = orderModeSelect ? orderModeSelect.value : 'dendrogram';

            // Show/hide linkage selector
            const linkageContainer = document.getElementById('linkage_container_$chart_title_str');
            if (linkageContainer) {
                linkageContainer.style.display = (orderMode === 'dendrogram') ? 'block' : 'none';
            }

            // Show/hide manual ordering UI
            const manualDiv = document.getElementById('manual_order_$chart_title_str');
            if (manualDiv) {
                manualDiv.style.display = (orderMode === 'manual') ? 'block' : 'none';
            }

            if (orderMode === 'manual') {
                initializeSortable_$chart_title_str();
            }

            // Get linkage method
            const linkageMethod = document.getElementById('linkage_select_$chart_title_str').value;

            // Build correlation matrix for selected variables
            const n = selectedVars.length;
            const corrMatrix = [];
            for (let i = 0; i < n; i++) {
                corrMatrix[i] = [];
                for (let j = 0; j < n; j++) {
                    if (i === j) {
                        corrMatrix[i][j] = 1.0;
                    } else {
                        // Find correlation from data
                        const item = corrDataRaw.find(d =>
                            ((d.node1 === selectedVars[i] && d.node2 === selectedVars[j]) ||
                             (d.node1 === selectedVars[j] && d.node2 === selectedVars[i])) &&
                            d.correlation_method === corrMethod &&
                            (!hasScenarios || d.scenario === currentScenario));
                        corrMatrix[i][j] = item ? item.strength : 0;
                    }
                }
            }

            // Determine variable order
            let orderedVars;
            if (orderMode === 'manual' && manualOrder.length > 0) {
                // Use manual order, filtered to selected vars
                orderedVars = manualOrder.filter(v => selectedVars.includes(v));
                // Add any selected vars not in manual order to the end
                selectedVars.forEach(v => {
                    if (!orderedVars.includes(v)) {
                        orderedVars.push(v);
                    }
                });
            } else if (orderMode === 'alphabetical') {
                orderedVars = selectedVars.slice().sort();
            } else {
                // Use precomputed hierarchical clustering from Julia
                orderedVars = performClustering_$chart_title_str(selectedVars, corrMatrix, linkageMethod, corrMethod);
            }

            // Reorder correlation matrix according to ordering
            const orderedIndices = orderedVars.map(v => selectedVars.indexOf(v));
            const reorderedMatrix = [];
            for (let i = 0; i < n; i++) {
                reorderedMatrix[i] = [];
                for (let j = 0; j < n; j++) {
                    reorderedMatrix[i][j] = corrMatrix[orderedIndices[i]][orderedIndices[j]];
                }
            }

            // Draw heatmap
            drawHeatmap_$chart_title_str(orderedVars, reorderedMatrix, corrMethod);

            // Draw dendrogram (only if using dendrogram order)
            if (orderMode === 'dendrogram') {
                drawDendrogram_$chart_title_str(orderedVars, linkageMethod, corrMethod);
            } else {
                document.getElementById('dendrogram_$chart_title_str').style.display = 'none';
            }
        };

        function performClustering_$chart_title_str(vars, corrMatrix, linkageMethod, corrMethod) {
            if (vars.length < 2) return vars;

            // Get precomputed dendrogram ordering from Julia
            const scenario = hasScenarios ? currentScenario : "default";

            if (!dendroOrderings[scenario] || !dendroOrderings[scenario][corrMethod] ||
                !dendroOrderings[scenario][corrMethod][linkageMethod]) {
                console.warn('No precomputed ordering for', scenario, corrMethod, linkageMethod);
                return vars;
            }

            // Get the full dendrogram data
            const dendroData = dendroOrderings[scenario][corrMethod][linkageMethod];
            if (!dendroData || !dendroData.ordering) {
                console.warn('Invalid dendrogram data structure');
                return vars;
            }

            const fullOrdering = dendroData.ordering;

            // Filter to only the selected variables, preserving the ordering
            const orderedVars = fullOrdering.filter(v => vars.includes(v));

            return orderedVars;
        }

        function drawHeatmap_$chart_title_str(vars, corrMatrix, corrMethod) {
            const n = vars.length;

            // Build z-values and text
            const zValues = [];
            const textValues = [];
            const hoverText = [];

            for (let i = 0; i < n; i++) {
                zValues[i] = [];
                textValues[i] = [];
                hoverText[i] = [];
                for (let j = 0; j < n; j++) {
                    const corr = corrMatrix[i][j];
                    zValues[i][j] = corr;

                    if (i === j) {
                        textValues[i][j] = '1.00';
                        hoverText[i][j] = vars[i];
                    } else if (i < j) {
                        // Upper triangle: Pearson
                        textValues[i][j] = 'P: ' + corr.toFixed(2);
                        hoverText[i][j] = vars[i] + ' vs ' + vars[j] + '<br>Pearson: ' + corr.toFixed(3);
                    } else {
                        // Lower triangle: Spearman
                        textValues[i][j] = 'S: ' + corr.toFixed(2);
                        hoverText[i][j] = vars[i] + ' vs ' + vars[j] + '<br>Spearman: ' + corr.toFixed(3);
                    }
                }
            }

            // Create heatmap
            const heatmapTrace = {
                z: zValues,
                x: vars,
                y: vars,
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

            // Add text annotations
            for (let i = 0; i < n; i++) {
                for (let j = 0; j < n; j++) {
                    heatmapLayout.annotations.push({
                        x: vars[j],
                        y: vars[i],
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
        }

        function drawDendrogram_$chart_title_str(vars, linkageMethod, corrMethod) {
            const dendroDiv = document.getElementById('dendrogram_$chart_title_str');
            dendroDiv.style.display = 'block';

            if (vars.length < 2) {
                dendroDiv.innerHTML = '<p style="color: #666;">Select at least 2 variables to see dendrogram</p>';
                return;
            }

            // Get precomputed tree structure from Julia
            const scenario = hasScenarios ? currentScenario : "default";
            const dendroData = dendroOrderings[scenario] && dendroOrderings[scenario][corrMethod] &&
                              dendroOrderings[scenario][corrMethod][linkageMethod];

            if (!dendroData || !dendroData.tree) {
                dendroDiv.innerHTML = '<p style="color: #666;">Dendrogram unavailable for this selection</p>';
                return;
            }

            const tree = dendroData.tree;

            // Filter tree to show only selected variables
            const selectedSet = new Set(vars);
            const varIndexMap = {};
            tree.labels.forEach((label, idx) => {
                varIndexMap[idx + 1] = label;  // 1-indexed
            });

            try {
                // Build dendrogram structure from tree merges
                const shapes = [];
                const positions = {};
                const heights = {};
                let nextPos = 0;
                let maxHeight = 0;

                // First pass: assign positions to leaves in the order they appear
                tree.order.forEach((leafIdx) => {
                    const label = tree.labels[leafIdx - 1];  // Convert to 0-indexed
                    if (selectedSet.has(label)) {
                        positions[-leafIdx] = nextPos;  // Leaves are negative
                        heights[-leafIdx] = 0;
                        nextPos++;
                    }
                });

                const n = nextPos;
                if (n === 0) {
                    dendroDiv.innerHTML = '<p style="color: #666;">No selected variables in dendrogram</p>';
                    return;
                }

                // Second pass: process merges
                for (let i = 0; i < tree.merges.length; i++) {
                    const [left, right] = tree.merges[i];
                    const height = tree.heights[i];
                    maxHeight = Math.max(maxHeight, height);

                    const clusterId = i + 1;  // Clusters are 1-indexed positive

                    // Check if either child involves selected variables
                    const leftInSelection = positions[left] !== undefined;
                    const rightInSelection = positions[right] !== undefined;

                    if (!leftInSelection && !rightInSelection) continue;

                    if (leftInSelection && rightInSelection) {
                        const leftPos = positions[left];
                        const rightPos = positions[right];
                        const leftHeight = heights[left];
                        const rightHeight = heights[right];
                        const mergePos = (leftPos + rightPos) / 2;

                        positions[clusterId] = mergePos;
                        heights[clusterId] = height;

                        // Draw U-shaped connection
                        shapes.push(
                            {type: 'line', x0: leftPos, y0: leftHeight, x1: leftPos, y1: height, line: {color: '#636efa', width: 2}},
                            {type: 'line', x0: leftPos, y0: height, x1: rightPos, y1: height, line: {color: '#636efa', width: 2}},
                            {type: 'line', x0: rightPos, y0: rightHeight, x1: rightPos, y1: height, line: {color: '#636efa', width: 2}}
                        );
                    } else if (leftInSelection) {
                        positions[clusterId] = positions[left];
                        heights[clusterId] = height;
                    } else {
                        positions[clusterId] = positions[right];
                        heights[clusterId] = height;
                    }
                }

                // Get leaf labels in display order
                const leafLabels = [];
                const leafPositions = [];
                for (let i = 0; i < n; i++) {
                    leafPositions.push(i);
                    // Find which leaf is at this position
                    for (const [key, pos] of Object.entries(positions)) {
                        if (pos === i && parseInt(key) < 0) {
                            const leafIdx = -parseInt(key);
                            leafLabels.push(tree.labels[leafIdx - 1]);
                            break;
                        }
                    }
                }

                // Draw dendrogram
                const leafTrace = {
                    x: leafPositions,
                    y: Array(n).fill(0),
                    mode: 'text',
                    type: 'scatter',
                    text: leafLabels,
                    textposition: 'bottom center',
                    textfont: {size: 10},
                    hoverinfo: 'text',
                    showlegend: false
                };

                // Ensure minimum y-axis range to prevent dendrogram from being crushed
                const minYRange = 0.1;  // Minimum height range

                // If maxHeight is too small, scale the shapes so dendrogram is visible
                // This happens when all variables are highly correlated
                let scaledShapes = shapes;
                let displayMaxHeight = maxHeight;

                if (maxHeight < minYRange && maxHeight > 0) {
                    // Scale factor to make dendrogram fill the visible area
                    const scaleFactor = (minYRange * 0.9) / maxHeight;  // 0.9 to leave some margin
                    displayMaxHeight = minYRange;

                    // Scale all y coordinates in shapes
                    scaledShapes = shapes.map(function(shape) {
                        return {
                            type: shape.type,
                            x0: shape.x0,
                            y0: shape.y0 * scaleFactor,
                            x1: shape.x1,
                            y1: shape.y1 * scaleFactor,
                            line: shape.line
                        };
                    });

                    console.info('Dendrogram heights scaled for visibility (original maxHeight=' + maxHeight.toFixed(6) + ', scale=' + scaleFactor.toFixed(2) + ')');
                } else if (maxHeight === 0 && shapes.length > 0) {
                    // All heights are exactly zero - assign arbitrary heights for visibility
                    displayMaxHeight = minYRange;
                    console.warn('All dendrogram heights are zero. Variables may be perfectly correlated or identical.');
                }

                const yAxisMax = Math.max(displayMaxHeight * 1.15, minYRange);
                const wasScaled = (maxHeight < minYRange && maxHeight > 0);

                // Log warning if original heights were very small
                if (maxHeight < 0.01 && maxHeight > 0) {
                    console.warn('Dendrogram heights are very small (maxHeight=' + maxHeight.toFixed(6) + '). This indicates highly correlated variables. Heights have been scaled for visibility.');
                }

                const yAxisTitle = wasScaled ? 'Height (scaled for visibility)' : 'Height';
                const chartTitle = wasScaled
                    ? 'Hierarchical Clustering Dendrogram (' + linkageMethod + ' linkage) - Note: Heights scaled due to high correlation'
                    : 'Hierarchical Clustering Dendrogram (' + linkageMethod + ' linkage)';

                const dendroLayout = {
                    title: chartTitle,
                    xaxis: {visible: false, range: [-0.5, n - 0.5]},
                    yaxis: {title: yAxisTitle, range: [0, yAxisMax]},
                    margin: {l: 80, r: 50, b: 120, t: 50},
                    showlegend: false,
                    shapes: scaledShapes,
                    height: 400
                };

                Plotly.newPlot('dendrogram_$chart_title_str', [leafTrace], dendroLayout, {responsive: true});
            } catch (error) {
                console.error('Failed to draw dendrogram:', error);
                dendroDiv.innerHTML = '<p style="color: red;">Error drawing dendrogram</p>';
            }
        }

    })();
    """
end

"""
    cluster_from_correlation(corr_matrix::AbstractMatrix; linkage::Symbol=:ward)

Perform hierarchical clustering on a correlation matrix.

# Arguments
- `corr_matrix::AbstractMatrix`: Correlation matrix (n×n)
- `linkage::Symbol`: Linkage method (:ward, :average, :single, :complete)

# Returns
- `Clustering.Hclust`: Hierarchical clustering result with fields:
  - `merges`: Merge matrix
  - `heights`: Height of each merge
  - `order`: Order of leaves in dendrogram

# Example
```julia
cors = compute_correlations(df, [:x1, :x2, :x3])
hc = cluster_from_correlation(cors.pearson, linkage=:ward)
```
"""
function cluster_from_correlation(corr_matrix::AbstractMatrix{<:Real}; linkage::Symbol=:ward)
    n = size(corr_matrix, 1)

    if n < 2
        error("Need at least 2 variables for clustering")
    end

    # Convert correlation to distance
    dist_matrix = zeros(n, n)
    for i in 1:n
        for j in 1:n
            dist_matrix[i, j] = sqrt(max(0.0, 0.5 * (1 - abs(corr_matrix[i, j]))))
        end
    end

    # Perform hierarchical clustering
    return hclust(dist_matrix, linkage=linkage, branchorder=:optimal)
end

"""
    CorrelationScenario

Struct holding correlation data for a specific scenario in advanced CorrPlot visualizations.

# Fields
- `name::String`: Scenario name
- `pearson::Matrix{Float64}`: Pearson correlation matrix
- `spearman::Matrix{Float64}`: Spearman correlation matrix
- `hc::Clustering.Hclust`: Hierarchical clustering result
- `var_labels::Vector{String}`: Variable names

# Example
```julia
cors = compute_correlations(df, [:x1, :x2, :x3])
hc = cluster_from_correlation(cors.pearson, linkage=:ward)
scenario = CorrelationScenario("My Scenario", cors.pearson, cors.spearman, hc, ["x1", "x2", "x3"])
```
"""
struct CorrelationScenario
    name::String
    pearson::Matrix{Float64}
    spearman::Matrix{Float64}
    hc::Clustering.Hclust
    var_labels::Vector{String}

    function CorrelationScenario(name::String,
                                pearson::AbstractMatrix{<:Real},
                                spearman::AbstractMatrix{<:Real},
                                hc::Clustering.Hclust,
                                var_labels::Vector{String})
        # Validate matrices
        n = length(var_labels)

        if size(pearson) != (n, n)
            error("Pearson matrix size $(size(pearson)) doesn't match number of variables ($n)")
        end

        if size(spearman) != (n, n)
            error("Spearman matrix size $(size(spearman)) doesn't match number of variables ($n)")
        end

        if length(hc.order) != n
            error("Dendrogram order length $(length(hc.order)) doesn't match number of variables ($n)")
        end

        new(name, Matrix{Float64}(pearson), Matrix{Float64}(spearman), hc, var_labels)
    end
end

"""
    prepare_corrplot_data(pearson, spearman, hc, var_labels)

OLD API: Prepare correlation data from matrices for basic CorrPlot (backward compatibility).

This function is provided for backward compatibility. New code should use the version
that takes matrices directly without hclust: `prepare_corrplot_data(pearson, spearman, var_labels)`.

# Arguments
- `pearson::Matrix`: Pearson correlation matrix
- `spearman::Matrix`: Spearman correlation matrix
- `hc::Clustering.Hclust`: Hierarchical clustering (ignored in new API)
- `var_labels::Vector{String}`: Variable names

# Returns
DataFrame with correlation data
"""
function prepare_corrplot_data(pearson::AbstractMatrix{<:Real},
                               spearman::AbstractMatrix{<:Real},
                               hc::Clustering.Hclust,
                               var_labels::Union{Vector{String}, Vector{Symbol}};
                               scenario::String="default")
    # Just call the new API, ignoring hc
    return prepare_corrplot_data(pearson, spearman, var_labels; scenario=scenario)
end

"""
    prepare_corrplot_advanced_data(scenarios::Vector{CorrelationScenario})

Prepare correlation data from multiple scenarios for advanced CorrPlot.

Converts CorrelationScenario objects into a single DataFrame suitable for CorrPlot.

# Arguments
- `scenarios::Vector{CorrelationScenario}`: Vector of correlation scenarios

# Returns
DataFrame with columns: node1, node2, strength, scenario, correlation_method
"""
function prepare_corrplot_advanced_data(scenarios::Vector{CorrelationScenario})
    dfs = DataFrame[]

    for scenario in scenarios
        df = prepare_corrplot_data(scenario.pearson, scenario.spearman,
                                   scenario.var_labels; scenario=scenario.name)
        push!(dfs, df)
    end

    return vcat(dfs...)
end

"""
    CorrPlot(chart_title, pearson, spearman, hc, var_labels, data_label; kwargs...)

OLD API: Create a basic CorrPlot from correlation matrices (backward compatibility).

This constructor is provided for backward compatibility. New code should use:
- For simple plots: Create DataFrame with prepare_corrplot_data() then pass to new constructor
- For advanced plots: Use the new constructor with DataFrame directly

# Arguments
- `chart_title::Symbol`: Chart identifier
- `pearson::Matrix`: Pearson correlation matrix
- `spearman::Matrix`: Spearman correlation matrix
- `hc::Clustering.Hclust`: Hierarchical clustering
- `var_labels::Vector{String}`: Variable names
- `data_label::Symbol`: Data identifier

# Keyword Arguments
- `title::String`: Chart title
- `notes::String`: Descriptive notes
"""
function CorrPlot(chart_title::Symbol,
                 pearson::AbstractMatrix{<:Real},
                 spearman::AbstractMatrix{<:Real},
                 hc::Clustering.Hclust,
                 var_labels::Vector{String},
                 data_label::Symbol;
                 title::String = "Correlation Plot with Dendrogram",
                 notes::String = "")
    # Validate matrices
    n = length(var_labels)

    if size(pearson) != (n, n)
        error("Pearson matrix size $(size(pearson)) doesn't match number of variables ($n)")
    end

    if size(spearman) != (n, n)
        error("Spearman matrix size $(size(spearman)) doesn't match number of variables ($n)")
    end

    if length(hc.order) != n
        error("Dendrogram order length $(length(hc.order)) doesn't match number of variables ($n)")
    end

    # Convert to DataFrame using new API
    corr_df = prepare_corrplot_data(pearson, spearman, var_labels)

    # Call new constructor
    return CorrPlot(chart_title, corr_df, data_label;
                   title=title, notes=notes, allow_manual_order=false)
end

"""
    CorrPlot(chart_title, scenarios, data_label; kwargs...)

OLD API: Create an advanced CorrPlot from multiple scenarios (backward compatibility).

This constructor is provided for backward compatibility. New code should use:
prepare_corrplot_advanced_data() to create DataFrame, then pass to new constructor.

# Arguments
- `chart_title::Symbol`: Chart identifier
- `scenarios::Vector{CorrelationScenario}`: Correlation scenarios
- `data_label::Symbol`: Data identifier

# Keyword Arguments
- `title::String`: Chart title
- `notes::String`: Descriptive notes
- `default_scenario::Union{String, Nothing}`: Default scenario name
- `default_variables::Union{Vector{String}, Nothing}`: Default selected variables
- `allow_manual_order::Bool`: Enable manual variable reordering
"""
function CorrPlot(chart_title::Symbol,
                 scenarios::Vector{CorrelationScenario},
                 data_label::Symbol;
                 title::String = "Correlation Plot with Dendrogram",
                 notes::String = "",
                 default_scenario::Union{String, Nothing} = nothing,
                 default_variables::Union{Vector{String}, Nothing} = nothing,
                 allow_manual_order::Bool = true)
    # Validate
    if isempty(scenarios)
        error("Must provide at least one scenario")
    end

    # Convert to DataFrame using new API
    corr_df = prepare_corrplot_advanced_data(scenarios)

    # Call new constructor
    return CorrPlot(chart_title, corr_df, data_label;
                   title=title, notes=notes,
                   scenario_col=:scenario,
                   default_scenario=default_scenario,
                   default_variables=default_variables,
                   allow_manual_order=allow_manual_order)
end

# Export functions
export CorrPlot, compute_correlations, prepare_corrplot_data
export cluster_from_correlation, CorrelationScenario, prepare_corrplot_advanced_data
