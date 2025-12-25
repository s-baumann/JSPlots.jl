"""
    RibbonPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive ribbon plot (alluvial diagram) showing flows between categories across timestages.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `timestage_cols::Vector{Symbol}`: Columns representing categorical groupings at each time stage (required)
- `value_cols::Union{Symbol, Vector{Symbol}}`: Column(s) for weighting the ribbons (default: equal weighting)
- `filters::Union{Vector{Symbol}, Dict}`: Filter columns (default: `Dict{Symbol,Any}()`)
- `title::String`: Chart title (default: `"Ribbon Plot"`)
- `notes::String`: Descriptive text (default: `""`)

# Data Structure
The DataFrame should contain:
- Multiple columns representing categories at different timestages
- Optional value column(s) for weighting observations
- Optional filter columns

# Example
```julia
df = DataFrame(
    stage1 = ["A", "A", "B", "B"],
    stage2 = ["X", "Y", "X", "Y"],
    stage3 = ["P", "P", "Q", "Q"],
    sales = [100, 200, 150, 250]
)

ribbon = RibbonPlot(:flows, df, :flow_data;
    timestage_cols = [:stage1, :stage2, :stage3],
    value_cols = :sales,
    title = "Customer Journey Flow"
)
```

# Interactive Features
- Switch between different value columns to change ribbon weighting
- Filter data to focus on specific segments
- Hover to see flow details
- Color-coded ribbons showing category transitions
"""
struct RibbonPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function RibbonPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                        timestage_cols::Vector{Symbol},
                        value_cols::Union{Symbol, Vector{Symbol}} = Symbol[],
                        filters::Union{Vector{Symbol}, Dict} = Dict{Symbol,Any}(),
                        title::String = "Ribbon Plot",
                        notes::String = "")

        # Validate timestage_cols
        if length(timestage_cols) < 2
            error("timestage_cols must have at least 2 columns for ribbon flow visualization")
        end

        for col in timestage_cols
            if !(col in Symbol.(names(df)))
                error("timestage_cols :$col not found in DataFrame. Available columns: $(names(df))")
            end
        end

        # Normalize value_cols to vector
        value_cols_vec = value_cols isa Symbol ? [value_cols] : value_cols
        default_value_col = isempty(value_cols_vec) ? :count : value_cols_vec[1]

        # Validate value columns
        for col in value_cols_vec
            if !(col in Symbol.(names(df)))
                error("value_cols :$col not found in DataFrame. Available columns: $(names(df))")
            end
        end

        # Normalize filters
        normalized_filters = normalize_filters(filters, df)

        # Build filter controls
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df, update_function)

        # Build value column dropdown if multiple provided
        value_col_dropdown = if length(value_cols_vec) > 1
            [DropdownControl(
                "value_col",
                "Weight By",
                String.(value_cols_vec),
                string(default_value_col),
                update_function
            )]
        else
            DropdownControl[]
        end

        # Create JavaScript arrays
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        timestage_cols_js = build_js_array(String.(timestage_cols))
        value_cols_js = build_js_array(String.(value_cols_vec))

        # Build appearance HTML
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
            filter_dropdowns,
            filter_sliders,
            value_col_dropdown,
            DropdownControl[],  # No faceting for ribbon plots
            title,
            notes
        )
        appearance_html_base = generate_appearance_html(controls)

        # Add ribbon plot styles
        ribbon_styles = """
        <style>
            .ribbon-container-$chart_title_str {
                width: 100%;
                max-width: 1200px;
                margin: 20px auto;
            }
        </style>
        """

        appearance_html = appearance_html_base * ribbon_styles * """
        <div class="ribbon-container-$chart_title_str">
            <div id="$chart_title"></div>
        </div>
        """

        # Build functional HTML (JavaScript)
        functional_html = """
        (function() {
            const FILTER_COLS = $filter_cols_js;
            const TIMESTAGE_COLS = $timestage_cols_js;
            const VALUE_COLS = $value_cols_js;
            let VALUE_COL = '$(string(default_value_col))';
            const USE_COUNT = $(isempty(value_cols_vec));

            let allData = [];

            function processRibbonData_$chart_title(data) {
                // Update value column from dropdown if exists
                const valueColSelect = document.getElementById('value_col_select_$chart_title');
                if (valueColSelect) {
                    VALUE_COL = valueColSelect.value;
                }

                // Create nodes and links for Sankey diagram
                const nodeMap = new Map();  // name -> index
                const nodes = [];
                const links = [];

                // Build node map
                TIMESTAGE_COLS.forEach((col, stageIdx) => {
                    const uniqueValues = [...new Set(data.map(row => String(row[col])))];
                    uniqueValues.forEach(value => {
                        const nodeName = `\${col}:\${value}`;
                        if (!nodeMap.has(nodeName)) {
                            nodeMap.set(nodeName, nodes.length);
                            nodes.push({
                                name: `\${value}`,
                                fullName: nodeName,
                                stage: stageIdx
                            });
                        }
                    });
                });

                // Build links between consecutive stages
                for (let i = 0; i < TIMESTAGE_COLS.length - 1; i++) {
                    const sourceCol = TIMESTAGE_COLS[i];
                    const targetCol = TIMESTAGE_COLS[i + 1];

                    // Group data by source->target pairs
                    const flowMap = new Map();
                    data.forEach(row => {
                        const sourceVal = String(row[sourceCol]);
                        const targetVal = String(row[targetCol]);
                        const sourceName = `\${sourceCol}:\${sourceVal}`;
                        const targetName = `\${targetCol}:\${targetVal}`;
                        const key = `\${sourceName}->\${targetName}`;

                        const value = USE_COUNT ? 1 : (Number(row[VALUE_COL]) || 0);

                        if (flowMap.has(key)) {
                            flowMap.set(key, flowMap.get(key) + value);
                        } else {
                            flowMap.set(key, value);
                        }
                    });

                    // Create links
                    flowMap.forEach((value, key) => {
                        const [source, target] = key.split('->');
                        const sourceIdx = nodeMap.get(source);
                        const targetIdx = nodeMap.get(target);

                        if (sourceIdx !== undefined && targetIdx !== undefined && value > 0) {
                            links.push({
                                source: sourceIdx,
                                target: targetIdx,
                                value: value
                            });
                        }
                    });
                }

                return { nodes, links };
            }

            window.updateChart_$chart_title = function() {
                if (!allData || allData.length === 0) {
                    return;
                }

                // Get current filter values
                const filters = {};
                FILTER_COLS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Filter data
                const filteredData = allData.filter(row => {
                    for (let col in filters) {
                        const selectedValues = filters[col];
                        if (selectedValues.length > 0 && !selectedValues.includes(String(row[col]))) {
                            return false;
                        }
                    }
                    return true;
                });

                if (filteredData.length === 0) {
                    console.warn('No data after filtering');
                    return;
                }

                // Process data into Sankey format
                const { nodes, links } = processRibbonData_$chart_title(filteredData);

                // Create Sankey diagram
                const data = [{
                    type: "sankey",
                    orientation: "h",
                    node: {
                        pad: 15,
                        thickness: 20,
                        line: {
                            color: "black",
                            width: 0.5
                        },
                        label: nodes.map(n => n.name),
                        color: nodes.map((n, i) => {
                            // Color by stage
                            const colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b'];
                            return colors[n.stage % colors.length];
                        })
                    },
                    link: {
                        source: links.map(l => l.source),
                        target: links.map(l => l.target),
                        value: links.map(l => l.value),
                        color: links.map(l => {
                            // Semi-transparent based on source color
                            const sourceNode = nodes[l.source];
                            const colors = ['rgba(31,119,180,0.3)', 'rgba(255,127,14,0.3)', 'rgba(44,160,44,0.3)',
                                          'rgba(214,39,40,0.3)', 'rgba(148,103,189,0.3)', 'rgba(140,86,75,0.3)'];
                            return colors[sourceNode.stage % colors.length];
                        })
                    }
                }];

                const layout = {
                    font: {
                        size: 12
                    },
                    height: 600,
                    margin: { l: 50, r: 50, t: 50, b: 50 }
                };

                Plotly.newPlot('$chart_title', data, layout, {responsive: true});
            };

            // Load data
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

# Dependencies function for RibbonPlot
function dependencies(x::RibbonPlot)
    return []  # Ribbon plots use Plotly.js which is already included in the base template
end
