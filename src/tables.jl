
const pivottable_function_template = raw"""
    $("#__NAME_OF_PLOT___").pivotUI(
                        $.csv.toArrays($("#__NAME_OF_DATA___").text()),
                        $.extend({
                            renderers: $.extend(
                                $.pivotUtilities.renderers,
                                $.pivotUtilities.c3_renderers,
                                $.pivotUtilities.d3_renderers,
                                $.pivotUtilities.export_renderers
                                ),
                            hiddenAttributes: [""]
                        }, ___KEYARGS_LOCATION___)
                    );
"""

const PIVOTTABLE_IN_PAGE_TEMPLATE = raw"""
    <h2>___TABLE_HEADING___</h2>
    <div id="__FUNCTION_NAME___"></div>

    <br><hr><br>
"""

function table_to_html(chart_title)
    html_str = replace(PIVOTTABLE_IN_PAGE_TEMPLATE, "___TABLE_HEADING___" => string(chart_title))
    html_str = replace(html_str, "__FUNCTION_NAME___" => replace(string(chart_title), " " => "_"))
    return html_str
end



struct PivotTable <: PivotTablesType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function PivotTable(chart_title::Symbol, data_label::Symbol;
                            rows::Union{Missing,Vector{Symbol}} = missing, cols::Union{Missing,Vector{Symbol}} = missing, vals::Union{Missing,Symbol} = missing,
                            inclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}= missing,
                            exclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}=missing,
                            colour_map::Union{Missing,Dict{Float64,String}}= Dict{Float64,String}([-2.5, -1.0, 0.0, 1.0, 2.5] .=> ["#FF9999", "#FFFF99", "#FFFFFF", "#99FF99", "#99CCFF"]),
                            aggregatorName::Symbol=:Average,
                            extrapolate_colours::Bool=false,
                            rendererName::Symbol=:Heatmap,
                            rendererOptions::Union{Missing,Dict{Symbol,Any}}=missing)
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
        #
        strr = replace(pivottable_function_template, "__NAME_OF_PLOT___" => replace(string(chart_title), " " => "_"), "__NAME_OF_DATA___" => replace(string(data_label), " " => "_"))
        strr = replace(strr, "___KEYARGS_LOCATION___" => kwargs_json)
        if ismissing(colour_map) == false
            colour_values = sort(collect(keys(colour_map)))
            colours = [colour_map[x] for x in colour_values]
            if extrapolate_colours
                strr = replace(strr, "\"___rendererOptions___\"" => "{ heatmap: { colorScaleGenerator: function(values) { return Plotly.d3.scale.linear().domain(" * string(colour_values) * ").range(" * string(colours) * ")}}}")
            else
                strr = replace(strr, "\"___rendererOptions___\"" => "{ heatmap: { colorScaleGenerator: function(values) { return Plotly.d3.scale.linear().domain(" * string(colour_values) * ").range(" * string(colours) * ").clamp(true)}}}")
            end
        end
        #
        appearance_html = table_to_html(chart_title)
        new(chart_title, data_label, strr, appearance_html)
    end
end

