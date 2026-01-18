"""
    prepare_execution_data(exec_data::RefinedSlippage.ExecutionData)

Prepare ExecutionData for visualization in ExecutionPlot.
Returns a Dict with all necessary DataFrames for the JavaScript visualization.

This function extracts data from RefinedSlippage.ExecutionData and computes cumulative
values needed for the visualization using the already-calculated per-fill metrics.
"""
function prepare_execution_data(exec_data)
    # Ensure slippage has been calculated
    if ismissing(exec_data.fill_returns)
        error("Slippage not yet calculated. Run RefinedSlippage.calculate_slippage!(exec_data) first.")
    end

    # Get unique executions
    execution_names = unique(exec_data.fills.execution_name)

    # Use fill_returns as our base - it has all the per-fill computed values
    fill_returns = copy(exec_data.fill_returns)
    has_counterfactual = "counterfactual_price" in names(fill_returns)
    has_spread_cross = "spread_cross" in names(fill_returns)
    has_market_vwap = "market_vwap" in names(fill_returns)

    # Merge with original fills to preserve any extra columns (like order_type, exchange for coloring)
    # Only add columns from original fills that aren't already in fill_returns
    original_fills = exec_data.fills
    for col in names(original_fills)
        if !(col in names(fill_returns))
            fill_returns[!, col] = original_fills[!, col]
        end
    end

    # Get list of peer columns (columns that are not standard and not categorical)
    standard_cols = ["time", "quantity", "price", "execution_name", "asset",
                     "arrival_price", "side", "counterfactual_price", "spread_cross", "market_vwap"]
    # Peer cols are numeric columns that contain returns (not categorical)
    peer_cols = String[]
    for col in names(fill_returns)
        if col in standard_cols
            continue
        end
        col_type = eltype(fill_returns[!, col])
        # Only include numeric columns as peer columns
        if col_type <: Union{Number, Missing} || (col_type isa Union && any(t -> t <: Number, Base.uniontypes(col_type)))
            push!(peer_cols, col)
        end
    end

    # Prepare TOB data
    tob_df = copy(exec_data.tob)
    tob_df[!, :mid_price] = (tob_df.bid_price .+ tob_df.ask_price) ./ 2

    # Prepare summary metrics (in basis points)
    summary_df = copy(exec_data.summary_bps)

    # Join with metadata to get desired_quantity
    fills_enriched = leftjoin(
        fill_returns,
        exec_data.metadata[:, [:execution_name, :desired_quantity]],
        on = :execution_name
    )

    # Pre-create cumulative columns
    n_rows = nrow(fills_enriched)
    fills_enriched[!, :cum_quantity] = zeros(Float64, n_rows)
    fills_enriched[!, :pct_complete] = zeros(Float64, n_rows)
    # Cumulative slippage in three units: bps, pct, usd
    fills_enriched[!, :cum_classical_slippage_bps] = zeros(Float64, n_rows)
    fills_enriched[!, :cum_classical_slippage_pct] = zeros(Float64, n_rows)
    fills_enriched[!, :cum_classical_slippage_usd] = zeros(Float64, n_rows)
    if has_counterfactual
        fills_enriched[!, :cum_refined_slippage_bps] = zeros(Float64, n_rows)
        fills_enriched[!, :cum_refined_slippage_pct] = zeros(Float64, n_rows)
        fills_enriched[!, :cum_refined_slippage_usd] = zeros(Float64, n_rows)
    end
    if has_spread_cross
        fills_enriched[!, :cum_spread_cross] = zeros(Float64, n_rows)
    end
    if has_market_vwap
        fills_enriched[!, :cum_vs_vwap_slippage_bps] = fill(NaN, n_rows)
        fills_enriched[!, :cum_vs_vwap_slippage_pct] = fill(NaN, n_rows)
        fills_enriched[!, :cum_vs_vwap_slippage_usd] = fill(NaN, n_rows)
    end

    # Calculate cumulative values for each execution
    for exec_name in execution_names
        mask = fills_enriched.execution_name .== exec_name
        exec_fills = fills_enriched[mask, :]
        sorted_idx = sortperm(exec_fills.time)
        orig_indices = findall(mask)[sorted_idx]

        # Get sorted values from fill_returns
        sorted_quantities = exec_fills.quantity[sorted_idx]
        sorted_prices = exec_fills.price[sorted_idx]
        arrival_price = exec_fills.arrival_price[1]
        side = exec_fills.side[1]
        side_sign = side == "buy" ? -1.0 : 1.0

        # Cumulative quantity and percentage
        cum_qty = cumsum(sorted_quantities)
        total_qty = sum(sorted_quantities)
        pct_complete = cum_qty ./ total_qty

        # Cumulative classical slippage (using price and arrival_price from fill_returns)
        # Calculate in all three units: bps, pct, usd
        cum_classical_cost = cumsum((sorted_prices .- arrival_price) .* sorted_quantities)
        cum_classical_slippage_bps = side_sign .* cum_classical_cost ./ (cum_qty .* arrival_price) .* 10000
        cum_classical_slippage_pct = side_sign .* cum_classical_cost ./ (cum_qty .* arrival_price) .* 100
        cum_classical_slippage_usd = side_sign .* cum_classical_cost

        for (i, orig_idx) in enumerate(orig_indices)
            fills_enriched[orig_idx, :cum_quantity] = cum_qty[i]
            fills_enriched[orig_idx, :pct_complete] = pct_complete[i]
            fills_enriched[orig_idx, :cum_classical_slippage_bps] = cum_classical_slippage_bps[i]
            fills_enriched[orig_idx, :cum_classical_slippage_pct] = cum_classical_slippage_pct[i]
            fills_enriched[orig_idx, :cum_classical_slippage_usd] = cum_classical_slippage_usd[i]
        end

        # Cumulative refined slippage (using counterfactual_price from fill_returns)
        if has_counterfactual
            sorted_cf = exec_fills.counterfactual_price[sorted_idx]
            cum_refined_cost = cumsum((sorted_prices .- sorted_cf) .* sorted_quantities)
            cum_refined_slippage_bps = side_sign .* cum_refined_cost ./ (cum_qty .* arrival_price) .* 10000
            cum_refined_slippage_pct = side_sign .* cum_refined_cost ./ (cum_qty .* arrival_price) .* 100
            cum_refined_slippage_usd = side_sign .* cum_refined_cost

            for (i, orig_idx) in enumerate(orig_indices)
                fills_enriched[orig_idx, :cum_refined_slippage_bps] = cum_refined_slippage_bps[i]
                fills_enriched[orig_idx, :cum_refined_slippage_pct] = cum_refined_slippage_pct[i]
                fills_enriched[orig_idx, :cum_refined_slippage_usd] = cum_refined_slippage_usd[i]
            end
        end

        # Cumulative vs_vwap slippage (using market_vwap from fill_returns)
        if has_market_vwap && !all(ismissing, exec_fills.market_vwap)
            cum_fill_value = cumsum(sorted_prices .* sorted_quantities)
            cum_fill_vwap = cum_fill_value ./ cum_qty
            sorted_market_vwap = exec_fills.market_vwap[sorted_idx]

            for (i, orig_idx) in enumerate(orig_indices)
                if !ismissing(sorted_market_vwap[i])
                    vs_vwap_bps = side_sign * (cum_fill_vwap[i] - sorted_market_vwap[i]) / arrival_price * 10000
                    vs_vwap_pct = side_sign * (cum_fill_vwap[i] - sorted_market_vwap[i]) / arrival_price * 100
                    vs_vwap_usd = side_sign * (cum_fill_vwap[i] - sorted_market_vwap[i]) * cum_qty[i]
                    fills_enriched[orig_idx, :cum_vs_vwap_slippage_bps] = vs_vwap_bps
                    fills_enriched[orig_idx, :cum_vs_vwap_slippage_pct] = vs_vwap_pct
                    fills_enriched[orig_idx, :cum_vs_vwap_slippage_usd] = vs_vwap_usd
                end
            end
        end

        # Cumulative average spread crossing (using spread_cross from fill_returns)
        if has_spread_cross
            sorted_spread_cross = exec_fills.spread_cross[sorted_idx]
            cum_spread_cross = cumsum(sorted_spread_cross .* sorted_quantities) ./ cum_qty

            for (i, orig_idx) in enumerate(orig_indices)
                fills_enriched[orig_idx, :cum_spread_cross] = cum_spread_cross[i]
            end
        end
    end

    # spread_cross is already (price - bid) / spread, which is the normalized position
    # Rename it for clarity in the visualization
    if has_spread_cross
        fills_enriched[!, :norm_fill_pos] = fills_enriched.spread_cross
    else
        fills_enriched[!, :norm_fill_pos] = fill(0.5, nrow(fills_enriched))
    end

    # Prepare volume data if available
    volume_df = if !ismissing(exec_data.volume)
        copy(exec_data.volume)
    else
        DataFrame()
    end

    # Store DataFrames for export and visualization
    result = Dict{Symbol, Any}(
        :fills => fills_enriched,
        :tob => tob_df,
        :volume => volume_df,
        :peer_cols => peer_cols,
        :has_counterfactual => has_counterfactual,
        :has_spread_cross => has_spread_cross,
        :has_vs_vwap => "vs_vwap_slippage" in names(summary_df),
        :has_volume => !ismissing(exec_data.volume),
        :fill_returns => copy(exec_data.fill_returns),
        :summary_bps => copy(exec_data.summary_bps)
    )

    # Add optional summary DataFrames if present
    if !ismissing(exec_data.summary_pct)
        result[:summary_pct] = copy(exec_data.summary_pct)
    end
    if !ismissing(exec_data.summary_usd)
        result[:summary_usd] = copy(exec_data.summary_usd)
    end

    return result
