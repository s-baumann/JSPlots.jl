# Advanced CorrPlot constructor with multiple scenarios, variable selection, and manual ordering

"""
    CorrPlot(chart_title::Symbol, scenarios::Vector{CorrelationScenario}, data_label::Symbol; kwargs...)

Create an advanced interactive correlation plot with multiple scenarios, variable selection, and manual ordering.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `scenarios::Vector{CorrelationScenario}`: Multiple correlation scenarios to switch between
- `data_label::Symbol`: Label for the correlation data in external storage

# Keyword Arguments
- `title::String`: Chart title (default: `"Correlation Plot with Dendrogram"`)
- `notes::String`: Descriptive text (default: `""`)
- `default_scenario::Union{String, Nothing}`: Name of default scenario (default: first scenario)
- `default_variables::Union{Vector{String}, Nothing}`: Default selected variables (default: all)
- `allow_manual_order::Bool`: Enable manual drag-drop reordering (default: `true`)

# Example
```julia
# Create multiple scenarios
scenario1 = CorrelationScenario("Price Returns",
    pearson_price, spearman_price, hc_price, asset_names)
scenario2 = CorrelationScenario("Volume",
    pearson_vol, spearman_vol, hc_vol, asset_names)

corrplot = CorrPlot(:multi_corr, [scenario1, scenario2], :corr_data;
    title="Asset Correlations",
    default_scenario="Price Returns",
    default_variables=["AAPL", "MSFT", "GOOGL"],
    allow_manual_order=true)
```

# Interactive Features
- Scenario dropdown: Switch between different correlation analyses
- Variable selection: Multi-select to choose which variables to display
- Order toggle: Switch between dendrogram order and manual drag-drop order
- Dendrogram shows hierarchical clustering
- Heatmap with Pearson (upper-right) and Spearman (lower-left) correlations
"""
function CorrPlot(chart_title::Symbol,
                  scenarios::Vector{CorrelationScenario},
                  data_label::Symbol;
                  title::String = "Correlation Plot with Dendrogram",
                  notes::String = "",
                  default_scenario::Union{String, Nothing} = nothing,
                  default_variables::Union{Vector{String}, Nothing} = nothing,
                  allow_manual_order::Bool = true)

    if isempty(scenarios)
        error("Must provide at least one CorrelationScenario")
    end

    # Determine default scenario
    default_scenario_name = isnothing(default_scenario) ? scenarios[1].name : default_scenario

    # Find default scenario index
    default_idx = findfirst(s -> s.name == default_scenario_name, scenarios)
    if isnothing(default_idx)
        error("Default scenario '$default_scenario_name' not found in scenarios")
    end

    chart_title_str = string(chart_title)

    # Prepare correlation DataFrame for external storage
    corr_df = prepare_corrplot_advanced_data(scenarios)

    # Prepare scenarios data for JavaScript (dendrogram and labels only)
    scenarios_data = []
    for scenario in scenarios
        n = length(scenario.var_labels)
        ordered_indices = scenario.hc.order
        ordered_labels = scenario.var_labels[ordered_indices]

        # Extract dendrogram structure
        dendro_data = extract_dendrogram_structure(scenario.hc, ordered_labels)

        push!(scenarios_data, Dict(
            "name" => scenario.name,
            "labels" => ordered_labels,
            "allLabels" => scenario.var_labels,  # Unordered for selection
            "dendroData" => dendro_data
        ))
    end

    # Determine default selected variables
    default_vars = if isnothing(default_variables)
        scenarios[default_idx].var_labels
    else
        # Validate that default variables exist
        for v in default_variables
            if !(v in scenarios[default_idx].var_labels)
                error("Default variable '$v' not found in scenario '$(scenarios[default_idx].name)'")
            end
        end
        default_variables
    end

    # Build appearance HTML with controls
    scenario_dropdown_html = if length(scenarios) > 1
        options_html = join(["""<option value="$(s.name)" $(s.name == default_scenario_name ? "selected" : "")>$(s.name)</option>"""
                            for s in scenarios], "\n                ")
        """
        <div style="margin-bottom: 15px;">
            <label for="scenario_select_$chart_title_str"><strong>Scenario:</strong></label>
            <select id="scenario_select_$chart_title_str" onchange="updateChart_$chart_title()">
                $options_html
            </select>
        </div>
        """
    else
        ""
    end

    order_toggle_html = if allow_manual_order
        """
        <div style="margin-bottom: 15px;">
            <label>
                <input type="checkbox" id="use_dendro_order_$chart_title_str" checked onchange="updateChart_$chart_title()">
                <strong>Order by Dendrogram</strong>
            </label>
        </div>
        """
    else
        ""
    end

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

    # Include SortableJS library if manual ordering is enabled
    sortable_script = if allow_manual_order
        """<script src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/Sortable.min.js"></script>"""
    else
        ""
    end

    appearance_html = """
    $sortable_script
    <div class="corrplot-container">
        <h2>$title</h2>
        <p>$notes</p>
        $scenario_dropdown_html
        <div style="margin-bottom: 15px;">
            <label for="var_select_$chart_title_str"><strong>Select Variables:</strong></label><br>
            <select id="var_select_$chart_title_str" multiple size="8" style="width: 300px;" onchange="updateChart_$chart_title()">
            </select>
        </div>
        $order_toggle_html
        $manual_order_html
        <div id="dendrogram_$chart_title_str" style="width: 100%; height: 300px;"></div>
        <div id="corrmatrix_$chart_title_str" style="width: 100%; height: 600px;"></div>
    </div>
    $manual_order_styles
    """

    # Build functional HTML (raw JavaScript, no <script> tags)
    scenarios_json = JSON.json(scenarios_data)
    default_vars_json = JSON.json(default_vars)

    functional_html = """
    (function() {
        const scenarios = $scenarios_json;
        let currentScenario = scenarios[$(default_idx - 1)];
        let selectedVars = $default_vars_json;
        let manualOrder = null;
        let corrDataRaw = null;

        // Load correlation data from external dataset
        loadDataset('$(data_label)').then(function(data) {
            corrDataRaw = data;
            populateVarSelector();
            updateChart_$chart_title();
        }).catch(function(error) {
            console.error('Failed to load correlation data:', error);
        });

        // Initialize variable selector
        function populateVarSelector() {
            const select = document.getElementById('var_select_$chart_title_str');
            select.innerHTML = '';
            currentScenario.allLabels.forEach(v => {
                const option = document.createElement('option');
                option.value = v;
                option.text = v;
                option.selected = selectedVars.includes(v);
                select.appendChild(option);
            });
        }

        // Initialize sortable list
        function initializeSortable() {
            const container = document.getElementById('sortable_vars_$chart_title_str');
            container.innerHTML = '';
            // Show all variables in the manual order list
            const orderToUse = manualOrder || currentScenario.allLabels;
            orderToUse.forEach(v => {
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
                        updateChart_$chart_title();
                    }
                });
            }
        }

        window.updateChart_$chart_title = function() {
            if (!corrDataRaw) {
                console.warn('Correlation data not loaded yet');
                return;
            }

            // Check if scenario changed
            const scenarioSelect = document.getElementById('scenario_select_$chart_title_str');
            let scenarioChanged = false;
            if (scenarioSelect) {
                const scenarioName = scenarioSelect.value;
                const newScenario = scenarios.find(s => s.name === scenarioName);
                if (newScenario !== currentScenario) {
                    scenarioChanged = true;
                    // Remember currently selected variables
                    const varSelect = document.getElementById('var_select_$chart_title_str');
                    const previouslySelected = Array.from(varSelect.selectedOptions).map(opt => opt.value);

                    // Update to new scenario
                    currentScenario = newScenario;

                    // Repopulate variable selector with new scenario's variables
                    populateVarSelector();

                    // Try to keep the same variables selected if they exist in new scenario
                    const newVarSelect = document.getElementById('var_select_$chart_title_str');
                    const availableVars = Array.from(newVarSelect.options).map(opt => opt.value);
                    const varsToSelect = previouslySelected.filter(v => availableVars.includes(v));

                    // If none of the previous variables exist in new scenario, select all
                    if (varsToSelect.length < 2) {
                        selectedVars = currentScenario.allLabels;
                        Array.from(newVarSelect.options).forEach(opt => opt.selected = true);
                    } else {
                        selectedVars = varsToSelect;
                        Array.from(newVarSelect.options).forEach(opt => {
                            opt.selected = varsToSelect.includes(opt.value);
                        });
                    }
                }
            }

            // Update selected variables (if scenario didn't change)
            if (!scenarioChanged) {
                const varSelect = document.getElementById('var_select_$chart_title_str');
                selectedVars = Array.from(varSelect.selectedOptions).map(opt => opt.value);
            }

            if (selectedVars.length < 2) {
                console.warn('Select at least 2 variables');
                return;
            }

            // Check order mode
            const useDendroOrder = document.getElementById('use_dendro_order_$chart_title_str');
            const useManual = useDendroOrder && !useDendroOrder.checked;

            // Show/hide manual ordering UI
            const manualDiv = document.getElementById('manual_order_$chart_title_str');
            if (manualDiv) {
                manualDiv.style.display = useManual ? 'block' : 'none';
            }

            if (useManual) {
                initializeSortable();
            }

            // Determine variable order
            let orderedVars;
            if (useManual && manualOrder) {
                // Use manual order, filtered to selected vars
                orderedVars = manualOrder.filter(v => selectedVars.includes(v));
            } else {
                // Use dendrogram order
                orderedVars = currentScenario.labels.filter(v => selectedVars.includes(v));
            }

            const n = orderedVars.length;

            // Build correlation matrix for selected variables
            const zValues = [];
            const textValues = [];
            const hoverText = [];

            for (let i = 0; i < n; i++) {
                zValues[i] = [];
                textValues[i] = [];
                hoverText[i] = [];
                for (let j = 0; j < n; j++) {
                    if (i === j) {
                        // Diagonal
                        zValues[i][j] = 1.0;
                        textValues[i][j] = '1.00';
                        hoverText[i][j] = orderedVars[i];
                    } else {
                        // Find correlation values from external data
                        // Data can have either (asset1, asset2) or (asset2, asset1) ordering
                        let pearsonCorr = 0;
                        let spearmanCorr = 0;

                        const pearsonItem = corrDataRaw.find(d =>
                            d.scenario === currentScenario.name &&
                            d.correlation_method === 'pearson' &&
                            ((d.asset1 === orderedVars[i] && d.asset2 === orderedVars[j]) ||
                             (d.asset1 === orderedVars[j] && d.asset2 === orderedVars[i])));

                        const spearmanItem = corrDataRaw.find(d =>
                            d.scenario === currentScenario.name &&
                            d.correlation_method === 'spearman' &&
                            ((d.asset1 === orderedVars[i] && d.asset2 === orderedVars[j]) ||
                             (d.asset1 === orderedVars[j] && d.asset2 === orderedVars[i])));

                        pearsonCorr = pearsonItem ? pearsonItem.correlation : 0;
                        spearmanCorr = spearmanItem ? spearmanItem.correlation : 0;

                        if (i < j) {
                            // Upper-right triangle: always show Pearson
                            zValues[i][j] = pearsonCorr;
                            textValues[i][j] = 'P: ' + pearsonCorr.toFixed(2);
                            hoverText[i][j] = orderedVars[i] + ' vs ' + orderedVars[j] + '<br>Pearson: ' + pearsonCorr.toFixed(3);
                        } else {
                            // Lower-left triangle: always show Spearman
                            zValues[i][j] = spearmanCorr;
                            textValues[i][j] = 'S: ' + spearmanCorr.toFixed(2);
                            hoverText[i][j] = orderedVars[i] + ' vs ' + orderedVars[j] + '<br>Spearman: ' + spearmanCorr.toFixed(3);
                        }
                    }
                }
            }

            // Create heatmap
            const heatmapTrace = {
                z: zValues,
                x: orderedVars,
                y: orderedVars,
                type: 'heatmap',
                colorscale: [
                    [0, '#ff0000'],
                    [0.5, '#ffffff'],
                    [1, '#0000ff']
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
                        x: orderedVars[j],
                        y: orderedVars[i],
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

            // Draw dendrogram (only if using dendrogram order and all variables are selected)
            const dendroDiv = document.getElementById('dendrogram_$chart_title_str');
            const allVarsSelected = selectedVars.length === currentScenario.allLabels.length;

            if (!useManual && allVarsSelected && currentScenario.dendroData.shapes && currentScenario.dendroData.shapes.length > 0) {
                dendroDiv.style.display = 'block';

                // Show full dendrogram with all variables
                const selectedIndices = orderedVars.map(v => currentScenario.labels.indexOf(v));
                const leafTrace = {
                    x: selectedIndices,
                    y: Array(n).fill(0),
                    mode: 'text',
                    type: 'scatter',
                    text: orderedVars,
                    textposition: 'bottom center',
                    textfont: { size: 10 },
                    hoverinfo: 'text',
                    showlegend: false
                };

                const dendroLayout = {
                    title: 'Hierarchical Clustering Dendrogram',
                    xaxis: {
                        visible: false,
                        range: [Math.min(...selectedIndices) - 0.5, Math.max(...selectedIndices) + 0.5]
                    },
                    yaxis: {
                        title: 'Height',
                        range: [0, currentScenario.dendroData.maxHeight * 1.15]
                    },
                    margin: { l: 80, r: 50, b: 120, t: 50 },
                    showlegend: false,
                    shapes: currentScenario.dendroData.shapes
                };

                Plotly.newPlot('dendrogram_$chart_title_str', [leafTrace], dendroLayout, {responsive: true});
            } else {
                dendroDiv.style.display = 'none';
            }
        };

        // Note: populateVarSelector() and updateChart_$chart_title() are called
        // after data loads in the loadDataset promise above
    })();
    """

    # Use the inner constructor from corrplot.jl
    return CorrPlot(chart_title, data_label, functional_html, appearance_html)
