"""
    RadarChart struct (internal representation)

Internal struct that stores the generated HTML for a radar chart.
Use the `RadarChart()` constructor function to create radar charts.
"""
struct RadarChartInternal <: JSPlotsType
    chart_id::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
end

# Dependencies
dependencies(r::RadarChartInternal) = [r.data_label]
js_dependencies(::RadarChartInternal) = vcat(JS_DEP_JQUERY, JS_DEP_D3)

"""
    RadarChart(chart_id, data_label; kwargs...)

Create a radar chart (also known as spider chart or web chart) that displays multivariate data on axes starting from the same point.

# Arguments
- `chart_id::Symbol`: Unique identifier for the chart
- `data_label::Symbol`: Label for the data source
- `value_cols::Vector{Symbol}`: Columns containing numeric values to plot on radar axes (minimum 3)
- `label_col::Symbol=:label`: Column containing labels for each radar chart (one per row)
- `group_mapping::Dict{Symbol, String}=Dict()`: Maps value columns to group names for axis grouping
- `variable_limits::Dict{Symbol, Float64}=Dict()`: Maps value columns to their maximum limits for display
- `scenario_col::Union{Nothing, Symbol}=nothing`: Column for scenario selection
- `variable_selector::Bool=false`: Whether to show variable selector dropdown
- `max_variables::Union{Nothing, Int}=nothing`: Maximum number of variables to show at once (defaults to min(10, n_variables) if variable_selector=true)
- `color_col::Union{Nothing, Symbol}=nothing`: Column to use for coloring radar charts
- `default_color::String="#1f77b4"`: Default color if no color_col specified
- `title::String="Radar Chart"`: Chart title
- `notes::String=""`: Additional notes or description
- `max_value::Union{Nothing, Float64}=nothing`: Global maximum value for radar chart scale (auto-calculated if nothing, overridden by variable_limits)
- `show_legend::Bool=true`: Whether to show legend
- `show_grid_labels::Bool=true`: Whether to show labels on grid circles

# Example
```julia
df = DataFrame(
    label = ["Product A", "Product B"],
    Quality = [8.5, 7.2],
    Price = [6.0, 9.0],
    Features = [9.0, 7.5],
    Support = [7.5, 8.0]
)

radar = RadarChart(:my_radar, :my_data;
    value_cols = [:Quality, :Price, :Features, :Support],
    label_col = :label,
    title = "Product Comparison"
)
```
"""
function RadarChart(
    chart_id::Symbol,
    data_label::Symbol;
    value_cols::Vector{Symbol},
    label_col::Symbol = :label,
    group_mapping::Dict{Symbol, String} = Dict{Symbol, String}(),
    variable_limits::Dict{Symbol, Float64} = Dict{Symbol, Float64}(),
    scenario_col::Union{Nothing, Symbol} = nothing,
    variable_selector::Bool = false,
    max_variables::Union{Nothing, Int} = nothing,
    color_col::Union{Nothing, Symbol} = nothing,
    default_color::String = "#1f77b4",
    title::String = "Radar Chart",
    notes::String = "",
    max_value::Union{Nothing, Float64} = nothing,
    show_legend::Bool = true,
    show_grid_labels::Bool = true
)

    # Validate inputs
    if length(value_cols) < 3
        error("RadarChart requires at least 3 value columns")
    end

    if variable_selector && isnothing(max_variables)
        max_variables = min(10, length(value_cols))
    end

    chart_id_str = string(chart_id)

    # Build appearance HTML
    appearance_html = build_radar_appearance_html(
        chart_id_str, title, notes, variable_selector, scenario_col
    )

    # Build functional HTML
    functional_html = build_radar_functional_html(
        chart_id_str, data_label, value_cols, label_col, group_mapping,
        variable_limits, scenario_col, variable_selector, max_variables, color_col,
        default_color, max_value, show_legend, show_grid_labels
    )

    return RadarChartInternal(chart_id, data_label, functional_html, appearance_html)
end