end


"""
    ExecutionPlot(chart_title::Symbol, exec_data, data_label::Symbol; kwargs...)

Interactive execution analysis visualization for trading execution data from RefinedSlippage.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `exec_data`: ExecutionData object from RefinedSlippage package (with calculate_slippage! already called)
- `data_label::Symbol`: Symbol referencing the prepared data in the page's data dictionary

# Keyword Arguments
- `color_cols::Vector{Symbol}`: Columns that can be used to color fills (default: auto-detected from fills)
- `default_color_col::Union{Symbol, Nothing}`: Default column for coloring (default: nothing = single color)
- `tooltip_cols::Vector{Symbol}`: Additional columns to show in fill tooltips (default: []). Color columns are automatically included.
- `metadata_cols::Vector{Symbol}`: Additional columns from metadata to show in summary table (default: [])
- `title::String`: Chart title (default: "Execution Analysis")
- `notes::String`: Descriptive text shown below the chart (default: "")

# Views (switchable via buttons)
1. **Bid/Ask + Fills**: Shows bid/ask lines with fill points, optional volume bars
2. **Mid + Counterfactual**: Mid price line with counterfactual price and fills
3. **With Peers**: Same as view 2 plus grey peer price lines (peer returns applied to arrival price)
4. **Execution Progress**: Empirical CDF showing cumulative executed quantity over time
5. **Spread Position**: Normalized view (bid=0, ask=1) showing where fills occurred in spread
6. **Slippage**: Cumulative classical, refined, and vs-VWAP slippage over time

# Example
```julia
using RefinedSlippage, JSPlots

# Calculate slippage first
calculate_slippage!(exec_data)

# Create the visualization
exec_plot = ExecutionPlot(:execution_analysis, exec_data, :exec_data;
    title = "Order Execution Analysis",
    notes = "Analyze execution quality across multiple orders"
)

# Add to page
page = JSPlotPage(
    Dict{Symbol, Any}(:exec_data => exec_data),
    [exec_plot]
)
create_html(page, "execution_analysis.html")
```
"""
struct ExecutionPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    prepared_data::Dict{Symbol, Any}  # Store prepared data for serialization

    function ExecutionPlot(chart_title::Symbol, exec_data, data_label::Symbol;
                          color_cols::Vector{Symbol}=Symbol[],
                          default_color_col::Union{Symbol, Nothing}=nothing,
                          tooltip_cols::Vector{Symbol}=Symbol[],
                          metadata_cols::Vector{Symbol}=Symbol[],
                          title::String="Execution Analysis",
                          notes::String="")

        # Prepare execution data
        prepared = prepare_execution_data(exec_data)

        # Sanitize chart title for use in JavaScript/HTML IDs
        chart_title_safe = string(sanitize_chart_title(chart_title))

        # Get execution names for dropdown
        execution_names = unique(prepared[:fills].execution_name)

        # Auto-detect color columns if not provided
        fills_df = prepared[:fills]
        if isempty(color_cols)
            # Look for categorical columns that could be used for coloring
            standard_cols = ["time", "quantity", "price", "execution_name", "asset", "arrival_price",
                           "side", "counterfactual_price", "spread_cross", "market_vwap",
                           "cum_quantity", "pct_complete", "cum_classical_slippage",
                           "cum_refined_slippage", "cum_vs_vwap_slippage", "cum_spread_cross",
                           "bid_price", "ask_price", "norm_fill_pos", "desired_quantity"]
            potential_cols = Symbol[]
            for col in names(fills_df)
                if col in standard_cols
                    continue
                end
                # Check if it's a categorical column
                if eltype(fills_df[!, col]) <: Union{AbstractString, Symbol, Missing}
                    push!(potential_cols, Symbol(col))
                end
            end
            color_cols = potential_cols
        end

        # Validate default_color_col
        if default_color_col !== nothing && !(default_color_col in color_cols)
            error("default_color_col '$default_color_col' must be in color_cols: $color_cols")
        end

        # Combine color_cols and tooltip_cols for tooltip display
        # Color columns are automatically included in tooltips
        df_col_names = Symbol.(names(fills_df))
        all_tooltip_cols = Symbol[]
        append!(all_tooltip_cols, color_cols)
        for col in tooltip_cols
            if !(col in all_tooltip_cols) && (col in df_col_names)
                push!(all_tooltip_cols, col)
            end
        end

        # Build execution names JSON
        exec_names_json = JSON.json(execution_names)

        # Build color columns JSON
        color_cols_json = JSON.json(string.(color_cols))
        default_color_json = default_color_col === nothing ? "null" : "\"$(default_color_col)\""

        # Tooltip columns (includes color_cols + additional tooltip_cols)
        tooltip_cols_json = JSON.json(string.(all_tooltip_cols))

        # Peer columns for View 3
        peer_cols_json = JSON.json(prepared[:peer_cols])

        # Metadata columns for summary table
        metadata_cols_json = JSON.json(string.(metadata_cols))

        # Feature flags
        has_counterfactual = prepared[:has_counterfactual]
        has_spread_cross = prepared[:has_spread_cross]
        has_vs_vwap = prepared[:has_vs_vwap]
        has_volume = prepared[:has_volume]

        functional_html = """
        (function() {
            // Configuration
            const EXECUTION_NAMES = $exec_names_json;
            const COLOR_COLS = $color_cols_json;
            const DEFAULT_COLOR_COL = $default_color_json;
            const TOOLTIP_COLS = $tooltip_cols_json;
            const PEER_COLS = $peer_cols_json;
            const METADATA_COLS = $metadata_cols_json;
            const HAS_COUNTERFACTUAL = $has_counterfactual;
            const HAS_SPREAD_CROSS = $has_spread_cross;
            const HAS_VS_VWAP = $has_vs_vwap;
            const HAS_VOLUME = $has_volume;

            // Data storage
            let fillsData = [];
            let tobData = [];
            let summaryDataBps = [];
            let summaryDataPct = [];
            let summaryDataUsd = [];
            let volumeData = [];

            // Current state
            let currentExecution = EXECUTION_NAMES.length > 0 ? EXECUTION_NAMES[0] : null;
            let currentColorCol = DEFAULT_COLOR_COL;
            let currentUnits = 'bps';  // Default to basis points
            let currentTopView = 1;
            let showVolume = HAS_VOLUME;  // Volume on by default if available

            // Get current summary data based on selected units
            function getSummaryData() {
                switch (currentUnits) {
                    case 'pct': return summaryDataPct;
                    case 'usd': return summaryDataUsd;
                    default: return summaryDataBps;
                }
            }

            // Get unit label for display
            function getUnitLabel() {
                switch (currentUnits) {
                    case 'pct': return '%';
                    case 'usd': return 'USD';
                    default: return 'bps';
                }
            }

            // Color palette
            const colorPalette = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
                                  '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'];

            // Initialize controls
            function initializeControls() {
                // Populate execution dropdown
                const execSelect = document.getElementById('exec_select_$chart_title_safe');
                if (execSelect) {
                    execSelect.innerHTML = '';
                    EXECUTION_NAMES.forEach(name => {
                        const option = document.createElement('option');
                        option.value = name;
                        option.textContent = name;
                        if (name === currentExecution) option.selected = true;
                        execSelect.appendChild(option);
                    });
                }

                // Populate color dropdown
                const colorSelect = document.getElementById('color_select_$chart_title_safe');
                if (colorSelect) {
                    colorSelect.innerHTML = '<option value="">No coloring</option>';
                    COLOR_COLS.forEach(col => {
                        const option = document.createElement('option');
                        option.value = col;
                        option.textContent = col;
                        if (col === currentColorCol) option.selected = true;
                        colorSelect.appendChild(option);
                    });
                }

                // Set up view toggle buttons
                updateTopViewButtons();

                // Set initial volume button state
                const volBtn = document.getElementById('volume_toggle_$chart_title_safe');
                if (volBtn) {
                    volBtn.style.backgroundColor = showVolume ? '#27ae60' : '#95a5a6';
                }
            }

            function updateTopViewButtons() {
                for (let i = 1; i <= 6; i++) {
                    const btn = document.getElementById('top_view_' + i + '_$chart_title_safe');
                    if (btn) {
                        btn.style.backgroundColor = (i === currentTopView) ? '#3498db' : '#95a5a6';
                    }
                }
                // Hide/show View 3 button if no peer data
                const view3Btn = document.getElementById('top_view_3_$chart_title_safe');
                if (view3Btn) {
                    view3Btn.style.display = (HAS_COUNTERFACTUAL && PEER_COLS.length > 0) ? 'inline-block' : 'none';
                }
                // Hide/show View 2 button if no counterfactual
                const view2Btn = document.getElementById('top_view_2_$chart_title_safe');
                if (view2Btn) {
                    view2Btn.style.display = HAS_COUNTERFACTUAL ? 'inline-block' : 'none';
                }
            }

            // Event handlers
            window.onExecChange_$chart_title_safe = function() {
                const select = document.getElementById('exec_select_$chart_title_safe');
                if (select) {
                    currentExecution = select.value;
                    updateChart_$chart_title_safe();
                }
            };

            window.onColorChange_$chart_title_safe = function() {
                const select = document.getElementById('color_select_$chart_title_safe');
                if (select) {
                    currentColorCol = select.value || null;
                    updateChart_$chart_title_safe();
                }
            };

            window.onUnitsChange_$chart_title_safe = function() {
                const select = document.getElementById('units_select_$chart_title_safe');
                if (select) {
                    currentUnits = select.value;
                    updateChart_$chart_title_safe();
                }
            };

            window.setTopView_$chart_title_safe = function(view) {
                currentTopView = view;
                updateTopViewButtons();
                updateChart_$chart_title_safe();
            };

            window.toggleVolume_$chart_title_safe = function() {
                showVolume = !showVolume;
                const btn = document.getElementById('volume_toggle_$chart_title_safe');
                if (btn) {
                    btn.style.backgroundColor = showVolume ? '#27ae60' : '#95a5a6';
                }
                updateChart_$chart_title_safe();
            };

            // Aspect ratio control for the chart panel
            function setupAspectRatioControl_$chart_title_safe() {
                const slider = document.getElementById('aspect_ratio_slider_$chart_title_safe');
                if (!slider) return;

                function applyAspectRatio() {
                    const ratio = parseFloat(slider.value);
                    const panel = document.getElementById('top_panel_$chart_title_safe');

                    if (panel) {
                        const width = panel.clientWidth;
                        const height = Math.round(width * ratio);
                        panel.style.height = height + 'px';
                        Plotly.relayout('top_panel_$chart_title_safe', { height: height });
                    }
                }

                slider.addEventListener('input', applyAspectRatio);

                // Apply initial aspect ratio after a short delay to ensure chart is rendered
                setTimeout(applyAspectRatio, 100);
            }

            // Update summary table
            function updateSummaryTable() {
                const table = document.getElementById('summary_table_$chart_title_safe');
                if (!table || !currentExecution) return;

                const summaryData = getSummaryData();
                const unitLabel = getUnitLabel();
                const summary = summaryData.find(r => r.execution_name === currentExecution);
                const fills = fillsData.filter(r => r.execution_name === currentExecution);

                if (!summary || fills.length === 0) {
                    table.innerHTML = '<tr><td colspan="8">No data for selected execution</td></tr>';
                    return;
                }

                const asset = fills[0].asset || 'N/A';
                const side = summary.side || 'N/A';
                const desiredQty = fills[0].desired_quantity || sum(fills.map(f => f.quantity));
                const executedQty = fills.reduce((s, f) => s + f.quantity, 0);

                let html = '<tr>';
                html += '<td><strong>Asset:</strong> ' + asset + '</td>';
                html += '<td><strong>Side:</strong> ' + side + '</td>';
                html += '<td><strong>Planned Qty:</strong> ' + desiredQty.toLocaleString() + '</td>';
                html += '<td><strong>Executed Qty:</strong> ' + executedQty.toLocaleString() + '</td>';
                html += '<td><strong>Classical:</strong> ' + (summary.classical_slippage || 0).toFixed(2) + ' ' + unitLabel + '</td>';

                if (HAS_VS_VWAP && summary.vs_vwap_slippage !== undefined) {
                    html += '<td><strong>vs VWAP:</strong> ' + (summary.vs_vwap_slippage || 0).toFixed(2) + ' ' + unitLabel + '</td>';
                }

                if (HAS_COUNTERFACTUAL && summary.refined_slippage !== undefined) {
                    html += '<td><strong>Refined:</strong> ' + (summary.refined_slippage || 0).toFixed(2) + ' ' + unitLabel + '</td>';
                }

                if (HAS_SPREAD_CROSS && summary.spread_cross_pct !== undefined) {
                    html += '<td><strong>Spread Cross:</strong> ' + ((summary.spread_cross_pct || 0) * 100).toFixed(1) + '%</td>';
                }

                // Add user-specified metadata columns
                METADATA_COLS.forEach(col => {
                    if (summary[col] !== undefined) {
                        let val = summary[col];
                        // Format numbers nicely
                        if (typeof val === 'number') {
                            val = Number.isInteger(val) ? val.toLocaleString() : val.toFixed(4);
                        }
                        html += '<td><strong>' + col + ':</strong> ' + val + '</td>';
                    }
                });

                html += '</tr>';
                table.innerHTML = html;
            }

            // Get filtered data for current execution
            function getExecutionData() {
                const fills = fillsData.filter(r => r.execution_name === currentExecution);
                if (fills.length === 0) return { fills: [], tob: [], volume: [] };

                const asset = fills[0].asset;
                const times = fills.map(f => f.time);
                const minTime = Math.min(...times);
                const maxTime = Math.max(...times);
                const timeRange = maxTime - minTime;

                // Get TOB data for this asset and time window (with 10% buffer)
                const tob = tobData.filter(r =>
                    r.symbol === asset &&
                    r.time >= minTime - timeRange * 0.1 &&
                    r.time <= maxTime + timeRange * 0.1
                ).sort((a, b) => a.time - b.time);

                // Get volume data if available
                const vol = volumeData.filter(r =>
                    r.symbol === asset &&
                    r.time_to >= minTime &&
                    r.time_from <= maxTime
                ).sort((a, b) => a.time_from - b.time_from);

                return { fills: fills.sort((a, b) => a.time - b.time), tob, volume: vol };
            }

            // Render top panel based on current view
            function renderTopPanel(data) {
                const { fills, tob, volume } = data;
                if (fills.length === 0) {
                    Plotly.newPlot('top_panel_$chart_title_safe', [], {
                        title: 'No data for selected execution'
                    });
                    return;
                }

                const traces = [];
                const layout = {
                    xaxis: { title: 'Time' },
                    hovermode: 'closest',
                    showlegend: true,
                    legend: { orientation: 'h', y: 1.1 }
                };

                // Get color mapping for fills
                const fillColors = getFillColors(fills);

                switch (currentTopView) {
                    case 1:
                        // Bid/Ask + Fills
                        renderBidAskView(traces, layout, fills, tob, volume, fillColors);
                        break;
                    case 2:
                        // Mid + Counterfactual
                        renderMidCounterfactualView(traces, layout, fills, tob, fillColors);
                        break;
                    case 3:
                        // With Peers
                        renderPeersView(traces, layout, fills, tob, fillColors);
                        break;
                    case 4:
                        // Execution Progress (CDF)
                        renderProgressView(traces, layout, fills, fillColors);
                        break;
                    case 5:
                        // Spread Position
                        renderSpreadPositionView(traces, layout, fills, tob, fillColors);
                        break;
                    case 6:
                        // Accrued Slippage
                        renderSlippageView(traces, layout, fills);
                        break;
                }

                // Add volume overlay for views 1-3 (price-based views)
                if (showVolume && HAS_VOLUME && volume.length > 0 && currentTopView <= 3) {
                    addVolumeTrace(traces, layout, volume);
                }

                Plotly.newPlot('top_panel_$chart_title_safe', traces, layout, {responsive: true});
            }

            // Get colors for fills based on color column
            function getFillColors(fills) {
                if (!currentColorCol) {
                    return fills.map(() => colorPalette[0]);
                }

                const categories = [...new Set(fills.map(f => f[currentColorCol]))];
                const colorMap = {};
                categories.forEach((cat, i) => {
                    colorMap[cat] = colorPalette[i % colorPalette.length];
                });

                return fills.map(f => colorMap[f[currentColorCol]]);
            }

            // Build tooltip text for a fill including all tooltip columns
            function buildFillTooltip(fill) {
                let text = 'Qty: ' + fill.quantity.toLocaleString() + '<br>Price: ' + fill.price.toFixed(4);

                // Add tooltip columns
                TOOLTIP_COLS.forEach(col => {
                    if (fill[col] !== undefined && fill[col] !== null) {
                        let val = fill[col];
                        // Format numbers nicely
                        if (typeof val === 'number') {
                            val = Number.isInteger(val) ? val.toLocaleString() : val.toFixed(4);
                        }
                        text += '<br>' + col + ': ' + val;
                    }
                });

                return text;
            }

            // View 1: Bid/Ask + Fills
            function renderBidAskView(traces, layout, fills, tob, volume, fillColors) {
                // Bid line
                traces.push({
                    x: tob.map(r => r.time),
                    y: tob.map(r => r.bid_price),
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Bid',
                    line: { color: '#006400', width: 1.5 }
                });

                // Ask line
                traces.push({
                    x: tob.map(r => r.time),
                    y: tob.map(r => r.ask_price),
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Ask',
                    line: { color: '#d62728', width: 1.5 }
                });

                // Fill points (sized by log volume)
                traces.push({
                    x: fills.map(r => r.time),
                    y: fills.map(r => r.price),
                    type: 'scatter',
                    mode: 'markers',
                    name: 'Fills',
                    marker: {
                        size: fills.map(r => Math.max(8, Math.log(r.quantity) * 3)),
                        color: fillColors,
                        line: { color: 'black', width: 1 }
                    },
                    text: fills.map(r => buildFillTooltip(r)),
                    hoverinfo: 'text'
                });

                layout.yaxis = { title: 'Price' };
            }

            // View 2: Mid + Counterfactual
            function renderMidCounterfactualView(traces, layout, fills, tob, fillColors) {
                // Mid price line
                traces.push({
                    x: tob.map(r => r.time),
                    y: tob.map(r => r.mid_price),
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Mid Price',
                    line: { color: '#1f77b4', width: 1.5 }
                });

                // Counterfactual price line (at fill times)
                if (HAS_COUNTERFACTUAL) {
                    traces.push({
                        x: fills.map(r => r.time),
                        y: fills.map(r => r.counterfactual_price),
                        type: 'scatter',
                        mode: 'lines+markers',
                        name: 'Counterfactual',
                        line: { color: '#ff7f0e', width: 2, dash: 'dash' },
                        marker: { size: 6 }
                    });
                }

                // Fill points
                traces.push({
                    x: fills.map(r => r.time),
                    y: fills.map(r => r.price),
                    type: 'scatter',
                    mode: 'markers',
                    name: 'Fills',
                    marker: {
                        size: fills.map(r => Math.max(8, Math.log(r.quantity) * 3)),
                        color: fillColors,
                        line: { color: 'black', width: 1 }
                    },
                    text: fills.map(r => buildFillTooltip(r)),
                    hoverinfo: 'text'
                });

                layout.yaxis = { title: 'Price' };
            }

            // View 3: With Peers
            function renderPeersView(traces, layout, fills, tob, fillColors) {
                // Get the initial price (arrival price of the first fill)
                const initialPrice = fills[0].arrival_price || fills[0].price;

                // First add peer lines (grey, semi-transparent)
                // Peer columns contain cumulative returns from time 1 to each fill time
                // We need returns relative to the first fill time, so we normalize:
                // peer_price = initialPrice * (peer_return_at_t / peer_return_at_first_fill)
                // This ensures the peer line starts at initialPrice at the first fill time
                PEER_COLS.forEach(peer => {
                    const firstFillPeerReturn = fills[0][peer];
                    if (firstFillPeerReturn !== undefined && firstFillPeerReturn !== 0) {
                        traces.push({
                            x: fills.map(r => r.time),
                            y: fills.map(r => initialPrice * (r[peer] / firstFillPeerReturn)),
                            type: 'scatter',
                            mode: 'lines',
                            name: peer,
                            line: { color: 'rgba(150, 150, 150, 0.5)', width: 1 },
                            hoverinfo: 'name+y'
                        });
                    }
                });

                // Then add mid and counterfactual (on top)
                renderMidCounterfactualView(traces, layout, fills, tob, fillColors);
            }

            // View 4: Execution Progress (CDF)
            function renderProgressView(traces, layout, fills, fillColors) {
                traces.push({
                    x: fills.map(r => r.time),
                    y: fills.map(r => (r.pct_complete || 0) * 100),
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: '% Completed',
                    line: { color: '#2ca02c', width: 2 },
                    marker: {
                        size: fills.map(r => Math.max(8, Math.log(r.quantity) * 3)),
                        color: fillColors,
                        line: { color: 'black', width: 1 }
                    },
                    text: fills.map(r => '% Complete: ' + ((r.pct_complete || 0) * 100).toFixed(1) + '%<br>' + buildFillTooltip(r)),
                    hoverinfo: 'text',
                    fill: 'tozeroy',
                    fillcolor: 'rgba(44, 160, 44, 0.2)'
                });

                layout.yaxis = { title: '% Executed', range: [0, 105] };
            }

            // View 5: Spread Position
            function renderSpreadPositionView(traces, layout, fills, tob, fillColors) {
                // Bid at 0
                traces.push({
                    x: tob.map(r => r.time),
                    y: tob.map(() => 0),
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Bid (0)',
                    line: { color: '#006400', width: 2 }
                });

                // Ask at 1
                traces.push({
                    x: tob.map(r => r.time),
                    y: tob.map(() => 1),
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Ask (1)',
                    line: { color: '#d62728', width: 2 }
                });

                // Mid at 0.5 (dotted)
                traces.push({
                    x: tob.map(r => r.time),
                    y: tob.map(() => 0.5),
                    type: 'scatter',
                    mode: 'lines',
                    name: 'Mid (0.5)',
                    line: { color: '#7f7f7f', width: 1, dash: 'dot' }
                });

                // Fill positions (normalized 0-1)
                traces.push({
                    x: fills.map(r => r.time),
                    y: fills.map(r => r.norm_fill_pos || 0.5),
                    type: 'scatter',
                    mode: 'markers',
                    name: 'Fills',
                    marker: {
                        size: fills.map(r => Math.max(8, Math.log(r.quantity) * 3)),
                        color: fillColors,
                        line: { color: 'black', width: 1 }
                    },
                    text: fills.map(r => 'Spread Position: ' + ((r.norm_fill_pos || 0.5) * 100).toFixed(1) + '%<br>' + buildFillTooltip(r)),
                    hoverinfo: 'text'
                });

                layout.yaxis = { title: 'Position in Spread', range: [-0.1, 1.1] };
            }

            // Add volume bars
            function addVolumeTrace(traces, layout, volume) {
                traces.push({
                    x: volume.map(r => (r.time_from + r.time_to) / 2),
                    y: volume.map(r => r.volume),
                    type: 'bar',
                    name: 'Volume',
                    yaxis: 'y2',
                    marker: { color: 'rgba(100, 100, 100, 0.3)' },
                    showlegend: false
                });

                layout.yaxis2 = {
                    title: 'Volume',
                    overlaying: 'y',
                    side: 'right',
                    showgrid: false
                };
            }

            // View 6: Accrued Slippage
            function renderSlippageView(traces, layout, fills) {
                const unitLabel = getUnitLabel();

                // Get the column suffix based on current units
                const unitSuffix = currentUnits;  // 'bps', 'pct', or 'usd'

                // Classical slippage
                const classicalCol = 'cum_classical_slippage_' + unitSuffix;
                traces.push({
                    x: fills.map(r => r.time),
                    y: fills.map(r => r[classicalCol] || 0),
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'Classical',
                    line: { color: '#8B4513', width: 2 },
                    marker: { size: 6 }
                });

                // vs VWAP slippage (if available)
                const vwapCol = 'cum_vs_vwap_slippage_' + unitSuffix;
                if (HAS_VS_VWAP && fills[0][vwapCol] !== undefined) {
                    traces.push({
                        x: fills.map(r => r.time),
                        y: fills.map(r => r[vwapCol] || 0),
                        type: 'scatter',
                        mode: 'lines+markers',
                        name: 'vs VWAP',
                        line: { color: '#4169E1', width: 2 },
                        marker: { size: 6 }
                    });
                }

                // Refined slippage (if available)
                const refinedCol = 'cum_refined_slippage_' + unitSuffix;
                if (HAS_COUNTERFACTUAL && fills[0][refinedCol] !== undefined) {
                    traces.push({
                        x: fills.map(r => r.time),
                        y: fills.map(r => r[refinedCol] || 0),
                        type: 'scatter',
                        mode: 'lines+markers',
                        name: 'Refined',
                        line: { color: '#000000', width: 2 },
                        marker: { size: 6 }
                    });
                }

                layout.yaxis = { title: 'Cumulative Slippage (' + unitLabel + ')' };
            }

            // Main update function
            window.updateChart_$chart_title_safe = function() {
                updateSummaryTable();
                const data = getExecutionData();
                renderTopPanel(data);

                // Setup aspect ratio control
                setupAspectRatioControl_$chart_title_safe();
            };

            // Check if summary_pct and summary_usd are available
            const HAS_SUMMARY_PCT = $(haskey(prepared, :summary_pct) ? "true" : "false");
            const HAS_SUMMARY_USD = $(haskey(prepared, :summary_usd) ? "true" : "false");

            // Load data and initialize
            Promise.all([
                loadDataset('$(data_label).fills'),
                loadDataset('$(data_label).tob'),
                loadDataset('$(data_label).summary_bps'),
                HAS_VOLUME ? loadDataset('$(data_label).volume') : Promise.resolve([]),
                HAS_SUMMARY_PCT ? loadDataset('$(data_label).summary_pct') : Promise.resolve([]),
                HAS_SUMMARY_USD ? loadDataset('$(data_label).summary_usd') : Promise.resolve([])
            ]).then(function([fills, tob, summaryBps, volume, summaryPct, summaryUsd]) {
                fillsData = fills;
                tobData = tob;
                summaryDataBps = summaryBps;
                summaryDataPct = HAS_SUMMARY_PCT ? summaryPct : summaryBps;  // Fallback to bps if not available
                summaryDataUsd = HAS_SUMMARY_USD ? summaryUsd : summaryBps;  // Fallback to bps if not available
                volumeData = volume;

                initializeControls();
                updateChart_$chart_title_safe();
            }).catch(function(error) {
                console.error('Error loading execution data:', error);
            });
        })();
        """

        # Build appearance HTML - all controls at top, charts below
        appearance_html = """
        <div class="chart-wrapper" style="margin: 20px 0;">
            <div class="chart-header" style="margin-bottom: 15px;">
                <h3 style="margin: 0;">$title</h3>
            </div>

            <!-- Controls Row 1: Execution, Color, and Units dropdowns -->
            <div style="display: flex; gap: 20px; align-items: center; margin-bottom: 10px; flex-wrap: wrap;">
                <div>
                    <label><strong>Execution:</strong></label>
                    <select id="exec_select_$chart_title_safe" onchange="onExecChange_$chart_title_safe()"
                            style="margin-left: 5px; padding: 4px 8px; min-width: 200px;">
                    </select>
                </div>
                <div>
                    <label><strong>Color by:</strong></label>
                    <select id="color_select_$chart_title_safe" onchange="onColorChange_$chart_title_safe()"
                            style="margin-left: 5px; padding: 4px 8px; min-width: 150px;">
                    </select>
                </div>
                <div>
                    <label><strong>Units:</strong></label>
                    <select id="units_select_$chart_title_safe" onchange="onUnitsChange_$chart_title_safe()"
                            style="margin-left: 5px; padding: 4px 8px; min-width: 80px;">
                        <option value="bps" selected>bps</option>
                        <option value="pct">%</option>
                        <option value="usd">USD</option>
                    </select>
                </div>
            </div>

            <!-- Summary Table -->
            <div style="margin-bottom: 15px; overflow-x: auto;">
                <table id="summary_table_$chart_title_safe" style="width: 100%; border-collapse: collapse; font-size: 13px;">
                    <tr><td colspan="8" style="padding: 8px; background: #f5f5f5;">Loading...</td></tr>
                </table>
            </div>

            <!-- Controls Row 2: View buttons - Top and Bottom on same row -->
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; flex-wrap: wrap; gap: 10px;">
                <!-- Top Panel View Buttons -->
                <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
                    <span><strong>Top:</strong></span>
                    <button id="top_view_1_$chart_title_safe" onclick="setTopView_$chart_title_safe(1)"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #3498db; font-size: 12px;">
                        Bid/Ask
                    </button>
                    <button id="top_view_2_$chart_title_safe" onclick="setTopView_$chart_title_safe(2)"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #95a5a6; font-size: 12px;">
                        Mid+CF
                    </button>
                    <button id="top_view_3_$chart_title_safe" onclick="setTopView_$chart_title_safe(3)"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #95a5a6; font-size: 12px;">
                        +Peers
                    </button>
                    <button id="top_view_4_$chart_title_safe" onclick="setTopView_$chart_title_safe(4)"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #95a5a6; font-size: 12px;">
                        Progress
                    </button>
                    <button id="top_view_5_$chart_title_safe" onclick="setTopView_$chart_title_safe(5)"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #95a5a6; font-size: 12px;">
                        Spread Pos
                    </button>
                    <button id="top_view_6_$chart_title_safe" onclick="setTopView_$chart_title_safe(6)"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #95a5a6; font-size: 12px;">
                        Slippage
                    </button>
                    <button id="volume_toggle_$chart_title_safe" onclick="toggleVolume_$chart_title_safe()"
                            style="padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer; color: white; background: #95a5a6; font-size: 12px;">
                        Volume
                    </button>
                </div>
            </div>

            <!-- Aspect Ratio Slider -->
            <div style="margin-bottom: 15px;">
                <label for="aspect_ratio_slider_$chart_title_safe"><strong>Aspect Ratio:</strong></label>
                <input type="range" id="aspect_ratio_slider_$chart_title_safe" min="0.3" max="0.8" step="0.02" value="0.5"
                       style="width: 70%; vertical-align: middle; margin-left: 10px;">
            </div>

            <!-- Chart Panel -->
            <div id="top_panel_$chart_title_safe" style="width: 100%; height: 400px;"></div>

            $(notes != "" ? "<div style=\"margin-top: 10px; font-size: 12px; color: #666;\">$notes</div>" : "")

            <!-- Data Sources -->
            <div style="margin-top: 15px; padding: 10px; background: #f8f9fa; border-radius: 4px; font-size: 11px; color: #666;">
                <strong>Data Sources:</strong> This visualization uses data from <code>RefinedSlippage.ExecutionData</code>.
                <ul style="margin: 5px 0 0 15px; padding: 0;">
                    <li><strong>Fills:</strong> Trade executions from <code>exec_data.fills</code> (time, price, quantity, execution_name, asset)</li>
                    <li><strong>Bid/Ask:</strong> Top-of-book quotes from <code>exec_data.tob</code> (time, symbol, bid_price, ask_price)</li>
                    <li><strong>Volume:</strong> Market volume from <code>exec_data.volume</code> (time_from, time_to, symbol, volume) - optional</li>
                    <li><strong>Peer Returns:</strong> Correlated asset returns from <code>exec_data.fill_returns</code> columns (computed via covariance matrix)</li>
                    <li><strong>Slippage Metrics:</strong> Summary statistics from <code>exec_data.summary_bps</code> (classical, refined, vs_vwap slippage)</li>
                </ul>
                To regenerate: <code>exec_data = ExecutionData(fills, metadata, tob, covar_matrix; volume=volume)</code> then <code>calculate_slippage!(exec_data)</code>
            </div>
        </div>
        """

        new(chart_title, data_label, functional_html, appearance_html, prepared)
    end
