"""
    Waterfall(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive waterfall chart visualization with side-by-side calculation table.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `color_cols::Union{Symbol, Vector{Symbol}}`: Column(s) containing category names (default: `:category`). If multiple columns provided, a dropdown will allow switching between them.
- `value_col::Symbol`: Column containing values (default: `:value`)
- `filters::Union{Vector{Symbol}, Dict}`: Default filter values (default: `Dict{Symbol,Any}()`)
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
    color_cols = :category,
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
                       color_cols::Union{Symbol, Vector{Symbol}} = :category,
                       value_col::Symbol = :value,
                       filters::Union{Vector{Symbol}, Dict} = Dict{Symbol,Any}(),
                       facet_cols::Union{Nothing, Symbol, Vector{Symbol}} = nothing,
                       default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}} = nothing,
                       show_table::Bool = true,
                       show_totals::Bool = true,
                       title::String = "Waterfall Chart",
                       notes::String = "")

        # Normalize filters to standard Dict{Symbol, Any} format
        normalized_filters = normalize_filters(filters, df)

        # Normalize color_cols to vector
        color_cols_vec = color_cols isa Symbol ? [color_cols] : color_cols

        # Validate that all color columns exist
        for col in color_cols_vec
            if !(col in Symbol.(names(df)))
                error("color_cols :$col not found in DataFrame. Available columns: $(names(df))")
            end
        end

        # Set default color column
        default_color_col = color_cols_vec[1]
        if !(value_col in Symbol.(names(df)))
            error("value_col :$value_col not found in DataFrame. Available columns: $(names(df))")
        end

        # Normalize and validate facets using centralized helper
        facet_choices, default_facet_array = normalize_and_validate_facets(facet_cols, default_facet_cols)

        # Get unique values for each filter column
        filter_options = build_filter_options(normalized_filters, df)

        # Build filter dropdowns using html_controls abstraction
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)

        # Build faceting dropdowns
        facet_dropdowns = build_facet_dropdowns(chart_title_str, facet_choices, default_facet_array, update_function)

        # Create JavaScript arrays for columns
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        color_cols_js = build_js_array(String.(color_cols_vec))

        # Build color column dropdown if multiple color columns provided
        color_col_dropdown = if length(color_cols_vec) > 1
            [DropdownControl(
                "color_col",
                "Color Column",
                String.(color_cols_vec),
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
            filter_dropdowns,
            filter_sliders,
            color_col_dropdown,  # Color column dropdown
            facet_dropdowns,
            title,
            notes
        )
        appearance_html_base = generate_appearance_html(controls)

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
                <p style=\"font-size: 0.85em; color: #666; margin-top: 0;\">Click on rows or chart bars to exclude from calculation</p>
                <table class=\"waterfall-table-$chart_title_str\" id=\"waterfall_table_$chart_title_str\">
                    <thead>
                        <tr>
                            <th>Category</th>
                            <th>Change</th>
                            <th>Running Total</th>
                        </tr>
                    </thead>
                    <tbody id=\"waterfall_tbody_$chart_title_str\">
                    </tbody>
                </table>
                <button class=\"waterfall-reset-btn-$chart_title_str\" onclick=\"resetWaterfall_$chart_title()\">🔄 Reset All</button>
            </div>" : "")
        </div>
        """

        # Build functional HTML (JavaScript code)
        functional_html = """
        (function() {
            // Configuration
            const FILTER_COLS = $filter_cols_js;
            const COLOR_COLS = $color_cols_js;
            let CATEGORY_COL = '$(string(default_color_col))';
            const VALUE_COL = '$(string(value_col))';
            const SHOW_TABLE = $(show_table);
            const SHOW_TOTALS = $(show_totals);

            // Store data globally
            let allData = [];
            let removedCategories = {};  // Map from facet_key to Set of removed categories

            function getFacetKey_$chart_title() {
                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;
                return (facet1 || 'none') + '|' + (facet2 || 'none');
            }

            function getRemovedSet_$chart_title() {
                const key = getFacetKey_$chart_title();
                if (!removedCategories[key]) {
                    removedCategories[key] = new Set();
                }
                return removedCategories[key];
            }

            function calculateWaterfall_$chart_title(data) {
                const removed = getRemovedSet_$chart_title();
                const activeData = data.filter(row => !removed.has(String(row[CATEGORY_COL])));

                let runningTotal = 0;
                const processed = [];

                for (const row of activeData) {
                    const category = String(row[CATEGORY_COL]);
                    const value = Number(row[VALUE_COL]) || 0;
                    const start = runningTotal;
                    const end = runningTotal + value;

                    processed.push({
                        category: category,
                        value: value,
                        start: start,
                        end: end,
                        type: value >= 0 ? 'increasing' : 'decreasing'
                    });

                    runningTotal = end;
                }

                // Add total if enabled
                if (SHOW_TOTALS && processed.length > 0) {
                    processed.push({
                        category: 'Total',
                        value: runningTotal,
                        start: 0,
                        end: runningTotal,
                        type: 'total'
                    });
                }

                return processed;
            }

            function updateTable_$chart_title(processedData, allCategories) {
                if (!SHOW_TABLE) return;

                const tbody = document.getElementById('waterfall_tbody_$chart_title');
                if (!tbody) return;

                const removed = getRemovedSet_$chart_title();
                tbody.innerHTML = '';

                // Build a map for quick lookup
                const dataMap = {};
                for (const item of processedData) {
                    dataMap[item.category] = item;
                }

                // Show all original categories (including removed ones)
                for (const cat of allCategories) {
                    const row = document.createElement('tr');
                    const isRemoved = removed.has(cat);
                    const item = dataMap[cat];

                    if (isRemoved) {
                        row.classList.add('removed');
                    } else if (item) {
                        if (item.type === 'increasing') {
                            row.classList.add('positive');
                        } else if (item.type === 'decreasing') {
                            row.classList.add('negative');
                        } else if (item.type === 'total') {
                            row.classList.add('total');
                        }
                    }

                    row.dataset.category = cat;
                    row.onclick = function() {
                        if (cat !== 'Total') {
                            toggleCategory_$chart_title(cat);
                        }
                    };

                    const categoryCell = document.createElement('td');
                    categoryCell.textContent = cat;
                    row.appendChild(categoryCell);

                    const valueCell = document.createElement('td');
                    if (item) {
                        valueCell.textContent = item.value.toFixed(2);
                        valueCell.style.textAlign = 'right';
                    } else {
                        valueCell.textContent = '-';
                    }
                    row.appendChild(valueCell);

                    const totalCell = document.createElement('td');
                    if (item) {
                        totalCell.textContent = item.end.toFixed(2);
                        totalCell.style.textAlign = 'right';
                    } else {
                        totalCell.textContent = '-';
                    }
                    row.appendChild(totalCell);

                    tbody.appendChild(row);
                }
            }

            function toggleCategory_$chart_title(category) {
                const removed = getRemovedSet_$chart_title();
                if (removed.has(category)) {
                    removed.delete(category);
                } else {
                    removed.add(category);
                }
                window.updateChart_$chart_title();
            }

            window.resetWaterfall_$chart_title = function() {
                const key = getFacetKey_$chart_title();
                removedCategories[key] = new Set();
                window.updateChart_$chart_title();
            };

            // Make it global so inline onchange can see it
            window.updateChart_$chart_title = function() {
                // Check if data is loaded
                if (!allData || allData.length === 0) {
                    return;
                }

                // Update color column if dropdown exists
                const colorColSelect = document.getElementById('color_col_select_$chart_title');
                if (colorColSelect) {
                    CATEGORY_COL = colorColSelect.value;
                }

                // Get current filter values (multiple selections)
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Filter data (support multiple selections per filter)
                const filteredData = allData.filter(row => {
                    for (let col in filters) {
                        const selectedValues = filters[col];
                        if (selectedValues.length > 0 && !selectedValues.includes(String(row[col]))) {
                            return false;
                        }
                    }
                    return true;
                });

                // Get all categories for table (before removal)
                const allCategories = [...new Set(filteredData.map(row => String(row[CATEGORY_COL])))];

                // Get current facet selections
                const facet1Select = document.getElementById('facet1_select_$chart_title');
                const facet2Select = document.getElementById('facet2_select_$chart_title');
                const facet1 = facet1Select && facet1Select.value !== 'None' ? facet1Select.value : null;
                const facet2 = facet2Select && facet2Select.value !== 'None' ? facet2Select.value : null;

                if (!facet1) {
                    // No faceting - single waterfall chart
                    const processed = calculateWaterfall_$chart_title(filteredData);

                    const categories = processed.map(d => d.category);
                    const values = processed.map(d => d.value);
                    const starts = processed.map(d => d.start);
                    const measure = processed.map(d =>
                        d.type === 'total' ? 'total' :
                        d.type === 'increasing' ? 'relative' : 'relative'
                    );

                    const trace = {
                        type: 'waterfall',
                        orientation: 'v',
                        x: categories,
                        y: values,
                        base: starts,
                        measure: measure,
                        text: values.map(v => v.toFixed(2)),
                        textposition: 'outside',
                        connector: {
                            line: { color: 'rgb(63, 63, 63)', width: 2 }
                        },
                        increasing: { marker: { color: '#2ecc71' } },
                        decreasing: { marker: { color: '#e74c3c' } },
                        totals: { marker: { color: '#3498db' } },
                        hovertemplate: '%{x}<br>Value: %{y}<br>Total: %{base}+%{y}<extra></extra>'
                    };

                    const layout = {
                        showlegend: false,
                        xaxis: { title: CATEGORY_COL },
                        yaxis: { title: VALUE_COL },
                        height: 500,
                        margin: {l: 80, r: 50, t: 50, b: 100}
                    };

                    Plotly.newPlot('$chart_title', [trace], layout, {responsive: true});

                    // Add click handler
                    document.getElementById('$chart_title').on('plotly_click', function(data) {
                        const clickedCategory = data.points[0].x;
                        if (clickedCategory !== 'Total') {
                            toggleCategory_$chart_title(clickedCategory);
                        }
                    });

                    // Update table
                    updateTable_$chart_title(processed, allCategories);

                } else {
                    // Faceting not implemented for waterfall yet
                    // (could be added in future enhancement)
                    const processed = calculateWaterfall_$chart_title(filteredData);

                    const categories = processed.map(d => d.category);
                    const values = processed.map(d => d.value);
                    const starts = processed.map(d => d.start);
                    const measure = processed.map(d =>
                        d.type === 'total' ? 'total' :
                        d.type === 'increasing' ? 'relative' : 'relative'
                    );

                    const trace = {
                        type: 'waterfall',
                        orientation: 'v',
                        x: categories,
                        y: values,
                        base: starts,
                        measure: measure,
                        text: values.map(v => v.toFixed(2)),
                        textposition: 'outside',
                        connector: {
                            line: { color: 'rgb(63, 63, 63)', width: 2 }
                        },
                        increasing: { marker: { color: '#2ecc71' } },
                        decreasing: { marker: { color: '#e74c3c' } },
                        totals: { marker: { color: '#3498db' } },
                        hovertemplate: '%{x}<br>Value: %{y}<br>Total: %{base}+%{y}<extra></extra>'
                    };

                    const layout = {
                        showlegend: false,
                        xaxis: { title: CATEGORY_COL },
                        yaxis: { title: VALUE_COL },
                        height: 500,
                        margin: {l: 80, r: 50, t: 50, b: 100}
                    };

                    Plotly.newPlot('$chart_title', [trace], layout, {responsive: true});

                    document.getElementById('$chart_title').on('plotly_click', function(data) {
                        const clickedCategory = data.points[0].x;
                        if (clickedCategory !== 'Total') {
                            toggleCategory_$chart_title(clickedCategory);
                        }
                    });

                    updateTable_$chart_title(processed, allCategories);
                }
            };

            // Load and parse data
            loadDataset('$data_label').then(function(data) {
                allData = data;
                window.updateChart_$chart_title();
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });
        })();
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end

dependencies(w::Waterfall) = [w.data_label]