"""
Build the appearance HTML (controls and title) for the radar chart.
"""
function build_radar_appearance_html(
    chart_id_str::String,
    title::String,
    notes::String,
    variable_selector::Bool,
    scenario_col::Union{Nothing, Symbol}
)
    html_parts = ["""
    <div class="chart-container" id="container_$(chart_id_str)">
        <h3>$(title)</h3>
        $(isempty(notes) ? "" : "<p>$(notes)</p>")
        <div style="display: flex; gap: 20px; flex-wrap: wrap;">
            <div style="flex: 0 0 auto; min-width: 200px;">
    """]

    # Scenario selector
    if !isnothing(scenario_col)
        push!(html_parts, """
        <div style="margin-bottom: 15px;">
            <label for="scenario_select_$(chart_id_str)"><strong>Scenario:</strong></label>
            <select id="scenario_select_$(chart_id_str)" onchange="updateRadarChart_$(chart_id_str)()">
                <!-- Options will be populated dynamically -->
            </select>
        </div>
        """)
    end

    # Variable selector
    if variable_selector
        push!(html_parts, """
        <div style="margin-bottom: 15px;">
            <label for="var_select_$(chart_id_str)"><strong>Select variables:</strong></label>
            <select id="var_select_$(chart_id_str)" multiple size="8" style="width: 100%; max-width: 300px;" onchange="updateRadarChart_$(chart_id_str)()">
                <!-- Options will be populated dynamically -->
            </select>
            <div style="margin-top: 5px; font-size: 0.9em; color: #666;">
                Hold Ctrl (Cmd on Mac) to select multiple
            </div>
        </div>
        """)
    end

    # Label selector
    push!(html_parts, """
    <div style="margin-bottom: 15px;">
        <label for="label_select_$(chart_id_str)"><strong>Select items to display:</strong></label>
        <select id="label_select_$(chart_id_str)" multiple size="6" style="width: 100%; max-width: 300px;" onchange="updateRadarChart_$(chart_id_str)()">
            <!-- Options will be populated dynamically -->
        </select>
        <div style="margin-top: 5px; font-size: 0.9em; color: #666;">
            Hold Ctrl (Cmd on Mac) to select multiple
        </div>
    </div>
    """)

    push!(html_parts, """
            </div>
            <div style="flex: 1 1 auto; min-width: 400px;">
                <div id="radar_$(chart_id_str)" style="width: 100%;"></div>
            </div>
        </div>
    </div>
    """)

    return join(html_parts, "\n")
end