end

# Custom dependencies - returns multiple data labels for the different data tables
# Uses dot notation for subfolder organization: exec_data.fills -> data/exec_data/fills.csv
function dependencies(a::ExecutionPlot)
    base = a.data_label
    deps = [
        Symbol("$(base).fills"),
        Symbol("$(base).tob"),
        Symbol("$(base).fill_returns"),
        Symbol("$(base).summary_bps")
    ]
    if a.prepared_data[:has_volume]
        push!(deps, Symbol("$(base).volume"))
    end
    if haskey(a.prepared_data, :summary_pct)
        push!(deps, Symbol("$(base).summary_pct"))
    end
    if haskey(a.prepared_data, :summary_usd)
        push!(deps, Symbol("$(base).summary_usd"))
    end
    return deps
end

# ExecutionPlot uses Plotly for visualization
js_dependencies(::ExecutionPlot) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)

# Custom function to get all data for serialization
# Uses dot notation for subfolder organization: exec_data.fills -> data/exec_data/fills.csv
# exec_data is the original ExecutionData object (stored in prepared_data[:exec_data])
function get_execution_data_dict(exec_plot::ExecutionPlot)
    base = exec_plot.data_label
    result = Dict{Symbol, Any}()

    # The enriched fills used for visualization (has cumulative columns)
    result[Symbol("$(base).fills")] = exec_plot.prepared_data[:fills]
    result[Symbol("$(base).tob")] = exec_plot.prepared_data[:tob]

    if exec_plot.prepared_data[:has_volume]
        result[Symbol("$(base).volume")] = exec_plot.prepared_data[:volume]
    end

    # DataFrames from ExecutionData
    if haskey(exec_plot.prepared_data, :fill_returns)
        result[Symbol("$(base).fill_returns")] = exec_plot.prepared_data[:fill_returns]
    end
    if haskey(exec_plot.prepared_data, :summary_bps)
        result[Symbol("$(base).summary_bps")] = exec_plot.prepared_data[:summary_bps]
    end
    if haskey(exec_plot.prepared_data, :summary_pct)
        result[Symbol("$(base).summary_pct")] = exec_plot.prepared_data[:summary_pct]
    end
    if haskey(exec_plot.prepared_data, :summary_usd)
        result[Symbol("$(base).summary_usd")] = exec_plot.prepared_data[:summary_usd]
    end

    return result
end