end

# Helper function to prepare correlation data for advanced CorrPlot
function prepare_corrplot_advanced_data(scenarios::Vector{CorrelationScenario})
    asset1_vec = String[]
    asset2_vec = String[]
    correlation_vec = Float64[]
    scenario_vec = String[]
    correlation_method_vec = String[]

    for scenario in scenarios
        n = length(scenario.var_labels)

        # Store correlations for all unique pairs
        for i in 1:n
            for j in (i+1):n  # Only upper triangle, excluding diagonal
                asset1 = scenario.var_labels[i]
                asset2 = scenario.var_labels[j]

                # Add Pearson correlation
                push!(asset1_vec, asset1)
                push!(asset2_vec, asset2)
                push!(correlation_vec, scenario.pearson[i, j])
                push!(scenario_vec, scenario.name)
                push!(correlation_method_vec, "pearson")

                # Add Spearman correlation
                push!(asset1_vec, asset1)
                push!(asset2_vec, asset2)
                push!(correlation_vec, scenario.spearman[i, j])
                push!(scenario_vec, scenario.name)
                push!(correlation_method_vec, "spearman")
            end
        end
    end

    return DataFrame(
        asset1 = asset1_vec,
        asset2 = asset2_vec,
        correlation = correlation_vec,
        scenario = scenario_vec,
        correlation_method = correlation_method_vec
    )
end
