
# CSS fix for PivotTable filter box positioning
# This is a known issue: https://github.com/nicolaskruchten/pivottable/issues/865
# We use position:fixed to ensure the dropdown appears relative to the viewport,
# not relative to a potentially scrolled parent. The JavaScript in make_html.jl
# calculates the actual position based on the clicked triangle.
const PIVOTTABLE_STYLE_FIXES = raw"""
<style>
    .pvtFilterBox {
        z-index: 10000 !important;
        position: fixed !important;
    }
</style>
"""

# Template for PivotTable with dataset switching support
const pivottable_function_template = raw"""
    // Store current data and settings for this pivot table
    window.pivotTableData__NAME_OF_PLOT___ = {};
    window.pivotTableConfig__NAME_OF_PLOT___ = ___KEYARGS_LOCATION___;

    // Helper function to convert values to strings suitable for PivotTable.js
    // PivotTable.js expects string values, not Date objects
    function valueToString__NAME_OF_PLOT___(value) {
        if (value === null || value === undefined) {
            return '';
        }
        if (value instanceof Date) {
            // Check if this is a date-only value (time is midnight)
            var hours = value.getHours();
            var minutes = value.getMinutes();
            var seconds = value.getSeconds();
            var ms = value.getMilliseconds();

            var year = value.getFullYear();
            var month = String(value.getMonth() + 1).padStart(2, '0');
            var day = String(value.getDate()).padStart(2, '0');

            if (hours === 0 && minutes === 0 && seconds === 0 && ms === 0) {
                // Date only: YYYY-MM-DD
                return year + '-' + month + '-' + day;
            } else {
                // DateTime: YYYY-MM-DD HH:MM:SS
                var h = String(hours).padStart(2, '0');
                var m = String(minutes).padStart(2, '0');
                var s = String(seconds).padStart(2, '0');
                return year + '-' + month + '-' + day + ' ' + h + ':' + m + ':' + s;
            }
        }
        return value;
    }

    // Function to load and render the pivot table with a specific dataset
    function loadPivotTable__NAME_OF_PLOT___(datasetName) {
        loadDataset(datasetName).then(function(data) {
            console.log('Loaded data for pivot table __NAME_OF_PLOT___ from dataset:', datasetName, data);

            // Validate data
            if (!data || data.length === 0) {
                throw new Error('No data loaded for pivot table __NAME_OF_PLOT___');
            }

            // Store the data
            window.pivotTableData__NAME_OF_PLOT___[datasetName] = data;

            // Convert data to array format expected by pivotUI
            // First row is headers
            var headers = Object.keys(data[0]);
            var arrayData = [headers];

            // Add data rows - convert Date objects to strings for proper display
            data.forEach(function(row) {
                var rowArray = headers.map(function(header) {
                    return valueToString__NAME_OF_PLOT___(row[header]);
                });
                arrayData.push(rowArray);
            });

            console.log('Converted array data for __NAME_OF_PLOT___:', arrayData.slice(0, 3));

            // Save current pivot state if exists
            var currentConfig = window.pivotTableConfig__NAME_OF_PLOT___;
            var pivotEl = $("#__NAME_OF_PLOT___");
            if (pivotEl.data('pivotUIOptions')) {
                // Preserve current user selections
                var opts = pivotEl.data('pivotUIOptions');
                currentConfig = {
                    rows: opts.rows,
                    cols: opts.cols,
                    vals: opts.vals,
                    aggregatorName: opts.aggregatorName,
                    rendererName: opts.rendererName,
                    inclusions: opts.inclusions,
                    exclusions: opts.exclusions,
                    rendererOptions: opts.rendererOptions
                };
            }

            // Render the pivot table
            pivotEl.pivotUI(
                arrayData,
                $.extend({
                    renderers: $.extend(
                        $.pivotUtilities.renderers,
                        $.pivotUtilities.c3_renderers,
                        $.pivotUtilities.d3_renderers,
                        $.pivotUtilities.export_renderers
                    ),
                    hiddenAttributes: [""]
                }, currentConfig)
            );

            // Initialize totals visibility based on checkbox state
            setTimeout(function() {
                if (window.toggleTotals___NAME_OF_PLOT___) {
                    window.toggleTotals___NAME_OF_PLOT___();
                }
            }, 100);
        }).catch(function(error) {
            console.error('Error loading data for pivot table __NAME_OF_PLOT___:', error);
            $("#__NAME_OF_PLOT___").html('<div style="color: red; padding: 20px;">Error loading pivot table: ' + error.message + '</div>');
        });
    }

    // Setup toggle for showing/hiding totals
    window.toggleTotals___NAME_OF_PLOT___ = function() {
        const checkbox = document.getElementById('show_totals_checkbox___NAME_OF_PLOT___');
        const showTotals = checkbox.checked;

        // Find all total cells in the pivot table
        const pivotContainer = document.getElementById('__NAME_OF_PLOT___');
        const totalCells = pivotContainer.querySelectorAll('.pvtTotal, .pvtGrandTotal');

        totalCells.forEach(function(cell) {
            cell.style.display = showTotals ? '' : 'none';
        });

        // Also hide/show total row headers (typically have "Totals" text)
        const allCells = pivotContainer.querySelectorAll('th, td');
        allCells.forEach(function(cell) {
            if (cell.textContent.trim() === 'Totals' || cell.textContent.trim() === 'Total') {
                cell.style.display = showTotals ? '' : 'none';
            }
        });
    };

    // Make dataset change handler global
    window.changeDataset___NAME_OF_PLOT___ = function() {
        var select = document.getElementById('dataset_select___NAME_OF_PLOT___');
        if (select) {
            loadPivotTable__NAME_OF_PLOT___(select.value);
        }
    };

    // Load the initial dataset
    loadPivotTable__NAME_OF_PLOT___('__NAME_OF_DATA___');
"""

