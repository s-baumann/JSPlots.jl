
struct PivotTablePage
    dataframes::Dict{Symbol,DataFrame}
    pivot_tables::Vector
    title_of_page::String
    function PivotTablePage(dataframes::Dict{Symbol,DataFrame}, pivot_tables::Vector; title_of_page::String="PivotTables.jl")
        new(dataframes, pivot_tables, title_of_page)
    end
end

const DATASET_TEMPLATE = raw"""<div id="___DDATA_LABEL___" style="display: none;">___DATA1___</div>"""



const FULL_PAGE_TEMPLATE = raw"""
<!DOCTYPE html>
<html>
<head>
    <title>__TITLE_OF_PAGE___</title>
    <meta charset="UTF-8">
    <script src="https://cdn.plot.ly/plotly-3.0.1.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/PapaParse/5.3.0/papaparse.min.js"></script>
    <link rel="stylesheet" href="https://code.jquery.com/ui/1.13.2/themes/base/jquery-ui.css">
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>
    <style>
        body { 
            margin: 0; 
            padding: 20px; 
            font-family: Arial, sans-serif; 
        }
        #controls {
            display: flex;
            flex-wrap: wrap;
            margin-bottom: 20px;
            padding: 10px;
            background-color: #f0f0f0;
            border-radius: 5px;
        }
        #$div_id { 
            width: 100%; 
            height: 600px; 
        }
    </style>

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

<!-- ACTUAL CONTENT -->

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



function create_html(pt::PivotTablePage, outfile_path::String="pivottable.html")
    data_set_bit   = reduce(*, [dataset_to_html(k, v) for (k,v) in pt.dataframes])
    functional_bit = reduce(*, [pti.functional_html for pti in pt.pivot_tables])
    table_bit      = reduce(*, [pti.appearance_html for pti in pt.pivot_tables])
    full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
    full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
    full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
    full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.title_of_page)

    open(outfile_path, "w") do outfile
        write(outfile, full_page_html)
    end

    println("Pivot table page saved to $outfile_path")
end

function create_html(pt::PivotTablesType, dd::DataFrame, outfile_path::String="pivottable.html")
    pge = PivotTablePage(Dict{Symbol,DataFrame}(pt.data_label => dd), [pt])
    create_html(pge,outfile_path)
end
