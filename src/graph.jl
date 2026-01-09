# Graph visualization with network layout

"""
    Graph(chart_title::Symbol, corr_df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive network graph visualization with variable selection.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `corr_df::DataFrame`: Correlation/edge data
- `data_label::Symbol`: Label for the graph data in external storage

# Keyword Arguments
- `title::String`: Chart title (default: `"Network Graph"`)
- `notes::String`: Descriptive text (default: `""`)
- `cutoff::Float64`: Connection strength cutoff (default: `0.5`)
- `color_cols::Union{Vector{Symbol}, Nothing}`: Columns for node coloring (default: `nothing`)
- `show_edge_labels::Bool`: Show edge strength labels by default (default: `false`)
- `layout::Symbol`: Graph layout algorithm (default: `:cose`)
- `scenario_col::Union{Symbol, Nothing}`: Column name for scenarios (default: `nothing`)
- `default_scenario::Union{String, Nothing}`: Name of default scenario (default: first scenario)
- `default_variables::Union{Vector{String}, Nothing}`: Default selected variables (default: all)

# Data Format
The data should be a DataFrame with columns:
- `node1`: First node in edge
- `node2`: Second node in edge
- `strength`: Connection strength
- Optional: scenario column if specified via `scenario_col`
- Optional: `correlation_method` column for filtering
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

# Example
```julia
# Prepare correlation data
vars = [:x1, :x2, :x3, :x4]
cors = compute_correlations(df, vars)
corr_df = prepare_corrplot_data(cors.pearson, cors.spearman, vars)

# Create graph
graph = Graph(:my_graph, corr_df, :graph_data;
              cutoff=0.5,
              color_cols=[:sector, :country],
              title="Variable Network")

page = JSPlotPage(Dict(:graph_data => corr_df), [graph])
```
"""
function Graph(chart_title::Symbol,
               corr_df::DataFrame,
               data_label::Symbol;
               title::String = "Network Graph",
               notes::String = "",
               cutoff::Float64 = 0.5,
               color_cols::Union{Vector{Symbol}, Nothing} = nothing,
               show_edge_labels::Bool = false,
               layout::Symbol = :cose,
               scenario_col::Union{Symbol, Nothing} = nothing,
               default_scenario::Union{String, Nothing} = nothing,
               default_variables::Union{Vector{String}, Nothing} = nothing)

    # Validate DataFrame structure
    required_cols = [:node1, :node2, :strength]
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

    # Validate layout
    valid_layouts = [:cose, :circle, :grid, :concentric, :breadthfirst, :random]
    if !(layout in valid_layouts)
        error("Invalid layout: $layout. Must be one of: $valid_layouts")
    end

    # Determine default color column (first from color_cols if provided)
    default_color = if !isnothing(color_cols) && !isempty(color_cols)
        color_cols[1]
    else
        nothing
    end

    # Build appearance HTML
    appearance_html = build_graph_appearance_html(
        chart_title_str, title, notes, scenarios, scenario_col,
        cutoff, color_cols, default_color, show_edge_labels, layout, valid_layouts
    )

    # Build functional HTML
    functional_html = build_graph_functional_html(
        chart_title_str, data_label, scenarios, scenario_col,
        default_scenario_name, cutoff, color_cols, default_color,
        show_edge_labels, layout, default_vars
    )

    return GraphChart(chart_title, data_label, functional_html, appearance_html)
end

