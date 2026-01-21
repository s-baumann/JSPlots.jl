# t-SNE visualization with interactive controls

"""
    TSNEPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive t-SNE (t-Distributed Stochastic Neighbor Embedding) visualization.

t-SNE is a dimensionality reduction technique that maps high-dimensional data to 2D
while preserving local structure. This implementation runs entirely in the browser,
allowing users to interactively adjust parameters and observe the optimization process.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data (see Data Formats below)
- `data_label::Symbol`: Label for the data in external storage

# Keyword Arguments
- `entity_col::Symbol`: Column identifying each entity/point (default: `:entity`)
- `label_col::Union{Symbol, Nothing}`: Column for display labels (default: uses entity_col)
- `feature_cols::Union{Vector{Symbol}, Nothing}`: Initial columns for distance calculation (default: all numeric)
- `distance_matrix::Bool`: If true, df is a distance/proximity matrix with columns `node1`, `node2`, `distance` (default: `false`)
- `color_cols::Vector{Symbol}`: Columns available for coloring nodes (default: `Symbol[]`)
- `tooltip_cols::Vector{Symbol}`: Additional columns to show in tooltips (default: `Symbol[]`)
- `colour_map::Union{Missing,Dict{Float64,String},Dict{String,Dict{Float64,String}}}`: Color gradient for continuous variables (default: `missing`)
- `extrapolate_colors::Bool`: Whether to extrapolate colors beyond gradient stops (default: `false`, clamps to min/max colors)
- `perplexity::Float64`: t-SNE perplexity parameter (default: `30.0`)
- `learning_rate::Float64`: t-SNE learning rate (default: `200.0`)
- `title::String`: Chart title (default: `"t-SNE Visualization"`)
- `notes::String`: Descriptive text (default: `""`)

# Interactive Features
- **Variable Selection**: Drag features between "Available" and "Selected" lists to change which
  variables are used for distance calculation. The t-SNE will recalculate automatically.
- Randomize initial positions
- Step forward one iteration at a time
- Run until convergence with adjustable threshold
- Drag nodes to manually reposition
- Color nodes by categorical or continuous variables (with gradient support)
- Hover tooltips with entity details

# Data Format for Distance Matrix
When `distance_matrix=true`, the DataFrame should have columns:
- `node1`: First node/entity name
- `node2`: Second node/entity name
- `distance`: Distance or dissimilarity value between the nodes

# Example
```julia
df = DataFrame(
    city = ["New York", "London", "Tokyo", "Paris"],
    population = [8.3, 9.0, 14.0, 2.1],
    gdp = [75000, 55000, 42000, 45000],
    region = ["Americas", "Europe", "Asia", "Europe"]
)

tsne = TSNEPlot(:cities_tsne, df, :city_data;
    entity_col = :city,
    feature_cols = [:population, :gdp],  # Initial selection
    color_cols = [:region],
    title = "City Similarity"
)
```
"""
struct TSNEPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function TSNEPlot(chart_title::Symbol,
                      df::DataFrame,
                      data_label::Symbol;
                      entity_col::Symbol = :entity,
                      label_col::Union{Symbol, Nothing} = nothing,
                      feature_cols::Union{Vector{Symbol}, Nothing} = nothing,
                      distance_matrix::Bool = false,
                      color_cols::Vector{Symbol} = Symbol[],
                      tooltip_cols::Vector{Symbol} = Symbol[],
                      colour_map::Union{Missing,Dict{Float64,String},Dict{String,Dict{Float64,String}}} = missing,
                      extrapolate_colors::Bool = false,
                      perplexity::Float64 = 30.0,
                      learning_rate::Float64 = 200.0,
                      title::String = "t-SNE Visualization",
                      notes::String = "")

        chart_title_str = string(chart_title)
        df_col_names = Symbol.(names(df))

        # Validate based on data format
        if distance_matrix
            required_cols = [:node1, :node2, :distance]
            for col in required_cols
                if !(col in df_col_names)
                    error("Distance matrix must have columns: node1, node2, distance. Missing: $col")
                end
            end
            entities = unique(vcat(df.node1, df.node2))
            all_numeric_cols = Symbol[]
            initial_feature_cols = Symbol[]
        else
            if !(entity_col in df_col_names)
                error("Entity column $entity_col not found in DataFrame")
            end

            # Find all numeric columns (excluding entity/label cols)
            all_numeric_cols = Symbol[]
            for col in df_col_names
                if col != entity_col && col != label_col
                    col_type = eltype(skipmissing(df[!, col]))
                    if col_type <: Number
                        push!(all_numeric_cols, col)
                    end
                end
            end

            # Determine initial feature columns
            if !isnothing(feature_cols)
                for col in feature_cols
                    if !(col in df_col_names)
                        error("Feature column $col not found in DataFrame")
                    end
                end
                initial_feature_cols = feature_cols
            else
                initial_feature_cols = all_numeric_cols
            end

            entities = unique(df[!, entity_col])
        end

        # Validate label column
        actual_label_col = isnothing(label_col) ? entity_col : label_col
        if !distance_matrix && !(actual_label_col in df_col_names)
            @warn "Label column $actual_label_col not found, using entity_col"
            actual_label_col = entity_col
        end

        # Validate color columns
        valid_color_cols = Symbol[]
        for col in color_cols
            if col in df_col_names
                push!(valid_color_cols, col)
            else
                @warn "Color column $col not found in DataFrame, it will be ignored"
            end
        end

        # Validate tooltip columns
        valid_tooltip_cols = Symbol[]
        for col in tooltip_cols
            if col in df_col_names && !(col in valid_color_cols)
                push!(valid_tooltip_cols, col)
            elseif !(col in df_col_names)
                @warn "Tooltip column $col not found in DataFrame, it will be ignored"
            end
        end

        all_tooltip_cols = vcat(valid_color_cols, valid_tooltip_cols)

        # Detect continuous vs discrete color columns
        continuous_cols = Symbol[]
        discrete_cols = Symbol[]
        for col in valid_color_cols
            if col in df_col_names
                col_values = df[!, col]
                non_missing = filter(x -> !ismissing(x), col_values)
                if !isempty(non_missing) && all(x -> x isa Number, non_missing)
                    push!(continuous_cols, col)
                else
                    push!(discrete_cols, col)
                end
            else
                push!(discrete_cols, col)
            end
        end

        # Validate colour_map structure if provided
        if !ismissing(colour_map)
            if colour_map isa Dict{Float64,String}
                if length(colour_map) < 2
                    error("colour_map must have at least 2 gradient stops")
                end
            elseif colour_map isa Dict{String,Dict{Float64,String}}
                for (var_name, gradient) in colour_map
                    if length(gradient) < 2
                        error("colour_map gradient for variable '$var_name' must have at least 2 stops")
                    end
                end
            else
                error("colour_map must be Dict{Float64,String} or Dict{String,Dict{Float64,String}}")
            end
        end

        # JSON for JS
        all_numeric_cols_json = JSON.json([String(c) for c in all_numeric_cols])
        initial_feature_cols_json = JSON.json([String(c) for c in initial_feature_cols])

        # Build HTML
        appearance_html = build_tsne_appearance_html(
            chart_title_str, title, notes,
            valid_color_cols, perplexity, learning_rate, all_tooltip_cols, distance_matrix,
            continuous_cols, discrete_cols
        )

        functional_html = build_tsne_functional_html(
            chart_title_str, data_label,
            String(entity_col), String(actual_label_col),
            all_numeric_cols_json, initial_feature_cols_json, distance_matrix,
            valid_color_cols, perplexity, learning_rate, all_tooltip_cols,
            continuous_cols, discrete_cols, colour_map, extrapolate_colors
        )

        return new(chart_title, data_label, functional_html, appearance_html)
    end