const PIVOTTABLE_IN_PAGE_TEMPLATE = raw"""
    ___STYLE_FIXES___
    <h2>___TABLE_HEADING___</h2>
    <p>___NOTES___</p>
    ___DATASET_SELECTOR___
    <div style="margin-bottom: 10px;">
        <label>
            <input type="checkbox" id="show_totals_checkbox___FUNCTION_NAME___" ___SHOW_TOTALS_CHECKED___ onchange="toggleTotals___FUNCTION_NAME___()" />
            Show Totals
        </label>
    </div>
    <div id="__FUNCTION_NAME___"></div>
    <div class="jsplots-datasource" style="text-align: right; font-size: 0.85em; color: #666; margin-top: 8px; font-style: italic;">
        Data: ___DATASOURCE___
    </div>
"""

const DATASET_SELECTOR_TEMPLATE = raw"""
    <div style="margin-bottom: 10px;">
        <label for="dataset_select___FUNCTION_NAME___"><strong>Dataset:</strong></label>
        <select id="dataset_select___FUNCTION_NAME___" onchange="changeDataset___FUNCTION_NAME___()">
            ___DATASET_OPTIONS___
        </select>
    </div>
"""

function table_to_html(chart_title, notes, show_totals, data_labels::Vector{Symbol})
    chart_title_safe = replace(string(chart_title), " " => "_")
    html_str = replace(PIVOTTABLE_IN_PAGE_TEMPLATE, "___STYLE_FIXES___" => PIVOTTABLE_STYLE_FIXES)
    html_str = replace(html_str, "___TABLE_HEADING___" => string(chart_title))
    html_str = replace(html_str, "__FUNCTION_NAME___" => chart_title_safe)
    html_str = replace(html_str, "___FUNCTION_NAME___" => chart_title_safe)
    html_str = replace(html_str, "___NOTES___" => notes)
    html_str = replace(html_str, "___SHOW_TOTALS_CHECKED___" => (show_totals ? "checked" : ""))

    # Add dataset selector only if there are multiple datasets
    if length(data_labels) > 1
        dataset_options = join(["<option value=\"$(replace(string(label), " " => "_"))\">$(string(label))</option>" for label in data_labels], "\n            ")
        selector_html = replace(DATASET_SELECTOR_TEMPLATE, "__FUNCTION_NAME___" => chart_title_safe)
        selector_html = replace(selector_html, "___FUNCTION_NAME___" => chart_title_safe)
        selector_html = replace(selector_html, "___DATASET_OPTIONS___" => dataset_options)
        html_str = replace(html_str, "___DATASET_SELECTOR___" => selector_html)
    else
        html_str = replace(html_str, "___DATASET_SELECTOR___" => "")
    end

    # Add datasource info
    datasource_str = join([string(label) for label in data_labels], ", ")
    html_str = replace(html_str, "___DATASOURCE___" => datasource_str)

    return html_str
