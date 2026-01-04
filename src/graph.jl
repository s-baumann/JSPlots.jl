# Graph visualization with network layout

# Struct for Graph scenarios (similar to CorrelationScenario)
struct GraphScenario
    name::String
    is_correlation::Bool
    node_labels::Vector{String}
end

"""
    calculate_smart_cutoff(data::DataFrame, scenario_name::String, is_correlation::Bool,
                          target_edge_percentage::Float64 = 0.15)

Calculate a smart cutoff value that displays approximately the target percentage of edges.

# Arguments
- `data::DataFrame`: Graph edge data with node1, node2, strength, scenario columns
- `scenario_name::String`: Name of the scenario to calculate cutoff for
- `is_correlation::Bool`: Whether higher values mean stronger connections (true for correlation, false for distance)
- `target_edge_percentage::Float64`: Target percentage of edges to display (default: 0.15 = 15%)

# Returns
- `Float64`: Cutoff value that will display approximately target_edge_percentage of edges

# Details
For correlation data (is_correlation=true), higher values mean stronger connections, so we want
cutoff where values >= cutoff represent the top target_edge_percentage.

For distance data (is_correlation=false), lower values mean stronger connections, so we want
cutoff where values <= cutoff represent the top target_edge_percentage.
"""
function calculate_smart_cutoff(data::DataFrame, scenario_name::String, is_correlation::Bool,
                                target_edge_percentage::Float64 = 0.15)
    # Filter data for this scenario
    scenario_data = filter(row -> row.scenario == scenario_name, data)

    if nrow(scenario_data) == 0
        @warn "No data found for scenario '$scenario_name', using default cutoff 0.5"
        return 0.5
    end

    # Get all strength values
    strengths = scenario_data.strength

    # Calculate how many edges we want to show
    target_count = max(1, round(Int, length(strengths) * target_edge_percentage))

    if is_correlation
        # For correlation: higher values = stronger connections
        # Sort descending and take the threshold at target_count position
        sorted_strengths = sort(abs.(strengths), rev=true)
        cutoff = sorted_strengths[min(target_count, length(sorted_strengths))]
    else
        # For distance: lower values = stronger connections
        # Sort ascending and take the threshold at target_count position
        sorted_strengths = sort(abs.(strengths), rev=false)
        cutoff = sorted_strengths[min(target_count, length(sorted_strengths))]
    end

    return cutoff
end

"""
    GraphScenario(name::String, is_correlation::Bool, node_labels::Vector{String})

Create a graph scenario with a specific distance/correlation matrix.

# Arguments
- `name::String`: Scenario name
- `is_correlation::Bool`: Whether the strength values are correlations (true) or distances (false)
- `node_labels::Vector{String}`: Labels for all nodes in this scenario
"""
GraphScenario