end

function build_tsne_appearance_html(chart_title_str, title, notes,
                                     color_cols, perplexity, learning_rate, tooltip_cols, distance_matrix,
                                     continuous_cols, discrete_cols)

    # Color selector with continuous/discrete indicators
    color_selector_html = if !isempty(color_cols)
        discrete_options = join(["""<option value="$col">$col (discrete)</option>"""
                                for col in discrete_cols], "\n                ")
        continuous_options = join(["""<option value="$col">$col (continuous)</option>"""
                                   for col in continuous_cols], "\n                ")

        all_options = if !isempty(discrete_options) && !isempty(continuous_options)
            discrete_options * "\n                " * continuous_options
        elseif !isempty(discrete_options)
            discrete_options
        else
            continuous_options
        end

        """
        <div style="margin-bottom: 10px;">
            <label for="color_select_$chart_title_str"><strong>Color nodes by:</strong></label>
            <select id="color_select_$chart_title_str" onchange="updateColors_$chart_title_str()">
                <option value="none">None (uniform color)</option>
                $all_options
            </select>
        </div>
        """
    else
        ""
    end

    # Variable selection UI (only for feature-based mode)
    variable_selection_html = if !distance_matrix
        """
        <div style="margin-bottom: 15px; padding: 10px; background-color: #f0f0f0; border-radius: 4px;">
            <strong>Feature Selection for Distance Calculation:</strong>
            <div style="display: flex; gap: 20px; margin-top: 10px;">
                <div style="flex: 1;">
                    <label><strong>Available Features:</strong></label>
                    <select id="available_features_$chart_title_str" multiple size="6" style="width: 100%; margin-top: 5px;">
                    </select>
                </div>
                <div style="display: flex; flex-direction: column; justify-content: center; gap: 5px;">
                    <button onclick="addFeature_$chart_title_str()" style="padding: 5px 15px;">&rarr; Add</button>
                    <button onclick="removeFeature_$chart_title_str()" style="padding: 5px 15px;">&larr; Remove</button>
                </div>
                <div style="flex: 1;">
                    <label><strong>Selected Features:</strong></label>
                    <select id="selected_features_$chart_title_str" multiple size="6" style="width: 100%; margin-top: 5px;">
                    </select>
                </div>
            </div>
            <div style="margin-top: 10px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
                <label><strong>Rescaling:</strong></label>
                <select id="rescaling_$chart_title_str" style="padding: 4px 8px;">
                    <option value="none">No rescaling</option>
                    <option value="zscore" selected>Z-score</option>
                    <option value="zscore_capped">Z-score (capped at ±2)</option>
                    <option value="quantile">Quantile (0 to 1)</option>
                </select>
                <button onclick="recalculateDistances_$chart_title_str()" style="padding: 8px 16px; background-color: #9b59b6; color: white; border: none; border-radius: 4px; cursor: pointer;">
                    Recalculate Distances & Reset
                </button>
                <span style="font-size: 11px; color: #666;">(Changes which variables determine similarity)</span>
            </div>
        </div>
        """
    else
        ""
    end

    # Perplexity slider
    perplexity_slider = """
    <div style="margin-bottom: 10px;">
        <label for="perplexity_slider_$chart_title_str"><strong>Perplexity:</strong>
               <span id="perplexity_value_$chart_title_str">$perplexity</span>
        </label>
        <input type="range" id="perplexity_slider_$chart_title_str"
               min="5" max="100" step="1" value="$perplexity"
               style="width: 50%; margin-left: 10px;"
               oninput="document.getElementById('perplexity_value_$chart_title_str').textContent = this.value;">
        <span style="font-size: 11px; color: #666; margin-left: 5px;">(5-100, typically 15-50)</span>
    </div>
    """

    # Learning rate slider
    learning_rate_slider = """
    <div style="margin-bottom: 10px;">
        <label for="lr_slider_$chart_title_str"><strong>Learning Rate:</strong>
               <span id="lr_value_$chart_title_str">$learning_rate</span>
        </label>
        <input type="range" id="lr_slider_$chart_title_str"
               min="10" max="1000" step="10" value="$learning_rate"
               style="width: 50%; margin-left: 10px;"
               oninput="document.getElementById('lr_value_$chart_title_str').textContent = this.value;">
        <span style="font-size: 11px; color: #666; margin-left: 5px;">(10-1000, typically 100-500)</span>
    </div>
    """

    # Control buttons
    control_buttons = """
    <div style="margin-bottom: 15px; display: flex; gap: 10px; flex-wrap: wrap; align-items: center;">
        <button id="randomize_btn_$chart_title_str" onclick="randomizePositions_$chart_title_str()"
                style="padding: 8px 16px; background-color: #3498db; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Randomize Positions
        </button>
        <button id="step_btn_$chart_title_str" onclick="stepIteration_$chart_title_str(false)"
                style="padding: 8px 16px; background-color: #27ae60; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Step (small)
        </button>
        <button id="exag_step_btn_$chart_title_str" onclick="stepIteration_$chart_title_str(true)"
                style="padding: 8px 16px; background-color: #f39c12; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Exaggerated Step
        </button>
        <button id="run_btn_$chart_title_str" onclick="toggleRun_$chart_title_str()"
                style="padding: 8px 16px; background-color: #e74c3c; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Run to Convergence
        </button>
    </div>
    """

    # Convergence settings
    convergence_settings = """
    <div style="margin-bottom: 15px; display: flex; gap: 20px; align-items: center; flex-wrap: wrap;">
        <div>
            <label for="convergence_$chart_title_str"><strong>Convergence threshold:</strong></label>
            <input type="number" id="convergence_$chart_title_str" value="0.1" min="0.001" max="10" step="0.01"
                   style="width: 80px; margin-left: 5px;">
        </div>
        <div>
            <label for="max_iter_$chart_title_str"><strong>Max iterations:</strong></label>
            <input type="number" id="max_iter_$chart_title_str" value="5000" min="100" max="10000" step="100"
                   style="width: 80px; margin-left: 5px;">
        </div>
        <div>
            <label for="exag_iters_$chart_title_str"><strong>Early exaggeration iters:</strong></label>
            <input type="number" id="exag_iters_$chart_title_str" value="100" min="0" max="500" step="10"
                   style="width: 70px; margin-left: 5px;">
        </div>
        <div>
            <label for="exag_factor_$chart_title_str"><strong>Exaggeration factor:</strong></label>
            <input type="number" id="exag_factor_$chart_title_str" value="4.0" min="1.0" max="20.0" step="0.5"
                   style="width: 60px; margin-left: 5px;">
        </div>
    </div>
    """

    # Status display
    status_display = """
    <div style="margin-bottom: 15px; padding: 10px; background-color: #f8f9fa; border-radius: 4px; font-family: monospace;">
        <div><strong>Iteration:</strong> <span id="iteration_$chart_title_str">0</span>
             <span id="exaggeration_status_$chart_title_str" style="color: #e74c3c; margin-left: 10px;"></span></div>
        <div><strong>Movement (last iteration):</strong> <span id="distance_$chart_title_str">0.000</span></div>
        <div><strong>Status:</strong> <span id="status_$chart_title_str">Ready</span></div>
    </div>
    """

    # Aspect ratio and zoom sliders
    aspect_ratio_default = 0.6
    zoom_default = 1.0
    aspect_ratio_slider = """
    <div style="margin-bottom: 10px; display: flex; gap: 30px; flex-wrap: wrap;">
        <div style="flex: 1; min-width: 200px;">
            <label for="aspect_ratio_slider_$chart_title_str"><strong>Aspect Ratio:</strong>
                   <span id="aspect_ratio_label_$chart_title_str">$aspect_ratio_default</span>
            </label>
            <input type="range" id="aspect_ratio_slider_$chart_title_str"
                   min="0.3" max="1.2" step="0.05" value="$aspect_ratio_default"
                   style="width: 70%; margin-left: 10px;">
        </div>
        <div style="flex: 1; min-width: 200px;">
            <label for="zoom_slider_$chart_title_str"><strong>Zoom:</strong>
                   <span id="zoom_label_$chart_title_str">$zoom_default</span>x
            </label>
            <input type="range" id="zoom_slider_$chart_title_str"
                   min="0.2" max="5.0" step="0.1" value="$zoom_default"
                   style="width: 70%; margin-left: 10px;">
        </div>
    </div>
    """

    return """
    <style>
        .tsne-container-$chart_title_str {
            position: relative;
        }
        .tsne-tooltip-$chart_title_str {
            position: fixed;
            display: none;
            background-color: rgba(0, 0, 0, 0.85);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            pointer-events: none;
            z-index: 1000;
            max-width: 300px;
            white-space: pre-line;
            line-height: 1.4;
        }
        .tsne-node-$chart_title_str {
            cursor: grab;
        }
        .tsne-node-$chart_title_str:active {
            cursor: grabbing;
        }
        .tsne-label-$chart_title_str {
            font-size: 10px;
            pointer-events: none;
            user-select: none;
        }
    </style>
    <div class="tsne-container-$chart_title_str">
        <h2>$title</h2>
        <p>$notes</p>
        $variable_selection_html
        $color_selector_html
        $perplexity_slider
        $learning_rate_slider
        $control_buttons
        $convergence_settings
        $status_display
        $aspect_ratio_slider
        <div id="tsne_canvas_$chart_title_str" style="width: 100%; border: 1px solid #ccc; position: relative; overflow: hidden;"></div>
        <div id="tooltip_$chart_title_str" class="tsne-tooltip-$chart_title_str"></div>
        <div style="margin-top: 10px; font-size: 12px; color: #666;">
            <strong>Tip:</strong> Drag nodes to manually reposition. "Run to Convergence" uses early exaggeration for the configured number of iterations; "Step (small)" never uses exaggeration; "Exaggerated Step" always uses it.
        </div>
    </div>
    """
