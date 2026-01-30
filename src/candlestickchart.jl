"""
    CandlestickChart(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Candlestick (Open-High-Low-Close) candlestick chart with volume bars for financial time series visualization.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `time_from_col::Symbol`: Column for bar start time/period (default: `:time_from`)
- `time_to_col::Symbol`: Column for bar end time/period (default: `:time_to`)
- `symbol_col::Symbol`: Column for symbol/ticker name (default: `:symbol`)
- `open_col::Symbol`: Column for opening price (default: `:open`)
- `high_col::Symbol`: Column for high price (default: `:high`)
- `low_col::Symbol`: Column for low price (default: `:low`)
- `close_col::Symbol`: Column for closing price (default: `:close`)
- `volume_col::Union{Symbol, Nothing}`: Column for volume (default: `:volume`, use `nothing` to disable)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict{Symbol, Any}`: Column => default values. Values can be a single value, vector, or nothing for all values
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
- `display_mode::String`: Display mode - "Overlay" or "Faceted" (default: `"Overlay"`)
- `show_volume::Bool`: Show volume subplot (default: `true`)
- `chart_type::String`: Chart type - "candlestick" or "ohlc" (default: `"candlestick"`)
- `title::String`: Chart title (default: `"Candlestick Chart"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
candlestick = CandlestickChart(:stock_chart, df, :stock_data,
    time_from_col=:date,
    time_to_col=:date,
    symbol_col=:ticker,
    open_col=:open,
    high_col=:high,
    low_col=:low,
    close_col=:close,
    volume_col=:volume,
    title="Stock Prices"
)
```
"""
struct CandlestickChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function CandlestickChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            time_from_col::Symbol=:time_from,
                            time_to_col::Symbol=:time_to,
                            symbol_col::Symbol=:symbol,
                            open_col::Symbol=:open,
                            high_col::Symbol=:high,
                            low_col::Symbol=:low,
                            close_col::Symbol=:close,
                            volume_col::Union{Symbol, Nothing}=:volume,
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            display_mode::String="Overlay",
                            show_volume::Bool=true,
                            chart_type::String="candlestick",
                            title::String="Candlestick Chart",
                            notes::String="")

        # Normalize filters and choices to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Sanitize chart title for use in JavaScript/HTML IDs
        chart_title_safe = string(sanitize_chart_title(chart_title))

        # Validate required columns exist
        validate_column(df, time_from_col, "time_from_col")
        validate_column(df, time_to_col, "time_to_col")
        validate_column(df, symbol_col, "symbol_col")
        validate_column(df, open_col, "open_col")
        validate_column(df, high_col, "high_col")
        validate_column(df, low_col, "low_col")
        validate_column(df, close_col, "close_col")

        # Validate volume column if provided
        has_volume = volume_col !== nothing
        if has_volume
            validate_column(df, volume_col, "volume_col")
        end

        # Validate Candlestick columns are numeric
        for col in [open_col, high_col, low_col, close_col]
            if !isa(df[!, col], AbstractVector{<:Union{Missing, Number}})
                error("Column $col must be numeric")
            end
        end

        # Validate volume column is numeric if provided
        if has_volume && !isa(df[!, volume_col], AbstractVector{<:Union{Missing, Number}})
            error("Column $volume_col must be numeric")
        end

        # Validate display_mode
        valid_display_modes = ["Overlay", "Faceted"]
        if !(display_mode in valid_display_modes)
            error("display_mode must be one of: $(join(valid_display_modes, ", "))")
        end

        # Validate chart_type
        valid_chart_types = ["candlestick", "ohlc"]
        if !(chart_type in valid_chart_types)
            error("chart_type must be one of: $(join(valid_chart_types, ", "))")
        end

        # Build HTML controls using abstraction
        update_function = "updateChart_$chart_title_safe()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_safe, normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(chart_title_safe, normalized_choices, df, update_function)

        # Separate categorical, continuous, and choice filters
        categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
        continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]
        choice_cols = collect(keys(normalized_choices))

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)

        # Create JavaScript constants
        time_from_col_js = string(time_from_col)
        time_to_col_js = string(time_to_col)
        symbol_col_js = string(symbol_col)
        open_col_js = string(open_col)
        high_col_js = string(high_col)
        low_col_js = string(low_col)
        close_col_js = string(close_col)
        volume_col_js = has_volume ? string(volume_col) : ""

        functional_html = """
        (function() {
            // Configuration
            const TIME_FROM_COL = '$time_from_col_js';
            const TIME_TO_COL = '$time_to_col_js';
            const SYMBOL_COL = '$symbol_col_js';
            const OPEN_COL = '$open_col_js';
            const HIGH_COL = '$high_col_js';
            const LOW_COL = '$low_col_js';
            const CLOSE_COL = '$close_col_js';
            const VOLUME_COL = '$volume_col_js';
            const HAS_VOLUME = $has_volume;
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;

            let allData = [];
            let firstBarOpenPrices = {};  // Store first bar open prices for renormalization

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title_safe = function() {
                // Get current control values
                const renormalizeCheckbox = document.getElementById('renormalize_checkbox_$chart_title_safe');
                const RENORMALIZE = renormalizeCheckbox ? renormalizeCheckbox.checked : false;

                const showVolumeCheckbox = document.getElementById('show_volume_checkbox_$chart_title_safe');
                const SHOW_VOLUME = HAS_VOLUME && showVolumeCheckbox ? showVolumeCheckbox.checked : false;

                const logVolumeCheckbox = document.getElementById('log_volume_checkbox_$chart_title_safe');
                const LOG_VOLUME = SHOW_VOLUME && logVolumeCheckbox ? logVolumeCheckbox.checked : false;

                const chartTypeSelect = document.getElementById('chart_type_select_$chart_title_safe');
                const CHART_TYPE = chartTypeSelect ? chartTypeSelect.value : '$chart_type';

                const displayModeSelect = document.getElementById('display_mode_select_$chart_title_safe');
                const DISPLAY_MODE = displayModeSelect ? displayModeSelect.value : '$display_mode';

                // Get current filter values
                const filters = {};
                const rangeFilters = {};

                // Read categorical filters (dropdowns)
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title_safe');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Read continuous filters (range sliders)
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title_safe' + '_slider');
                    if (slider.length > 0) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                // Get choice filter values (single-select)
                const choices = {};
                CHOICE_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_choice_$chart_title_safe');
                    if (select) {
                        choices[col] = select.value;
                    }
                });

                // Apply filters with observation counting
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title_safe',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters,
                    CHOICE_FILTERS,
                    choices
                );

                // Group data by symbol
                const symbolData = {};
                filteredData.forEach(row => {
                    const symbol = String(row[SYMBOL_COL]);
                    if (!symbolData[symbol]) {
                        symbolData[symbol] = [];
                    }
                    symbolData[symbol].push(row);
                });

                // Sort each symbol's data by time
                for (let symbol in symbolData) {
                    symbolData[symbol].sort((a, b) => {
                        const aTime = a[TIME_FROM_COL];
                        const bTime = b[TIME_FROM_COL];
                        if (aTime instanceof Date && bTime instanceof Date) {
                            return aTime - bTime;
                        }
                        return aTime < bTime ? -1 : (aTime > bTime ? 1 : 0);
                    });
                }

                // Calculate first bar open prices for renormalization (only once)
                if (Object.keys(firstBarOpenPrices).length === 0 || !RENORMALIZE) {
                    firstBarOpenPrices = {};
                    for (let symbol in symbolData) {
                        if (symbolData[symbol].length > 0) {
                            firstBarOpenPrices[symbol] = symbolData[symbol][0][OPEN_COL];
                        }
                    }
                }

                // Route to appropriate rendering function
                if (DISPLAY_MODE === 'Overlay') {
                    renderOverlay(symbolData, RENORMALIZE, SHOW_VOLUME, LOG_VOLUME, CHART_TYPE);
                } else {
                    renderFaceted(symbolData, RENORMALIZE, SHOW_VOLUME, LOG_VOLUME, CHART_TYPE);
                }
            };

            // Render overlay mode (all symbols on same chart)
            function renderOverlay(symbolData, renormalize, showVolume, logVolume, chartType) {
                const traces = [];
                const symbols = Object.keys(symbolData).sort();
                const colorPalette = ['#636efa', '#EF553B', '#00cc96', '#ab63fa', '#FFA15A',
                                     '#19d3f3', '#FF6692', '#B6E880', '#FF97FF', '#FECB52'];

                symbols.forEach((symbol, idx) => {
                    const data = symbolData[symbol];
                    const color = colorPalette[idx % colorPalette.length];

                    // Prepare Candlestick data
                    const x = data.map(row => row[TIME_FROM_COL]);
                    let open = data.map(row => row[OPEN_COL]);
                    let high = data.map(row => row[HIGH_COL]);
                    let low = data.map(row => row[LOW_COL]);
                    let close = data.map(row => row[CLOSE_COL]);

                    // Apply renormalization if enabled
                    if (renormalize && firstBarOpenPrices[symbol] && firstBarOpenPrices[symbol] !== 0) {
                        const base = firstBarOpenPrices[symbol];
                        open = open.map(v => v / base);
                        high = high.map(v => v / base);
                        low = low.map(v => v / base);
                        close = close.map(v => v / base);
                    }

                    // Candlestick trace
                    const candlestickTrace = {
                        x: x,
                        open: open,
                        high: high,
                        low: low,
                        close: close,
                        type: chartType,
                        name: symbol,
                        xaxis: 'x',
                        yaxis: 'y',
                        increasing: {line: {color: color}},
                        decreasing: {line: {color: color}}
                    };
                    traces.push(candlestickTrace);

                    // Volume trace if enabled
                    if (showVolume && HAS_VOLUME) {
                        let volumes = data.map(row => row[VOLUME_COL]);
                        if (logVolume) {
                            volumes = volumes.map(v => Math.log(v + 1));
                        }

                        const volumeTrace = {
                            x: x,
                            y: volumes,
                            type: 'bar',
                            name: symbol + ' Volume',
                            xaxis: 'x',
                            yaxis: 'y2',
                            marker: {color: color},
                            showlegend: false
                        };
                        traces.push(volumeTrace);
                    }
                });

                // Layout configuration
                const layout = {
                    xaxis: {
                        title: TIME_FROM_COL,
                        anchor: 'y'
                    },
                    hovermode: 'closest',
                    showlegend: true
                };

                if (showVolume && HAS_VOLUME) {
                    // Two subplots: Candlestick on top, volume on bottom
                    layout.yaxis = {
                        title: renormalize ? 'Normalized Price' : 'Price',
                        domain: [0.3, 1]
                    };
                    layout.yaxis2 = {
                        title: logVolume ? 'log(Volume)' : 'Volume',
                        domain: [0, 0.25],
                        anchor: 'x'
                    };
                    layout.barmode = 'group';  // Dodge volume bars
                } else {
                    // Single plot: Candlestick only
                    layout.yaxis = {
                        title: renormalize ? 'Normalized Price' : 'Price'
                    };
                }

                Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true});
            }

            // Render faceted mode (one subplot per symbol)
            function renderFaceted(symbolData, renormalize, showVolume, logVolume, chartType) {
                const symbols = Object.keys(symbolData).sort();
                const nSymbols = symbols.length;

                // Calculate grid dimensions (prefer wider grids)
                const nCols = Math.ceil(Math.sqrt(nSymbols * 1.5));
                const nRows = Math.ceil(nSymbols / nCols);

                const traces = [];
                const layout = {
                    hovermode: 'closest',
                    showlegend: false,
                    grid: {rows: nRows, columns: nCols, pattern: 'independent'}
                };

                if (showVolume && HAS_VOLUME) {
                    layout.barmode = 'group';
                }

                symbols.forEach((symbol, idx) => {
                    const data = symbolData[symbol];

                    // Prepare Candlestick data
                    const x = data.map(row => row[TIME_FROM_COL]);
                    let open = data.map(row => row[OPEN_COL]);
                    let high = data.map(row => row[HIGH_COL]);
                    let low = data.map(row => row[LOW_COL]);
                    let close = data.map(row => row[CLOSE_COL]);

                    // Apply renormalization if enabled
                    if (renormalize && firstBarOpenPrices[symbol] && firstBarOpenPrices[symbol] !== 0) {
                        const base = firstBarOpenPrices[symbol];
                        open = open.map(v => v / base);
                        high = high.map(v => v / base);
                        low = low.map(v => v / base);
                        close = close.map(v => v / base);
                    }

                    const row = Math.floor(idx / nCols) + 1;
                    const col = (idx % nCols) + 1;
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                    // Candlestick trace
                    const candlestickTrace = {
                        x: x,
                        open: open,
                        high: high,
                        low: low,
                        close: close,
                        type: chartType,
                        name: symbol,
                        xaxis: xaxis,
                        yaxis: yaxis
                    };
                    traces.push(candlestickTrace);

                    // Volume trace if enabled
                    if (showVolume && HAS_VOLUME) {
                        let volumes = data.map(row => row[VOLUME_COL]);
                        if (logVolume) {
                            volumes = volumes.map(v => Math.log(v + 1));
                        }

                        const yaxis_vol = idx === 0 ? 'y' + (nSymbols + 1) : 'y' + (nSymbols + idx + 1);

                        const volumeTrace = {
                            x: x,
                            y: volumes,
                            type: 'bar',
                            name: symbol + ' Volume',
                            xaxis: xaxis,
                            yaxis: yaxis_vol,
                            showlegend: false
                        };
                        traces.push(volumeTrace);

                        // Configure volume yaxis
                        layout[yaxis_vol] = {
                            title: row === nRows ? (logVolume ? 'log(Vol)' : 'Vol') : '',
                            anchor: xaxis
                        };
                    }

                    // Add axis configuration
                    layout[xaxis] = {
                        title: row === nRows ? TIME_FROM_COL : '',
                        anchor: yaxis
                    };
                    layout[yaxis] = {
                        title: col === 1 ? (renormalize ? 'Norm Price' : 'Price') : '',
                        anchor: xaxis
                    };

                    // Add annotation for symbol label
                    if (!layout.annotations) layout.annotations = [];
                    layout.annotations.push({
                        text: symbol,
                        showarrow: false,
                        xref: xaxis === 'x' ? 'x domain' : xaxis + ' domain',
                        yref: yaxis === 'y' ? 'y domain' : yaxis + ' domain',
                        x: 0.5,
                        y: 1.05,
                        xanchor: 'center',
                        yanchor: 'bottom',
                        font: {size: 10}
                    });
                });

                Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true});
            }

            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title_safe();

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title_safe');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title_safe:', error);
            });
        })();
        """

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # Chart type dropdown
        push!(attribute_dropdowns, DropdownControl(
            "chart_type_select_$chart_title_safe",
            "Chart Type",
            valid_chart_types,
            chart_type,
            update_function
        ))

        # Display mode dropdown
        push!(attribute_dropdowns, DropdownControl(
            "display_mode_select_$chart_title_safe",
            "Display Mode",
            ["Overlay", "Faceted"],
            display_mode,
            update_function
        ))

        # Build custom HTML for checkboxes
        checkbox_html = """
            <div style="margin: 10px; display: flex; flex-direction: column;">
                <div style="margin: 5px 0;">
                    <input type="checkbox" id="renormalize_checkbox_$chart_title_safe" onchange="$update_function">
                    <label for="renormalize_checkbox_$chart_title_safe">Renormalize (first bar open = 1)</label>
                </div>
        """

        if has_volume
            checkbox_html *= """
                <div style="margin: 5px 0;">
                    <input type="checkbox" id="show_volume_checkbox_$chart_title_safe" checked onchange="$update_function">
                    <label for="show_volume_checkbox_$chart_title_safe">Show Volume</label>
                </div>
                <div style="margin: 5px 0;">
                    <input type="checkbox" id="log_volume_checkbox_$chart_title_safe" onchange="$update_function">
                    <label for="log_volume_checkbox_$chart_title_safe">Log Volume</label>
                </div>
            """
        end

        checkbox_html *= """
            </div>
        """

        # Build axes HTML (empty for Candlestick chart - we don't have axis selectors)
        axes_html = checkbox_html

        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_safe,
            chart_title_safe,
            update_function,
            choice_dropdowns,
            filter_dropdowns,
            filter_sliders,
            attribute_dropdowns,
            axes_html,
            DropdownControl[],  # No faceting for Candlestick
            title,
            notes
        )
        appearance_html = generate_appearance_html(controls; aspect_ratio_default=0.6)

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::CandlestickChart) = [a.data_label]
js_dependencies(::CandlestickChart) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
