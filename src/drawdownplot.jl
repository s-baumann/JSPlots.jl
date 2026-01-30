"""
    DrawdownPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Drawdown visualization chart for comparing strategy drawdowns over time.

# Description
This chart shows drawdowns from peak cumulative PnL. When cumulative PnL is at or above
its running maximum (i.e., at a new high), the line is at zero. When below the peak,
the line shows the negative drawdown value. Hovering over a strategy shows its maximum
drawdown in the tooltip.

On initial load, the entire data range is shown. Use "Step Forward" to view the first interval,
then subsequent intervals. Use "Reset" to return to the full view.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_col::Symbol`: Column for x-axis (must be Date, DateTime, or numeric) (default: `:date`)
- `y_transforms::Vector{Tuple{Symbol, String}}`: Y column and transform pairs. Each tuple is
  (column, transform) where transform is "cumulative" or "cumprod".
  For "cumprod", values are treated as returns and compounded correctly: cumprod(1+r) - 1.
  The drawdown is then computed from the transformed values.
  (default: `[(:pnl, "cumulative")]`)
- `color_cols`: Columns for color grouping (strategies). Can be:
  - `Vector{Symbol}`: `[:col1, :col2]` - uses default palette
  - `Vector{Tuple}`: `[(:col1, :default), (:col2, Dict(:val => "#hex"))]` - with custom colors
  (default: `Symbol[]`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`)
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `default_duration_fraction::Float64`: Default duration as fraction of total span (default: `0.2` = 1/5)
- `default_step_fraction::Float64`: Default step size as fraction of total span (default: `0.2` = 1/5)
- `title::String`: Chart title (default: `"Drawdown Chart"`)
- `line_width::Int`: Width of lines (default: `2`)
- `fill::Bool`: Whether to fill area under the drawdown curve (default: `true`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
# Compare strategy drawdowns with cumulative transform
dd = DrawdownPlot(:strategy_drawdowns, df, :pnl_data,
    x_col=:date,
    y_transforms=[(:daily_pnl, "cumulative")],
    color_cols=[:strategy],
    title="Strategy Drawdowns"
)

# Multiple metrics with different transforms
dd = DrawdownPlot(:multi_metric_dd, df, :pnl_data,
    x_col=:date,
    y_transforms=[
        (:daily_pnl, "cumulative"),
        (:daily_pnl_gross, "cumulative"),
        (:daily_return, "cumprod")
    ],
    color_cols=[:strategy],
    title="Multi-Metric Drawdowns"
)

# With custom color mapping
dd = DrawdownPlot(:custom_dd, df, :pnl_data,
    x_col=:date,
    y_transforms=[(:daily_pnl, "cumulative")],
    color_cols=[(:strategy, Dict(:Momentum => "#ff0000", :Value => "#0000ff"))],
    facet_cols=[:region]
)
```
"""
struct DrawdownPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function DrawdownPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_col::Symbol=:date,
                            y_transforms::Vector{Tuple{Symbol, String}}=[(:pnl, "cumulative")],
                            color_cols::ColorColSpec=Symbol[],
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_duration_fraction::Float64=0.2,
                            default_step_fraction::Float64=0.2,
                            title::String="Drawdown Chart",
                            line_width::Int=2,
                            fill::Bool=true,
                            notes::String="")

        # Normalize filters and choices to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Validate x_col exists
        validate_column(df, x_col, "x_col")

        # Validate y_transforms
        valid_transforms = ["cumulative", "cumprod"]
        validated_y_transforms = Tuple{Symbol, String}[]
        df_columns = Symbol.(names(df))
        for (col, transform) in y_transforms
            if !(transform in valid_transforms)
                error("Transform '$transform' for column '$col' must be one of: $(join(valid_transforms, ", "))")
            end
            if col in df_columns
                push!(validated_y_transforms, (col, transform))
            else
                @warn "Column $col not found in DataFrame, skipping"
            end
        end
        if isempty(validated_y_transforms)
            error("No valid y_transforms found. At least one (column, transform) tuple must reference an existing column.")
        end

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build color maps for all possible color columns that exist (with optional custom colors)
        color_maps, color_scales, valid_color_cols = build_color_maps_extended(color_cols, df)

        # Build HTML controls using abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title(true)"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(chart_title_str, normalized_choices, df, update_function)

        # Separate categorical and continuous filters
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]
        choice_cols = [string(d.id)[1:findfirst("_choice_", string(d.id))[1]-1] for d in choice_dropdowns]

        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)
        color_cols_js = build_js_array(valid_color_cols)

        # Build y_transforms as JavaScript array of objects
        y_transforms_js = "[" * join([
            "{col: '$(col)', transform: '$(transform)', label: '$(col) ($(transform))'}"
            for (col, transform) in validated_y_transforms
        ], ", ") * "]"

        # Create color maps as nested JavaScript object (categorical)
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Create color scales as nested JavaScript object (continuous)
        color_scales_js = build_color_scales_js(color_scales)

        # Default columns
        default_color_col = select_default_column(valid_color_cols, "__no_color__")
        x_col_str = string(x_col)

        fill_js = fill ? "'tozeroy'" : "'none'"

        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;
            const X_COL = '$x_col_str';
            const Y_TRANSFORMS = $y_transforms_js;
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const COLOR_SCALES = $color_scales_js;
            const DEFAULT_COLOR_COL = '$default_color_col';

            $JS_COLOR_INTERPOLATION
            const DEFAULT_DURATION_FRACTION = $default_duration_fraction;
            const DEFAULT_STEP_FRACTION = $default_step_fraction;

            let allData = [];

            // Chart state
            window.ddChartState_$chart_title = {
                uniqueXValues: [],
                startIdx: 0,
                duration: 0,
                step: 0,
                timeUnit: 'days',
                unitMultiplier: 1,
                showingFullRange: true,
                totalDuration: 0
            };

            // Determine time unit based on data span
            function determineTimeUnit(xValues) {
                if (xValues.length < 2) return { unit: 'units', multiplier: 1 };

                const first = xValues[0];
                const last = xValues[xValues.length - 1];
                const isDate = first > 946684800000;

                if (!isDate) {
                    return { unit: 'units', multiplier: 1 };
                }

                const spanMs = last - first;
                const spanDays = spanMs / (24 * 60 * 60 * 1000);

                if (spanDays > 3) {
                    return { unit: 'days', multiplier: 24 * 60 * 60 * 1000 };
                } else if (spanDays * 24 > 3) {
                    return { unit: 'hours', multiplier: 60 * 60 * 1000 };
                } else {
                    return { unit: 'minutes', multiplier: 60 * 1000 };
                }
            }

            // Compute drawdown from cumulative values
            // Returns {drawdown: array, maxDrawdown: number}
            function computeDrawdown(cumulativeValues) {
                const drawdown = [];
                let runningMax = -Infinity;
                let maxDrawdown = 0;

                for (let i = 0; i < cumulativeValues.length; i++) {
                    const val = cumulativeValues[i];
                    if (val > runningMax) {
                        runningMax = val;
                    }
                    const dd = val - runningMax;  // This will be <= 0
                    drawdown.push(dd);
                    if (dd < maxDrawdown) {
                        maxDrawdown = dd;
                    }
                }

                return { drawdown: drawdown, maxDrawdown: maxDrawdown };
            }

            // Reset to show full range
            window.resetRange_$chart_title = function() {
                const state = window.ddChartState_$chart_title;
                state.showingFullRange = true;
                state.startIdx = 0;

                const durationInput = document.getElementById('duration_input_$chart_title');
                if (durationInput) {
                    durationInput.value = Math.round(state.totalDuration * 100) / 100;
                }

                window.updateChart_$chart_title(true);
            };

            // Step forward/backward
            window.stepRange_$chart_title = function(direction) {
                const state = window.ddChartState_$chart_title;
                const durationInput = document.getElementById('duration_input_$chart_title');
                const stepInput = document.getElementById('step_input_$chart_title');

                if (state.showingFullRange) {
                    state.showingFullRange = false;
                    const intervalDuration = state.totalDuration * DEFAULT_DURATION_FRACTION;
                    if (durationInput) {
                        durationInput.value = Math.round(intervalDuration * 100) / 100;
                    }

                    if (direction === 'forward') {
                        state.startIdx = 0;
                    } else {
                        const endX = state.uniqueXValues[state.uniqueXValues.length - 1];
                        const startX = endX - intervalDuration * state.unitMultiplier;
                        let newStartIdx = 0;
                        for (let i = state.uniqueXValues.length - 1; i >= 0; i--) {
                            if (state.uniqueXValues[i] <= startX) {
                                newStartIdx = i;
                                break;
                            }
                        }
                        state.startIdx = newStartIdx;
                    }
                    window.updateChart_$chart_title(true);
                    return;
                }

                const step = parseFloat(stepInput.value) || state.step;
                const stepInUnits = step * state.unitMultiplier;
                const numPoints = state.uniqueXValues.length;

                if (direction === 'forward') {
                    const currentStartX = state.uniqueXValues[state.startIdx];
                    const newStartX = currentStartX + stepInUnits;
                    let newStartIdx = state.startIdx;
                    for (let i = state.startIdx; i < numPoints; i++) {
                        if (state.uniqueXValues[i] >= newStartX) {
                            newStartIdx = i;
                            break;
                        }
                        newStartIdx = i;
                    }
                    state.startIdx = Math.min(newStartIdx, numPoints - 1);
                } else {
                    const currentStartX = state.uniqueXValues[state.startIdx];
                    const newStartX = currentStartX - stepInUnits;
                    let newStartIdx = 0;
                    for (let i = state.startIdx; i >= 0; i--) {
                        if (state.uniqueXValues[i] <= newStartX) {
                            newStartIdx = i;
                            break;
                        }
                    }
                    state.startIdx = Math.max(newStartIdx, 0);
                }

                window.updateChart_$chart_title(true);
            };

            window.updateDuration_$chart_title = function() {
                window.updateChart_$chart_title(true);
            };

            window.updateChart_$chart_title = function(preserveRange) {
                const state = window.ddChartState_$chart_title;

                // Get current Y transform selection (combined column + transform)
                const yTransformSelect = document.getElementById('y_transform_select_$chart_title');
                const selectedIdx = yTransformSelect ? parseInt(yTransformSelect.value) : 0;
                const selectedYTransform = Y_TRANSFORMS[selectedIdx] || Y_TRANSFORMS[0];
                const Y_COL = selectedYTransform.col;
                const Y_TRANSFORM = selectedYTransform.transform;

                // Get current filter values
                const filters = {};
                const rangeFilters = {};
                const choices = {};

                // Read choice filters (single-select dropdowns)
                CHOICE_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_choice_$chart_title');
                    if (select) {
                        choices[col] = select.value;
                    }
                });

                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title' + '_slider');
                    if (slider.length > 0 && slider.hasClass('ui-slider')) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                const colorColSelect = document.getElementById('color_col_select_$chart_title');
                const COLOR_COL = colorColSelect ? colorColSelect.value : DEFAULT_COLOR_COL;

                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};

                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters,
                    CHOICE_FILTERS,
                    choices
                );

                // Sort data by X
                filteredData.sort((a, b) => {
                    const aVal = a[X_COL];
                    const bVal = b[X_COL];
                    if (aVal instanceof Date && bVal instanceof Date) {
                        return aVal - bVal;
                    }
                    return aVal < bVal ? -1 : (aVal > bVal ? 1 : 0);
                });

                // Get unique X values
                const uniqueXValues = [...new Set(filteredData.map(row => {
                    const v = row[X_COL];
                    return v instanceof Date ? v.getTime() : v;
                }))].sort((a, b) => a - b);

                state.uniqueXValues = uniqueXValues;

                if (!preserveRange || state.timeUnit === undefined) {
                    const unitInfo = determineTimeUnit(uniqueXValues);
                    state.timeUnit = unitInfo.unit;
                    state.unitMultiplier = unitInfo.multiplier;

                    const unitLabel = document.getElementById('unit_label_$chart_title');
                    const unitLabel2 = document.getElementById('unit_label2_$chart_title');
                    if (unitLabel) unitLabel.textContent = state.timeUnit;
                    if (unitLabel2) unitLabel2.textContent = state.timeUnit;

                    if (uniqueXValues.length >= 2) {
                        const totalSpan = uniqueXValues[uniqueXValues.length - 1] - uniqueXValues[0];
                        state.totalDuration = totalSpan / state.unitMultiplier;
                        state.duration = state.totalDuration * DEFAULT_DURATION_FRACTION;
                        state.step = state.totalDuration * DEFAULT_STEP_FRACTION;
                    } else {
                        state.totalDuration = 1;
                        state.duration = 1;
                        state.step = 1;
                    }

                    state.showingFullRange = true;
                    state.startIdx = 0;

                    const durationInput = document.getElementById('duration_input_$chart_title');
                    const stepInput = document.getElementById('step_input_$chart_title');
                    if (durationInput) durationInput.value = Math.round(state.duration * 100) / 100;
                    if (stepInput) stepInput.value = Math.round(state.step * 100) / 100;
                }

                let startX, endX;
                if (state.showingFullRange) {
                    startX = uniqueXValues[0];
                    endX = uniqueXValues[uniqueXValues.length - 1];
                } else {
                    const durationInput = document.getElementById('duration_input_$chart_title');
                    const duration = parseFloat(durationInput.value) || state.duration;
                    const durationInUnits = duration * state.unitMultiplier;
                    startX = uniqueXValues[state.startIdx] || uniqueXValues[0];
                    endX = startX + durationInUnits;
                }

                let endIdx = state.startIdx;
                for (let i = state.startIdx; i < uniqueXValues.length; i++) {
                    if (uniqueXValues[i] <= endX) {
                        endIdx = i;
                    } else {
                        break;
                    }
                }

                updateIntervalDisplay_$chart_title(startX, uniqueXValues[endIdx], state.timeUnit, state.unitMultiplier);

                let facet1Values = facet1 ? [...new Set(filteredData.map(r => String(r[facet1])))] : [null];
                let facet2Values = facet2 ? [...new Set(filteredData.map(r => String(r[facet2])))] : [null];
                facet1Values.sort();
                facet2Values.sort();

                const nRows = facet2Values.length;
                const nCols = facet1Values.length;
                const hasFacets = facet1 !== null || facet2 !== null;

                // Group FULL data by color
                const fullGroupedData = {};
                filteredData.forEach(row => {
                    const colorVal = (COLOR_COL === '__no_color__') ? 'all' : String(row[COLOR_COL]);
                    const f1Val = facet1 ? String(row[facet1]) : '';
                    const f2Val = facet2 ? String(row[facet2]) : '';
                    const fullKey = colorVal + '|' + f1Val + '|' + f2Val;
                    if (!fullGroupedData[fullKey]) {
                        fullGroupedData[fullKey] = {
                            color: colorVal,
                            facet1: f1Val,
                            facet2: f2Val,
                            rows: []
                        };
                    }
                    fullGroupedData[fullKey].rows.push(row);
                });

                const mainTraces = [];

                for (let fullKey in fullGroupedData) {
                    const groupInfo = fullGroupedData[fullKey];
                    const group = groupInfo.rows;
                    if (group.length === 0) continue;

                    // Sort by X within group
                    group.sort((a, b) => {
                        const aVal = a[X_COL];
                        const bVal = b[X_COL];
                        if (aVal instanceof Date && bVal instanceof Date) {
                            return aVal - bVal;
                        }
                        return aVal < bVal ? -1 : (aVal > bVal ? 1 : 0);
                    });

                    const fullXValues = group.map(row => row[X_COL]);
                    const fullXNumeric = fullXValues.map(v => v instanceof Date ? v.getTime() : v);
                    let fullYValues = group.map(row => parseFloat(row[Y_COL]));

                    // Apply cumulative transform first
                    let cumulative;
                    if (Y_TRANSFORM === 'cumulative') {
                        cumulative = computeCumulativeSum(fullYValues);
                    } else if (Y_TRANSFORM === 'cumprod') {
                        // For cumprod, compute cumulative product of (1+r), result is wealth factor
                        cumulative = computeCumulativeProduct(fullYValues);
                        // Convert from cumulative return to wealth (add 1)
                        cumulative = cumulative.map(v => v + 1);
                    } else {
                        cumulative = computeCumulativeSum(fullYValues);
                    }

                    // Compute drawdown from cumulative
                    const ddResult = computeDrawdown(cumulative);
                    const fullDrawdown = ddResult.drawdown;

                    // Extract range for display
                    const rangeIndices = [];
                    for (let i = 0; i < fullXNumeric.length; i++) {
                        if (fullXNumeric[i] >= startX && fullXNumeric[i] <= endX) {
                            rangeIndices.push(i);
                        }
                    }

                    if (rangeIndices.length > 0) {
                        const rangeXValues = rangeIndices.map(i => fullXValues[i]);

                        // Recalculate drawdown for the window (starting fresh from window start)
                        const windowCumulative = rangeIndices.map(i => cumulative[i]);
                        const windowDdResult = computeDrawdown(windowCumulative);
                        const windowDrawdown = windowDdResult.drawdown;
                        const windowMaxDrawdown = windowDdResult.maxDrawdown;

                        let xAxisNum = 1;
                        let yAxisNum = 1;
                        if (hasFacets) {
                            const f1Idx = facet1 ? facet1Values.indexOf(groupInfo.facet1) : 0;
                            const f2Idx = facet2 ? facet2Values.indexOf(groupInfo.facet2) : 0;
                            const plotIdx = f2Idx * nCols + f1Idx + 1;
                            xAxisNum = plotIdx;
                            yAxisNum = plotIdx;
                        }

                        mainTraces.push({
                            x: rangeXValues,
                            y: windowDrawdown,
                            type: 'scatter',
                            mode: 'lines',
                            name: groupInfo.color,
                            legendgroup: groupInfo.color,
                            showlegend: hasFacets ? (groupInfo.facet1 === facet1Values[0] && groupInfo.facet2 === facet2Values[0]) : true,
                            fill: $fill_js,
                            line: {
                                color: getColor(COLOR_MAPS, COLOR_SCALES, COLOR_COL, groupInfo.color),
                                width: $line_width
                            },
                            xaxis: xAxisNum === 1 ? 'x' : 'x' + xAxisNum,
                            yaxis: yAxisNum === 1 ? 'y' : 'y' + yAxisNum,
                            hovertemplate: '<b>' + groupInfo.color + '</b><br>' +
                                           'Date: %{x}<br>' +
                                           'Drawdown: %{y:.4f}<br>' +
                                           'Max Drawdown: ' + windowMaxDrawdown.toFixed(4) +
                                           '<extra></extra>'
                        });
                    }
                }

                // Build layout
                const yAxisTitle = Y_TRANSFORM === 'cumprod' ? 'Drawdown (wealth)' : 'Drawdown (' + Y_COL + ')';
                const layout = {
                    hovermode: 'closest',
                    showlegend: true,
                    legend: {
                        orientation: 'h',
                        y: 1.02,
                        x: 0.5,
                        xanchor: 'center'
                    },
                    annotations: []
                };

                if (!hasFacets) {
                    layout.xaxis = {
                        title: X_COL,
                        domain: [0, 1],
                        anchor: 'y'
                    };
                    layout.yaxis = {
                        title: yAxisTitle,
                        domain: [0, 1],
                        anchor: 'x'
                    };
                } else {
                    const gapX = 0.05;
                    const gapY = 0.08;
                    const plotWidth = (1 - gapX * (nCols - 1)) / nCols;
                    const plotHeight = (1 - gapY * (nRows - 1)) / nRows;

                    for (let row = 0; row < nRows; row++) {
                        for (let col = 0; col < nCols; col++) {
                            const plotIdx = row * nCols + col + 1;
                            const x0 = col * (plotWidth + gapX);
                            const x1 = x0 + plotWidth;
                            const y1 = 1 - row * (plotHeight + gapY);
                            const y0 = y1 - plotHeight;

                            const xAxisName = plotIdx === 1 ? 'xaxis' : 'xaxis' + plotIdx;
                            const yAxisName = plotIdx === 1 ? 'yaxis' : 'yaxis' + plotIdx;

                            layout[xAxisName] = {
                                domain: [x0, x1],
                                anchor: plotIdx === 1 ? 'y' : 'y' + plotIdx,
                                showticklabels: row === nRows - 1
                            };
                            layout[yAxisName] = {
                                domain: [y0, y1],
                                anchor: plotIdx === 1 ? 'x' : 'x' + plotIdx,
                                showticklabels: col === 0,
                                title: col === 0 && row === Math.floor(nRows / 2) ? yAxisTitle : ''
                            };

                            let facetLabel = '';
                            if (facet1 && facet2) {
                                facetLabel = facet1Values[col] + ' / ' + facet2Values[row];
                            } else if (facet1) {
                                facetLabel = facet1Values[col];
                            } else if (facet2) {
                                facetLabel = facet2Values[row];
                            }

                            layout.annotations.push({
                                text: '<b>' + facetLabel + '</b>',
                                x: (x0 + x1) / 2,
                                y: y1 + 0.02,
                                xref: 'paper',
                                yref: 'paper',
                                showarrow: false,
                                font: { size: 11 }
                            });
                        }
                    }
                }

                Plotly.newPlot('$chart_title', mainTraces, layout, {responsive: true});
            };

            function updateIntervalDisplay_$chart_title(startX, endX, timeUnit, unitMultiplier) {
                const displayDiv = document.getElementById('interval_display_$chart_title');
                if (!displayDiv) return;

                const isDate = startX > 946684800000;

                if (isDate) {
                    const startDate = new Date(startX);
                    const endDate = new Date(endX);

                    const formatDate = (d) => {
                        if (timeUnit === 'days') {
                            return d.getFullYear() + '-' +
                                   String(d.getMonth() + 1).padStart(2, '0') + '-' +
                                   String(d.getDate()).padStart(2, '0');
                        } else {
                            return d.getFullYear() + '-' +
                                   String(d.getMonth() + 1).padStart(2, '0') + '-' +
                                   String(d.getDate()).padStart(2, '0') + ' ' +
                                   String(d.getHours()).padStart(2, '0') + ':' +
                                   String(d.getMinutes()).padStart(2, '0');
                        }
                    };

                    const durationUnits = Math.round((endX - startX) / unitMultiplier * 100) / 100;

                    displayDiv.innerHTML = '<strong>Start:</strong> ' + formatDate(startDate) +
                                           ' &nbsp; <strong>End:</strong> ' + formatDate(endDate) +
                                           ' &nbsp; <strong>Duration:</strong> ' + durationUnits + ' ' + timeUnit;
                } else {
                    const durationUnits = Math.round((endX - startX) * 100) / 100;
                    displayDiv.innerHTML = '<strong>Start:</strong> ' + startX +
                                           ' &nbsp; <strong>End:</strong> ' + endX +
                                           ' &nbsp; <strong>Duration:</strong> ' + durationUnits + ' ' + timeUnit;
                }
            }

            // Load and parse data
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title(false);
                setupAspectRatioControl('$chart_title');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        # Build Y transform dropdown (combined column + transform)
        y_transform_options = join([
            """<option value="$(i-1)"$(i == 1 ? " selected" : "")>$(col) ($(transform))</option>"""
            for (i, (col, transform)) in enumerate(validated_y_transforms)
        ], "\n")

        # Only show dropdown if more than one option
        y_transform_html = if length(validated_y_transforms) > 1
            """
            <div style="display: flex; gap: 15px; flex-wrap: wrap; align-items: center; margin-bottom: 10px;">
                <div>
                    <label for="y_transform_select_$chart_title_str">Metric: </label>
                    <select id="y_transform_select_$chart_title_str" style="padding: 5px 10px;" onchange="$update_function">
                        $y_transform_options
                    </select>
                </div>
            </div>"""
        else
            # Hidden input to store the single value
            """<input type="hidden" id="y_transform_select_$chart_title_str" value="0">"""
        end

        axes_html = y_transform_html * """
            <div style="display: flex; gap: 10px; align-items: center; margin-bottom: 10px; flex-wrap: wrap;">
                <button onclick="resetRange_$chart_title_str()" style="padding: 8px 15px; cursor: pointer; font-size: 14px;">Reset</button>
                <button onclick="stepRange_$chart_title_str('backward')" style="padding: 8px 15px; cursor: pointer; font-size: 14px;">&larr; Step Back</button>
                <div style="display: flex; align-items: center; gap: 5px;">
                    <label>Duration:</label>
                    <input type="number" id="duration_input_$chart_title_str" style="width: 80px; padding: 5px;" onchange="updateDuration_$chart_title_str()">
                    <span id="unit_label_$chart_title_str">days</span>
                </div>
                <div style="display: flex; align-items: center; gap: 5px;">
                    <label>Step:</label>
                    <input type="number" id="step_input_$chart_title_str" style="width: 80px; padding: 5px;">
                    <span>(<span id="unit_label2_$chart_title_str">days</span>)</span>
                </div>
                <button onclick="stepRange_$chart_title_str('forward')" style="padding: 8px 15px; cursor: pointer; font-size: 14px;">Step Forward &rarr;</button>
            </div>
            <div id="interval_display_$chart_title_str" style="font-family: monospace; background: #f5f5f5; padding: 8px 15px; border-radius: 4px; margin-bottom: 10px;">
                <strong>Start:</strong> -- &nbsp; <strong>End:</strong> -- &nbsp; <strong>Duration:</strong> --
            </div>
        """

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # Color column dropdown
        if length(valid_color_cols) > 1
            push!(attribute_dropdowns, DropdownControl(
                "color_col_select_$chart_title_str",
                "Color by",
                [string(col) for col in valid_color_cols],
                string(valid_color_cols[1]),
                update_function
            ))
        end

        # Build faceting dropdowns
        facet_dropdowns = build_facet_dropdowns(chart_title_str, facet_choices, default_facet_array, update_function)

        # Build appearance HTML
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
            choice_dropdowns,
            filter_dropdowns,
            filter_sliders,
            attribute_dropdowns,
            axes_html,
            facet_dropdowns,
            title,
            notes
        )
        appearance_html = generate_appearance_html(controls; aspect_ratio_default=0.5)

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::DrawdownPlot) = [a.data_label]
js_dependencies(::DrawdownPlot) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)

export DrawdownPlot