end

function build_tsne_functional_html(chart_title_str, data_label,
                                     entity_col, label_col,
                                     all_numeric_cols_json, initial_feature_cols_json, distance_matrix,
                                     color_cols, perplexity, learning_rate, tooltip_cols,
                                     continuous_cols, discrete_cols, colour_map, extrapolate_colors)

    has_colors = !isempty(color_cols)
    color_cols_json = JSON.json([String(c) for c in color_cols])
    tooltip_cols_json = JSON.json([String(c) for c in tooltip_cols])

    # Color configuration for continuous support
    continuous_cols_json = JSON.json([String(c) for c in continuous_cols])
    discrete_cols_json = JSON.json([String(c) for c in discrete_cols])

    # Convert colour_map to JSON
    colour_map_json = if ismissing(colour_map)
        "null"
    elseif colour_map isa Dict{Float64,String}
        JSON.json(colour_map)
    else  # Dict{String,Dict{Float64,String}}
        JSON.json(colour_map)
    end

    return """
    (function() {
        // Configuration
        const ENTITY_COL = '$entity_col';
        const LABEL_COL = '$label_col';
        const ALL_NUMERIC_COLS = $all_numeric_cols_json;
        const INITIAL_FEATURE_COLS = $initial_feature_cols_json;
        const IS_DISTANCE_MATRIX = $distance_matrix;
        const COLOR_COLS = $color_cols_json;
        const TOOLTIP_COLS = $tooltip_cols_json;
        const INITIAL_PERPLEXITY = $perplexity;
        const INITIAL_LEARNING_RATE = $learning_rate;

        // Color configuration for continuous support
        const continuousCols = $continuous_cols_json;
        const discreteCols = $discrete_cols_json;
        const colourMap = $colour_map_json;
        const extrapolateColors = $extrapolate_colors;

        // State
        let rawData = null;
        let entities = [];
        let entityMap = {};
        let distanceMatrix = null;
        let selectedFeatures = [...INITIAL_FEATURE_COLS];
        let positions = [];
        let velocities = [];
        let gains = [];  // For adaptive learning rate
        let iteration = 0;
        let isRunning = false;
        let animationFrameId = null;
        let lastTotalMovement = 0;
        let cachedP = null;
        let lastPerplexity = null;

        // Current transform state (for drag coordinate conversion)
        let currentTransform = { scale: 1, centerX: 0, centerY: 0 };

        // Pan offset (in embedding coordinates)
        let panOffsetX = 0;
        let panOffsetY = 0;

        // Zoom factor (for manual zoom control)
        let zoomFactor = 1.0;

        // SVG elements
        let svg = null;
        let width = 800;
        let height = 600;
        const margin = { top: 20, right: 20, bottom: 20, left: 20 };
        const nodeRadius = 8;

        // Tooltip - get dynamically to ensure DOM is ready
        function getTooltipDiv() {
            return document.getElementById('tooltip_$chart_title_str');
        }

        // Load data
        loadDataset('$(data_label)').then(function(data) {
            rawData = data;
            initializeVisualization();
        }).catch(function(error) {
            console.error('Failed to load t-SNE data:', error);
        });

        function initializeVisualization() {
            // Extract entities
            if (IS_DISTANCE_MATRIX) {
                const entitySet = new Set();
                rawData.forEach(function(row) {
                    entitySet.add(row.node1);
                    entitySet.add(row.node2);
                });
                entities = Array.from(entitySet).sort();
            } else {
                entities = [];
                const seen = new Set();
                rawData.forEach(function(row) {
                    const e = row[ENTITY_COL];
                    if (!seen.has(e)) {
                        seen.add(e);
                        entities.push(e);
                    }
                });
            }

            // Build entity to index map
            entities.forEach(function(e, i) {
                entityMap[e] = i;
            });

            // Initialize feature selection UI
            if (!IS_DISTANCE_MATRIX) {
                populateFeatureSelectors();
            }

            // Build distance matrix
            buildDistanceMatrix();

            // Initialize random positions
            randomizePositions_$chart_title_str();

            // Create SVG
            createSVG();

            // Setup aspect ratio control
            setupAspectRatio();

            // Initial render
            render();
        }

        function populateFeatureSelectors() {
            const availableSelect = document.getElementById('available_features_$chart_title_str');
            const selectedSelect = document.getElementById('selected_features_$chart_title_str');

            if (!availableSelect || !selectedSelect) return;

            availableSelect.innerHTML = '';
            selectedSelect.innerHTML = '';

            ALL_NUMERIC_COLS.forEach(function(col) {
                const option = document.createElement('option');
                option.value = col;
                option.text = col;
                if (selectedFeatures.includes(col)) {
                    selectedSelect.appendChild(option);
                } else {
                    availableSelect.appendChild(option);
                }
            });
        }

        window.addFeature_$chart_title_str = function() {
            const availableSelect = document.getElementById('available_features_$chart_title_str');
            const selectedSelect = document.getElementById('selected_features_$chart_title_str');
            const selected = Array.from(availableSelect.selectedOptions);
            selected.forEach(function(opt) {
                selectedSelect.appendChild(opt);
                if (!selectedFeatures.includes(opt.value)) {
                    selectedFeatures.push(opt.value);
                }
            });
        };

        window.removeFeature_$chart_title_str = function() {
            const availableSelect = document.getElementById('available_features_$chart_title_str');
            const selectedSelect = document.getElementById('selected_features_$chart_title_str');
            const selected = Array.from(selectedSelect.selectedOptions);
            selected.forEach(function(opt) {
                availableSelect.appendChild(opt);
                const idx = selectedFeatures.indexOf(opt.value);
                if (idx > -1) selectedFeatures.splice(idx, 1);
            });
        };

        window.recalculateDistances_$chart_title_str = function() {
            if (selectedFeatures.length === 0) {
                alert('Please select at least one feature');
                return;
            }
            // Stop any running optimization
            if (isRunning) {
                toggleRun_$chart_title_str();
            }
            // Rebuild distance matrix with new features
            buildDistanceMatrix();
            // Reset positions and state
            cachedP = null;
            randomizePositions_$chart_title_str();
            render();
            updateStatus('Distances recalculated - ready');
        };

        function buildDistanceMatrix() {
            const n = entities.length;
            distanceMatrix = [];
            for (let i = 0; i < n; i++) {
                distanceMatrix[i] = [];
                for (let j = 0; j < n; j++) {
                    distanceMatrix[i][j] = 0;
                }
            }

            if (IS_DISTANCE_MATRIX) {
                rawData.forEach(function(row) {
                    const i = entityMap[row.node1];
                    const j = entityMap[row.node2];
                    if (i !== undefined && j !== undefined) {
                        distanceMatrix[i][j] = row.distance;
                        distanceMatrix[j][i] = row.distance;
                    }
                });
            } else {
                // Get rescaling method
                const rescalingSelect = document.getElementById('rescaling_$chart_title_str');
                const rescaling = rescalingSelect ? rescalingSelect.value : 'zscore';

                // Build feature vectors
                const featureVectors = {};
                rawData.forEach(function(row) {
                    const entity = row[ENTITY_COL];
                    if (!featureVectors[entity]) {
                        const vec = selectedFeatures.map(function(col) {
                            const val = row[col];
                            return typeof val === 'number' && !isNaN(val) ? val : 0;
                        });
                        featureVectors[entity] = vec;
                    }
                });

                // Apply rescaling per feature
                if (selectedFeatures.length > 0 && rescaling !== 'none') {
                    selectedFeatures.forEach(function(col, colIdx) {
                        const values = entities.map(function(e) {
                            return featureVectors[e] ? featureVectors[e][colIdx] : 0;
                        });

                        if (rescaling === 'zscore' || rescaling === 'zscore_capped') {
                            // Z-score normalization
                            const mean = values.reduce(function(a, b) { return a + b; }, 0) / values.length;
                            const variance = values.reduce(function(a, b) { return a + (b - mean) * (b - mean); }, 0) / values.length;
                            const std = Math.sqrt(variance) || 1;

                            entities.forEach(function(entity) {
                                if (featureVectors[entity]) {
                                    let zval = (featureVectors[entity][colIdx] - mean) / std;
                                    if (rescaling === 'zscore_capped') {
                                        zval = Math.max(-2, Math.min(2, zval));
                                    }
                                    featureVectors[entity][colIdx] = zval;
                                }
                            });
                        } else if (rescaling === 'quantile') {
                            // Quantile scaling: min=0, median=0.5, max=1
                            const sorted = values.slice().sort(function(a, b) { return a - b; });
                            const rankMap = {};
                            sorted.forEach(function(val, rank) {
                                if (!(val in rankMap)) {
                                    rankMap[val] = rank;
                                }
                            });
                            const maxRank = sorted.length - 1;

                            entities.forEach(function(entity) {
                                if (featureVectors[entity]) {
                                    const val = featureVectors[entity][colIdx];
                                    const rank = rankMap[val] || 0;
                                    featureVectors[entity][colIdx] = maxRank > 0 ? rank / maxRank : 0.5;
                                }
                            });
                        }
                    });
                }

                // Calculate Euclidean distances
                for (let i = 0; i < n; i++) {
                    for (let j = i + 1; j < n; j++) {
                        const v1 = featureVectors[entities[i]] || [];
                        const v2 = featureVectors[entities[j]] || [];
                        let dist = 0;
                        const len = Math.max(v1.length, v2.length);
                        for (let k = 0; k < len; k++) {
                            const a = v1[k] || 0;
                            const b = v2[k] || 0;
                            dist += (a - b) * (a - b);
                        }
                        dist = Math.sqrt(dist);
                        distanceMatrix[i][j] = dist;
                        distanceMatrix[j][i] = dist;
                    }
                }
            }
        }

        function createSVG() {
            const container = document.getElementById('tsne_canvas_$chart_title_str');
            width = container.offsetWidth || 800;
            height = width * 0.6;
            container.style.height = height + 'px';
            container.innerHTML = '';

            svg = d3.select(container)
                .append('svg')
                .attr('width', width)
                .attr('height', height);

            // Add background rect for pan events
            svg.append('rect')
                .attr('class', 'tsne-background-$chart_title_str')
                .attr('width', width)
                .attr('height', height)
                .attr('fill', 'transparent')
                .style('cursor', 'move')
                .call(d3.behavior.drag()
                    .on('dragstart', panStarted)
                    .on('drag', panning)
                    .on('dragend', panEnded));

            // D3 v3 drag behavior for nodes
            const drag = d3.behavior.drag()
                .origin(function(d) { return d; })
                .on('dragstart', dragStarted)
                .on('drag', dragged)
                .on('dragend', dragEnded);

            window.tsneDrag_$chart_title_str = drag;
        }

        // Pan handlers
        let isPanning = false;
        let panStartX = 0;
        let panStartY = 0;

        function panStarted() {
            isPanning = true;
            panStartX = d3.event.x;
            panStartY = d3.event.y;
            d3.event.sourceEvent.stopPropagation();
        }

        function panning() {
            if (!isPanning) return;
            const dx = d3.event.x - panStartX;
            const dy = d3.event.y - panStartY;
            // Convert screen delta to embedding delta
            panOffsetX -= dx / currentTransform.scale;
            panOffsetY -= dy / currentTransform.scale;
            panStartX = d3.event.x;
            panStartY = d3.event.y;
            render();
        }

        function panEnded() {
            isPanning = false;
        }

        function dragStarted(d) {
            if (isRunning) {
                toggleRun_$chart_title_str();
            }
            d3.select(this).classed('dragging', true);
        }

        function dragged(d) {
            const idx = entityMap[d.entity];
            // Convert screen coordinates back to embedding coordinates
            const screenX = d3.event.x;
            const screenY = d3.event.y;
            const embeddingX = currentTransform.centerX + (screenX - width / 2) / currentTransform.scale;
            const embeddingY = currentTransform.centerY + (screenY - height / 2) / currentTransform.scale;

            positions[idx].x = embeddingX;
            positions[idx].y = embeddingY;
            // Reset velocity when manually moved
            velocities[idx].x = 0;
            velocities[idx].y = 0;

            render();
        }

        function dragEnded(d) {
            d3.select(this).classed('dragging', false);
        }

        function setupAspectRatio() {
            const aspectSlider = document.getElementById('aspect_ratio_slider_$chart_title_str');
            const aspectLabel = document.getElementById('aspect_ratio_label_$chart_title_str');
            const zoomSlider = document.getElementById('zoom_slider_$chart_title_str');
            const zoomLabel = document.getElementById('zoom_label_$chart_title_str');
            const container = document.getElementById('tsne_canvas_$chart_title_str');

            if (!aspectSlider || !aspectLabel || !container) return;

            // Aspect ratio slider - changes viewport height/width ratio
            aspectSlider.addEventListener('input', function() {
                const aspectRatio = parseFloat(this.value);
                aspectLabel.textContent = aspectRatio.toFixed(2);

                width = container.offsetWidth;
                height = width * aspectRatio;
                container.style.height = height + 'px';

                if (svg) {
                    svg.attr('width', width).attr('height', height);
                    // Update background rect size
                    svg.select('.tsne-background-$chart_title_str')
                        .attr('width', width)
                        .attr('height', height);
                    render();
                }
            });

            // Zoom slider - changes how much of the embedding is visible
            if (zoomSlider && zoomLabel) {
                zoomSlider.addEventListener('input', function() {
                    zoomFactor = parseFloat(this.value);
                    zoomLabel.textContent = zoomFactor.toFixed(1);
                    render();
                });
            }

            // Initialize aspect ratio
            const initialAspectRatio = parseFloat(aspectSlider.value);
            aspectLabel.textContent = initialAspectRatio.toFixed(2);
            height = width * initialAspectRatio;
            container.style.height = height + 'px';
        }

        // t-SNE algorithm with proper scaling
        function computeGaussianPerplexity(distances, targetPerplexity) {
            const n = distances.length;
            const P = [];
            for (let i = 0; i < n; i++) {
                P[i] = [];
                for (let j = 0; j < n; j++) {
                    P[i][j] = 0;
                }
            }
            const logPerp = Math.log(targetPerplexity);

            for (let i = 0; i < n; i++) {
                let betaMin = -Infinity;
                let betaMax = Infinity;
                let beta = 1.0;

                for (let iter = 0; iter < 50; iter++) {
                    let sum = 0;
                    for (let j = 0; j < n; j++) {
                        if (i !== j) {
                            P[i][j] = Math.exp(-distances[i][j] * distances[i][j] * beta);
                            sum += P[i][j];
                        }
                    }

                    if (sum > 0) {
                        for (let j = 0; j < n; j++) {
                            P[i][j] /= sum;
                        }
                    }

                    let H = 0;
                    for (let j = 0; j < n; j++) {
                        if (P[i][j] > 1e-7) {
                            H -= P[i][j] * Math.log(P[i][j]);
                        }
                    }

                    const diff = H - logPerp;
                    if (Math.abs(diff) < 1e-5) break;

                    if (diff > 0) {
                        betaMin = beta;
                        beta = betaMax === Infinity ? beta * 2 : (beta + betaMax) / 2;
                    } else {
                        betaMax = beta;
                        beta = betaMin === -Infinity ? beta / 2 : (beta + betaMin) / 2;
                    }
                }
            }

            // Symmetrize
            const P_sym = [];
            for (let i = 0; i < n; i++) {
                P_sym[i] = [];
                for (let j = 0; j < n; j++) {
                    P_sym[i][j] = (P[i][j] + P[j][i]) / (2 * n);
                }
            }

            return P_sym;
        }

        function getExaggerationFactor() {
            const input = document.getElementById('exag_factor_$chart_title_str');
            return input ? parseFloat(input.value) || 4.0 : 4.0;
        }

        function getExaggerationIters() {
            const input = document.getElementById('exag_iters_$chart_title_str');
            return input ? parseInt(input.value) || 100 : 100;
        }

        function tsneStep(P, learningRate, useExaggeration) {
            const n = positions.length;
            const exaggeration = useExaggeration ? getExaggerationFactor() : 1.0;

            // Compute Q matrix (Student-t distribution)
            let Qsum = 0;
            const Qnum = [];
            for (let i = 0; i < n; i++) {
                Qnum[i] = [];
                for (let j = 0; j < n; j++) {
                    if (i !== j) {
                        const dx = positions[i].x - positions[j].x;
                        const dy = positions[i].y - positions[j].y;
                        const dist2 = dx * dx + dy * dy;
                        Qnum[i][j] = 1 / (1 + dist2);
                        Qsum += Qnum[i][j];
                    } else {
                        Qnum[i][j] = 0;
                    }
                }
            }

            // Compute gradients
            const gradients = [];
            for (let i = 0; i < n; i++) {
                gradients[i] = { x: 0, y: 0 };
            }

            for (let i = 0; i < n; i++) {
                for (let j = 0; j < n; j++) {
                    if (i !== j) {
                        const Q_ij = Qnum[i][j] / Qsum;
                        const P_ij = P[i][j] * exaggeration;
                        const dx = positions[i].x - positions[j].x;
                        const dy = positions[i].y - positions[j].y;
                        const mult = (P_ij - Q_ij) * Qnum[i][j];
                        gradients[i].x += 4 * mult * dx;
                        gradients[i].y += 4 * mult * dy;
                    }
                }
            }

            // Update with momentum and adaptive gains
            const momentum = iteration < 250 ? 0.5 : 0.8;
            let totalMovement = 0;

            for (let i = 0; i < n; i++) {
                // Update gains (for adaptive learning rate)
                const gx = gradients[i].x;
                const gy = gradients[i].y;
                gains[i].x = (Math.sign(gx) === Math.sign(velocities[i].x)) ? gains[i].x * 0.8 : gains[i].x + 0.2;
                gains[i].y = (Math.sign(gy) === Math.sign(velocities[i].y)) ? gains[i].y * 0.8 : gains[i].y + 0.2;
                gains[i].x = Math.max(gains[i].x, 0.01);
                gains[i].y = Math.max(gains[i].y, 0.01);

                // Velocity update
                velocities[i].x = momentum * velocities[i].x - learningRate * gains[i].x * gx;
                velocities[i].y = momentum * velocities[i].y - learningRate * gains[i].y * gy;

                // Position update
                positions[i].x += velocities[i].x;
                positions[i].y += velocities[i].y;

                totalMovement += Math.sqrt(velocities[i].x * velocities[i].x + velocities[i].y * velocities[i].y);
            }

            return totalMovement;
        }

        // Global functions
        window.randomizePositions_$chart_title_str = function() {
            const n = entities.length;
            positions = [];
            velocities = [];
            gains = [];

            // Initialize in a small region centered at origin
            const scale = 0.0001;
            for (let i = 0; i < n; i++) {
                positions.push({
                    x: (Math.random() - 0.5) * scale,
                    y: (Math.random() - 0.5) * scale
                });
                velocities.push({ x: 0, y: 0 });
                gains.push({ x: 1, y: 1 });
            }

            iteration = 0;
            lastTotalMovement = 0;
            cachedP = null;
            // Reset pan offset
            panOffsetX = 0;
            panOffsetY = 0;
            updateStatus('Ready');
            updateIterationDisplay();

            if (svg) render();
        };

        window.stepIteration_$chart_title_str = function(forceExaggeration) {
            if (!distanceMatrix) return;

            const perplexity = parseFloat(document.getElementById('perplexity_slider_$chart_title_str').value);
            const learningRate = parseFloat(document.getElementById('lr_slider_$chart_title_str').value);

            // Cache P matrix if perplexity hasn't changed
            if (!cachedP || lastPerplexity !== perplexity) {
                cachedP = computeGaussianPerplexity(distanceMatrix, perplexity);
                lastPerplexity = perplexity;
            }

            // forceExaggeration: true = always exaggerate, false = never exaggerate
            const useExaggeration = forceExaggeration === true;
            lastTotalMovement = tsneStep(cachedP, learningRate, useExaggeration);
            iteration++;

            updateIterationDisplay();
            render();
        };

        window.toggleRun_$chart_title_str = function() {
            if (isRunning) {
                isRunning = false;
                if (animationFrameId) {
                    cancelAnimationFrame(animationFrameId);
                    animationFrameId = null;
                }
                document.getElementById('run_btn_$chart_title_str').textContent = 'Run to Convergence';
                updateStatus('Stopped');
            } else {
                isRunning = true;
                document.getElementById('run_btn_$chart_title_str').textContent = 'Stop';
                updateStatus('Running...');
                runLoop();
            }
        };

        function runLoop() {
            if (!isRunning) return;

            const perplexity = parseFloat(document.getElementById('perplexity_slider_$chart_title_str').value);
            const learningRate = parseFloat(document.getElementById('lr_slider_$chart_title_str').value);
            const convergenceThreshold = parseFloat(document.getElementById('convergence_$chart_title_str').value);
            const maxIter = parseInt(document.getElementById('max_iter_$chart_title_str').value);
            const exagIters = getExaggerationIters();

            if (!cachedP || lastPerplexity !== perplexity) {
                cachedP = computeGaussianPerplexity(distanceMatrix, perplexity);
                lastPerplexity = perplexity;
            }

            const useExaggeration = iteration < exagIters;
            lastTotalMovement = tsneStep(cachedP, learningRate, useExaggeration);
            iteration++;

            updateIterationDisplay();
            render();

            if (iteration > exagIters && lastTotalMovement < convergenceThreshold) {
                isRunning = false;
                document.getElementById('run_btn_$chart_title_str').textContent = 'Run to Convergence';
                updateStatus('Converged!');
                return;
            }

            if (iteration >= maxIter) {
                isRunning = false;
                document.getElementById('run_btn_$chart_title_str').textContent = 'Run to Convergence';
                updateStatus('Max iterations reached');
                return;
            }

            animationFrameId = requestAnimationFrame(runLoop);
        }

        window.updateColors_$chart_title_str = function() {
            render();
        };

        function updateIterationDisplay() {
            document.getElementById('iteration_$chart_title_str').textContent = iteration;
            document.getElementById('distance_$chart_title_str').textContent = lastTotalMovement.toFixed(4);

            const exaggerationStatus = document.getElementById('exaggeration_status_$chart_title_str');
            const exagIters = getExaggerationIters();
            if (exaggerationStatus) {
                if (iteration < exagIters) {
                    exaggerationStatus.textContent = '(Early Exaggeration: ' + (exagIters - iteration) + ' iters remaining)';
                } else {
                    exaggerationStatus.textContent = '';
                }
            }
        }

        function updateStatus(status) {
            document.getElementById('status_$chart_title_str').textContent = status;
        }

        function render() {
            if (!svg || !positions || positions.length === 0) return;
            if (width <= 0 || height <= 0) return;

            // Find bounds and scale to fit canvas
            let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
            positions.forEach(function(p) {
                if (p.x < minX) minX = p.x;
                if (p.x > maxX) maxX = p.x;
                if (p.y < minY) minY = p.y;
                if (p.y > maxY) maxY = p.y;
            });

            // Handle case where all points are at the same location
            let rangeX = maxX - minX;
            let rangeY = maxY - minY;
            if (rangeX < 1e-10) rangeX = 1;
            if (rangeY < 1e-10) rangeY = 1;

            const innerWidth = Math.max(1, width - margin.left - margin.right - 2 * nodeRadius);
            const innerHeight = Math.max(1, height - margin.top - margin.bottom - 2 * nodeRadius);

            // Base scale fits all points, zoom factor adjusts how much is visible
            const baseScale = Math.min(innerWidth / rangeX, innerHeight / rangeY) * 0.9;
            const currentZoom = zoomFactor || 1.0;
            const scale = isFinite(baseScale) ? baseScale * currentZoom : 1;
            const centerX = (minX + maxX) / 2;
            const centerY = (minY + maxY) / 2;

            // Apply pan offset to center (ensure panOffset is valid)
            const validPanX = isFinite(panOffsetX) ? panOffsetX : 0;
            const validPanY = isFinite(panOffsetY) ? panOffsetY : 0;
            const viewCenterX = centerX + validPanX;
            const viewCenterY = centerY + validPanY;

            // Save transform for drag coordinate conversion
            currentTransform.scale = scale;
            currentTransform.centerX = viewCenterX;
            currentTransform.centerY = viewCenterY;

            function toScreenX(x) {
                return width / 2 + (x - viewCenterX) * scale;
            }
            function toScreenY(y) {
                return height / 2 + (y - viewCenterY) * scale;
            }

            // Get current color column
            const colorSelect = document.getElementById('color_select_$chart_title_str');
            const colorBy = colorSelect ? colorSelect.value : 'none';

            // Check if this is a continuous or discrete column
            const isContinuous = continuousCols.includes(colorBy);

            // Build color map for discrete coloring
            const colorPalette = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
                                  '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'];
            let colorMap = {};
            if (colorBy !== 'none' && !IS_DISTANCE_MATRIX && !isContinuous) {
                const uniqueValues = [];
                const seen = new Set();
                rawData.forEach(function(row) {
                    const v = row[colorBy];
                    if (!seen.has(v)) {
                        seen.add(v);
                        uniqueValues.push(v);
                    }
                });
                uniqueValues.forEach(function(val, idx) {
                    colorMap[val] = colorPalette[idx % colorPalette.length];
                });
            }

            // Build continuous color scale if needed
            let continuousColorScale = null;
            if (colorBy !== 'none' && isContinuous && !IS_DISTANCE_MATRIX) {
                // Get gradient for this variable
                let gradient = null;
                if (colourMap) {
                    const keys = Object.keys(colourMap);
                    if (keys.length > 0) {
                        if (!isNaN(parseFloat(keys[0]))) {
                            gradient = colourMap;
                        } else {
                            gradient = colourMap[colorBy];
                        }
                    }
                }
                if (!gradient) {
                    gradient = { "-2": "#FF0000", "0": "#FFFFFF", "2": "#0000FF" };
                }
                continuousColorScale = { gradient: gradient };
            }

            // Get entity data
            const entityData = {};
            if (!IS_DISTANCE_MATRIX) {
                rawData.forEach(function(row) {
                    const entity = row[ENTITY_COL];
                    if (!entityData[entity]) {
                        entityData[entity] = row;
                    }
                });
            }

            // Prepare node data
            const nodeData = entities.map(function(entity, idx) {
                let nodeColor = '#3498db';
                if (colorBy !== 'none' && entityData[entity]) {
                    const colorValue = entityData[entity][colorBy];
                    if (isContinuous && continuousColorScale) {
                        // Use continuous color interpolation
                        if (typeof colorValue === 'number' && !isNaN(colorValue)) {
                            nodeColor = interpolateColor_$chart_title_str(colorValue, continuousColorScale.gradient);
                        } else {
                            nodeColor = '#CCCCCC';  // Gray for missing values
                        }
                    } else {
                        // Use discrete color map
                        nodeColor = colorMap[colorValue] || '#3498db';
                    }
                }
                return {
                    entity: entity,
                    label: IS_DISTANCE_MATRIX ? entity : (entityData[entity] ? entityData[entity][LABEL_COL] : entity) || entity,
                    x: toScreenX(positions[idx].x),
                    y: toScreenY(positions[idx].y),
                    color: nodeColor,
                    data: entityData[entity] || {}
                };
            });

            // Update nodes (D3 v3 pattern)
            const nodes = svg.selectAll('.tsne-node-$chart_title_str')
                .data(nodeData, function(d) { return d.entity; });

            nodes.exit().remove();

            nodes.enter()
                .append('circle')
                .attr('class', 'tsne-node-$chart_title_str')
                .attr('r', nodeRadius)
                .call(window.tsneDrag_$chart_title_str)
                .on('mouseover', function(d) { showTooltip(d); })
                .on('mousemove', function(d) { moveTooltip(); })
                .on('mouseout', function() { hideTooltip(); });

            svg.selectAll('.tsne-node-$chart_title_str')
                .attr('cx', function(d) { return d.x; })
                .attr('cy', function(d) { return d.y; })
                .attr('fill', function(d) { return d.color; });

            // Update labels
            const labels = svg.selectAll('.tsne-label-$chart_title_str')
                .data(nodeData, function(d) { return d.entity; });

            labels.exit().remove();

            labels.enter()
                .append('text')
                .attr('class', 'tsne-label-$chart_title_str');

            svg.selectAll('.tsne-label-$chart_title_str')
                .attr('x', function(d) { return d.x + nodeRadius + 3; })
                .attr('y', function(d) { return d.y + 3; })
                .text(function(d) { return d.label; });
        }

        function showTooltip(d) {
            const tooltipDiv = getTooltipDiv();
            if (!tooltipDiv) return;

            let content = '<strong>' + d.label + '</strong>';

            TOOLTIP_COLS.forEach(function(col) {
                const val = d.data[col];
                if (val !== undefined && val !== null) {
                    const colName = col.charAt(0).toUpperCase() + col.slice(1).replace(/_/g, ' ');
                    let formattedValue;
                    if (typeof val === 'number') {
                        formattedValue = Math.abs(val) < 10 ? val.toFixed(2) : val.toFixed(1);
                    } else {
                        formattedValue = val;
                    }
                    content += '<br>' + colName + ': ' + formattedValue;
                }
            });

            tooltipDiv.innerHTML = content;
            tooltipDiv.style.display = 'block';
            moveTooltip();
        }

        function moveTooltip() {
            const tooltipDiv = getTooltipDiv();
            if (!tooltipDiv) return;

            const event = d3.event;
            if (!event) return;

            // Use clientX/clientY with position:fixed for accurate positioning
            tooltipDiv.style.left = (event.clientX + 15) + 'px';
            tooltipDiv.style.top = (event.clientY + 15) + 'px';
        }

        function hideTooltip() {
            const tooltipDiv = getTooltipDiv();
            if (tooltipDiv) {
                tooltipDiv.style.display = 'none';
            }
        }

        // Color interpolation functions for continuous coloring
        function interpolateColor_$chart_title_str(value, gradient) {
            // Convert gradient object to sorted array of stops
            const stopPairs = Object.keys(gradient)
                .map(function(k) { return { stop: parseFloat(k), color: gradient[k] }; })
                .sort(function(a, b) { return a.stop - b.stop; });
            const stops = stopPairs.map(function(p) { return p.stop; });
            const colors = stopPairs.map(function(p) { return p.color; });

            // Handle values below minimum stop
            if (value < stops[0]) {
                if (!extrapolateColors) {
                    return colors[0];
                } else {
                    if (stops.length > 1) {
                        const t = (value - stops[0]) / (stops[1] - stops[0]);
                        return interpolateBetweenColors_$chart_title_str(colors[0], colors[1], t);
                    }
                    return colors[0];
                }
            }

            // Handle values above maximum stop
            if (value > stops[stops.length - 1]) {
                if (!extrapolateColors) {
                    return colors[colors.length - 1];
                } else {
                    if (stops.length > 1) {
                        const n = stops.length - 1;
                        const t = (value - stops[n]) / (stops[n] - stops[n - 1]);
                        return interpolateBetweenColors_$chart_title_str(colors[n], colors[n - 1], -t);
                    }
                    return colors[colors.length - 1];
                }
            }

            // Find surrounding stops for values within range
            for (let i = 0; i < stops.length - 1; i++) {
                if (value >= stops[i] && value <= stops[i + 1]) {
                    const t = (value - stops[i]) / (stops[i + 1] - stops[i]);
                    return interpolateBetweenColors_$chart_title_str(colors[i], colors[i + 1], t);
                }
            }

            return colors[0];  // Fallback
        }

        // Linear interpolation between two hex colors
        function interpolateBetweenColors_$chart_title_str(color1, color2, t) {
            const c1 = parseHexColor_$chart_title_str(color1);
            const c2 = parseHexColor_$chart_title_str(color2);

            const r = Math.round(c1.r + (c2.r - c1.r) * t);
            const g = Math.round(c1.g + (c2.g - c1.g) * t);
            const b = Math.round(c1.b + (c2.b - c1.b) * t);

            return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
        }

        // Parse hex color to RGB
        function parseHexColor_$chart_title_str(hex) {
            const result = /^#?([a-f\\d]{2})([a-f\\d]{2})([a-f\\d]{2})\$/i.exec(hex);
            return result ? {
                r: parseInt(result[1], 16),
                g: parseInt(result[2], 16),
                b: parseInt(result[3], 16)
            } : {r: 0, g: 0, b: 0};
        }
    })();
    """
end

# Struct definition and dependencies
dependencies(t::TSNEPlot) = [t.data_label]
js_dependencies(::TSNEPlot) = vcat(JS_DEP_JQUERY, JS_DEP_D3)

export TSNEPlot
