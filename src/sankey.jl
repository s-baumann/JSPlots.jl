"""
    SanKey(chart_title::Symbol, df::DataFrame, data_label::Symbol; kwargs...)

Create an interactive Sankey diagram (alluvial diagram) showing flows between group affiliations across time.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `df::DataFrame`: DataFrame containing the panel data
- `data_label::Symbol`: Symbol referencing the DataFrame in the page's data dictionary

# Keyword Arguments
- `id_col::Union{Symbol, Nothing}`: Column identifying each entity/individual (optional, auto-generated if not provided)
- `time_col::Symbol`: Column indicating time/stage (required)
- `color_cols::Vector{Symbol}`: Column(s) for group affiliation (required). If multiple columns provided, a dropdown allows switching between them.
- `value_cols::Vector{Symbol}`: Column(s) for weighting flows (default: equal weighting = empty vector). If multiple columns provided, a dropdown allows switching between them.
- `filters::Union{Vector{Symbol}, Dict}`: Filter columns (default: `Dict{Symbol,Any}()`)
- `title::String`: Chart title (default: `"Sankey Diagram"`)
- `notes::String`: Descriptive text (default: `""`)

# Data Structure
The DataFrame should be in long format with each row representing an entity-time observation:
- `id_col`: Identifier for tracking entities across time (optional - if not provided, each row gets a unique auto-generated ID)
- `time_col`: Time period (can be Date, Number, or OrderedCategorical)
- `color_cols`: Group affiliation at that time
- `value_cols`: Weight for that observation (optional)

# Example
```julia
df = DataFrame(
    person_id = [1, 1, 2, 2, 3, 3],
    year = [2020, 2024, 2020, 2024, 2020, 2024],
    party = ["Rep", "Dem", "Dem", "Ind", "Rep", "Rep"],
    employment = ["Employed", "Unemployed", "Employed", "Employed", "Unemployed", "Employed"],
    weight = [1, 1, 1, 1, 1, 1]
)

ribbon = SanKey(:flows, df, :flow_data;
    id_col = :person_id,
    time_col = :year,
    color_cols = [:party, :employment],
    value_cols = [:weight],
    title = "Voter Transitions Over Time"
)
```

# Interactive Features
- Switch between different affiliation columns (e.g., party vs employment)
- Switch between different value columns to change flow weighting
- Filter data to focus on specific segments
- Hover to see flow details
- Color-coded ribbons showing category transitions
"""
struct SanKey <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function SanKey(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                        id_col::Union{Symbol, Nothing} = nothing,
                        time_col::Symbol,
                        color_cols::Vector{Symbol},
                        value_cols::Vector{Symbol} = Symbol[],
                        filters::Union{Vector{Symbol}, Dict} = Dict{Symbol,Any}(),
                        title::String = "Sankey Diagram",
                        notes::String = "")

        # If id_col not provided, auto-generate unique IDs
        df_work = if id_col === nothing
            df_temp = copy(df)
            df_temp[!, :_auto_id] = 1:nrow(df_temp)
            id_col = :_auto_id
            df_temp
        else
            validate_column(df, id_col, "id_col")
            df
        end

        # Validate required columns
        validate_column(df_work, time_col, "time_col")

        # Validate color_cols and value_cols
        if isempty(color_cols)
            error("color_cols must contain at least one column")
        end

        for col in color_cols
            validate_column(df_work, col, "color_cols")
        end

        for col in value_cols
            validate_column(df_work, col, "value_cols")
        end

        default_color_col = color_cols[1]
        default_value_col = isempty(value_cols) ? :count : value_cols[1]

        # Normalize filters
        normalized_filters = normalize_filters(filters, df_work)

        # Build filter controls
        chart_title_str = string(chart_title)
        update_function = "updateChart_$chart_title()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(chart_title_str, normalized_filters, df_work, update_function)

        # Separate categorical and continuous filters for JavaScript
        categorical_filter_cols = [string(d.id)[1:findfirst("_select_", string(d.id))[1]-1] for d in filter_dropdowns]
        continuous_filter_cols = [string(s.id)[1:findfirst("_range_", string(s.id))[1]-1] for s in filter_sliders]
        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)

        # Build color column dropdown if multiple provided
        color_col_dropdown = if length(color_cols) > 1
            [DropdownControl(
                "color_col_$chart_title_str",
                "Affiliation",
                String.(color_cols),
                string(default_color_col),
                update_function
            )]
        else
            DropdownControl[]
        end

        # Build value column dropdown if multiple provided
        value_col_dropdown = if length(value_cols) > 1
            [DropdownControl(
                "value_col_$chart_title_str",
                "Weight By",
                String.(value_cols),
                string(default_value_col),
                update_function
            )]
        else
            DropdownControl[]
        end

        # Create JavaScript arrays
        filter_cols_js = build_js_array(collect(keys(normalized_filters)))
        color_cols_js = build_js_array(String.(color_cols))
        value_cols_js = build_js_array(String.(value_cols))

        # Build appearance HTML
        controls = ChartHtmlControls(
            chart_title_str,
            chart_title_str,
            update_function,
            filter_dropdowns,
            filter_sliders,
            vcat(color_col_dropdown, value_col_dropdown),
            "",  # No axes controls for Sankey diagrams
            DropdownControl[],  # No faceting for Sankey diagrams
            title,
            notes
        )
        appearance_html_base = generate_appearance_html(controls)

        # Add Sankey diagram styles
        ribbon_styles = """
        <style>
            .sankey-container-$chart_title_str {
                width: 100%;
                max-width: 1200px;
                margin: 20px auto;
            }
        </style>
        """

        appearance_html = appearance_html_base * ribbon_styles * """
        <div class="sankey-container-$chart_title_str">
            <div id="$chart_title"></div>
        </div>
        """

        # Build functional HTML (JavaScript)
        functional_html = """
        (function() {
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const COLOR_COLS = $color_cols_js;
            const VALUE_COLS = $value_cols_js;
            const ID_COL = '$(string(id_col))';
            const TIME_COL = '$(string(time_col))';
            let COLOR_COL = '$(string(default_color_col))';
            let VALUE_COL = '$(string(default_value_col))';
            const USE_COUNT = $(isempty(value_cols));

            let allData = [];

            function processSankeyData_$chart_title(data) {
                // Update columns from dropdowns if they exist
                const colorColSelect = document.getElementById('color_col_$chart_title_str');
                if (colorColSelect) {
                    COLOR_COL = colorColSelect.value;
                }

                const valueColSelect = document.getElementById('value_col_$chart_title_str');
                if (valueColSelect) {
                    VALUE_COL = valueColSelect.value;
                }

                // Get unique time values preserving order of first appearance
                // This respects categorical ordering from the data
                const uniqueTimes = [];
                const seen = new Set();
                for (const row of data) {
                    const time = row[TIME_COL];
                    if (!seen.has(time)) {
                        seen.add(time);
                        uniqueTimes.push(time);
                    }
                }

                // Only sort if values are dates or numbers (not categorical strings)
                const firstTime = uniqueTimes[0];
                if (firstTime instanceof Date || typeof firstTime === 'number') {
                    uniqueTimes.sort((a, b) => {
                        if (a instanceof Date && b instanceof Date) {
                            return a - b;
                        } else {
                            return a - b;
                        }
                    });
                }
                // For strings (categorical), keep first-occurrence order

                if (uniqueTimes.length < 2) {
                    console.error('Need at least 2 time periods for Sankey diagram');
                    return { nodes: [], links: [] };
                }

                // Build nodes and links for Sankey diagram
                const nodeMap = new Map();  // name -> index
                const nodes = [];
                const links = [];

                // Create nodes for each (time, affiliation) pair
                uniqueTimes.forEach((time, timeIdx) => {
                    const timeData = data.filter(row => row[TIME_COL] === time);
                    const uniqueAffiliations = [...new Set(timeData.map(row => String(row[COLOR_COL])))];

                    uniqueAffiliations.forEach(affiliation => {
                        const nodeName = `\${time}__\${affiliation}`;
                        if (!nodeMap.has(nodeName)) {
                            nodeMap.set(nodeName, nodes.length);
                            nodes.push({
                                name: affiliation,
                                fullName: nodeName,
                                time: time,
                                timeIdx: timeIdx
                            });
                        }
                    });
                });

                // Build links between consecutive time periods
                for (let i = 0; i < uniqueTimes.length - 1; i++) {
                    const time1 = uniqueTimes[i];
                    const time2 = uniqueTimes[i + 1];

                    // Get data for both time periods
                    const time1Data = data.filter(row => row[TIME_COL] === time1);
                    const time2Data = data.filter(row => row[TIME_COL] === time2);

                    // Build lookup by ID for time2
                    const time2Lookup = new Map();
                    time2Data.forEach(row => {
                        time2Lookup.set(row[ID_COL], row);
                    });

                    // Track flows: (affiliation1, affiliation2) -> total value
                    const flowMap = new Map();

                    time1Data.forEach(row1 => {
                        const id = row1[ID_COL];
                        const affiliation1 = String(row1[COLOR_COL]);

                        // Find matching record at time2
                        const row2 = time2Lookup.get(id);
                        if (row2) {
                            const affiliation2 = String(row2[COLOR_COL]);
                            const flowKey = `\${affiliation1}→\${affiliation2}`;

                            const value = USE_COUNT ? 1 : (Number(row1[VALUE_COL]) || 0);

                            if (flowMap.has(flowKey)) {
                                flowMap.set(flowKey, flowMap.get(flowKey) + value);
                            } else {
                                flowMap.set(flowKey, value);
                            }
                        }
                    });

                    // Create links from flow map
                    flowMap.forEach((value, flowKey) => {
                        const [affiliation1, affiliation2] = flowKey.split('→');
                        const sourceName = `\${time1}__\${affiliation1}`;
                        const targetName = `\${time2}__\${affiliation2}`;

                        const sourceIdx = nodeMap.get(sourceName);
                        const targetIdx = nodeMap.get(targetName);

                        if (sourceIdx !== undefined && targetIdx !== undefined && value > 0) {
                            links.push({
                                source: sourceIdx,
                                target: targetIdx,
                                value: value
                            });
                        }
                    });
                }

                return { nodes, links, uniqueTimes };
            }

            window.updateChart_$chart_title = function() {
                if (!allData || allData.length === 0) {
                    return;
                }

                // Get categorical filter values
                const filters = {};
                CATEGORICAL_FILTERS.forEach(col => {
                    const select = document.getElementById(col + '_select_$chart_title');
                    if (select) {
                        filters[col] = Array.from(select.selectedOptions).map(opt => opt.value);
                    }
                });

                // Get continuous filter values (range sliders)
                const rangeFilters = {};
                CONTINUOUS_FILTERS.forEach(col => {
                    const slider = \$('#' + col + '_range_$chart_title' + '_slider');
                    if (slider.length > 0) {
                        rangeFilters[col] = {
                            min: slider.slider("values", 0),
                            max: slider.slider("values", 1)
                        };
                    }
                });

                // Apply filters with observation counting (centralized function)
                const filteredData = applyFiltersWithCounting(
                    allData,
                    '$chart_title',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters
                );

                if (filteredData.length === 0) {
                    console.warn('No data after filtering');
                    return;
                }

                // Process data into Sankey format
                const { nodes, links, uniqueTimes } = processSankeyData_$chart_title(filteredData);

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
                            // Color by time stage
                            const colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'];
                            return colors[n.timeIdx % colors.length];
                        }),
                        // Add x positions based on time
                        x: nodes.map(n => n.timeIdx / (Math.max(...nodes.map(node => node.timeIdx)) || 1)),
                        y: Array(nodes.length).fill(null)  // Let Plotly auto-position vertically
                    },
                    link: {
                        source: links.map(l => l.source),
                        target: links.map(l => l.target),
                        value: links.map(l => l.value),
                        color: links.map(l => {
                            // Semi-transparent based on source color
                            const sourceNode = nodes[l.source];
                            const colors = ['rgba(31,119,180,0.3)', 'rgba(255,127,14,0.3)', 'rgba(44,160,44,0.3)',
                                          'rgba(214,39,40,0.3)', 'rgba(148,103,189,0.3)', 'rgba(140,86,75,0.3)',
                                          'rgba(227,119,194,0.3)', 'rgba(127,127,127,0.3)', 'rgba(188,189,34,0.3)', 'rgba(23,190,207,0.3)'];
                            return colors[sourceNode.timeIdx % colors.length];
                        })
                    }
                }];

                // Create time labels annotations
                const timeAnnotations = uniqueTimes.map((time, idx) => {
                    const xPos = idx / (uniqueTimes.length - 1 || 1);
                    return {
                        x: xPos,
                        y: 1.05,
                        xref: 'paper',
                        yref: 'paper',
                        text: String(time),
                        showarrow: false,
                        font: {
                            size: 14,
                            color: '#333'
                        },
                        xanchor: 'center'
                    };
                });

                const layout = {
                    font: {
                        size: 12
                    },
                    height: 600,
                    margin: { l: 50, r: 50, t: 70, b: 50 },
                    annotations: timeAnnotations
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

# Dependencies function for SanKey
function dependencies(x::SanKey)
    return [x.data_label]  # Return the data label so the data file gets saved
end
