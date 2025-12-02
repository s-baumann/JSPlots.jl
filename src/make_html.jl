
struct JSPlotPage
    dataframes::Dict{Symbol,DataFrame}
    pivot_tables::Vector
    tab_title::String
    page_header::String
    notes::String
    dataformat::Symbol
    function JSPlotPage(dataframes::Dict{Symbol,DataFrame}, pivot_tables::Vector; tab_title::String="JSPlots.jl", page_header::String="", notes::String="", dataformat::Symbol=:csv_embedded)
        if !(dataformat in [:csv_embedded, :json_embedded])
            error("dataformat must be either :csv_embedded or :json_embedded")
        end
        new(dataframes, pivot_tables, tab_title, page_header, notes, dataformat)
    end
end

const DATASET_TEMPLATE = raw"""<script type="text/plain" id="___DDATA_LABEL___" data-format="___DATA_FORMAT___">___DATA1___</script>"""



const FULL_PAGE_TEMPLATE = raw"""
<!DOCTYPE html>
<html>
<head>
    <title>___TITLE_OF_PAGE___</title>
    <meta charset="UTF-8">
    <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
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

<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>

<script>
// Centralized data loading function
// This function parses data from a hidden div and returns a Promise
// Supports both CSV and JSON formats based on the data-format attribute
// Usage: loadDataset('dataLabel').then(function(data) { /* use data */ });
function loadDataset(dataLabel) {
    return new Promise(function(resolve, reject) {
        var dataElement = document.getElementById(dataLabel);
        if (!dataElement) {
            reject(new Error('Data element not found: ' + dataLabel));
            return;
        }

        var format = dataElement.getAttribute('data-format') || 'csv_embedded';
        var dataText = dataElement.textContent.trim();

        if (format === 'json_embedded') {
            // Parse JSON data
            try {
                var data = JSON.parse(dataText);
                resolve(data);
            } catch (error) {
                console.error('JSON parsing error:', error);
                reject(error);
            }
        } else if (format === 'csv_embedded') {
            // Parse CSV data using PapaParse
            Papa.parse(dataText, {
                header: true,
                dynamicTyping: true,
                skipEmptyLines: true,
                complete: function(results) {
                    // Check for fatal errors only (not warnings)
                    // PapaParse includes non-fatal warnings in errors array
                    var fatalErrors = results.errors.filter(function(err) {
                        // Filter out delimiter detection warnings - these aren't fatal
                        // (common for single-column CSVs)
                        return err.type !== 'Delimiter';
                    });

                    if (fatalErrors.length > 0) {
                        console.error('CSV parsing errors:', fatalErrors);
                        reject(fatalErrors);
                    } else if (results.data && results.data.length > 0) {
                        resolve(results.data);
                    } else {
                        reject(new Error('No data parsed from CSV'));
                    }
                },
                error: function(error) {
                    console.error('CSV parsing error:', error);
                    reject(error);
                }
            });
        } else {
            reject(new Error('Unsupported data format: ' + format));
        }
    });
}

$(function(){

___FUNCTIONAL_BIT___

});
</script>

<!-- DATASETS -->

___DATASETS___

<!-- ACTUAL CONTENT -->

<h1>___PAGE_HEADER___</h1>
<p>___NOTES___</p>

___PIVOT_TABLES___

</body>
</html>
"""

function dataset_to_html(data_label::Symbol, df::DataFrame, format::Symbol=:csv_embedded)
    data_string = if format == :csv_embedded
        io_buffer = IOBuffer()
        CSV.write(io_buffer, df)
        String(take!(io_buffer))
    elseif format == :json_embedded
        # Convert DataFrame to array of dictionaries for JSON
        rows = []
        for row in eachrow(df)
            row_dict = Dict(String(col) => row[col] for col in names(df))
            push!(rows, row_dict)
        end
        # Pretty print JSON with indentation for readability
        JSON.json(rows, 2)
    else
        error("Unsupported format: $format")
    end

    # Escape only </script> to prevent premature script tag closing
    # Using <\/script> is safe in script tags and won't interfere with CSV/JSON parsing
    data_string_safe = replace(data_string, "</script>" => "<\\/script>")

    html_str = replace(DATASET_TEMPLATE, "___DATA1___" => "\n" * data_string_safe * "\n")
    html_str = replace(html_str, "___DDATA_LABEL___" => replace(string(data_label), " " => "_"))
    html_str = replace(html_str, "___DATA_FORMAT___" => string(format))
    return html_str
end



function create_html(pt::JSPlotPage, outfile_path::String="pivottable.html")
    data_set_bit   = reduce(*, [dataset_to_html(k, v, pt.dataformat) for (k,v) in pt.dataframes])
    functional_bit = reduce(*, [pti.functional_html for pti in pt.pivot_tables])
    table_bit      = reduce(*, [pti.appearance_html for pti in pt.pivot_tables])
    full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
    full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
    full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
    full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
    full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
    full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)

    open(outfile_path, "w") do outfile
        write(outfile, full_page_html)
    end

    println("Pivot table page saved to $outfile_path")
end

function create_html(pt::JSPlotsType, dd::DataFrame, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(pt.data_label => dd), [pt])
    create_html(pge,outfile_path)
end
