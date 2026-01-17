"""
    BumpChart(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Bump chart visualization showing entity rankings over time with interactive controls and faceting.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `x_col::Symbol`: Column for x-axis (time/period) (default: `:x`)
- `performance_cols::Vector{Symbol}`: Columns available for performance metrics (default: `[:performance]`)
- `entity_col::Symbol`: Column identifying entities being ranked (default: `:entity`)
- `filters::Union{Vector{Symbol}, Dict}`: Filter specification (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - creates filters with all unique values selected by default
  - `Dict{Symbol, Any}`: Column => default values. Values can be a single value, vector, or nothing for all values
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `y_mode::String`: Y-axis mode - "Ranking" or "Absolute" (default: `"Ranking"`)
- `default_performance_col::Union{Symbol, Nothing}`: Default performance column (default: first in performance_cols)
- `title::String`: Chart title (default: `"Bump Chart"`)
- `line_width::Int`: Width of lines (default: `2`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
bc = BumpChart(:rankings, df, :rankings_data,
    x_col=:period,
    performance_cols=[:score, :revenue],
    entity_col=:competitor,
    y_mode="Ranking",
    title="Market Rankings Over Time"
)
```
"""
struct BumpChart <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function BumpChart(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                            x_col::Symbol=:x,
                            performance_cols::Vector{Symbol}=[:performance],
                            entity_col::Symbol=:entity,
                            filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                            facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}}=nothing,
                            y_mode::String="Ranking",
                            default_performance_col::Union{Symbol, Nothing}=nothing,
                            title::String="Bump Chart",
                            line_width::Int=2,
                            notes::String="")

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)

        # Sanitize chart title for use in JavaScript/HTML IDs
        chart_title_safe = string(sanitize_chart_title(chart_title))

        # Validate columns exist in dataframe
        validate_column(df, x_col, "x_col")
        valid_performance_cols = validate_and_filter_columns(performance_cols, df, "performance_cols")

        # Validate entity column
        validate_column(df, entity_col, "entity_col")

        # Ensure at least one performance_col
        if length(valid_performance_cols) == 0
            error("At least one performance_col must be provided and exist in the dataframe")
        end

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Validate y_mode
        valid_y_modes = ["Ranking", "Absolute"]
        if !(y_mode in valid_y_modes)
            error("y_mode must be one of: $(join(valid_y_modes, ", "))")
        end

        # Build color maps for entities
        color_maps, _ = build_color_maps([entity_col], df)

        # Build HTML controls using abstraction
        update_function = "updateChart_$chart_title_safe()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_safe, normalized_filters, df, update_function)

        # Separate categorical and continuous filters
        categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
        continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        x_col_js = string(x_col)
        performance_cols_js = build_js_array(valid_performance_cols)
        entity_col_js = string(entity_col)

        # Create color map as JavaScript object
        color_map_js = if haskey(color_maps, string(entity_col))
            entity_map = color_maps[string(entity_col)]
            "{" * join(["'$k': '$v'" for (k, v) in entity_map], ", ") * "}"
        else
            "{}"
        end

        # Default performance column
        default_perf = default_performance_col !== nothing ? string(default_performance_col) : string(valid_performance_cols[1])

        functional_html = """
        (function() {
            // Configuration
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const X_COL = '$x_col_js';
            const PERFORMANCE_COLS = $performance_cols_js;
            const ENTITY_COL = '$entity_col_js';
            const COLOR_MAP = $color_map_js;
            const COLOR_PALETTE = ['#636efa', '#EF553B', '#00cc96', '#ab63fa', '#FFA15A',
                                   '#19d3f3', '#FF6692', '#B6E880', '#FF97FF', '#FECB52'];
            const DEFAULT_PERF_COL = '$default_perf';

            let allData = [];
            let entityColors = {};  // Store entity color assignments

            // Calculate dense ranks for data
            function calculateDenseRanks(data, xCol, perfCol) {
                const xGroups = {};
                data.forEach(row => {
                    const xVal = row[xCol];
                    const xKey = String(xVal);
                    if (!xGroups[xKey]) {
                        xGroups[xKey] = [];
                    }
                    xGroups[xKey].push(row);
                });

                const rankedData = [];
                for (let xKey in xGroups) {
                    const group = xGroups[xKey];

                    // Sort by performance descending (best first)
                    const sorted = group.sort((a, b) => b[perfCol] - a[perfCol]);

                    // Get unique performance values
                    const uniqueValues = [...new Set(sorted.map(r => r[perfCol]))].sort((a, b) => b - a);

                    // Assign dense ranks (ties get same rank, next rank = current + 1)
                    const valueToRank = {};
                    uniqueValues.forEach((val, idx) => {
                        valueToRank[val] = idx + 1;  // Dense rank: 1, 2, 3, ... (no gaps)
                    });

                    sorted.forEach(row => {
                        rankedData.push({
                            ...row,
                            y_value: valueToRank[row[perfCol]],
                            original_value: row[perfCol]
                        });
                    });
                }

                return rankedData;
            }

            // Assign colors to entities from filtered data
            function assignEntityColors(data) {
                const entities = [...new Set(data.map(row => String(row[ENTITY_COL])))].sort();
                entityColors = {};
                entities.forEach((entity, idx) => {
                    entityColors[entity] = COLOR_MAP[entity] || COLOR_PALETTE[idx % COLOR_PALETTE.length];
                });
            }

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title_safe = function() {
                // Get current performance column
                const perfColSelect = document.getElementById('perf_col_select_$chart_title_safe');
                const PERF_COL = perfColSelect ? perfColSelect.value : DEFAULT_PERF_COL;

                // Get Y-axis mode
                const yModeSelect = document.getElementById('y_mode_select_$chart_title_safe');
                const Y_MODE = yModeSelect ? yModeSelect.value : '$y_mode';

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

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title_safe');
                const facet2Select = document.getElementById('facet2_select_$chart_title_safe');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                // Build FACET_COLS array based on selections
                const FACET_COLS = [];
                if (facet1) FACET_COLS.push(facet1);
                if (facet2) FACET_COLS.push(facet2);

                // Apply filters with observation counting
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title_safe',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters
                );

                // Assign colors to entities in filtered data
                assignEntityColors(filteredData);

                // Route to appropriate rendering function
                // For facets, rankings will be calculated within each facet
                if (FACET_COLS.length === 0) {
                    // No facets: calculate rankings globally
                    let processedData;
                    if (Y_MODE === 'Ranking') {
                        processedData = calculateDenseRanks(filteredData, X_COL, PERF_COL);
                    } else {
                        processedData = filteredData.map(row => ({
                            ...row,
                            y_value: row[PERF_COL],
                            original_value: row[PERF_COL]
                        }));
                    }
                    renderNoFacets(processedData, X_COL, Y_MODE);
                } else if (FACET_COLS.length === 1) {
                    // One facet: pass raw data and PERF_COL, rankings calculated per facet
                    renderOneFacet(filteredData, X_COL, Y_MODE, FACET_COLS[0], PERF_COL);
                } else {
                    // Two facets: pass raw data and PERF_COL, rankings calculated per facet
                    renderTwoFacets(filteredData, X_COL, Y_MODE, FACET_COLS[0], FACET_COLS[1], PERF_COL);
                }
            };

            // Render without facets
            function renderNoFacets(data, xCol, yMode) {
                const entities = [...new Set(data.map(row => String(row[ENTITY_COL])))].sort();
                const traces = [];

                entities.forEach(entity => {
                    const entityData = data.filter(row => String(row[ENTITY_COL]) === entity);
                    entityData.sort((a, b) => {
                        const aVal = a[xCol];
                        const bVal = b[xCol];
                        if (aVal instanceof Date && bVal instanceof Date) {
                            return aVal - bVal;
                        }
                        return aVal < bVal ? -1 : (aVal > bVal ? 1 : 0);
                    });

                    const xValues = entityData.map(row => row[xCol]);
                    const yValues = entityData.map(row => row.y_value);
                    const origValues = entityData.map(row => row.original_value);

                    traces.push({
                        x: xValues,
                        y: yValues,
                        type: 'scatter',
                        mode: 'lines+markers',
                        name: entity,
                        line: {
                            color: entityColors[entity],
                            width: $line_width
                        },
                        marker: {size: 6},
                        customdata: origValues,
                        hovertemplate: entity + '<br>' + xCol + ': %{x}<br>' +
                                      (yMode === 'Ranking' ? 'Rank: %{y}<br>Value: %{customdata}' : 'Value: %{y}') +
                                      '<extra></extra>'
                    });
                });

                const layout = {
                    xaxis: {title: xCol},
                    yaxis: {
                        title: yMode === 'Ranking' ? 'Rank' : 'Performance',
                        autorange: yMode === 'Ranking' ? 'reversed' : true  // Rank 1 at top
                    },
                    hovermode: 'closest',
                    showlegend: true
                };

                Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true}).then(() => {
                    setupCrossFacetHighlighting('$chart_title_safe', traces);
                });
            }

            // Render with one facet
            function renderOneFacet(data, xCol, yMode, facetCol, perfCol) {
                const facetValues = [...new Set(data.map(row => row[facetCol]))].sort();
                const nFacets = facetValues.length;

                // Calculate grid dimensions (prefer wider grids)
                const nCols = Math.ceil(Math.sqrt(nFacets * 1.5));
                const nRows = Math.ceil(nFacets / nCols);

                const traces = [];
                const layout = {
                    hovermode: 'closest',
                    showlegend: true,
                    grid: {rows: nRows, columns: nCols, pattern: 'independent'}
                };

                facetValues.forEach((facetVal, idx) => {
                    const rawFacetData = data.filter(row => row[facetCol] === facetVal);

                    // Calculate rankings within this facet
                    let facetData;
                    if (yMode === 'Ranking') {
                        facetData = calculateDenseRanks(rawFacetData, xCol, perfCol);
                    } else {
                        facetData = rawFacetData.map(row => ({
                            ...row,
                            y_value: row[perfCol],
                            original_value: row[perfCol]
                        }));
                    }

                    const entities = [...new Set(facetData.map(row => String(row[ENTITY_COL])))].sort();

                    const row = Math.floor(idx / nCols) + 1;
                    const col = (idx % nCols) + 1;
                    const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                    const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                    entities.forEach(entity => {
                        const entityData = facetData.filter(row => String(row[ENTITY_COL]) === entity);
                        entityData.sort((a, b) => {
                            const aVal = a[xCol];
                            const bVal = b[xCol];
                            if (aVal instanceof Date && bVal instanceof Date) {
                                return aVal - bVal;
                            }
                            return aVal < bVal ? -1 : (aVal > bVal ? 1 : 0);
                        });

                        const xValues = entityData.map(row => row[xCol]);
                        const yValues = entityData.map(row => row.y_value);
                        const origValues = entityData.map(row => row.original_value);

                        traces.push({
                            x: xValues,
                            y: yValues,
                            type: 'scatter',
                            mode: 'lines+markers',
                            name: entity,
                            legendgroup: entity,
                            showlegend: idx === 0,
                            xaxis: xaxis,
                            yaxis: yaxis,
                            line: {
                                color: entityColors[entity],
                                width: $line_width
                            },
                            marker: {size: 6},
                            customdata: origValues,
                            hovertemplate: entity + '<br>' + xCol + ': %{x}<br>' +
                                          (yMode === 'Ranking' ? 'Rank: %{y}<br>Value: %{customdata}' : 'Value: %{y}') +
                                          '<extra></extra>'
                        });
                    });

                    // Add axis configuration
                    layout[xaxis] = {
                        title: row === nRows ? xCol : '',
                        anchor: yaxis
                    };

                    if (yMode === 'Ranking') {
                        layout[yaxis] = {
                            title: col === 1 ? 'Rank' : '',
                            anchor: xaxis,
                            autorange: 'reversed'
                        };
                    } else {
                        layout[yaxis] = {
                            title: col === 1 ? 'Performance' : '',
                            anchor: xaxis,
                            autorange: true
                        };
                    }

                    // Add annotation for facet label
                    if (!layout.annotations) layout.annotations = [];
                    layout.annotations.push({
                        text: facetCol + ': ' + facetVal,
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

                Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true}).then(() => {
                    setupCrossFacetHighlighting('$chart_title_safe', traces);
                });
            }

            // Render with two facets
            function renderTwoFacets(data, xCol, yMode, facetRow, facetCol, perfCol) {
                const rowValues = [...new Set(data.map(row => row[facetRow]))].sort();
                const colValues = [...new Set(data.map(row => row[facetCol]))].sort();
                const nRows = rowValues.length;
                const nCols = colValues.length;

                const traces = [];
                const layout = {
                    hovermode: 'closest',
                    showlegend: true,
                    grid: {rows: nRows, columns: nCols, pattern: 'independent'}
                };

                rowValues.forEach((rowVal, rowIdx) => {
                    colValues.forEach((colVal, colIdx) => {
                        const rawFacetData = data.filter(row =>
                            row[facetRow] === rowVal && row[facetCol] === colVal
                        );

                        // Calculate rankings within this facet combination
                        let facetData;
                        if (yMode === 'Ranking') {
                            facetData = calculateDenseRanks(rawFacetData, xCol, perfCol);
                        } else {
                            facetData = rawFacetData.map(row => ({
                                ...row,
                                y_value: row[perfCol],
                                original_value: row[perfCol]
                            }));
                        }

                        const entities = [...new Set(facetData.map(row => String(row[ENTITY_COL])))].sort();

                        const idx = rowIdx * nCols + colIdx;
                        const xaxis = idx === 0 ? 'x' : 'x' + (idx + 1);
                        const yaxis = idx === 0 ? 'y' : 'y' + (idx + 1);

                        entities.forEach(entity => {
                            const entityData = facetData.filter(row => String(row[ENTITY_COL]) === entity);
                            entityData.sort((a, b) => {
                                const aVal = a[xCol];
                                const bVal = b[xCol];
                                if (aVal instanceof Date && bVal instanceof Date) {
                                    return aVal - bVal;
                                }
                                return aVal < bVal ? -1 : (aVal > bVal ? 1 : 0);
                            });

                            const xValues = entityData.map(row => row[xCol]);
                            const yValues = entityData.map(row => row.y_value);
                            const origValues = entityData.map(row => row.original_value);

                            traces.push({
                                x: xValues,
                                y: yValues,
                                type: 'scatter',
                                mode: 'lines+markers',
                                name: entity,
                                legendgroup: entity,
                                showlegend: idx === 0,
                                xaxis: xaxis,
                                yaxis: yaxis,
                                line: {
                                    color: entityColors[entity],
                                    width: $line_width
                                },
                                marker: {size: 6},
                                customdata: origValues,
                                hovertemplate: entity + '<br>' + xCol + ': %{x}<br>' +
                                              (yMode === 'Ranking' ? 'Rank: %{y}<br>Value: %{customdata}' : 'Value: %{y}') +
                                              '<extra></extra>'
                            });
                        });

                        // Add axis configuration
                        layout[xaxis] = {
                            title: rowIdx === nRows - 1 ? xCol : '',
                            anchor: yaxis
                        };

                        if (yMode === 'Ranking') {
                            layout[yaxis] = {
                                title: colIdx === 0 ? 'Rank' : '',
                                anchor: xaxis,
                                autorange: 'reversed'
                            };
                        } else {
                            layout[yaxis] = {
                                title: colIdx === 0 ? 'Performance' : '',
                                anchor: xaxis,
                                autorange: true
                            };
                        }

                        // Add annotations for facet labels
                        if (!layout.annotations) layout.annotations = [];

                        // Column header
                        if (rowIdx === 0) {
                            layout.annotations.push({
                                text: facetCol + ': ' + colVal,
                                showarrow: false,
                                xref: xaxis === 'x' ? 'x domain' : xaxis + ' domain',
                                yref: yaxis === 'y' ? 'y domain' : yaxis + ' domain',
                                x: 0.5,
                                y: 1.1,
                                xanchor: 'center',
                                yanchor: 'bottom',
                                font: {size: 10}
                            });
                        }

                        // Row label
                        if (colIdx === nCols - 1) {
                            layout.annotations.push({
                                text: facetRow + ': ' + rowVal,
                                showarrow: false,
                                xref: xaxis === 'x' ? 'x domain' : xaxis + ' domain',
                                yref: yaxis === 'y' ? 'y domain' : yaxis + ' domain',
                                x: 1.05,
                                y: 0.5,
                                xanchor: 'left',
                                yanchor: 'middle',
                                textangle: -90,
                                font: {size: 10}
                            });
                        }
                    });
                });

                Plotly.newPlot('$chart_title_safe', traces, layout, {responsive: true}).then(() => {
                    setupCrossFacetHighlighting('$chart_title_safe', traces);
                });
            }

            // Setup cross-facet highlighting (hover over one line greys out all others)
            function setupCrossFacetHighlighting(chartId, allTraces) {
                const chartDiv = document.getElementById(chartId);
                const originalColors = allTraces.map(t => t.line.color);

                chartDiv.on('plotly_hover', function(data) {
                    if (!data.points || data.points.length === 0) return;

                    const hoveredEntity = data.points[0].data.name;

                    // Update all traces: hovered stays colored, others turn grey
                    const updates = allTraces.map((trace, idx) => {
                        if (trace.name === hoveredEntity) {
                            return originalColors[idx];  // Keep original color
                        } else {
                            return 'rgba(200, 200, 200, 0.3)';  // Grey out
                        }
                    });

                    Plotly.restyle(chartId, {'line.color': updates});
                });

                chartDiv.on('plotly_unhover', function() {
                    // Restore all original colors
                    Plotly.restyle(chartId, {'line.color': originalColors});
                });
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

        # Build axis controls HTML (Performance metric only - X is fixed)
        axes_html = """
            <div style="background-color: #f0f8ff; padding: 10px; margin: 10px 0; border-radius: 5px;">
                <h4 style="margin: 0 0 10px 0;">Performance Metric</h4>
                <div style="margin: 10px; display: flex; align-items: center;">
                    <div style="flex: 0 0 70%;">
                        <label for="perf_col_select_$chart_title_safe">Metric: </label>
                        <select id="perf_col_select_$chart_title_safe" onchange="$update_function">
        """

        for col in valid_performance_cols
            selected = col == Symbol(default_perf) ? " selected" : ""
            axes_html *= "                    <option value=\"$col\"$selected>$col</option>\n"
        end

        axes_html *= """
                        </select>
                    </div>
                </div>
            </div>
        """

        # Build attribute dropdowns
        attribute_dropdowns = DropdownControl[]

        # Y-axis mode dropdown
        push!(attribute_dropdowns, DropdownControl(
            "y_mode_select_$chart_title_safe",
            "Y-axis Mode",
            ["Ranking", "Absolute"],
            y_mode,
            update_function
        ))

        # Build faceting dropdowns
        facet_dropdowns = build_facet_dropdowns(chart_title_safe, facet_choices, default_facet_array, update_function)

        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_safe,
            chart_title_safe,
            update_function,
            filter_dropdowns,
            filter_sliders,
            attribute_dropdowns,
            axes_html,
            facet_dropdowns,
            title,
            notes
        )
        appearance_html = generate_appearance_html(controls; aspect_ratio_default=0.3)

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(a::BumpChart) = [a.data_label]
