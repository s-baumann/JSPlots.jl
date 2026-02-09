"""
    BoxAndWhiskers(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Horizontal box and whiskers plot showing distribution statistics for groups.

Displays min, 25th percentile, median, 75th percentile, and max as box and whiskers,
with mean and standard deviation overlaid in a differentiated style. Groups are arranged
vertically with clear visual separation by grouping columns.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_cols::Vector{Symbol}`: Columns to compute distribution over (default: `[:value]`)
- `color_cols::Vector{Symbol}`: Columns available for coloring groups (default: `Symbol[]`)
- `grouping_cols::Vector{Symbol}`: Columns available for organizing/grouping (default: `Symbol[]`)
- `group_col::Symbol`: Column defining the groups (default: `:group`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
- `title::String`: Chart title (default: `"Box and Whiskers Plot"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
dd = DataFrame(
    group = repeat(["A", "B", "C"], inner = 50),
    value = vcat(randn(50) .+ 2, randn(50) .+ 5, randn(50) .+ 8),
    country = repeat(["USA", "USA", "Brazil"], inner = 50)
)

bw = BoxAndWhiskers(:my_chart, dd, :data,
    x_cols=[:value],
    color_cols=[:country],
    grouping_cols=[:country],
    group_col=:group
)
```
"""
struct BoxAndWhiskers <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function BoxAndWhiskers(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                           x_cols::Vector{Symbol}=[:value],
                           color_cols::Vector{Symbol}=Symbol[],
                           grouping_cols::Vector{Symbol}=Symbol[],
                           group_col::Symbol=:group,
                           filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                           choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                           title::String="Box and Whiskers Plot",
                           notes::String="")

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Sanitize chart title
        chart_title_safe = sanitize_chart_title(chart_title)

        # Validate columns
        all_cols = names(df)
        for col in vcat(x_cols, color_cols, grouping_cols, [group_col])
            String(col) in all_cols || error("Column $col not found. Available: $all_cols")
        end

        # Validate x_cols are numeric
        for col in x_cols
            eltype(df[!, col]) <: Union{Number, Missing} || error("Column $col must be numeric")
        end

        # Ensure we have at least one grouping option
        if isempty(color_cols)
            color_cols = Symbol[]
        end
        if isempty(grouping_cols)
            grouping_cols = Symbol[]
        end

        # Get unique groups
        groups = unique(df[!, group_col])
        n_groups = length(groups)

        # Build color maps for color columns
        color_maps = Dict{Symbol, Dict{String, String}}()
        for col in color_cols
            unique_vals = unique(skipmissing(df[!, col]))
            n_vals = length(unique_vals)
            colors = [DEFAULT_COLOR_PALETTE[mod1(i, length(DEFAULT_COLOR_PALETTE))] for i in 1:n_vals]
            color_maps[col] = Dict(string(val) => colors[i] for (i, val) in enumerate(unique_vals))
        end

        # Generate HTML
        functional_html, appearance_html = generate_boxandwhiskers_html(
            chart_title_safe, data_label, df,
            x_cols, color_cols, grouping_cols, group_col,
            normalized_filters, normalized_choices, color_maps, title, notes
        )

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

