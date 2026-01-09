"""
    ExecutionPlot(chart_title::Symbol, top_of_book_df::DataFrame, volume_df::DataFrame, fills_df::DataFrame, execution_metadata_df::DataFrame, data_labels::NTuple{4, Symbol}; kwargs...)

Execution markout chart for analyzing trade execution quality against benchmarks.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `top_of_book_df::DataFrame`: Top of book prices with columns `(time, bid, ask)`
- `volume_df::DataFrame`: Volume in time buckets with columns `(time_from, time_to, volume)`
- `fills_df::DataFrame`: Fill data with columns `(time, quantity, price, execution_name, [color_cols...])`
- `execution_metadata_df::DataFrame`: Metadata with columns `(execution_name, arrival_price, side, desired_quantity)`
- `data_labels::NTuple{4, Symbol}`: Tuple of data labels `(tob_label, volume_label, fills_label, metadata_label)`

# Keyword Arguments
- `time_col::Symbol`: Time column name (default: `:time`)
- `bid_col::Symbol`: Bid price column (default: `:bid`)
- `ask_col::Symbol`: Ask price column (default: `:ask`)
- `time_from_col::Symbol`: Volume start time column (default: `:time_from`)
- `time_to_col::Symbol`: Volume end time column (default: `:time_to`)
- `volume_col::Symbol`: Volume column (default: `:volume`)
- `fill_time_col::Symbol`: Fill time column (default: `:time`)
- `quantity_col::Symbol`: Fill quantity column (default: `:quantity`)
- `price_col::Symbol`: Fill price column (default: `:price`)
- `execution_name_col::Symbol`: Execution identifier column (default: `:execution_name`)
- `color_cols::Vector{Symbol}`: Columns for fill coloring (default: `Symbol[]`)
- `arrival_price_col::Symbol`: Arrival price column (default: `:arrival_price`)
- `side_col::Symbol`: Side column (buy/sell) (default: `:side`)
- `desired_quantity_col::Symbol`: Desired quantity column (default: `:desired_quantity`)
- `title::String`: Chart title (default: `"Execution Markout"`)
- `notes::String`: Descriptive text (default: `""`)

# Examples
```julia
chart = ExecutionPlot(:exec1, tob_df, vol_df, fills_df, metadata_df,
    (:tob_data, :vol_data, :fills_data, :metadata);
    color_cols=[:venue, :aggressiveness],
    title="Trade Execution Analysis"
)
```
"""
struct ExecutionPlot <: JSPlotsType
    chart_title::Symbol
    data_labels::NTuple{4, Symbol}
    functional_html::String
    appearance_html::String

    function ExecutionPlot(chart_title::Symbol,
                             top_of_book_df::DataFrame,
                             volume_df::DataFrame,
                             fills_df::DataFrame,
                             execution_metadata_df::DataFrame,
                             data_labels::NTuple{4, Symbol};
                             time_col::Symbol=:time,
                             bid_col::Symbol=:bid,
                             ask_col::Symbol=:ask,
                             time_from_col::Symbol=:time_from,
                             time_to_col::Symbol=:time_to,
                             volume_col::Symbol=:volume,
                             fill_time_col::Symbol=:time,
                             quantity_col::Symbol=:quantity,
                             price_col::Symbol=:price,
                             execution_name_col::Symbol=:execution_name,
                             color_cols::Vector{Symbol}=Symbol[],
                             arrival_price_col::Symbol=:arrival_price,
                             side_col::Symbol=:side,
                             desired_quantity_col::Symbol=:desired_quantity,
                             title::String="Execution Markout",
                             notes::String="")

        # Validate data labels
        tob_label, volume_label, fills_label, metadata_label = data_labels

        # Sanitize chart title
        chart_title_safe = string(sanitize_chart_title(chart_title))

        # Validate top of book columns
        validate_column(top_of_book_df, time_col, "time_col")
        validate_column(top_of_book_df, bid_col, "bid_col")
        validate_column(top_of_book_df, ask_col, "ask_col")

        # Validate volume columns
        validate_column(volume_df, time_from_col, "time_from_col")
        validate_column(volume_df, time_to_col, "time_to_col")
        validate_column(volume_df, volume_col, "volume_col")

        # Validate fills columns
        validate_column(fills_df, fill_time_col, "fill_time_col")
        validate_column(fills_df, quantity_col, "quantity_col")
        validate_column(fills_df, price_col, "price_col")
        validate_column(fills_df, execution_name_col, "execution_name_col")

        # Validate color columns in fills
        for col in color_cols
            validate_column(fills_df, col, "color_col")
        end

        # Validate metadata columns
        validate_column(execution_metadata_df, execution_name_col, "execution_name_col")
        validate_column(execution_metadata_df, side_col, "side_col")
        validate_column(execution_metadata_df, desired_quantity_col, "desired_quantity_col")

        # Check if arrival_price column exists
        has_arrival = arrival_price_col in Symbol.(names(execution_metadata_df))

        # Build color maps
        color_maps = Dict{String, Dict{String, String}}()
        if !isempty(color_cols)
            color_maps, _ = build_color_maps(color_cols, fills_df)
        end

        # JavaScript constants
        update_function = "updateChart_$chart_title_safe()"

        time_col_js = string(time_col)
        bid_col_js = string(bid_col)
        ask_col_js = string(ask_col)
        time_from_col_js = string(time_from_col)
        time_to_col_js = string(time_to_col)
        volume_col_js = string(volume_col)
        fill_time_col_js = string(fill_time_col)
        quantity_col_js = string(quantity_col)
        price_col_js = string(price_col)
        execution_name_col_js = string(execution_name_col)
        arrival_price_col_js = has_arrival ? string(arrival_price_col) : ""
        side_col_js = string(side_col)
        desired_quantity_col_js = string(desired_quantity_col)

        color_cols_js = build_js_array(color_cols)

        # Build color map JavaScript objects
        color_map_js_objects = String[]
        for col in color_cols
            col_str = string(col)
            if haskey(color_maps, col_str)
                map_str = "{" * join(["'$k': '$v'" for (k, v) in color_maps[col_str]], ", ") * "}"
                push!(color_map_js_objects, "'$col': $map_str")
            end
        end
        color_maps_js = "{" * join(color_map_js_objects, ", ") * "}"

        # Get unique executions
        executions = unique(fills_df[!, execution_name_col])
        default_execution = !isempty(executions) ? string(first(executions)) : ""

        functional_html = """
        (function() {
            // Configuration
            const TIME_COL = '$time_col_js';
            const BID_COL = '$bid_col_js';
            const ASK_COL = '$ask_col_js';
            const TIME_FROM_COL = '$time_from_col_js';
            const TIME_TO_COL = '$time_to_col_js';
            const VOLUME_COL = '$volume_col_js';
            const FILL_TIME_COL = '$fill_time_col_js';
            const QUANTITY_COL = '$quantity_col_js';
            const PRICE_COL = '$price_col_js';
            const EXECUTION_NAME_COL = '$execution_name_col_js';
            const ARRIVAL_PRICE_COL = '$arrival_price_col_js';
            const HAS_ARRIVAL = $(has_arrival);
            const SIDE_COL = '$side_col_js';
            const DESIRED_QUANTITY_COL = '$desired_quantity_col_js';
            const COLOR_COLS = $color_cols_js;
            const COLOR_MAPS = $color_maps_js;
            const COLOR_PALETTE = ['#636efa', '#EF553B', '#00cc96', '#ab63fa', '#FFA15A',
                                   '#19d3f3', '#FF6692', '#B6E880', '#FF97FF', '#FECB52'];

            let tobData = [];
            let volumeData = [];
            let fillsData = [];
            let metadataData = [];
            let deselectedFills = new Set();  // Track manually deselected fills

            window.updateChart_$chart_title_safe = function() {
                // Get current controls
                const execSelect = document.getElementById('execution_select_$chart_title_safe');
                const currentExecution = execSelect ? execSelect.value : '$default_execution';

                const benchmarkSelect = document.getElementById('benchmark_select_$chart_title_safe');
                const benchmark = benchmarkSelect ? benchmarkSelect.value : (HAS_ARRIVAL ? 'arrival' : 'first');

                const showVolumeCheckbox = document.getElementById('show_volume_checkbox_$chart_title_safe');
                const showVolume = showVolumeCheckbox ? showVolumeCheckbox.checked : true;

                // Get data for current execution
                const execMetadata = metadataData.find(row => String(row[EXECUTION_NAME_COL]) === currentExecution);
                if (!execMetadata) {
                    console.error('No metadata found for execution:', currentExecution);
                    return;
                }

                const execFills = fillsData.filter(row => String(row[EXECUTION_NAME_COL]) === currentExecution);
                const side = execMetadata[SIDE_COL];
                const desiredQty = execMetadata[DESIRED_QUANTITY_COL];

                // Calculate benchmark price
                let benchmarkPrice;
                if (benchmark === 'arrival' && HAS_ARRIVAL) {
                    benchmarkPrice = execMetadata[ARRIVAL_PRICE_COL];
                } else {
                    // Use mid price right before first fill
                    if (execFills.length > 0) {
                        const firstFillTime = execFills[0][FILL_TIME_COL];
                        const tobBeforeFirst = tobData.filter(row => row[TIME_COL] <= firstFillTime);
                        if (tobBeforeFirst.length > 0) {
                            const lastTob = tobBeforeFirst[tobBeforeFirst.length - 1];
                            benchmarkPrice = (lastTob[BID_COL] + lastTob[ASK_COL]) / 2;
                        } else {
                            benchmarkPrice = execMetadata[ARRIVAL_PRICE_COL] || 0;
                        }
                    } else {
                        benchmarkPrice = execMetadata[ARRIVAL_PRICE_COL] || 0;
                    }
                }

                // Render chart
                renderChart(execFills, benchmarkPrice, side, desiredQty, showVolume);

                // Render tables
                renderFillsTable(execFills, benchmarkPrice, side, desiredQty);
                renderSummaryTable(execFills, benchmarkPrice, side, desiredQty);
            };

            function renderChart(fills, benchmarkPrice, side, desiredQty, showVolume) {
                const traces = [];

                // Bid and ask lines
                const tobTimes = tobData.map(row => row[TIME_COL]);
                const bids = tobData.map(row => row[BID_COL]);
                const asks = tobData.map(row => row[ASK_COL]);

                traces.push({
                    x: tobTimes,
                    y: bids,
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Bid',
                    line: {color: '#EF553B', width: 2},
                    xaxis: 'x',
                    yaxis: 'y'
                });

                traces.push({
                    x: tobTimes,
                    y: asks,
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Ask',
                    line: {color: '#00cc96', width: 2},
                    xaxis: 'x',
                    yaxis: 'y'
                });

                // Volume bars if enabled
                if (showVolume) {
                    const volTimes = volumeData.map(row => row[TIME_FROM_COL]);
                    const volumes = volumeData.map(row => row[VOLUME_COL]);

                    traces.push({
                        x: volTimes,
                        y: volumes,
                        type: 'bar',
                        name: 'Volume',
                        marker: {color: '#636efa'},
                        xaxis: 'x',
                        yaxis: 'y2'
                    });
                }

                // Fill points
                const activeFills = fills.filter((_, idx) => !deselectedFills.has(idx));

                if (COLOR_COLS.length > 0) {
                    // Group by first color column
                    const colorCol = COLOR_COLS[0];
                    const fillsByColor = {};
                    activeFills.forEach((fill, idx) => {
                        const colorValue = String(fill[colorCol]);
                        if (!fillsByColor[colorValue]) fillsByColor[colorValue] = [];
                        fillsByColor[colorValue].push({fill, originalIdx: idx});
                    });

                    for (let colorValue in fillsByColor) {
                        const items = fillsByColor[colorValue];
                        const fillGroup = items.map(item => item.fill);
                        const color = COLOR_MAPS[colorCol] && COLOR_MAPS[colorCol][colorValue] ?
                                     COLOR_MAPS[colorCol][colorValue] :
                                     COLOR_PALETTE[0];

                        traces.push({
                            x: fillGroup.map(f => f[FILL_TIME_COL]),
                            y: fillGroup.map(f => f[PRICE_COL]),
                            type: 'scatter',
                            mode: 'markers',
                            name: colorValue,
                            marker: {
                                size: fillGroup.map(f => Math.max(5, 5 + Math.log(f[QUANTITY_COL] + 1) * 2)),
                                color: color
                            },
                            xaxis: 'x',
                            yaxis: 'y'
                        });
                    }
                } else {
                    // No color grouping
                    traces.push({
                        x: activeFills.map(f => f[FILL_TIME_COL]),
                        y: activeFills.map(f => f[PRICE_COL]),
                        type: 'scatter',
                        mode: 'markers',
                        name: 'Fills',
                        marker: {
                            size: activeFills.map(f => Math.max(5, 5 + Math.log(f[QUANTITY_COL] + 1) * 2)),
                            color: '#636efa'
                        },
                        xaxis: 'x',
                        yaxis: 'y'
                    });
                }

                // Calculate shortfall timeline
                const sideMultiplier = side === 'buy' ? 1 : -1;
                const shortfallTimes = [];
                const cumImpShortfalls = [];
                const cumVwapShortfalls = [];

                let cumImpShortfall = 0;
                let cumVwapShortfall = 0;

                fills.forEach((fill, idx) => {
                    if (deselectedFills.has(idx)) return;

                    const qty = fill[QUANTITY_COL];
                    const price = fill[PRICE_COL];
                    const rollingVWAP = calculateRollingVWAP(fills, idx);

                    const impShortfall = sideMultiplier * (price - benchmarkPrice) * qty;
                    const vwapShortfall = sideMultiplier * (price - rollingVWAP) * qty;

                    cumImpShortfall += impShortfall;
                    cumVwapShortfall += vwapShortfall;

                    shortfallTimes.push(fill[FILL_TIME_COL]);
                    cumImpShortfalls.push(cumImpShortfall);
                    cumVwapShortfalls.push(cumVwapShortfall);
                });

                // Add shortfall timeline traces
                traces.push({
                    x: shortfallTimes,
                    y: cumImpShortfalls,
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'Imp. Shortfall',
                    line: {color: '#FFA15A', width: 2},
                    marker: {size: 6},
                    xaxis: 'x',
                    yaxis: 'y3',
                    hovertemplate: 'Time: %{x}<br>Imp. Shortfall: %{y:.2f}<extra></extra>'
                });

                traces.push({
                    x: shortfallTimes,
                    y: cumVwapShortfalls,
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'VWAP Shortfall',
                    line: {color: '#ab63fa', width: 2},
                    marker: {size: 6},
                    xaxis: 'x',
                    yaxis: 'y3',
                    hovertemplate: 'Time: %{x}<br>VWAP Shortfall: %{y:.2f}<extra></extra>'
                });

                // Add zero reference line for shortfall chart
                if (shortfallTimes.length > 0) {
                    traces.push({
                        x: [shortfallTimes[0], shortfallTimes[shortfallTimes.length - 1]],
                        y: [0, 0],
                        type: 'scatter',
                        mode: 'lines',
                        name: 'Zero',
                        line: {color: 'gray', width: 1, dash: 'dash'},
                        xaxis: 'x',
                        yaxis: 'y3',
                        showlegend: false,
                        hoverinfo: 'skip'
                    });
                }

                // Adjust layout for three subplots
                const layout = {
                    xaxis: {title: 'Time', anchor: showVolume ? 'y3' : 'y3'},
                    yaxis: {
                        title: 'Price',
                        domain: showVolume ? [0.45, 1] : [0.35, 1]
                    },
                    yaxis3: {
                        title: 'Cumulative Shortfall',
                        domain: [0, showVolume ? 0.25 : 0.3],
                        anchor: 'x'
                    },
                    hovermode: 'closest',
                    showlegend: true
                };

                if (showVolume) {
                    layout.yaxis2 = {
                        title: 'Volume',
                        domain: [0.3, 0.4],
                        anchor: 'x'
                    };
                }

                Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true});
            }

            function calculateRollingVWAP(fills, upToIndex) {
                // Calculate VWAP for active fills up to and including upToIndex
                let totalValue = 0;
                let totalQty = 0;
                for (let i = 0; i <= upToIndex; i++) {
                    if (!deselectedFills.has(i)) {
                        const fill = fills[i];
                        totalValue += fill[PRICE_COL] * fill[QUANTITY_COL];
                        totalQty += fill[QUANTITY_COL];
                    }
                }
                return totalQty > 0 ? totalValue / totalQty : 0;
            }

            function getSpreadCrossing(fill, side) {
                // Find the bid/ask at the fill time
                const fillTime = fill[FILL_TIME_COL];
                const tobAtFill = tobData.filter(row => row[TIME_COL] <= fillTime);
                if (tobAtFill.length === 0) return null;

                const lastTob = tobAtFill[tobAtFill.length - 1];
                const bid = lastTob[BID_COL];
                const ask = lastTob[ASK_COL];
                const spread = ask - bid;

                if (spread <= 0) return null;

                const fillPrice = fill[PRICE_COL];
                if (side === 'buy') {
                    // 0 = bought at bid (neartouch), 1 = bought at ask (fartouch)
                    return Math.max(0, Math.min(1, (fillPrice - bid) / spread));
                } else {
                    // 0 = sold at ask (neartouch), 1 = sold at bid (fartouch)
                    return Math.max(0, Math.min(1, (ask - fillPrice) / spread));
                }
            }

            function renderFillsTable(fills, benchmarkPrice, side, desiredQty) {
                const container = document.getElementById('fills_table_$chart_title_safe');
                if (!container) return;

                let html = '<h4>Fill Details</h4>';
                html += '<table id="fills_table_content_$chart_title_safe" style="width:100%; border-collapse: collapse;">';
                html += '<thead><tr>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Time</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Price</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Quantity</th>';
                COLOR_COLS.forEach(col => {
                    html += `<th style="border: 1px solid #ddd; padding: 8px;">\${col}</th>`;
                });
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Imp. Shortfall</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">VWAP Shortfall</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Spread Cross %</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Remaining %</th>';
                html += '</tr></thead><tbody>';

                let cumQty = 0;
                let cumImpShortfall = 0;
                let cumVwapShortfall = 0;

                fills.forEach((fill, idx) => {
                    const isDeselected = deselectedFills.has(idx);
                    const qty = fill[QUANTITY_COL];
                    const price = fill[PRICE_COL];
                    const sideMultiplier = side === 'buy' ? 1 : -1;

                    if (!isDeselected) {
                        cumQty += qty;
                    }

                    const remaining = Math.max(0, (desiredQty - cumQty) / desiredQty * 100);

                    // Calculate rolling VWAP up to this fill
                    const rollingVWAP = calculateRollingVWAP(fills, idx);

                    const impShortfall = sideMultiplier * (price - benchmarkPrice) * qty;
                    const vwapShortfall = sideMultiplier * (price - rollingVWAP) * qty;
                    const spreadCrossing = getSpreadCrossing(fill, side);

                    if (!isDeselected) {
                        cumImpShortfall += impShortfall;
                        cumVwapShortfall += vwapShortfall;
                    }

                    const bgColor = isDeselected ? '#f0f0f0' : 'white';

                    html += `<tr id="fill_row_\${idx}_$chart_title_safe"
                                 style="background-color: \${bgColor}; cursor: pointer; transition: background-color 0.2s;"
                                 onclick="toggleFill_$chart_title_safe(\${idx})"
                                 onmouseover="highlightFill_$chart_title_safe(\${idx}, true)"
                                 onmouseout="highlightFill_$chart_title_safe(\${idx}, false)">`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${fill[FILL_TIME_COL]}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${price.toFixed(2)}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${qty}</td>`;
                    COLOR_COLS.forEach(col => {
                        html += `<td style="border: 1px solid #ddd; padding: 8px;">\${fill[col]}</td>`;
                    });
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${cumImpShortfall.toFixed(2)}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${cumVwapShortfall.toFixed(2)}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${spreadCrossing !== null ? (spreadCrossing * 100).toFixed(1) + '%' : 'N/A'}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${remaining.toFixed(1)}%</td>`;
                    html += '</tr>';
                });

                html += '</tbody></table>';
                container.innerHTML = html;
            }

            function renderSummaryTable(fills, benchmarkPrice, side, desiredQty) {
                const container = document.getElementById('summary_table_$chart_title_safe');
                if (!container) return;

                // Get active fills only
                const activeFills = fills.filter((_, idx) => !deselectedFills.has(idx));

                let html = '<h4>Summary by Category</h4>';

                if (COLOR_COLS.length === 0) {
                    // No color columns, just show overall summary
                    html += '<p>No categories to aggregate by. Add color_cols for detailed breakdown.</p>';
                    container.innerHTML = html;
                    return;
                }

                // Use first color column for aggregation
                const colorCol = COLOR_COLS[0];
                const categories = {};

                const sideMultiplier = side === 'buy' ? 1 : -1;

                // Need to iterate through all fills (not just active) to get correct indices for rolling VWAP
                fills.forEach((fill, idx) => {
                    if (deselectedFills.has(idx)) return; // Skip deselected fills

                    const category = String(fill[colorCol]);
                    if (!categories[category]) {
                        categories[category] = {
                            totalImpShortfall: 0,
                            totalVwapShortfall: 0,
                            spreadCrossings: [],
                            count: 0,
                            totalQty: 0
                        };
                    }

                    const qty = fill[QUANTITY_COL];
                    const price = fill[PRICE_COL];

                    // Use rolling VWAP up to this fill
                    const rollingVWAP = calculateRollingVWAP(fills, idx);

                    const impShortfall = sideMultiplier * (price - benchmarkPrice) * qty;
                    const vwapShortfall = sideMultiplier * (price - rollingVWAP) * qty;
                    const spreadCrossing = getSpreadCrossing(fill, side);

                    categories[category].totalImpShortfall += impShortfall;
                    categories[category].totalVwapShortfall += vwapShortfall;
                    if (spreadCrossing !== null) {
                        categories[category].spreadCrossings.push(spreadCrossing);
                    }
                    categories[category].count += 1;
                    categories[category].totalQty += qty;
                });

                // Calculate overall totals
                let overallImpShortfall = 0;
                let overallVwapShortfall = 0;
                let overallSpreadCrossings = [];
                let overallCount = 0;
                let overallQty = 0;

                for (let cat in categories) {
                    overallImpShortfall += categories[cat].totalImpShortfall;
                    overallVwapShortfall += categories[cat].totalVwapShortfall;
                    overallSpreadCrossings.push(...categories[cat].spreadCrossings);
                    overallCount += categories[cat].count;
                    overallQty += categories[cat].totalQty;
                }

                html += '<table style="width:100%; border-collapse: collapse;">';
                html += '<thead><tr>';
                html += `<th style="border: 1px solid #ddd; padding: 8px;">\${colorCol}</th>`;
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Fills</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Quantity</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Imp. Shortfall</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">VWAP Shortfall</th>';
                html += '<th style="border: 1px solid #ddd; padding: 8px;">Avg Spread Cross %</th>';
                html += '</tr></thead><tbody>';

                // Sort categories alphabetically
                const sortedCategories = Object.keys(categories).sort();

                sortedCategories.forEach(category => {
                    const data = categories[category];
                    const avgSpreadCrossing = data.spreadCrossings.length > 0 ?
                        data.spreadCrossings.reduce((a, b) => a + b, 0) / data.spreadCrossings.length : null;

                    html += '<tr>';
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${category}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${data.count}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${data.totalQty}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${data.totalImpShortfall.toFixed(2)}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${data.totalVwapShortfall.toFixed(2)}</td>`;
                    html += `<td style="border: 1px solid #ddd; padding: 8px;">\${avgSpreadCrossing !== null ? (avgSpreadCrossing * 100).toFixed(1) + '%' : 'N/A'}</td>`;
                    html += '</tr>';
                });

                // Add overall row
                const overallAvgSpreadCrossing = overallSpreadCrossings.length > 0 ?
                    overallSpreadCrossings.reduce((a, b) => a + b, 0) / overallSpreadCrossings.length : null;

                html += '<tr style="font-weight: bold; background-color: #f9f9f9;">';
                html += '<td style="border: 1px solid #ddd; padding: 8px;">Overall</td>';
                html += `<td style="border: 1px solid #ddd; padding: 8px;">\${overallCount}</td>`;
                html += `<td style="border: 1px solid #ddd; padding: 8px;">\${overallQty}</td>`;
                html += `<td style="border: 1px solid #ddd; padding: 8px;">\${overallImpShortfall.toFixed(2)}</td>`;
                html += `<td style="border: 1px solid #ddd; padding: 8px;">\${overallVwapShortfall.toFixed(2)}</td>`;
                html += `<td style="border: 1px solid #ddd; padding: 8px;">\${overallAvgSpreadCrossing !== null ? (overallAvgSpreadCrossing * 100).toFixed(1) + '%' : 'N/A'}</td>`;
                html += '</tr>';

                html += '</tbody></table>';
                container.innerHTML = html;
            }

            window.toggleFill_$chart_title_safe = function(idx) {
                if (deselectedFills.has(idx)) {
                    deselectedFills.delete(idx);
                } else {
                    deselectedFills.add(idx);
                }
                updateChart_$chart_title_safe();
            };

            window.highlightFill_$chart_title_safe = function(idx, isHighlighted) {
                // Get the chart element
                const chartDiv = document.getElementById('$chart_title_safe');
                if (!chartDiv || !chartDiv.data) return;

                // Find which trace contains this fill
                const execSelect = document.getElementById('execution_select_$chart_title_safe');
                const currentExecution = execSelect ? execSelect.value : '$default_execution';
                const execFills = fillsData.filter(row => String(row[EXECUTION_NAME_COL]) === currentExecution);
                const fill = execFills[idx];
                if (!fill) return;

                // Find the trace and point index
                const fillTime = fill[FILL_TIME_COL];
                const fillPrice = fill[PRICE_COL];

                // Iterate through traces to find the matching fill point
                chartDiv.data.forEach((trace, traceIdx) => {
                    if (trace.mode === 'markers' || trace.mode === 'markers+lines') {
                        trace.x.forEach((x, pointIdx) => {
                            if (x === fillTime && Math.abs(trace.y[pointIdx] - fillPrice) < 0.01) {
                                // Found the point, update its marker
                                const update = {};
                                if (isHighlighted) {
                                    // Increase size and add border
                                    const currentSize = trace.marker.size[pointIdx] || trace.marker.size || 8;
                                    update['marker.size'] = trace.marker.size.map((s, i) =>
                                        i === pointIdx ? s * 1.5 : s
                                    );
                                    update['marker.line'] = {
                                        color: 'black',
                                        width: trace.marker.size.map((s, i) => i === pointIdx ? 2 : 0)
                                    };
                                } else {
                                    // Reset to original size
                                    const originalSize = Math.max(5, 5 + Math.log(fill[QUANTITY_COL] + 1) * 2);
                                    update['marker.size'] = trace.marker.size.map((s, i) =>
                                        i === pointIdx ? originalSize : s
                                    );
                                    update['marker.line'] = {width: 0};
                                }
                                Plotly.restyle(chartDiv, update, [traceIdx]);
                            }
                        });
                    }
                });
            };

            // Load data
            Promise.all([
                loadDataset('$tob_label'),
                loadDataset('$volume_label'),
                loadDataset('$fills_label'),
                loadDataset('$metadata_label')
            ]).then(function([tob, vol, fills, metadata]) {
                tobData = tob;
                volumeData = vol;
                fillsData = fills;
                metadataData = metadata;

                updateChart_$chart_title_safe();
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title_safe:', error);
            });
        })();
        """

        # Build appearance HTML
        appearance_html = """
        <div style="padding: 20px;">
            <h2>$title</h2>
            <p>$notes</p>

            <div style="margin: 20px 0;">
                <label for="execution_select_$chart_title_safe">Execution: </label>
                <select id="execution_select_$chart_title_safe" onchange="$update_function">
        """

        for exec in executions
            exec_str = string(exec)
            selected = exec_str == default_execution ? " selected" : ""
            appearance_html *= "                    <option value=\"$exec_str\"$selected>$exec_str</option>\n"
        end

        appearance_html *= """
                </select>

                <label for="benchmark_select_$chart_title_safe" style="margin-left: 20px;">Benchmark: </label>
                <select id="benchmark_select_$chart_title_safe" onchange="$update_function">
        """

        if has_arrival
            appearance_html *= """
                    <option value="arrival" selected>Arrival</option>
                    <option value="first">First Fill Mid</option>
            """
        else
            appearance_html *= """
                    <option value="first" selected>First Fill Mid</option>
            """
        end

        appearance_html *= """
                </select>

                <label style="margin-left: 20px;">
                    <input type="checkbox" id="show_volume_checkbox_$chart_title_safe" checked onchange="$update_function">
                    Show Volume
                </label>
            </div>

            <div id="$chart_title_safe" style="width: 100%; height: 800px;"></div>

            <div style="display: flex; margin-top: 20px;">
                <div id="fills_table_$chart_title_safe" style="flex: 1; margin-right: 20px;"></div>
                <div id="summary_table_$chart_title_safe" style="flex: 1;"></div>
            </div>
        </div>
        """

        new(chart_title, data_labels, functional_html, appearance_html)
    end
end

dependencies(a::ExecutionPlot) = collect(a.data_labels)
