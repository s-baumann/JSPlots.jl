"""
    CumPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Cumulative performance chart for comparing strategies over time with text-based range controls.

# Description
This chart is designed for comparing multiple strategies' cumulative performance (like PnL).
The main chart shows cumulative or cumulative product of Y values, normalized so all lines
start at 1 at the selected start date. Text inputs control the duration and step size.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_col::Symbol`: Column for x-axis (must be Date, DateTime, or numeric) (default: `:date`)
- `y_cols::Vector{Symbol}`: Columns available for y-axis values (like daily PnL) (default: `[:pnl]`)
- `color_cols::Vector{Symbol}`: Columns available for color grouping (like strategy name) (default: `Symbol[]`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`)
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `default_transform::String`: Default Y transform - "cumulative" or "cumprod" (default: `"cumulative"`)
- `title::String`: Chart title (default: `"Cumulative Chart"`)
- `line_width::Int`: Width of lines (default: `2`)
- `marker_size::Int`: Size of markers (default: `0` - no markers)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
# Compare strategy performance
cc = CumPlot(:strategy_comparison, df, :pnl_data,
    x_col=:date,
    y_cols=[:daily_pnl],
    color_cols=[:strategy],
    title="Strategy Performance Comparison"
)
```
"""
struct CumPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function CumPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_col::Symbol=:date,
                            y_cols::Vector{Symbol}=[:pnl],
                            color_cols::Vector{Symbol}=Symbol[],
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_transform::String="cumulative",
                            title::String="Cumulative Chart",
                            line_width::Int=2,
                            marker_size::Int=0,
                            notes::String="")

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)

        # Validate x_col exists
        validate_column(df, x_col, "x_col")

        # Validate columns exist in dataframe
        valid_y_cols = validate_and_filter_columns(y_cols, df, "y_cols")

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Validate default_transform
        valid_transforms = ["cumulative", "cumprod"]
        if !(default_transform in valid_transforms)
            error("default_transform must be one of: $(join(valid_transforms, ", "))")
        end

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build color maps for all possible color columns that exist
        color_maps, valid_color_cols = build_color_maps(color_cols, df)

        # Build HTML controls using abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title(true)"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)

        # Separate categorical and continuous filters
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]

        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        y_cols_js = build_js_array(valid_y_cols)
        color_cols_js = build_js_array(valid_color_cols)

        # Create color maps as nested JavaScript object
        color_maps_js = "{" * join([
            "'$col': {" * join(["'$k': '$v'" for (k, v) in map], ", ") * "}"
            for (col, map) in color_maps
        ], ", ") * "}"

        # Default columns
        default_y_col = string(valid_y_cols[1])
        default_color_col = select_default_column(valid_color_cols, "__no_color__")
        x_col_str = string(x_col)

        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const X_COL = '$x_col_str';
            const Y_COLS = $y_cols_js;
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const DEFAULT_Y_COL = '$default_y_col';
            const DEFAULT_COLOR_COL = '$default_color_col';
            const DEFAULT_TRANSFORM = '$default_transform';

            let allData = [];

            // Chart state
            window.cumChartState_$chart_title = {
                uniqueXValues: [],
                startIdx: 0,
                duration: 0,  // in units
                step: 0,      // in units
                timeUnit: 'days',  // 'days', 'hours', 'minutes', 'seconds', or 'units'
                unitMultiplier: 1  // milliseconds per unit (or 1 for numeric)
            };

            // Determine time unit based on data span
            function determineTimeUnit(xValues) {
                if (xValues.length < 2) return { unit: 'units', multiplier: 1 };

                const first = xValues[0];
                const last = xValues[xValues.length - 1];

                // Check if values are dates (timestamps in ms)
                const isDate = first > 946684800000; // After year 2000

                if (!isDate) {
                    return { unit: 'units', multiplier: 1 };
                }

                const spanMs = last - first;
                const spanSeconds = spanMs / 1000;
                const spanMinutes = spanSeconds / 60;
                const spanHours = spanMinutes / 60;
                const spanDays = spanHours / 24;

                if (spanDays > 3) {
                    return { unit: 'days', multiplier: 24 * 60 * 60 * 1000 };
                } else if (spanHours > 3) {
                    return { unit: 'hours', multiplier: 60 * 60 * 1000 };
                } else if (spanMinutes > 3) {
                    return { unit: 'minutes', multiplier: 60 * 1000 };
                } else if (spanSeconds > 3) {
                    return { unit: 'seconds', multiplier: 1000 };
                } else {
                    return { unit: 'units', multiplier: 1 };
                }
            }

            // Step forward/backward
            window.stepRange_$chart_title = function(direction) {
                const state = window.cumChartState_$chart_title;
                const stepInput = document.getElementById('step_input_$chart_title');
                const step = parseFloat(stepInput.value) || state.step;

                const stepInUnits = step * state.unitMultiplier;
                const numPoints = state.uniqueXValues.length;

                if (direction === 'forward') {
                    // Find new start index
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
                    // Find new start index going backward
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

            // Update duration from input
            window.updateDuration_$chart_title = function() {
                window.updateChart_$chart_title(true);
            };

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title = function(preserveRange) {
                const state = window.cumChartState_$chart_title;

                // Get current Y column
                const yColSelect = document.getElementById('y_col_select_$chart_title');
                const Y_COL = yColSelect ? yColSelect.value : DEFAULT_Y_COL;

                // Get current Y transform
                const yTransformSelect = document.getElementById('y_transform_select_$chart_title');
                const Y_TRANSFORM = yTransformSelect ? yTransformSelect.value : DEFAULT_TRANSFORM;

                // Get current filter values
                const filters = {};
                const rangeFilters = {};

                // Read categorical filters (dropdowns)
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Read continuous filters (range sliders)
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title' + '_slider');
                    if (slider.length > 0 && slider.hasClass('ui-slider')) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                // Get current color column
                const colorColSelect = document.getElementById('color_col_select_$chart_title');
                const COLOR_COL = colorColSelect ? colorColSelect.value : DEFAULT_COLOR_COL;

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                // Get color map for current selection
                const COLOR_MAP = COLOR_MAPS[COLOR_COL] || {};

                // Apply filters with observation counting (centralized function)
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters
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

                // Determine time unit on first load or when data changes significantly
                if (!preserveRange || state.timeUnit === undefined) {
                    const unitInfo = determineTimeUnit(uniqueXValues);
                    state.timeUnit = unitInfo.unit;
                    state.unitMultiplier = unitInfo.multiplier;

                    // Update unit labels
                    const unitLabel = document.getElementById('unit_label_$chart_title');
                    const unitLabel2 = document.getElementById('unit_label2_$chart_title');
                    if (unitLabel) {
                        unitLabel.textContent = state.timeUnit;
                    }
                    if (unitLabel2) {
                        unitLabel2.textContent = state.timeUnit;
                    }

                    // Set default duration (full span) and step (1/5 of duration)
                    if (uniqueXValues.length >= 2) {
                        const totalSpan = uniqueXValues[uniqueXValues.length - 1] - uniqueXValues[0];
                        state.duration = totalSpan / state.unitMultiplier;
                        state.step = state.duration / 5;
                    } else {
                        state.duration = 1;
                        state.step = 1;
                    }

                    // Update input fields
                    const durationInput = document.getElementById('duration_input_$chart_title');
                    const stepInput = document.getElementById('step_input_$chart_title');
                    if (durationInput) durationInput.value = Math.round(state.duration * 100) / 100;
                    if (stepInput) stepInput.value = Math.round(state.step * 100) / 100;

                    state.startIdx = 0;
                }

                // Read duration from input
                const durationInput = document.getElementById('duration_input_$chart_title');
                const duration = parseFloat(durationInput.value) || state.duration;
                const durationInUnits = duration * state.unitMultiplier;

                // Calculate end index based on start and duration
                const startX = uniqueXValues[state.startIdx] || uniqueXValues[0];
                const endX = startX + durationInUnits;

                // Find end index
                let endIdx = state.startIdx;
                for (let i = state.startIdx; i < uniqueXValues.length; i++) {
                    if (uniqueXValues[i] <= endX) {
                        endIdx = i;
                    } else {
                        break;
                    }
                }

                // Update interval display
                updateIntervalDisplay_$chart_title(startX, uniqueXValues[endIdx], state.timeUnit, state.unitMultiplier);

                // Get unique facet values if faceting is selected
                let facet1Values = facet1 ? [...new Set(filteredData.map(r => String(r[facet1])))] : [null];
                let facet2Values = facet2 ? [...new Set(filteredData.map(r => String(r[facet2])))] : [null];
                facet1Values.sort();
                facet2Values.sort();

                const nRows = facet2Values.length;
                const nCols = facet1Values.length;
                const hasFacets = facet1 !== null || facet2 !== null;

                // Group FULL data by color (for computing cumulative on full range)
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

                // Compute cumulative on FULL data for each group, then extract range and normalize
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

                    // Apply cumulative transform on FULL data
                    if (Y_TRANSFORM === 'cumulative') {
                        fullYValues = computeCumulativeSum(fullYValues);
                    } else if (Y_TRANSFORM === 'cumprod') {
                        fullYValues = computeCumulativeProduct(fullYValues);
                    }

                    // Extract range for main chart
                    const rangeIndices = [];
                    for (let i = 0; i < fullXNumeric.length; i++) {
                        if (fullXNumeric[i] >= startX && fullXNumeric[i] <= endX) {
                            rangeIndices.push(i);
                        }
                    }

                    if (rangeIndices.length > 0) {
                        const rangeXValues = rangeIndices.map(i => fullXValues[i]);
                        let rangeYValues = rangeIndices.map(i => fullYValues[i]);

                        // Normalize: divide all values by the FIRST value in the range
                        const firstVal = rangeYValues[0];
                        if (firstVal !== 0 && !isNaN(firstVal) && isFinite(firstVal)) {
                            rangeYValues = rangeYValues.map(v => v / firstVal);
                        }

                        // Determine which subplot this trace belongs to
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
                            y: rangeYValues,
                            type: 'scatter',
                            mode: $marker_size > 0 ? 'lines+markers' : 'lines',
                            name: groupInfo.color,
                            legendgroup: groupInfo.color,
                            showlegend: hasFacets ? (groupInfo.facet1 === facet1Values[0] && groupInfo.facet2 === facet2Values[0]) : true,
                            line: {
                                color: COLOR_MAP[groupInfo.color] || '#000000',
                                width: $line_width
                            },
                            marker: { size: $marker_size },
                            xaxis: xAxisNum === 1 ? 'x' : 'x' + xAxisNum,
                            yaxis: yAxisNum === 1 ? 'y' : 'y' + yAxisNum
                        });
                    }
                }

                // Build layout
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

                // Setup axes based on faceting
                if (!hasFacets) {
                    layout.xaxis = {
                        title: X_COL,
                        domain: [0, 1],
                        anchor: 'y'
                    };
                    layout.yaxis = {
                        title: 'Normalized ' + (Y_TRANSFORM === 'cumulative' ? 'Cumulative' : 'CumProd') + '(' + Y_COL + ')',
                        domain: [0, 1],
                        anchor: 'x'
                    };
                } else {
                    // Faceted layout
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
                                title: col === 0 && row === Math.floor(nRows / 2) ?
                                    'Normalized ' + (Y_TRANSFORM === 'cumulative' ? 'Cumulative' : 'CumProd') + '(' + Y_COL + ')' : ''
                            };

                            // Add facet label annotation
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
                                   String(d.getMinutes()).padStart(2, '0') + ':' +
                                   String(d.getSeconds()).padStart(2, '0');
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

            // Load and parse data using centralized parser
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title(false);

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        # Build Y column dropdown
        y_col_options = join(["""<option value="$(col)"$(string(col) == default_y_col ? " selected" : "")>$(col)</option>"""
                            for col in valid_y_cols], "\n")

        y_col_html = if length(valid_y_cols) > 1
            """
            <div style="display: flex; gap: 15px; flex-wrap: wrap; align-items: center; margin-bottom: 10px;">
                <div>
                    <label for="y_col_select_$chart_title_str">Y Variable: </label>
                    <select id="y_col_select_$chart_title_str" style="padding: 5px 10px;" onchange="$update_function">
                        $y_col_options
                    </select>
                </div>
            """
        else
            "<div style=\"display: flex; gap: 15px; flex-wrap: wrap; align-items: center; margin-bottom: 10px;\">\n"
        end

        # Y transform dropdown (only cumulative and cumprod)
        y_transform_options_html = join([
            """<option value="cumulative"$(default_transform == "cumulative" ? " selected" : "")>cumulative</option>""",
            """<option value="cumprod"$(default_transform == "cumprod" ? " selected" : "")>cumprod</option>"""
        ], "\n")

        axes_html = y_col_html * """
                <div>
                    <label for="y_transform_select_$chart_title_str">Transform: </label>
                    <select id="y_transform_select_$chart_title_str" style="padding: 5px 10px;" onchange="$update_function">
                        $y_transform_options_html
                    </select>
                </div>
            </div>
            <div style="display: flex; gap: 10px; align-items: center; margin-bottom: 10px; flex-wrap: wrap;">
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

        # Build faceting dropdowns using html_controls abstraction
        facet_dropdowns = build_facet_dropdowns(chart_title_str, facet_choices, default_facet_array, update_function)

        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
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

dependencies(a::CumPlot) = [a.data_label]
js_dependencies(::CumPlot) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