"""
    Graph(chart_title::Symbol, scenarios::Vector{GraphScenario}, data_label::Symbol; kwargs...)

Create an interactive network graph visualization with multiple scenarios and variable selection.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `scenarios::Vector{GraphScenario}`: Multiple graph scenarios to switch between
- `data_label::Symbol`: Label for the graph data in external storage

# Keyword Arguments
- `title::String`: Chart title (default: `"Network Graph"`)
- `notes::String`: Descriptive text (default: `""`)
- `cutoff::Float64`: Connection strength cutoff (default: `0.5`)
- `color_cols::Union{Vector{Symbol}, Nothing}`: Columns for node coloring (default: `nothing`)
- `default_color_col::Union{Symbol, Nothing}`: Default coloring column (default: first in color_cols)
- `show_edge_labels::Bool`: Show edge strength labels by default (default: `false`)
- `layout::Symbol`: Graph layout algorithm (default: `:cose`)
- `default_scenario::Union{String, Nothing}`: Name of default scenario (default: first scenario)
- `default_variables::Union{Vector{String}, Nothing}`: Default selected variables (default: all)

# Smart Cutoff Calculation
To avoid trivial graphs (all edges or no edges), use `calculate_smart_cutoff()` to find a cutoff
that displays approximately 15% of edges:

```julia
cutoff = calculate_smart_cutoff(graph_data, "My Scenario", true, 0.15)
graph = Graph(:my_graph, [scenario], :graph_data; cutoff=cutoff)
```

# Data Format
The data should be a DataFrame with columns:
- `node1`: First node in edge
- `node2`: Second node in edge
- `strength`: Connection strength
- `scenario`: Scenario name (if multiple scenarios)
- Additional columns for node attributes (e.g., sector, country)

# Interactive Features
- Select subset of variables (nodes become translucent until recalculated)
- Switch between scenarios (edges update, nodes stay in place)
- Recalculate button to fully update graph with selected variables
- Drag nodes to rearrange
- Toggle edge labels on/off
- Change node coloring
- Adjust cutoff
- Change layout (triggers recalculation)
- Zoom and pan
"""
function Graph(chart_title::Symbol,
               scenarios::Vector{GraphScenario},
               data_label::Symbol;
               title::String = "Network Graph",
               notes::String = "",
               cutoff::Float64 = 0.5,
               color_cols::Union{Vector{Symbol}, Nothing} = nothing,
               default_color_col::Union{Symbol, Nothing} = nothing,
               show_edge_labels::Bool = false,
               layout::Symbol = :cose,
               default_scenario::Union{String, Nothing} = nothing,
               default_variables::Union{Vector{String}, Nothing} = nothing)

    # Validate scenarios
    if isempty(scenarios)
        error("At least one GraphScenario is required")
    end

    # Determine default scenario
    default_scenario_name = isnothing(default_scenario) ? scenarios[1].name : default_scenario
    default_idx = findfirst(s -> s.name == default_scenario_name, scenarios)
    if isnothing(default_idx)
        error("Default scenario '$default_scenario_name' not found in scenarios")
    end

    # Determine default variables
    default_vars = if isnothing(default_variables)
        scenarios[default_idx].node_labels
    else
        # Validate default variables exist
        for var in default_variables
            if !(var in scenarios[default_idx].node_labels)
                error("Default variable '$var' not found in scenario '$(scenarios[default_idx].name)'")
            end
        end
        default_variables
    end

    chart_title_str = string(chart_title)

    # Validate layout
    valid_layouts = [:cose, :circle, :grid, :concentric, :breadthfirst, :random]
    if !(layout in valid_layouts)
        error("Invalid layout: $layout. Must be one of: $valid_layouts")
    end

    # Determine default color column
    if !isnothing(color_cols) && !isempty(color_cols)
        default_color = isnothing(default_color_col) ? color_cols[1] : default_color_col
    else
        default_color = nothing
    end

    # Build appearance HTML
    appearance_html = build_graph_appearance_html(
        chart_title_str, title, notes, scenarios, cutoff, color_cols,
        default_color, show_edge_labels, layout, valid_layouts
    )

    # Build functional HTML
    functional_html = build_graph_functional_html(
        chart_title_str, data_label, scenarios, cutoff,
        color_cols, default_color, show_edge_labels, layout,
        default_idx, default_vars
    )

    return GraphChart(chart_title, data_label, functional_html, appearance_html)
end