"""
Generate HTML and JavaScript for BoxAndWhiskers chart
"""
function generate_boxandwhiskers_html(chart_title_safe, data_label, df,
                                     x_cols, color_cols, grouping_cols, group_col,
                                     normalized_filters, normalized_choices, color_maps, title, notes)

    # Build filter dropdowns
    update_function = "updateChart_$(chart_title_safe)()"
    filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title_safe), normalized_filters, df, update_function)
    choice_dropdowns = build_choice_dropdowns(string(chart_title_safe), normalized_choices, df, update_function)

    # Separate categorical and continuous filters for JavaScript
    categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
    continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]
    choice_cols = collect(keys(normalized_choices))
    categorical_filters_js = build_js_array(categorical_filter_cols)
    continuous_filters_js = build_js_array(continuous_filter_cols)
    choice_filters_js = build_js_array(choice_cols)

    # Build attribute dropdowns
    attribute_dropdowns = DropdownControl[]

    # X column dropdown (value to plot)
    if length(x_cols) > 1
        push!(attribute_dropdowns, DropdownControl(
            "x_col_select_$(chart_title_safe)",
            "Value",
            [string(col) for col in x_cols],
            string(x_cols[1]),
            update_function
        ))
    end

    # Color column dropdown
    if length(color_cols) > 0
        color_options = ["none", [string(col) for col in color_cols]...]
        push!(attribute_dropdowns, DropdownControl(
            "color_col_select_$(chart_title_safe)",
            "Color by",
            color_options,
            string(color_cols[1]),  # Default to first color column
            update_function
        ))
    end

    # Grouping column dropdown
    if length(grouping_cols) > 0
        grouping_options = ["none", [string(col) for col in grouping_cols]...]
        push!(attribute_dropdowns, DropdownControl(
            "grouping_col_select_$(chart_title_safe)",
            "Group by",
            grouping_options,
            string(grouping_cols[1]),  # Default to first grouping column
            update_function
        ))
    end

    # Build filters HTML
    filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") *
                   join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")

    # Build attributes HTML with toggle buttons (side by side)
    toggles_html = """
        <div style="display: flex; align-items: center; padding: 5px 10px; border-bottom: 1px solid #ddd;">
            <div style="flex: 1; padding-left: 10px;">
                <label style="display: flex; align-items: center; cursor: pointer;">
                    <input type="checkbox" id="show_quantiles_$(chart_title_safe)" checked onchange="updateChart_$(chart_title_safe)()" style="margin-right: 8px;">
                    <span>Show Quantiles</span>
                </label>
            </div>
            <div style="flex: 1; padding-left: 10px;">
                <label style="display: flex; align-items: center; cursor: pointer;">
                    <input type="checkbox" id="show_mean_std_$(chart_title_safe)" checked onchange="updateChart_$(chart_title_safe)()" style="margin-right: 8px;">
                    <span>Show Mean ± Std Dev</span>
                </label>
            </div>
        </div>
    """

    attributes_html = join([generate_dropdown_html(dd) for dd in attribute_dropdowns], "\n") * toggles_html

    # Generate choices HTML
    choices_html = join([generate_choice_dropdown_html(dd) for dd in choice_dropdowns], "\n")

    # Generate appearance HTML
    base_appearance_html = generate_appearance_html_from_sections(
        filters_html,
        attributes_html,
        "",  # No faceting for box and whiskers
        title,
        notes,
        string(chart_title_safe);
        choices_html=choices_html,
        aspect_ratio_default=0.6
    )

    # Convert color maps to JSON
    color_maps_json = JSON.json(Dict(
        string(k) => v for (k, v) in color_maps
    ))

    # JavaScript arrays
    x_cols_js = build_js_array(x_cols)
    color_cols_js = build_js_array(color_cols)
    grouping_cols_js = build_js_array(grouping_cols)

    # JavaScript functional HTML
    functional_html = """
    (function() {
    // Color maps for BoxAndWhiskers $(chart_title_safe)
    const colorMaps_$(chart_title_safe) = $(color_maps_json);

    // Available columns
    const xCols_$(chart_title_safe) = $(x_cols_js);
    const colorCols_$(chart_title_safe) = $(color_cols_js);
    const groupingCols_$(chart_title_safe) = $(grouping_cols_js);
    const groupCol_$(chart_title_safe) = '$(group_col)';

    // Filter configuration
    const categoricalFilters_$(chart_title_safe) = $(categorical_filters_js);
    const continuousFilters_$(chart_title_safe) = $(continuous_filters_js);
    const CHOICE_FILTERS = $(choice_filters_js);

    // State variables
    let currentData_$(chart_title_safe) = null;
    let filters_$(chart_title_safe) = {};
    let rangeFilters_$(chart_title_safe) = {};

    // Helper function to safely get dropdown value
    const getCol_$(chart_title_safe) = function(id, def) {
        var el = document.getElementById(id);
        return el ? el.value : def;
    };

    // Initialize filters from dropdowns
    function initializeFilters_$(chart_title_safe)() {
        categoricalFilters_$(chart_title_safe).forEach(function(col) {
            var selectElement = document.getElementById(col + '_select_$(chart_title_safe)');
            if (selectElement) {
                var options = Array.from(selectElement.options);
                filters_$(chart_title_safe)[col] = options
                    .filter(function(opt) { return opt.selected; })
                    .map(function(opt) { return opt.value; });
            }
        });

        continuousFilters_$(chart_title_safe).forEach(function(col) {
            var slider = \$('#' + col + '_range_$(chart_title_safe)' + '_slider');
            if (slider.length > 0) {
                rangeFilters_$(chart_title_safe)[col] = {
                    min: slider.slider("values", 0),
                    max: slider.slider("values", 1)
                };
            }
        });
    }

    // Compute box and whiskers statistics for a group
    function computeStats(values) {
        if (values.length === 0) return null;

        // Sort values
        var sorted = values.slice().sort(function(a, b) { return a - b; });
        var n = sorted.length;

        // Helper function to compute quantile
        function quantile(arr, p) {
            var index = (arr.length - 1) * p;
            var lower = Math.floor(index);
            var upper = Math.ceil(index);
            var weight = index - lower;
            return arr[lower] * (1 - weight) + arr[upper] * weight;
        }

        // Compute quantiles
        var min = sorted[0];
        var max = sorted[n - 1];
        var p10 = quantile(sorted, 0.10);
        var q1 = quantile(sorted, 0.25);
        var median = quantile(sorted, 0.50);
        var q3 = quantile(sorted, 0.75);
        var p90 = quantile(sorted, 0.90);

        // Compute mean and stdev
        var mean = values.reduce(function(a, b) { return a + b; }, 0) / n;
        var variance = values.reduce(function(sum, val) {
            return sum + Math.pow(val - mean, 2);
        }, 0) / n;
        var stdev = Math.sqrt(variance);

        return {
            min: min,
            max: max,
            p10: p10,
            q1: q1,
            median: median,
            q3: q3,
            p90: p90,
            mean: mean,
            stdev: stdev
        };
    }

    // Update chart
    function updateChart_$(chart_title_safe)() {
        if (!currentData_$(chart_title_safe)) return;

        // Get selected values using helper function
        var xCol = getCol_$(chart_title_safe)('x_col_select_$(chart_title_safe)', '$(x_cols[1])');
        var colorCol = getCol_$(chart_title_safe)('color_col_select_$(chart_title_safe)', 'none');
        var groupingCol = getCol_$(chart_title_safe)('grouping_col_select_$(chart_title_safe)', 'none');

        // Get toggle states
        var showQuantiles = document.getElementById('show_quantiles_$(chart_title_safe)');
        var showMeanStd = document.getElementById('show_mean_std_$(chart_title_safe)');
        var displayQuantiles = showQuantiles ? showQuantiles.checked : true;
        var displayMeanStd = showMeanStd ? showMeanStd.checked : true;

        // Get choice filter values (single-select)
        var choices = {};
        CHOICE_FILTERS.forEach(function(col) {
            var select = document.getElementById(col + '_choice_$(chart_title_safe)');
            if (select) {
                choices[col] = select.value;
            }
        });

        // Re-read filter values from dropdowns/sliders (they may have changed)
        var currentFilters = {};
        categoricalFilters_$(chart_title_safe).forEach(function(col) {
            var selectElement = document.getElementById(col + '_select_$(chart_title_safe)');
            if (selectElement) {
                currentFilters[col] = Array.from(selectElement.selectedOptions).map(function(opt) {
                    return opt.value;
                });
            }
        });

        var currentRangeFilters = {};
        continuousFilters_$(chart_title_safe).forEach(function(col) {
            var slider = \$('#' + col + '_range_$(chart_title_safe)' + '_slider');
            if (slider.length > 0) {
                currentRangeFilters[col] = {
                    min: slider.slider("values", 0),
                    max: slider.slider("values", 1)
                };
            }
        });

        // Apply filters
        var filteredData = applyFiltersWithCounting(
            currentData_$(chart_title_safe),
            '$(chart_title_safe)',
            categoricalFilters_$(chart_title_safe),
            continuousFilters_$(chart_title_safe),
            currentFilters,
            currentRangeFilters,
            CHOICE_FILTERS,
            choices
        );

        // Group data
        var groupedData = {};
        var groupMetadata = {};  // Store metadata for each group

        filteredData.forEach(function(row) {
            var groupName = String(row[groupCol_$(chart_title_safe)]);
            if (!groupedData[groupName]) {
                groupedData[groupName] = [];
                groupMetadata[groupName] = {
                    color: colorCol !== 'none' ? String(row[colorCol]) : '',
                    grouping: groupingCol !== 'none' ? String(row[groupingCol]) : ''
                };
            }

            var value = parseFloat(row[xCol]);
            if (!isNaN(value)) {
                groupedData[groupName].push(value);
            }
        });

        // Sort groups by grouping column if specified
        var groupNames = Object.keys(groupedData);
        if (groupingCol !== 'none') {
            groupNames.sort(function(a, b) {
                var aGrouping = groupMetadata[a].grouping;
                var bGrouping = groupMetadata[b].grouping;
                if (aGrouping !== bGrouping) {
                    return aGrouping.localeCompare(bGrouping);
                }
                return a.localeCompare(b);
            });
        } else {
            groupNames.sort();
        }

        // Create traces for box plots
        var traces = [];
        var annotations = [];
        var yPos = 0;
        var prevGrouping = null;

        groupNames.forEach(function(groupName, index) {
            var values = groupedData[groupName];
            var stats = computeStats(values);

            if (!stats) return;

            // Add spacing between different grouping values
            if (groupingCol !== 'none' && prevGrouping !== null &&
                prevGrouping !== groupMetadata[groupName].grouping) {
                yPos--;  // Add extra spacing
            }
            prevGrouping = groupMetadata[groupName].grouping;

            // Determine color
            var boxColor = '#636efa';  // Default color
            if (colorCol !== 'none' && colorMaps_$(chart_title_safe)[colorCol]) {
                var colorValue = groupMetadata[groupName].color;
                boxColor = colorMaps_$(chart_title_safe)[colorCol][colorValue] || boxColor;
            }

            // Draw box and whiskers if enabled
            if (displayQuantiles) {
                // Draw box and whiskers manually with custom quantiles (10%, 25%, 50%, 75%, 90%)
                var boxHeight = 0.4;
                var whiskerCapSize = 0.15;

                // Draw the box (Q1 to Q3) as a filled rectangle using scatter
                traces.push({
                    type: 'scatter',
                    x: [stats.q1, stats.q3, stats.q3, stats.q1, stats.q1],
                    y: [yPos - boxHeight/2, yPos - boxHeight/2, yPos + boxHeight/2, yPos + boxHeight/2, yPos - boxHeight/2],
                    fill: 'toself',
                    fillcolor: boxColor,
                    opacity: 0.5,
                    line: { color: boxColor, width: 2 },
                    mode: 'lines',
                    showlegend: false,
                    hoverinfo: 'skip'
                });

                // Draw median line
                traces.push({
                    type: 'scatter',
                    x: [stats.median, stats.median],
                    y: [yPos - boxHeight/2, yPos + boxHeight/2],
                    mode: 'lines',
                    line: { color: boxColor, width: 3 },
                    showlegend: false,
                    hovertemplate: groupName + '<br>Median: %{x:.3f}<extra></extra>'
                });

                // Lower whisker (Q1 to P10)
                traces.push({
                    type: 'scatter',
                    x: [stats.p10, stats.q1],
                    y: [yPos, yPos],
                    mode: 'lines',
                    line: { color: boxColor, width: 1.5 },
                    showlegend: false,
                    hoverinfo: 'skip'
                });

                // Upper whisker (Q3 to P90)
                traces.push({
                    type: 'scatter',
                    x: [stats.q3, stats.p90],
                    y: [yPos, yPos],
                    mode: 'lines',
                    line: { color: boxColor, width: 1.5 },
                    showlegend: false,
                    hoverinfo: 'skip'
                });

                // Lower whisker cap at P10
                traces.push({
                    type: 'scatter',
                    x: [stats.p10, stats.p10],
                    y: [yPos - whiskerCapSize, yPos + whiskerCapSize],
                    mode: 'lines',
                    line: { color: boxColor, width: 1.5 },
                    showlegend: false,
                    hovertemplate: groupName + '<br>P10: %{x:.3f}<extra></extra>'
                });

                // Upper whisker cap at P90
                traces.push({
                    type: 'scatter',
                    x: [stats.p90, stats.p90],
                    y: [yPos - whiskerCapSize, yPos + whiskerCapSize],
                    mode: 'lines',
                    line: { color: boxColor, width: 1.5 },
                    showlegend: false,
                    hovertemplate: groupName + '<br>P90: %{x:.3f}<extra></extra>'
                });

                // Add hover info for Q1 and Q3
                traces.push({
                    type: 'scatter',
                    x: [stats.q1, stats.q3],
                    y: [yPos, yPos],
                    mode: 'markers',
                    marker: { size: 0.1, color: boxColor },
                    showlegend: false,
                    hovertemplate: groupName + '<br>Q1/Q3: %{x:.3f}<extra></extra>'
                });

                // Add dots for minimum and maximum observations
                traces.push({
                    type: 'scatter',
                    x: [stats.min, stats.max],
                    y: [yPos, yPos],
                    mode: 'markers',
                    marker: {
                        size: 6,
                        color: boxColor,
                        symbol: 'circle',
                        line: { width: 1, color: '#FFFFFF' }
                    },
                    showlegend: false,
                    hovertemplate: groupName + '<br>Min/Max: %{x:.3f}<extra></extra>'
                });
            }  // End of displayQuantiles

            // Mean and stdev trace if enabled
            if (displayMeanStd) {
                // Mean and stdev trace - positioned below the box with wavy line
                var meanYPos = yPos - 0.35;  // Position below the box

                // Create wavy line through mean ± stdev points
                var numWaves = 30;  // Number of points for smooth wave
                var xPoints = [];
                var yPoints = [];

                // Generate wavy line from mean-2*stdev to mean+2*stdev
                for (var i = 0; i <= numWaves; i++) {
                    var t = i / numWaves;  // 0 to 1
                    var xVal = stats.mean - 2*stats.stdev + t * 4 * stats.stdev;
                    // Sinusoidal wave with 2 complete cycles
                    var waveAmplitude = 0.08;
                    var yWave = meanYPos + waveAmplitude * Math.sin(t * Math.PI * 4);
                    xPoints.push(xVal);
                    yPoints.push(yWave);
                }

                // Wavy line trace
                traces.push({
                    type: 'scatter',
                    x: xPoints,
                    y: yPoints,
                    mode: 'lines',
                    line: {
                        color: boxColor,
                        width: 2.5,
                        shape: 'spline'
                    },
                    showlegend: false,
                    hoverinfo: 'skip'
                });

                // Add markers at key points: mean-2*std, mean-std, mean, mean+std, mean+2*std
                var markerX = [
                    stats.mean - 2*stats.stdev,
                    stats.mean - stats.stdev,
                    stats.mean,
                    stats.mean + stats.stdev,
                    stats.mean + 2*stats.stdev
                ];
                var markerY = Array(5).fill(meanYPos);
                var markerSymbols = ['diamond', 'circle', 'diamond', 'circle', 'diamond'];
                var markerSizes = [8, 10, 12, 10, 8];
                var markerLabels = ['μ-2σ', 'μ-σ', 'μ', 'μ+σ', 'μ+2σ'];

                traces.push({
                    type: 'scatter',
                    x: markerX,
                    y: markerY,
                    mode: 'markers',
                    marker: {
                        symbol: markerSymbols,
                        size: markerSizes,
                        color: boxColor,
                        line: { width: 2, color: '#FFFFFF' }
                    },
                    name: 'Mean ± StDev',
                    showlegend: index === 0,
                    hovertemplate: groupName + '<br>%{text}<br>Value: %{x:.3f}<extra></extra>',
                    text: markerLabels
                });
            }  // End of displayMeanStd

            // Add group label
            var dataRange = stats.p90 - stats.p10;
            annotations.push({
                x: stats.p10 - dataRange * 0.05,
                y: yPos,
                text: groupName,
                xanchor: 'right',
                yanchor: 'middle',
                showarrow: false,
                font: { size: 11, color: '#333' }
            });

            yPos--;
        });

        // Add grouping section labels if applicable
        if (groupingCol !== 'none') {
            var currentGrouping = null;
            var groupingStartY = 0;
            var yPos = 0;

            groupNames.forEach(function(groupName, index) {
                var thisGrouping = groupMetadata[groupName].grouping;

                if (currentGrouping !== thisGrouping) {
                    if (currentGrouping !== null) {
                        // Add label for previous grouping
                        var midY = (groupingStartY + yPos + 1) / 2;
                        annotations.push({
                            x: 0,
                            y: midY,
                            text: '<b>' + currentGrouping + '</b>',
                            xanchor: 'left',
                            yanchor: 'middle',
                            xref: 'paper',
                            showarrow: false,
                            font: { size: 13, color: '#000' },
                            xshift: -100
                        });
                    }
                    currentGrouping = thisGrouping;
                    groupingStartY = yPos;
                }

                if (prevGrouping !== null && prevGrouping !== thisGrouping) {
                    yPos--;
                }
                prevGrouping = thisGrouping;
                yPos--;
            });

            // Add label for last grouping
            if (currentGrouping !== null) {
                var midY = (groupingStartY + yPos + 1) / 2;
                annotations.push({
                    x: 0,
                    y: midY,
                    text: '<b>' + currentGrouping + '</b>',
                    xanchor: 'left',
                    yanchor: 'middle',
                    xref: 'paper',
                    showarrow: false,
                    font: { size: 13, color: '#000' },
                    xshift: -100
                });
            }
        }

        // Layout
        var layout = {
            title: '',
            xaxis: {
                title: xCol,
                showgrid: true,
                zeroline: true
            },
            yaxis: {
                showticklabels: false,
                showgrid: false,
                zeroline: false,
                range: [yPos - 0.5, 0.5]
            },
            margin: { l: 150, r: 50, t: 20, b: 60 },
            hovermode: 'closest',
            annotations: annotations,
            height: Math.max(400, Math.abs(yPos) * 40)
        };

        Plotly.react('$(chart_title_safe)', traces, layout, {responsive: true});
    }

    // Expose updateChart to global scope for dropdown onchange handlers
    window.updateChart_$(chart_title_safe) = updateChart_$(chart_title_safe);

    // Initialize on load
    loadDataset('$(data_label)').then(function(data) {
        currentData_$(chart_title_safe) = data;
        initializeFilters_$(chart_title_safe)();
        updateChart_$(chart_title_safe)();
        setupAspectRatioControl('$(chart_title_safe)');
    }).catch(function(error) {
        console.error('Error loading data for BoxAndWhiskers $(chart_title_safe):', error);
        document.getElementById('$(chart_title_safe)').innerHTML =
            '<p style="color: red;">Error loading data: ' + error.message + '</p>';
    });
    })();
    """

    return functional_html, base_appearance_html
end

dependencies(bw::BoxAndWhiskers) = [bw.data_label]
js_dependencies(::BoxAndWhiskers) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