function build_graph_appearance_html(chart_title_str, title, notes, scenarios,
                                     scenario_col, cutoff, color_cols, default_color,
                                     show_edge_labels, layout, valid_layouts)

    # Scenario selector (if scenarios exist)
    scenario_selector_html = if !isnothing(scenario_col) && length(scenarios) > 1
        options = join(["""<option value="$s">$s</option>"""
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

    # Correlation method selector (dynamically populated based on data)
    corr_method_selector = """
    <div id="corr_method_container_$chart_title_str" style="margin-bottom: 10px; display: none;">
        <label for="corr_method_select_$chart_title_str"><strong>Correlation method:</strong></label>
        <select id="corr_method_select_$chart_title_str" onchange="updateEdges_$chart_title_str()">
            <!-- Options will be populated dynamically from data -->
        </select>
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
        $corr_method_selector
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
                                     scenario_col, default_scenario_name, cutoff,
                                     color_cols, default_color, show_edge_labels,
                                     layout, default_vars)

    has_scenarios = !isnothing(scenario_col) && length(scenarios) > 1
    has_colors = !isnothing(color_cols) && !isempty(color_cols)
    default_color_str = isnothing(default_color) ? "none" : string(default_color)
    scenarios_json = JSON.json(scenarios)
    default_vars_json = JSON.json(default_vars)

    return """
    (function() {
        const scenarios = $scenarios_json;
        const hasScenarios = $has_scenarios;
        let currentScenario = "$default_scenario_name";
        let selectedVars = $default_vars_json;
        let graphData = null;
        let cy = null;
        let nodePositions = {};
        let allVars = [];

        // Load graph data
        loadDataset('$(data_label)').then(function(data) {
            graphData = data;
            allVars = [...new Set(data.map(d => d.node1).concat(data.map(d => d.node2)))].sort();

            // Check if data has correlation_method column and populate selector dynamically
            if (data.length > 0) {
                const firstRow = data[0];
                const hasCorrelationMethod = 'correlation_method' in firstRow || firstRow.hasOwnProperty('correlation_method');
                if (hasCorrelationMethod) {
                    // Get unique correlation methods from data
                    const corrMethods = [...new Set(data.map(row => row.correlation_method).filter(m => m))];

                    if (corrMethods.length > 0) {
                        const select = document.getElementById('corr_method_select_$chart_title_str');
                        const container = document.getElementById('corr_method_container_$chart_title_str');

                        if (select && container) {
                            // Clear existing options
                            select.innerHTML = '';

                            // Add options for each correlation method (first one is default)
                            corrMethods.forEach((method, idx) => {
                                const option = document.createElement('option');
                                option.value = method;
                                option.text = method.charAt(0).toUpperCase() + method.slice(1);
                                if (idx === 0) {
                                    option.selected = true;
                                }
                                select.appendChild(option);
                            });

                            // Show the selector
                            container.style.display = 'block';
                        }
                    }
                }
            }

            populateVarSelector_$chart_title_str();
            initializeGraph_$chart_title_str();
        }).catch(function(error) {
            console.error('Failed to load graph data:', error);
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
            if (hasScenarios) {
                const scenarioSelect = document.getElementById('scenario_select_$chart_title_str');
                if (scenarioSelect) {
                    currentScenario = scenarioSelect.value;
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

            // Get selected correlation method (if selector exists)
            const corrMethodSelect = document.getElementById('corr_method_select_$chart_title_str');
            const selectedCorrMethod = corrMethodSelect ? corrMethodSelect.value : null;

            const scenarioData = graphData.filter(row => {
                // Basic filters
                const scenarioMatch = !hasScenarios || !row.scenario || row.scenario === scenario;
                const nodeMatch = varsToShow.includes(row.node1) && varsToShow.includes(row.node2);

                // Correlation method filter (only if data has this column AND selector exists)
                const corrMethodMatch = !selectedCorrMethod || !row.correlation_method || row.correlation_method === selectedCorrMethod;

                return scenarioMatch && nodeMatch && corrMethodMatch;
            });

            scenarioData.forEach((row, idx) => {
                let strength = row.strength;
                // For correlation data, convert to distance
                let distance = 1 - Math.abs(strength);

                if (distance <= cutoffValue) {
                    const edgeWidth = Math.abs(strength) * 5 + 1;

                    const edgeData = {
                        id: 'edge_' + scenario + '_' + idx,
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
export Graph