function build_graph_appearance_html(chart_title_str, title, notes, scenarios,
                                     cutoff, color_cols, default_color,
                                     show_edge_labels, layout, valid_layouts)

    # Scenario selector (if multiple scenarios)
    scenario_selector_html = if length(scenarios) > 1
        options = join(["""<option value="$(s.name)">$(s.name)</option>"""
                       for s in scenarios], "\n                ")
        """
        <div style="margin-bottom: 10px;">
            <label for="scenario_select_$chart_title_str"><strong>Scenario:</strong></label>
            <select id="scenario_select_$chart_title_str" onchange="updateEdges_$chart_title_str()">
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
        <select id="var_select_$chart_title_str" multiple size="6" style="width: 300px;" onchange="updateNodeOpacity_$chart_title_str()">
        </select>
    </div>
    """

    # Recalculate button
    recalculate_button = """
    <div style="margin-bottom: 15px;">
        <button id="recalc_btn_$chart_title_str" onclick="recalculateGraph_$chart_title_str()"
                style="padding: 8px 16px; background-color: #3498db; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">
            Recalculate Graph
        </button>
        <span style="margin-left: 10px; font-size: 12px; color: #666;">
            (Apply variable selection & reorganize layout)
        </span>
    </div>
    """

    # Color selector
    color_selector_html = if !isnothing(color_cols) && !isempty(color_cols)
        options = join(["""<option value="$col" $(col == default_color ? "selected" : "")>$col</option>"""
                       for col in color_cols], "\n                ")
        """
        <div style="margin-bottom: 10px;">
            <label for="color_select_$chart_title_str"><strong>Color nodes by:</strong></label>
            <select id="color_select_$chart_title_str" onchange="updateColors_$chart_title_str()">
                <option value="none">None</option>
                $options
            </select>
        </div>
        """
    else
        ""
    end

    # Layout selector
    layout_options = join(["""<option value="$lay" $(lay == layout ? "selected" : "")>$(uppercasefirst(string(lay)))</option>"""
                          for lay in valid_layouts], "\n                ")
    layout_selector_html = """
    <div style="margin-bottom: 10px;">
        <label for="layout_select_$chart_title_str"><strong>Layout:</strong></label>
        <select id="layout_select_$chart_title_str" onchange="recalculateGraph_$chart_title_str()">
            $layout_options
        </select>
        <span style="margin-left: 5px; font-size: 11px; color: #666;">(Changing layout recalculates)</span>
    </div>
    """

    # Edge label toggle
    edge_label_toggle = """
    <div style="margin-bottom: 10px;">
        <label>
            <input type="checkbox" id="show_edges_$chart_title_str"
                   $(show_edge_labels ? "checked" : "")
                   onchange="updateEdgeLabels_$chart_title_str()">
            <strong>Show edge strengths</strong>
        </label>
    </div>
    """

    # Cutoff slider
    cutoff_slider = """
    <div style="margin-bottom: 15px;">
        <label for="cutoff_slider_$chart_title_str"><strong>Connection cutoff:</strong>
               <span id="cutoff_value_$chart_title_str">$cutoff</span>
        </label>
        <input type="range" id="cutoff_slider_$chart_title_str"
               min="0" max="1" step="0.05" value="$cutoff"
               style="width: 75%; margin-left: 10px;"
               oninput="document.getElementById('cutoff_value_$chart_title_str').textContent = this.value; updateEdges_$chart_title_str()">
    </div>
    """

    return """
    <script src="https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.28.1/cytoscape.min.js"></script>
    <div class="graph-container">
        <h2>$title</h2>
        <p>$notes</p>
        $scenario_selector_html
        $variable_selector_html
        $recalculate_button
        $color_selector_html
        $layout_selector_html
        $edge_label_toggle
        $cutoff_slider
        <div id="graph_$chart_title_str" style="width: 100%; height: 600px; border: 1px solid #ccc;"></div>
        <div style="margin-top: 10px; font-size: 12px; color: #666;">
            <strong>Tip:</strong> Deselected variables become translucent. Click "Recalculate Graph" to remove them and reorganize.
            Switching scenarios updates edges but keeps node positions.
        </div>
    </div>
    """
end

