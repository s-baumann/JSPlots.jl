"""
    Waterfall(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive waterfall chart visualization with side-by-side calculation table.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `color_cols::Vector{Symbol}`: Column(s) containing category names (default: `[:category]`). If multiple columns provided, a dropdown will allow switching between them.
- `value_col::Symbol`: Column containing values (default: `:value`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
- `choices`: Single-select choice filters (default: `Dict{Symbol,Any}()`). Can be:
  - `Vector{Symbol}`: Column names - uses first unique value as default
  - `Dict{Symbol, Any}`: Column => default value mapping
- `facet_cols`: Columns available for faceting (default: `nothing`)
- `default_facet_cols`: Default faceting columns (default: `nothing`)
- `show_table::Bool`: Display side-by-side calculation table (default: `true`)
- `show_totals::Bool`: Add total bar at the end (default: `true`)
- `title::String`: Chart title (default: `"Waterfall Chart"`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Data Structure
The DataFrame should contain:
- A category column with step names (e.g., "Revenue", "COGS", "Operating Exp")
- A value column with positive/negative values
- Optional filter columns for filtering different datasets
- Optional facet columns for creating multiple charts

# Example
```julia
df = DataFrame(
    category = ["Revenue", "COGS", "Operating Exp", "Net Income"],
    value = [1000, -400, -200, 400],
    region = repeat(["North"], 4)
)

wf = Waterfall(:pnl, df, :pnl_data;
    color_cols = [:category],
    value_col = :value,
    filters = Dict(:region => ["North", "South"]),
    title = "Profit & Loss Statement",
    show_table = true
)
```

# Interactive Features
- Click on waterfall segments to temporarily remove them from both chart and table
- Reset button to restore all segments
- Automatic cumulative sum calculation
- Color coding: green (positive), red (negative), blue (totals)
- Filter controls to switch datasets
- Faceting support for multiple charts
"""
struct Waterfall <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function Waterfall(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                       item_col::Symbol = :item,
                       color_cols::Vector{Symbol} = [:category],
                       value_col::Symbol = :value,
                       filters::Union{Vector{Symbol}, Dict} = Dict{Symbol,Any}(),
                       choices::Union{Vector{Symbol}, Dict} = Dict{Symbol, Any}(),
                       show_table::Bool = true,
                       show_totals::Bool = true,
                       title::String = "Waterfall Chart",
                       notes::String = "")

        # Normalize filters and choices to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Validate item_col
        if !(item_col in Symbol.(names(df)))
            error("item_col :$item_col not found in DataFrame. Available columns: $(names(df))")
        end

        # Validate color_cols
        if isempty(color_cols)
            error("color_cols must contain at least one column")
        end

        # Validate that all color columns exist
        for col in color_cols
            if !(col in Symbol.(names(df)))
                error("color_cols :$col not found in DataFrame. Available columns: $(names(df))")
            end
        end

        # Set default color column
        default_color_col = color_cols[1]
        if !(value_col in Symbol.(names(df)))
            error("value_col :$value_col not found in DataFrame. Available columns: $(names(df))")
        end

        # Build filter dropdowns (single-select only)
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"

        # Build single-select filter dropdowns manually
        filter_dropdowns = DropdownControl[]
        for (col, default_vals) in normalized_filters
            col_str = string(col)
            unique_vals = unique(df[!, col])
            default_val = isempty(default_vals) ? string(unique_vals[1]) : string(default_vals[1])

            push!(filter_dropdowns, DropdownControl(
                col_str * "_select_" * chart_title_str,
                col_str,
                string.(unique_vals),  # Use string.() not String.() to handle all types
                default_val,
                update_function
            ))
        end
        choice_dropdowns = build_choice_dropdowns(chart_title_str, normalized_choices, df, update_function)

        # Build color maps for category-based coloring
        color_maps, _ = build_color_maps(color_cols, df, DEFAULT_COLOR_PALETTE)

        # Create JavaScript arrays for columns
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        choice_cols = collect(keys(normalized_choices))
        choice_filters_js = build_js_array(choice_cols)
        color_cols_js = build_js_array(String.(color_cols))
        color_maps_js = JSON.json(color_maps)

        # Build color mode dropdown (always shown)
        color_mode_dropdown = [DropdownControl(
            "color_mode_$chart_title_str",
            "Color By",
            ["Value (Positive/Negative)", "Category"],
            "Value (Positive/Negative)",
            update_function
        )]

        # Build color column dropdown if multiple color columns provided
        color_col_dropdown = if length(color_cols) > 1
            [DropdownControl(
                "color_col_$chart_title_str",
                "Category Column",
                String.(color_cols),
                string(default_color_col),
                update_function
            )]
        else
            DropdownControl[]
        end

        # Build appearance HTML using html_controls abstraction
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
            choice_dropdowns,
            filter_dropdowns,
            DropdownControl[],  # No sliders
            vcat(color_mode_dropdown, color_col_dropdown),  # Color mode + category column dropdowns
            "",  # No axes controls for Waterfall
            DropdownControl[],  # No faceting
            title,
            notes
        )
        appearance_html_base = generate_appearance_html(controls; multiselect_filters=false, aspect_ratio_default=0.4)

        # Add waterfall-specific styles and layout
        waterfall_styles = """
        <style>
            .waterfall-layout-$chart_title_str {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 20px;
                margin: 20px 0;
            }

            .waterfall-chart-section-$chart_title_str {
                width: 100%;
                max-width: 1200px;
            }

            .waterfall-table-section-$chart_title_str {
                background-color: #f9f9f9;
                padding: 15px;
                border: 1px solid #ddd;
                border-radius: 5px;
                overflow-x: auto;
                max-width: 800px;
            }

            .waterfall-table-$chart_title_str {
                width: 100%;
                border-collapse: collapse;
                font-size: 0.9em;
            }

            .waterfall-table-$chart_title_str th,
            .waterfall-table-$chart_title_str td {
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
            }

            .waterfall-table-$chart_title_str th {
                background-color: #4CAF50;
                color: white;
                font-weight: bold;
            }

            .waterfall-table-$chart_title_str tr.removed {
                opacity: 0.3;
                text-decoration: line-through;
                background-color: #e0e0e0 !important;
            }

            .waterfall-table-$chart_title_str tr.positive {
                background-color: #d5f4e6;
            }

            .waterfall-table-$chart_title_str tr.negative {
                background-color: #fadbd8;
            }

            .waterfall-table-$chart_title_str tr.total {
                background-color: #d6eaf8;
                font-weight: bold;
                border-top: 2px solid #333;
            }

            .waterfall-table-$chart_title_str tr:hover:not(.removed) {
                background-color: #fffacd !important;
                cursor: pointer;
            }

            .waterfall-reset-btn-$chart_title_str {
                margin-top: 10px;
                padding: 8px 16px;
                background-color: #ff5722;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 14px;
            }

            .waterfall-reset-btn-$chart_title_str:hover {
                background-color: #e64a19;
            }
        </style>
        """

        # Modify appearance_html to include waterfall layout
        appearance_html = appearance_html_base * waterfall_styles * """
        <div class="waterfall-layout-$chart_title_str">
            <div class="waterfall-chart-section-$chart_title_str">
                <!-- Chart will be rendered here -->
            </div>
            $(show_table ? "<div class=\"waterfall-table-section-$chart_title_str\">
                <h4>Calculation Table</h4>
                <p style=\"font-size: 0.85em; color: #666; margin-top: 0;\">Click on category headers to toggle groups, or individual rows to exclude items</p>
                <div id=\"waterfall_table_container_$chart_title_str\">
                    <!-- Table will be generated by JavaScript -->
                </div>
                <button class=\"waterfall-reset-btn-$chart_title_str\" onclick=\"resetWaterfall_$chart_title()\">🔄 Reset All</button>
            </div>" : "")
        </div>
        """

        # Build functional HTML (JavaScript code)
        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const CHOICE_FILTERS = $choice_filters_js;
            const COLOR_COLS = $color_cols_js;
            const ITEM_COL = '$(string(item_col))';
            let CATEGORY_COL = '$(string(default_color_col))';
            const VALUE_COL = '$(string(value_col))';
            const SHOW_TABLE = $(show_table);
            const SHOW_TOTALS = $(show_totals);
            const COLOR_MAPS = $color_maps_js;

            // Store data globally
            let allData = [];
            let removedItems = new Set();  // Set of removed item names
            let removedCategories = new Set();  // Set of removed category names

            function calculateWaterfall_$chart_title(data) {
                const activeData = data.filter(row => {
                    const item = String(row[ITEM_COL]);
                    const category = String(row[CATEGORY_COL]);
                    return !removedItems.has(item) && !removedCategories.has(category);
                });

                let runningTotal = 0;
                const processed = [];

                for (let i = 0; i < activeData.length; i++) {
                    const row = activeData[i];
                    const item = String(row[ITEM_COL]);
                    const category = String(row[CATEGORY_COL]);
                    const value = Number(row[VALUE_COL]) || 0;
                    const start = runningTotal;
                    const end = runningTotal + value;

                    // All items are 'relative' (floating bars showing individual changes)
                    // First item starts from 0 but still uses relative measure
                    processed.push({
                        item: item,
                        category: category,
                        value: value,
                        start: start,
                        end: end,
                        type: value >= 0 ? 'increasing' : 'decreasing',
                        isFirst: i === 0
                    });

                    runningTotal = end;
                }

                // Add total if enabled
                if (SHOW_TOTALS && processed.length > 0) {
                    processed.push({
                        item: 'Total',
                        category: 'Total',
                        value: runningTotal,
                        start: 0,
                        end: runningTotal,
                        type: 'total',
                        isFirst: false
                    });
                }

                return processed;
            }

            function updateTable_$chart_title(processedData, allItemsData) {
                if (!SHOW_TABLE) return;

                const container = document.getElementById('waterfall_table_container_$chart_title');
                if (!container) return;

                // Build a map for quick lookup by item name
                const dataMap = {};
                for (const item of processedData) {
                    dataMap[item.item] = item;
                }

                // Group items by category
                const categoryGroups = {};
                for (const row of allItemsData) {
                    const cat = String(row[CATEGORY_COL]);
                    const item = String(row[ITEM_COL]);
                    if (!categoryGroups[cat]) {
                        categoryGroups[cat] = [];
                    }
                    categoryGroups[cat].push(item);
                }

                // Build table HTML
                let html = '<table class="waterfall-table-$chart_title_str">';
                html += '<thead><tr><th>Item</th><th>Change</th><th>Running Total</th></tr></thead>';
                html += '<tbody>';

                // Iterate through categories
                for (const [category, items] of Object.entries(categoryGroups)) {
                    const catRemoved = removedCategories.has(category);

                    // Category header row
                    html += `<tr class="category-header" style="background-color: #e0e0e0; font-weight: bold; cursor: pointer;"
                             onclick="toggleCategoryGroup_$chart_title('\${category}')">`;
                    html += `<td colspan="3">`;
                    html += `<input type="checkbox" \${!catRemoved ? 'checked' : ''}
                             onclick="event.stopPropagation(); toggleCategoryGroup_$chart_title('\${category}')"
                             style="margin-right: 8px;">`;
                    html += `\${category}</td></tr>`;

                    // Item rows within category
                    for (const item of items) {
                        const itemRemoved = removedItems.has(item) || catRemoved;
                        const data = dataMap[item];

                        let rowClass = '';
                        if (itemRemoved) {
                            rowClass = 'removed';
                        } else if (data) {
                            if (data.type === 'absolute' || data.type === 'increasing') {
                                rowClass = 'positive';
                            } else if (data.type === 'decreasing') {
                                rowClass = 'negative';
                            } else if (data.type === 'total') {
                                rowClass = 'total';
                            }
                        }

                        html += `<tr class="\${rowClass}" style="cursor: pointer; padding-left: 20px;"
                                 onclick="toggleItem_$chart_title('\${item}')">`;
                        html += `<td style="padding-left: 20px;">\${item}</td>`;

                        if (data && !itemRemoved) {
                            html += `<td style="text-align: right;">\${data.value.toFixed(2)}</td>`;
                            html += `<td style="text-align: right;">\${data.end.toFixed(2)}</td>`;
                        } else {
                            html += `<td style="text-align: right;">-</td>`;
                            html += `<td style="text-align: right;">-</td>`;
                        }
                        html += '</tr>';
                    }
                }

                // Add Total row if it exists in processed data
                const totalData = processedData.find(d => d.type === 'total');
                if (totalData) {
                    const totalRemoved = removedItems.has('Total');
                    const rowClass = totalRemoved ? 'removed' : 'total';

                    html += `<tr class="\${rowClass}" style="background-color: #f5f5f5; font-weight: bold; cursor: pointer;"
                             onclick="toggleItem_$chart_title('Total')">`;
                    html += `<td style="padding-left: 20px;">Total</td>`;

                    if (!totalRemoved) {
                        html += `<td style="text-align: right;">\${totalData.value.toFixed(2)}</td>`;
                        html += `<td style="text-align: right;">\${totalData.end.toFixed(2)}</td>`;
                    } else {
                        html += `<td style="text-align: right;">-</td>`;
                        html += `<td style="text-align: right;">-</td>`;
                    }
                    html += '</tr>';
                }

                html += '</tbody></table>';
                container.innerHTML = html;
            }

            window.toggleItem_$chart_title = function(item) {
                // Allow toggling of all items including Total
                if (removedItems.has(item)) {
                    removedItems.delete(item);
                } else {
                    removedItems.add(item);
                }
                window.updateChart_$chart_title();
            };

            window.toggleCategoryGroup_$chart_title = function(category) {
                if (removedCategories.has(category)) {
                    removedCategories.delete(category);
                } else {
                    removedCategories.add(category);
                }
                window.updateChart_$chart_title();
            };

            window.resetWaterfall_$chart_title = function() {
                removedItems = new Set();
                removedCategories = new Set();
                window.updateChart_$chart_title();
            };

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title = function() {
                // Check if data is loaded
                if (!allData || allData.length === 0) {
                    return;
                }

                // Update category column if dropdown exists
                const colorColSelect = document.getElementById('color_col_$chart_title_str');
                if (colorColSelect) {
                    CATEGORY_COL = colorColSelect.value;
                }

                // Get color mode
                const colorModeSelect = document.getElementById('color_mode_$chart_title_str');
                const colorMode = colorModeSelect ? colorModeSelect.value : 'Value (Positive/Negative)';
                console.log('Color mode:', colorMode);
                console.log('CATEGORY_COL:', CATEGORY_COL);
                console.log('COLOR_MAPS:', COLOR_MAPS);

                // Get current filter values (single selection)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = select.value;
                    }
                });

                // Get choice filter values (single-select)
                const choices = {};
                CHOICE_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_choice_$chart_title');
                    if (select) {
                        choices[col] = select.value;
                    }
                });

                // Filter data (single selection per filter + choices)
                const filteredData = allData.filter(row => {
                    for (let col in filters) {
                        if (String(row[col]) !== filters[col]) {
                            return false;
                        }
                    }
                    for (let col in choices) {
                        if (String(row[col]) !== choices[col]) {
                            return false;
                        }
                    }
                    return true;
                });

                // Calculate waterfall (includes all items)
                const processed = calculateWaterfall_$chart_title(filteredData);

                // Filter processed data for chart display (remove toggled items like Total)
                const processedForChart = processed.filter(d => !removedItems.has(d.item));

                const items = processedForChart.map(d => d.item);
                const values = processedForChart.map(d => d.value);
                const bases = processedForChart.map(d => d.type === 'total' ? 0 : d.start);

                // Determine colors based on mode
                let markerColors;
                if (colorMode === 'Category' && COLOR_MAPS[CATEGORY_COL]) {
                    // Category-based coloring
                    markerColors = processedForChart.map(d => {
                        if (d.type === 'total') return '#000000';  // Total is always black
                        const categoryColor = COLOR_MAPS[CATEGORY_COL][d.category];
                        return categoryColor || '#4285F4';
                    });
                    console.log('Using category-based colors:', markerColors);
                } else {
                    // Value-based coloring (positive/negative)
                    markerColors = processedForChart.map(d => {
                        if (d.type === 'total') return '#000000';  // Total is always black
                        return d.value >= 0 ? '#4CAF50' : '#F44336';  // Green for positive, Red for negative
                    });
                    console.log('Using value-based colors (positive/negative):', markerColors);
                }

                // Build waterfall using bar chart with base values
                // This gives us full control over colors
                const trace = {
                    type: 'bar',
                    orientation: 'v',
                    x: items,
                    y: values,
                    base: bases,
                    text: values.map(v => v.toFixed(2)),
                    textposition: 'outside',
                    hovertemplate: '%{x}<br>Change: %{y:.2f}<br>Running Total: %{base:+y:.2f}<extra></extra>',
                    marker: {
                        color: markerColors,
                        line: { width: 1, color: '#333' }
                    }
                };

                // Add connector lines as shapes
                const shapes = [];
                for (let i = 0; i < processedForChart.length - 1; i++) {
                    if (processedForChart[i].type !== 'total' && processedForChart[i + 1].type !== 'total') {
                        const endY = processedForChart[i].end;
                        shapes.push({
                            type: 'line',
                            x0: i + 0.4,
                            x1: i + 1 - 0.4,
                            y0: endY,
                            y1: endY,
                            line: {
                                color: 'rgb(63, 63, 63)',
                                width: 2,
                                dash: 'dot'
                            }
                        });
                    }
                }

                const layout = {
                    showlegend: false,
                    xaxis: { title: ITEM_COL },
                    yaxis: { title: VALUE_COL },
                    height: 500,
                    margin: {l: 80, r: 50, t: 50, b: 100},
                    shapes: shapes
                };

                // Use newPlot to ensure colors update properly
                // (react sometimes doesn't update all trace properties)
                Plotly.newPlot('$chart_title', [trace], layout, {responsive: true}).then(function() {
                    // Initialize click handler after first plot is created
                    initClickHandler_$chart_title();
                });

                // Update table
                updateTable_$chart_title(processed, filteredData);
            };

            // Track if click handler has been initialized
            let clickHandlerInitialized = false;

            // Initialize click handler after first plot is created
            function initClickHandler_$chart_title() {
                if (clickHandlerInitialized) return;
                const chartDiv = document.getElementById('$chart_title');
                chartDiv.on('plotly_click', function(data) {
                    const clickedItem = data.points[0].x;
                    window.toggleItem_$chart_title(clickedItem);
                });
                clickHandlerInitialized = true;
            }

            // Load and parse data
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title();

                // Setup aspect ratio control after initial render
                setupAspectRatioControl('$chart_title');
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(w::Waterfall) = [w.data_label]
js_dependencies(::Waterfall) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