end



"""
    PivotTable(chart_title::Symbol, data_label::Union{Symbol, Vector{Symbol}}; kwargs...)

Interactive pivot table with drag-and-drop functionality using PivotTable.js.

# Arguments
- `chart_title::Symbol`: Unique identifier for this chart
- `data_label::Union{Symbol, Vector{Symbol}}`: Symbol or Vector of Symbols referencing DataFrames in the page's data dictionary.
  When multiple datasets are provided, a dropdown selector appears allowing the user to switch between them.

# Keyword Arguments
- `rows`: Column(s) to use as rows (default: `missing`)
- `cols`: Column(s) to use as columns (default: `missing`)
- `vals`: Column to aggregate (default: `missing`)
- `inclusions`: Dict of values to include in filtering (default: `missing`)
- `exclusions`: Dict of values to exclude from filtering (default: `missing`)
- `colour_map`: Custom color mapping for heatmaps (default: standard gradient)
- `aggregatorName::Symbol`: Aggregation function like `:Sum`, `:Average`, `:Count` (default: `:Average`)
- `extrapolate_colours::Bool`: Whether to extrapolate color scale (default: `false`)
- `rendererName::Symbol`: Renderer type like `:Table`, `:Heatmap`, `:Bar Chart` (default: `:Heatmap`)
- `rendererOptions`: Custom renderer options (default: `missing`)
- `show_totals::Bool`: Whether to show sum/total rows and columns by default (default: `true`)
- `notes::String`: Descriptive text shown below the chart (default: `""`)

# Examples
```julia
# Single dataset
pt = PivotTable(:pivot_chart, :data,
    rows=[:region],
    cols=[:year],
    vals=:sales,
    aggregatorName=:Sum,
    rendererName=:Heatmap
)

# Multiple datasets with selector
pt = PivotTable(:pivot_chart, [:fills_data, :metadata, :volume_data],
    rows=[:region],
    cols=[:year],
    vals=:sales,
    aggregatorName=:Sum,
    rendererName=:Heatmap
)
```
"""
struct PivotTable <: JSPlotsType
    chart_title::Symbol
    data_labels::Vector{Symbol}
    functional_html::String
    appearance_html::String

    # Constructor for single Symbol data_label (backwards compatible)
    function PivotTable(chart_title::Symbol, data_label::Symbol;
                            rows::Union{Missing,Vector{Symbol}} = missing, cols::Union{Missing,Vector{Symbol}} = missing, vals::Union{Missing,Symbol} = missing,
                            inclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}= missing,
                            exclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}=missing,
                            colour_map::Union{Missing,Dict{Float64,String}}= Dict{Float64,String}([-2.5, -1.0, 0.0, 1.0, 2.5] .=> ["#FF9999", "#FFFF99", "#FFFFFF", "#99FF99", "#99CCFF"]),
                            aggregatorName::Symbol=:Average,
                            extrapolate_colours::Bool=false,
                            rendererName::Symbol=:Heatmap,
                            rendererOptions::Union{Missing,Dict{Symbol,Any}}=missing,
                            show_totals::Bool=false,
                            notes::String="")
        # Delegate to the Vector{Symbol} constructor
        return PivotTable(chart_title, [data_label];
                          rows=rows, cols=cols, vals=vals,
                          inclusions=inclusions, exclusions=exclusions,
                          colour_map=colour_map, aggregatorName=aggregatorName,
                          extrapolate_colours=extrapolate_colours, rendererName=rendererName,
                          rendererOptions=rendererOptions, show_totals=show_totals, notes=notes)
    end

    # Main constructor for Vector{Symbol} data_labels
    function PivotTable(chart_title::Symbol, data_labels::Vector{Symbol};
                            rows::Union{Missing,Vector{Symbol}} = missing, cols::Union{Missing,Vector{Symbol}} = missing, vals::Union{Missing,Symbol} = missing,
                            inclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}= missing,
                            exclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}=missing,
                            colour_map::Union{Missing,Dict{Float64,String}}= Dict{Float64,String}([-2.5, -1.0, 0.0, 1.0, 2.5] .=> ["#FF9999", "#FFFF99", "#FFFFFF", "#99FF99", "#99CCFF"]),
                            aggregatorName::Symbol=:Average,
                            extrapolate_colours::Bool=false,
                            rendererName::Symbol=:Heatmap,
                            rendererOptions::Union{Missing,Dict{Symbol,Any}}=missing,
                            show_totals::Bool=false,
                            notes::String="")

        if isempty(data_labels)
            error("data_labels cannot be empty")
        end

        #
        kwargs_d = Dict{Symbol,Any}()
        if ismissing(rows) == false kwargs_d[:rows] = rows end
        if ismissing(cols) == false kwargs_d[:cols] = cols end
        if ismissing(vals) == false kwargs_d[:vals] = [vals] end
        if ismissing(inclusions) == false kwargs_d[:inclusions] = inclusions end
        if ismissing(exclusions) == false kwargs_d[:exclusions] = exclusions end
        if ismissing(aggregatorName) == false kwargs_d[:aggregatorName] = aggregatorName end
        if ismissing(rendererName) == false kwargs_d[:rendererName] = rendererName end
        if ismissing(rendererOptions) == false
            kwargs_d[:rendererOptions] = rendererOptions
        end
        if ismissing(rendererOptions) && (ismissing(colour_map) == false)
            kwargs_d[:rendererOptions] = "___rendererOptions___"
        end
        kwargs_json = JSON.json(kwargs_d)

        # Use first data label as default
        default_data_label = first(data_labels)
        chart_title_safe = replace(string(chart_title), " " => "_")

        #
        strr = replace(pivottable_function_template, "__NAME_OF_PLOT___" => chart_title_safe)
        strr = replace(strr, "__NAME_OF_DATA___" => replace(string(default_data_label), " " => "_"))
        strr = replace(strr, "___KEYARGS_LOCATION___" => kwargs_json)
        if ismissing(colour_map) == false
            colour_values = sort(collect(keys(colour_map)))
            colours = [colour_map[x] for x in colour_values]
            if extrapolate_colours
                strr = replace(strr, "\"___rendererOptions___\"" => "{ heatmap: { colorScaleGenerator: function(values) { return d3.scale.linear().domain(" * string(colour_values) * ").range(" * string(colours) * ")}}}")
            else
                strr = replace(strr, "\"___rendererOptions___\"" => "{ heatmap: { colorScaleGenerator: function(values) { return d3.scale.linear().domain(" * string(colour_values) * ").range(" * string(colours) * ").clamp(true)}}}")
            end
        end
        #
        appearance_html = table_to_html(chart_title, notes, show_totals, data_labels)
        new(chart_title, data_labels, strr, appearance_html)
    end
end

# For backward compatibility, expose data_label property (returns first label)
function Base.getproperty(pt::PivotTable, name::Symbol)
    if name === :data_label
        return first(getfield(pt, :data_labels))
    else
        return getfield(pt, name)
    end
end

dependencies(a::PivotTable) = collect(a.data_labels)
js_dependencies(::PivotTable) = vcat(JS_DEP_JQUERY, JS_DEP_D3, JS_DEP_C3, JS_DEP_PIVOTTABLE)
