# using PivotTable
using CSV, DataFrames, JSON


# dd = CSV.read("/home/stuart/Downloads/aggregated_markouts_summary.csv", DataFrame)



# create_pivot_html(dd, outfile_path="pivottable.html";
#                   rows = [:covar_method], cols = [:clustering_method],
#                   vals = [:relative_std_median],
#                   inclusions = inclusions,exclusions = exclusions)





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





struct PivotTable
    chart_title::Symbol
    data_label::Symbol
    pivottable_html::String
    function PivotTable(chart_title::Symbol, data_label::Symbol;
                            rows::Union{Missing,Vector{Symbol}} = missing, cols::Union{Missing,Vector{Symbol}} = missing, vals::Union{Missing,Symbol} = missing,
                            inclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}= missing,
                            exclusions::Union{Missing,Dict{Symbol,Vector{Symbol}}}=missing,
                            colour_map::Union{Missing,Dict{Float64,String}}= Dict{Float64,String}([-2.0, -1.0, 0.0, 1.0, 2.0] .=> ["#FF4545", "#FFE045" , "#ffffff", "#42f55a", "#4F92FF"]),
                            aggregatorName::Symbol=:Average,
                            rendererName::Symbol=:Heatmap,
                            rendererOptions::Union{Missing,Dict{Symbol,Any}}=missing)
        
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

        strr = replace(pivottable_function_template, "__NAME_OF_PLOT___" => replace(string(chart_title), " " => "_"), "__NAME_OF_DATA___" => replace(string(data_label), " " => "_"))
        strr = replace(strr, "___KEYARGS_LOCATION___" => kwargs_json)
        if ismissing(colour_map) == false
            colour_values = sort(collect(keys(colour_map)))
            colours = [colour_map[x] for x in colour_values]
            strr = replace(strr, "\"___rendererOptions___\"" => "{ heatmap: { colorScaleGenerator: function(values) { return Plotly.d3.scale.linear().domain(" * string(colour_values) * ").range(" * string(colours) * ")}}}")
        end

        new(chart_title, data_label, strr)
    end
end


dd = CSV.read("/home/stuart/temp/aggregated_markouts_summary.csv", DataFrame)

rows = [:covar_method]
cols = [:clustering_method]
vals = :relative_std_median

inclusions = Dict(
    :covar_method => [:pearson, :pearson_long, :spearman, :spearman_long]
)
exclusions = Dict(
    :clustering_method => [:spearman, :spearman_long]
)
ptp = PivotTable(:main_plot, :dd;  rows=rows, cols=cols, vals=vals, inclusions=inclusions, exclusions=exclusions, aggregatorName=:Average, rendererName=:Heatmap, rendererOptions=missing)



dd2 = deepcopy(dd)
dd2[!, :newcol] = dd2.relative_std_median .^ 2
dd2 = dd2[dd2.covar_method .!= :pearson, :]


ptp2 = PivotTable(Symbol("Poo and Jizz"), :dd2;  rows=cols, cols=rows, vals=:newcol, aggregatorName=:Average, rendererName=:Heatmap, rendererOptions=missing, colour_map = missing)


ptp3 = PivotTable(:third_plot, :dd;  rows=rows, cols=cols, vals=:delta_on_cfvol_std, inclusions=inclusions, aggregatorName=:Count, rendererName=:Table, rendererOptions=missing)



struct PivotTablePage
    dataframes::Dict{Symbol,DataFrame}
    pivot_tables::Vector{PivotTable}
end


pt = PivotTablePage(Dict{Symbol,DataFrame}(:dd => dd, :dd2 => dd2), [ptp, ptp2, ptp3])


const DATASET_TEMPLATE = raw"""<div id="___DDATA_LABEL___" style="display: none;">___DATA1___</div>"""

const PIVOTTABLE_IN_PAGE_TEMPLATE = raw"""
    <h2>___TABLE_HEADING___</h2>
    <div id="__FUNCTION_NAME___"></div>

    <br><hr><br>
"""

const FULL_PAGE_TEMPLATE = raw"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>PivotTable.js</title>

    <!-- external libs -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/c3/0.4.11/c3.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.5/d3.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/c3/0.4.11/c3.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.11.4/jquery-ui.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery-csv/0.71/jquery.csv-0.71.min.js"></script>

    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/pivot.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/pivot.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/d3_renderers.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/c3_renderers.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/export_renderers.min.js"></script>
</head>

<body>

<script src="https://cdn.plot.ly/plotly-latest.min.js"></script>

<script>
$(function(){

___FUNCTIONAL_BIT___

});
</script>

<!-- DATASETS -->

___DATASETS___

<!-- PIVOT TABLES -->

___PIVOT_TABLES___

</body>
</html>
"""

function dataset_to_html(data_label::Symbol, df::DataFrame)
    io_buffer = IOBuffer()
    CSV.write(io_buffer, df)
    csv_string = String(take!(io_buffer))
    html_str = replace(DATASET_TEMPLATE, "___DATA1___" => csv_string)
    html_str = replace(html_str, "___DDATA_LABEL___" => replace(string(data_label), " " => "_"))
    return html_str
end
function table_to_html(pt::PivotTable)
    html_str = replace(PIVOTTABLE_IN_PAGE_TEMPLATE, "___TABLE_HEADING___" => string(pt.chart_title))
    html_str = replace(html_str, "__FUNCTION_NAME___" => replace(string(pt.chart_title), " " => "_"))
    return html_str
end



function create_pivot_table_html(pt::PivotTablePage, outfile_path::String="pivottable.html")
    data_set_bit = reduce(*, [dataset_to_html(k, v) for (k,v) in pt.dataframes])
    table_bit = reduce(*, [table_to_html(pti) for pti in pt.pivot_tables])
    functional_bit = reduce(*, [pti.pivottable_html for pti in pt.pivot_tables])
    full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
    full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
    full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)

    open(outfile_path, "w") do outfile
        write(outfile, full_page_html)
    end

    println("Pivot table page saved to $outfile_path")
end




create_pivot_table_html(pt, "pivottable.html")