"""
Build the functional HTML (JavaScript and chart rendering) for the radar chart.
"""
function build_radar_functional_html(
    chart_id_str::String,
    data_label::Symbol,
    value_cols::Vector{Symbol},
    label_col::Symbol,
    group_mapping::Dict{Symbol, String},
    variable_limits::Dict{Symbol, Float64},
    scenario_col::Union{Nothing, Symbol},
    variable_selector::Bool,
    max_variables::Union{Nothing, Int},
    color_col::Union{Nothing, Symbol},
    default_color::String,
    max_value::Union{Nothing, Float64},
    show_legend::Bool,
    show_grid_labels::Bool
)
    data_label_str = string(data_label)
    value_cols_json = JSON.json(string.(value_cols))
    label_col_str = string(label_col)
    group_mapping_json = JSON.json(Dict(string(k) => v for (k, v) in group_mapping))
    variable_limits_json = JSON.json(Dict(string(k) => v for (k, v) in variable_limits))
    scenario_col_str = isnothing(scenario_col) ? "null" : "\"$(scenario_col)\""
    color_col_str = isnothing(color_col) ? "null" : "\"$(color_col)\""
    max_value_str = isnothing(max_value) ? "null" : string(max_value)
    max_variables_str = isnothing(max_variables) ? "null" : string(max_variables)

    return """
    (function() {
        let radarData_$(chart_id_str) = null;
        let selectedVariables_$(chart_id_str) = $(value_cols_json);
        let selectedLabels_$(chart_id_str) = [];
        let selectedScenario_$(chart_id_str) = null;

        const VALUE_COLS = $(value_cols_json);
        const LABEL_COL = "$(label_col_str)";
        const GROUP_MAPPING = $(group_mapping_json);
        const VARIABLE_LIMITS = $(variable_limits_json);
        const SCENARIO_COL = $(scenario_col_str);
        const COLOR_COL = $(color_col_str);
        const DEFAULT_COLOR = "$(default_color)";
        const MAX_VALUE = $(max_value_str);
        const MAX_VARIABLES = $(max_variables_str);
        const SHOW_LEGEND = $(show_legend);
        const SHOW_GRID_LABELS = $(show_grid_labels);
        const VARIABLE_SELECTOR = $(variable_selector);

        // Load data
        loadDataset('$(data_label_str)').then(function(data) {
            radarData_$(chart_id_str) = data;
            initializeRadarChart_$(chart_id_str)();
        }).catch(function(error) {
            console.error('Error loading data:', error);
            document.getElementById('radar_$(chart_id_str)').innerHTML =
                '<p style="color: red;">Error loading data: ' + error.message + '</p>';
        });

        function initializeRadarChart_$(chart_id_str)() {
            const data = radarData_$(chart_id_str);
            if (!data || data.length === 0) {
                document.getElementById('radar_$(chart_id_str)').innerHTML = '<p>No data available</p>';
                return;
            }

            // Populate scenario selector
            if (SCENARIO_COL) {
                const scenarioSelect = document.getElementById('scenario_select_$(chart_id_str)');
                if (scenarioSelect) {
                    const uniqueScenarios = [...new Set(data.map(d => d[SCENARIO_COL]))].filter(s => s);
                    scenarioSelect.innerHTML = '';
                    uniqueScenarios.forEach(function(scenario, idx) {
                        const option = document.createElement('option');
                        option.value = scenario;
                        option.text = scenario;
                        if (idx === 0) {
                            option.selected = true;
                            selectedScenario_$(chart_id_str) = scenario;
                        }
                        scenarioSelect.appendChild(option);
                    });
                }
            }

            // Populate variable selector
            if (VARIABLE_SELECTOR) {
                const varSelect = document.getElementById('var_select_$(chart_id_str)');
                if (varSelect) {
                    varSelect.innerHTML = '';
                    VALUE_COLS.forEach(function(col) {
                        const option = document.createElement('option');
                        option.value = col;
                        option.text = col.replace(/_/g, ' ');
                        option.selected = selectedVariables_$(chart_id_str).includes(col);
                        varSelect.appendChild(option);
                    });
                }
            } else {
                selectedVariables_$(chart_id_str) = VALUE_COLS;
            }

            // Populate label selector
            const labelSelect = document.getElementById('label_select_$(chart_id_str)');
            if (labelSelect) {
                // Filter by scenario if applicable
                let scenarioData = data;
                if (SCENARIO_COL && selectedScenario_$(chart_id_str)) {
                    scenarioData = data.filter(d => d[SCENARIO_COL] === selectedScenario_$(chart_id_str));
                }

                const uniqueLabels = [...new Set(scenarioData.map(d => d[LABEL_COL]))].filter(l => l);
                labelSelect.innerHTML = '';
                uniqueLabels.forEach(function(label) {
                    const option = document.createElement('option');
                    option.value = label;
                    option.text = label;
                    option.selected = true;
                    labelSelect.appendChild(option);
                });
                const maxToSelect = MAX_VARIABLES || uniqueLabels.length;
                selectedLabels_$(chart_id_str) = uniqueLabels.slice(0, maxToSelect);

                // Set selected options
                Array.from(labelSelect.options).forEach(function(opt) {
                    opt.selected = selectedLabels_$(chart_id_str).includes(opt.value);
                });
            }

            updateRadarChart_$(chart_id_str)();
        }

        window.updateRadarChart_$(chart_id_str) = function() {
            // Get selected scenario
            if (SCENARIO_COL) {
                const scenarioSelect = document.getElementById('scenario_select_$(chart_id_str)');
                if (scenarioSelect) {
                    selectedScenario_$(chart_id_str) = scenarioSelect.value;
                }
            }

            // Get selected variables
            if (VARIABLE_SELECTOR) {
                const varSelect = document.getElementById('var_select_$(chart_id_str)');
                if (varSelect) {
                    selectedVariables_$(chart_id_str) = Array.from(varSelect.selectedOptions).map(opt => opt.value);

                    if (selectedVariables_$(chart_id_str).length < 3) {
                        document.getElementById('radar_$(chart_id_str)').innerHTML =
                            '<p style="color: orange;">Please select at least 3 variables to display a radar chart.</p>';
                        return;
                    }
                }
            }

            // Get selected labels
            const labelSelect = document.getElementById('label_select_$(chart_id_str)');
            if (labelSelect) {
                selectedLabels_$(chart_id_str) = Array.from(labelSelect.selectedOptions).map(opt => opt.value);

                if (selectedLabels_$(chart_id_str).length === 0) {
                    document.getElementById('radar_$(chart_id_str)').innerHTML =
                        '<p style="color: orange;">Please select at least one item to display.</p>';
                    return;
                }
            }

            renderRadarChart_$(chart_id_str)(selectedVariables_$(chart_id_str), selectedLabels_$(chart_id_str), selectedScenario_$(chart_id_str));
        }

        function renderRadarChart_$(chart_id_str)(variables, labels, scenario) {
            const data = radarData_$(chart_id_str);
            const container = document.getElementById('radar_$(chart_id_str)');
            if (!container) return;

            container.innerHTML = '';

            // Filter data by labels and scenario
            let filteredData = data.filter(d => labels.includes(d[LABEL_COL]));

            if (SCENARIO_COL && scenario) {
                filteredData = filteredData.filter(d => d[SCENARIO_COL] === scenario);
            }

            if (filteredData.length === 0) {
                container.innerHTML = '<p>No data matches the selected filters.</p>';
                return;
            }

            // Calculate max value per variable (respecting variable_limits)
            const maxValues = {};
            variables.forEach(function(v) {
                if (VARIABLE_LIMITS.hasOwnProperty(v)) {
                    maxValues[v] = VARIABLE_LIMITS[v];
                } else if (MAX_VALUE) {
                    maxValues[v] = MAX_VALUE;
                } else {
                    // Auto-calculate from data
                    let maxVal = 0;
                    filteredData.forEach(function(d) {
                        const val = parseFloat(d[v]);
                        if (!isNaN(val) && val > maxVal) {
                            maxVal = val;
                        }
                    });
                    maxValues[v] = Math.ceil(maxVal * 1.1);
                }
            });

            // Group variables by group_mapping
            const groupedVars = {};
            const ungroupedVars = [];

            variables.forEach(function(v) {
                if (GROUP_MAPPING.hasOwnProperty(v)) {
                    const group = GROUP_MAPPING[v];
                    if (!groupedVars[group]) {
                        groupedVars[group] = [];
                    }
                    groupedVars[group].push(v);
                } else {
                    ungroupedVars.push(v);
                }
            });

            // Create ordered list of axes with groups
            const axes = [];
            const groupBoundaries = [];  // Track where each group starts and ends
            let currentIndex = 0;

            // Sort groups for consistent ordering
            const sortedGroups = Object.keys(groupedVars).sort();

            sortedGroups.forEach(function(group) {
                const startIdx = currentIndex;
                groupedVars[group].forEach(function(v) {
                    axes.push({ name: v, group: group, maxValue: maxValues[v] });
                    currentIndex++;
                });
                const endIdx = currentIndex - 1;
                groupBoundaries.push({ group: group, startIdx: startIdx, endIdx: endIdx });
            });

            ungroupedVars.forEach(function(v) {
                axes.push({ name: v, group: null, maxValue: maxValues[v] });
                currentIndex++;
            });

            // Create color mapping
            const colorMap = {};
            if (COLOR_COL) {
                const uniqueColors = [...new Set(filteredData.map(d => d[COLOR_COL]))];
                // D3 v3 API: use d3.scale.category10()
                const colorScale = d3.scale.category10();
                uniqueColors.forEach(function(c, i) {
                    colorMap[c] = colorScale(i);
                });
            }

            // Calculate layout
            const numCharts = filteredData.length;
            const chartsPerRow = Math.ceil(Math.sqrt(numCharts));
            const chartSize = Math.min(450, Math.max(350, Math.floor((container.offsetWidth || 800) / chartsPerRow)));

            // Create SVG container
            const svg = d3.select(container)
                .append('svg')
                .attr('width', '100%')
                .attr('height', Math.ceil(numCharts / chartsPerRow) * chartSize);

            // Draw each radar chart
            filteredData.forEach(function(d, idx) {
                const row = Math.floor(idx / chartsPerRow);
                const col = idx % chartsPerRow;
                const x = col * chartSize;
                const y = row * chartSize;

                const color = COLOR_COL ? (colorMap[d[COLOR_COL]] || DEFAULT_COLOR) : DEFAULT_COLOR;

                drawSingleRadar_$(chart_id_str)(svg, d, axes, groupBoundaries, x, y, chartSize, color);
            });

            // Add legend
            if (SHOW_LEGEND && COLOR_COL) {
                addLegend_$(chart_id_str)(container, colorMap);
            }
        }

        function drawSingleRadar_$(chart_id_str)(svg, dataPoint, axes, groupBoundaries, offsetX, offsetY, size, color) {
            const margin = 60;
            const radius = (size - 2 * margin) / 2;
            const centerX = offsetX + size / 2;
            const centerY = offsetY + size / 2;

            const g = svg.append('g')
                .attr('transform', 'translate(' + centerX + ',' + centerY + ')');

            // Determine overall max for grid (use the max of all variable maxes for consistent grid)
            let gridMax = 0;
            axes.forEach(function(axis) {
                if (axis.maxValue > gridMax) gridMax = axis.maxValue;
            });

            // Draw grid circles
            const levels = 5;
            for (let i = 1; i <= levels; i++) {
                const r = radius * i / levels;
                g.append('circle')
                    .attr('r', r)
                    .attr('fill', 'none')
                    .attr('stroke', '#ddd')
                    .attr('stroke-width', 1);

                if (SHOW_GRID_LABELS && i === levels) {
                    g.append('text')
                        .attr('x', 5)
                        .attr('y', -r)
                        .attr('font-size', '10px')
                        .attr('fill', '#666')
                        .text(gridMax.toFixed(1));
                }
            }

            // Draw axes
            const angleSlice = Math.PI * 2 / axes.length;

            axes.forEach(function(axis, i) {
                const angle = angleSlice * i - Math.PI / 2;
                const x = radius * Math.cos(angle);
                const y = radius * Math.sin(angle);

                // Draw axis line
                g.append('line')
                    .attr('x1', 0)
                    .attr('y1', 0)
                    .attr('x2', x)
                    .attr('y2', y)
                    .attr('stroke', '#999')
                    .attr('stroke-width', 1);

                // Draw axis label
                const labelRadius = radius + 15;
                const labelX = labelRadius * Math.cos(angle);
                const labelY = labelRadius * Math.sin(angle);

                g.append('text')
                    .attr('x', labelX)
                    .attr('y', labelY)
                    .attr('text-anchor', 'middle')
                    .attr('dominant-baseline', 'middle')
                    .attr('font-size', '10px')
                    .attr('fill', '#333')
                    .text(axis.name.replace(/_/g, ' '));
            });

            // Draw group labels using boundaries
            groupBoundaries.forEach(function(boundary) {
                const startAngle = angleSlice * boundary.startIdx - Math.PI / 2;
                const endAngle = angleSlice * (boundary.endIdx + 1) - Math.PI / 2;
                const midAngle = (startAngle + endAngle) / 2;
                const labelRadius = radius + 40;
                const x = labelRadius * Math.cos(midAngle);
                const y = labelRadius * Math.sin(midAngle);

                g.append('text')
                    .attr('x', x)
                    .attr('y', y)
                    .attr('text-anchor', 'middle')
                    .attr('dominant-baseline', 'middle')
                    .attr('font-size', '12px')
                    .attr('font-weight', 'bold')
                    .attr('fill', '#0066cc')
                    .text(boundary.group);
            });

            // Draw data polygon
            const points = [];
            axes.forEach(function(axis, i) {
                const value = parseFloat(dataPoint[axis.name]) || 0;
                // Clamp value to axis max, then normalize by grid max for consistent display
                const clampedValue = Math.min(value, axis.maxValue);
                const normalizedValue = Math.min(Math.max(clampedValue / gridMax, 0), 1);
                const angle = angleSlice * i - Math.PI / 2;
                const r = radius * normalizedValue;
                const x = r * Math.cos(angle);
                const y = r * Math.sin(angle);
                points.push([x, y]);
            });

            // Close the polygon
            if (points.length > 0) {
                const pathData = 'M' + points.map(p => p.join(',')).join('L') + 'Z';

                g.append('path')
                    .attr('d', pathData)
                    .attr('fill', color)
                    .attr('fill-opacity', 0.3)
                    .attr('stroke', color)
                    .attr('stroke-width', 2);

                // Draw points
                points.forEach(function(p) {
                    g.append('circle')
                        .attr('cx', p[0])
                        .attr('cy', p[1])
                        .attr('r', 3)
                        .attr('fill', color);
                });
            }

            // Add title
            g.append('text')
                .attr('x', 0)
                .attr('y', -radius - 45)
                .attr('text-anchor', 'middle')
                .attr('font-size', '12px')
                .attr('font-weight', 'bold')
                .attr('fill', '#333')
                .text(dataPoint[LABEL_COL]);
        }

        function addLegend_$(chart_id_str)(container, colorMap) {
            const legendDiv = document.createElement('div');
            legendDiv.style.marginTop = '20px';
            legendDiv.innerHTML = '<strong>Legend:</strong>';

            const legendItems = document.createElement('div');
            legendItems.style.display = 'flex';
            legendItems.style.flexWrap = 'wrap';
            legendItems.style.gap = '15px';
            legendItems.style.marginTop = '10px';

            Object.keys(colorMap).forEach(function(key) {
                const item = document.createElement('div');
                item.style.display = 'flex';
                item.style.alignItems = 'center';
                item.style.gap = '5px';

                const colorBox = document.createElement('div');
                colorBox.style.width = '20px';
                colorBox.style.height = '20px';
                colorBox.style.backgroundColor = colorMap[key];
                colorBox.style.border = '1px solid #ccc';

                const label = document.createElement('span');
                label.textContent = key;

                item.appendChild(colorBox);
                item.appendChild(label);
                legendItems.appendChild(item);
            });

            legendDiv.appendChild(legendItems);
            container.appendChild(legendDiv);
        }
    })();
    """
end