function build_graph_functional_html(chart_title_str, data_label, scenarios,
                                     cutoff, color_cols, default_color,
                                     show_edge_labels, layout, default_idx, default_vars)

    has_colors = !isnothing(color_cols) && !isempty(color_cols)
    default_color_str = isnothing(default_color) ? "none" : string(default_color)
    scenarios_json = JSON.json([Dict("name" => s.name, "is_correlation" => s.is_correlation,
                                     "node_labels" => s.node_labels) for s in scenarios])
    default_vars_json = JSON.json(default_vars)

    return """
    (function() {
        const scenarios = $scenarios_json;
        let currentScenario = scenarios[$(default_idx - 1)];
        let selectedVars = $default_vars_json;
        let graphData = null;
        let cy = null;
        let nodePositions = {};  // Store node positions to keep them stable

        // Load graph data
        loadDataset('$(data_label)').then(function(data) {
            graphData = data;
            populateVarSelector_$chart_title_str();  // Populate selector BEFORE initializing graph
            initializeGraph_$chart_title_str();
        }).catch(function(error) {
            console.error('Failed to load graph data:', error);
        });

        function populateVarSelector_$chart_title_str() {
            const select = document.getElementById('var_select_$chart_title_str');
            select.innerHTML = '';
            currentScenario.node_labels.forEach(v => {
                const option = document.createElement('option');
                option.value = v;
                option.text = v;
                option.selected = selectedVars.includes(v);
                select.appendChild(option);
            });
        }

        function initializeGraph_$chart_title_str() {
            if (!graphData || graphData.length === 0) {
                console.warn('No graph data loaded');
                return;
            }

            // Initialize Cytoscape
            cy = cytoscape({
                container: document.getElementById('graph_$chart_title_str'),

                style: [
                    {
                        selector: 'node',
                        style: {
                            'background-color': '#3498db',
                            'label': 'data(label)',
                            'color': '#000',
                            'text-valign': 'center',
                            'text-halign': 'center',
                            'font-size': '10px',
                            'width': '30px',
                            'height': '30px',
                            'opacity': 1.0
                        }
                    },
                    {
                        selector: 'node.deselected',
                        style: {
                            'opacity': 0.15
                        }
                    },
                    {
                        selector: 'edge',
                        style: {
                            'width': 'data(displayWidth)',
                            'line-color': '#95a5a6',
                            'opacity': 0.6,
                            'curve-style': 'bezier'
                        }
                    },
                    {
                        selector: 'edge[label]',
                        style: {
                            'label': 'data(label)',
                            'font-size': '8px',
                            'text-rotation': 'autorotate',
                            'text-margin-y': -10,
                            'color': '#555'
                        }
                    },
                    {
                        selector: ':selected',
                        style: {
                            'background-color': '#e74c3c',
                            'line-color': '#e74c3c',
                            'width': '40px',
                            'height': '40px'
                        }
                    }
                ],

                layout: {
                    name: '$(layout)'
                }
            });

            // Store initial positions after layout
            cy.on('layoutstop', function() {
                cy.nodes().forEach(node => {
                    const pos = node.position();
                    nodePositions[node.id()] = {x: pos.x, y: pos.y};
                });
            });

            recalculateGraph_$chart_title_str();
        }

        // Recalculate graph - full rebuild with selected variables
        window.recalculateGraph_$chart_title_str = function() {
            if (!cy || !graphData) return;

            const layoutType = document.getElementById('layout_select_$chart_title_str').value;

            // Update selected variables from selector
            const varSelect = document.getElementById('var_select_$chart_title_str');
            selectedVars = Array.from(varSelect.selectedOptions).map(opt => opt.value);

            if (selectedVars.length === 0) {
                console.warn('Select at least one variable');
                return;
            }

            // Clear existing graph
            cy.elements().remove();
            nodePositions = {};  // Clear stored positions for full recalculation

            // Build new graph with only selected variables
            buildGraph_$chart_title_str(selectedVars, layoutType);
        };

        // Update edges when scenario or cutoff changes (keep node positions)
        window.updateEdges_$chart_title_str = function() {
            if (!cy || !graphData) return;

            // Update scenario
            const scenarioSelect = document.getElementById('scenario_select_$chart_title_str');
            if (scenarioSelect) {
                const scenarioName = scenarioSelect.value;
                const newScenario = scenarios.find(s => s.name === scenarioName);
                if (newScenario !== currentScenario) {
                    currentScenario = newScenario;
                    populateVarSelector_$chart_title_str();
                }
            }

            // Remove and rebuild edges (keep nodes)
            cy.edges().remove();
            const cutoffValue = parseFloat(document.getElementById('cutoff_slider_$chart_title_str').value);
            const showEdgeLabels = document.getElementById('show_edges_$chart_title_str').checked;

            // Add edges based on current scenario and cutoff
            const edges = getEdgesForScenario_$chart_title_str(currentScenario, selectedVars, cutoffValue, showEdgeLabels);
            cy.add(edges);
        };

        // Update node opacity when variable selection changes
        window.updateNodeOpacity_$chart_title_str = function() {
            if (!cy) return;

            const varSelect = document.getElementById('var_select_$chart_title_str');
            const currentlySelected = Array.from(varSelect.selectedOptions).map(opt => opt.value);

            // Make deselected nodes translucent
            cy.nodes().forEach(node => {
                if (currentlySelected.includes(node.id())) {
                    node.removeClass('deselected');
                } else {
                    node.addClass('deselected');
                }
            });
        };

        // Update colors
        window.updateColors_$chart_title_str = function() {
            if (!cy) return;

            $(if has_colors
                "const colorBy = document.getElementById('color_select_$chart_title_str').value;"
            else
                "const colorBy = 'none';"
            end)

            if (colorBy === 'none') {
                cy.nodes().style('background-color', '#3498db');
            } else {
                // Apply colors based on attribute
                const uniqueValues = new Set();
                cy.nodes().forEach(node => {
                    const val = node.data(colorBy);
                    if (val) uniqueValues.add(val);
                });

                const colors = generateColors_$chart_title_str(uniqueValues.size);
                const colorMap = {};
                Array.from(uniqueValues).forEach((val, idx) => {
                    colorMap[val] = colors[idx];
                });

                cy.nodes().forEach(node => {
                    const val = node.data(colorBy);
                    const color = val ? (colorMap[val] || '#3498db') : '#3498db';
                    node.style('background-color', color);
                });
            }
        };

        // Update edge labels
        window.updateEdgeLabels_$chart_title_str = function() {
            const showLabels = document.getElementById('show_edges_$chart_title_str').checked;
            cy.edges().forEach(edge => {
                if (showLabels) {
                    edge.data('label', edge.data('strength').toFixed(2));
                } else {
                    edge.removeData('label');
                }
            });
        };

        function buildGraph_$chart_title_str(varsToShow, layoutType) {
            const cutoffValue = parseFloat(document.getElementById('cutoff_slider_$chart_title_str').value);
            const showEdgeLabels = document.getElementById('show_edges_$chart_title_str').checked;

            $(if has_colors
                "const colorBy = document.getElementById('color_select_$chart_title_str').value;"
            else
                "const colorBy = 'none';"
            end)

            // Collect all nodes and their attributes
            const nodeSet = new Set();
            const nodeAttributes = {};

            graphData.forEach(row => {
                if (!row.node1 || !row.node2) return;
                if (!varsToShow.includes(row.node1) || !varsToShow.includes(row.node2)) return;

                nodeSet.add(row.node1);
                nodeSet.add(row.node2);

                if (!nodeAttributes[row.node1]) nodeAttributes[row.node1] = {};
                if (!nodeAttributes[row.node2]) nodeAttributes[row.node2] = {};

                Object.keys(row).forEach(key => {
                    if (key !== 'node1' && key !== 'node2' && key !== 'strength' && key !== 'scenario') {
                        nodeAttributes[row.node1][key] = row[key];
                        nodeAttributes[row.node2][key] = row[key];
                    }
                });
            });

            // Create color mapping
            let colorMap = {};
            if (colorBy !== 'none') {
                const uniqueValues = new Set();
                Object.values(nodeAttributes).forEach(attrs => {
                    if (attrs[colorBy]) uniqueValues.add(attrs[colorBy]);
                });
                const colors = generateColors_$chart_title_str(uniqueValues.size);
                Array.from(uniqueValues).forEach((val, idx) => {
                    colorMap[val] = colors[idx];
                });
            }

            // Add nodes
            Array.from(nodeSet).forEach(nodeName => {
                const attrs = nodeAttributes[nodeName] || {};
                const colorValue = (colorBy !== 'none' && attrs[colorBy]) ? attrs[colorBy] : null;
                const nodeColor = colorValue ? (colorMap[colorValue] || '#3498db') : '#3498db';

                const nodeData = {
                    id: nodeName,
                    label: nodeName,
                    color: nodeColor,
                    ...attrs
                };

                // Use stored position if available
                if (nodePositions[nodeName]) {
                    cy.add({
                        data: nodeData,
                        position: nodePositions[nodeName]
                    });
                } else {
                    cy.add({data: nodeData});
                }
            });

            // Add edges
            const edges = getEdgesForScenario_$chart_title_str(currentScenario, varsToShow, cutoffValue, showEdgeLabels);
            cy.add(edges);

            // Apply colors
            if (colorBy !== 'none') {
                cy.nodes().forEach(node => {
                    node.style('background-color', node.data('color'));
                });
            }

            // Apply layout only if no positions stored
            const hasStoredPositions = Array.from(nodeSet).every(n => nodePositions[n]);
            if (!hasStoredPositions) {
                cy.layout({
                    name: layoutType,
                    animate: true,
                    animationDuration: 500,
                    fit: true,
                    padding: 30
                }).run();
            }
        }

        function getEdgesForScenario_$chart_title_str(scenario, varsToShow, cutoffValue, showEdgeLabels) {
            const edges = [];
            const scenarioData = graphData.filter(row =>
                (!row.scenario || row.scenario === scenario.name) &&
                varsToShow.includes(row.node1) && varsToShow.includes(row.node2)
            );

            scenarioData.forEach((row, idx) => {
                let strength = row.strength;
                let distance = strength;

                if (scenario.is_correlation) {
                    distance = 1 - Math.abs(strength);
                }

                if (distance <= cutoffValue) {
                    const edgeWidth = scenario.is_correlation ?
                        Math.abs(strength) * 5 + 1 :
                        (1 - distance) * 5 + 1;

                    const edgeData = {
                        id: 'edge_' + scenario.name + '_' + idx,
                        source: row.node1,
                        target: row.node2,
                        strength: strength,
                        displayWidth: edgeWidth
                    };

                    if (showEdgeLabels) {
                        edgeData.label = strength.toFixed(2);
                    }

                    edges.push({data: edgeData});
                }
            });

            return edges;
        }

        function generateColors_$chart_title_str(n) {
            const colors = [
                '#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6',
                '#1abc9c', '#34495e', '#e67e22', '#95a5a6', '#d35400',
                '#c0392b', '#2980b9', '#27ae60', '#8e44ad', '#16a085'
            ];

            if (n <= colors.length) return colors.slice(0, n);

            const result = [...colors];
            for (let i = colors.length; i < n; i++) {
                const hue = (i * 137.508) % 360;
                result.push(\`hsl(\${hue}, 70%, 50%)\`);
            }
            return result;
        }
    })();
    """
end

# Struct definition
struct GraphChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
end

# Dependencies
dependencies(g::GraphChart) = [g.data_label]

# Export
export Graph, GraphScenario
