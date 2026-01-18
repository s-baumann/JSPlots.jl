
const TABLE_TEMPLATE = raw"""
    <div class="jsplots-table-container">
        <h2>___TABLE_TITLE___</h2>
        <p>___NOTES___</p>
        <div class="table-wrapper">
            ___TABLE_CONTENT___
        </div>
        <div class="table-actions">
            <button onclick="downloadTableCSV____TABLE_ID___()" class="download-csv-button">
                📥 Download as CSV
            </button>
        </div>
    </div>
"""

const TABLE_STYLE = raw"""
    <style>
        .jsplots-table-container {
            padding: 20px;
            margin: 10px 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }

        .jsplots-table-container h2 {
            font-size: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
            color: #333;
        }

        .jsplots-table-container p {
            color: #666;
            margin-bottom: 1em;
        }

        .table-wrapper {
            overflow-x: auto;
            margin-bottom: 1em;
            border: 1px solid #ddd;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }

        .jsplots-table-container table {
            width: 100%;
            border-collapse: collapse;
            background-color: white;
        }

        .jsplots-table-container th {
            background-color: #f8f9fa;
            color: #333;
            font-weight: 600;
            text-align: left;
            padding: 12px 15px;
            border-bottom: 2px solid #dee2e6;
            position: sticky;
            top: 0;
            z-index: 10;
        }

        .jsplots-table-container td {
            padding: 10px 15px;
            border-bottom: 1px solid #dee2e6;
            color: #495057;
        }

        .jsplots-table-container tr:hover {
            background-color: #f8f9fa;
        }

        .jsplots-table-container tr:last-child td {
            border-bottom: none;
        }

        .table-actions {
            text-align: center;
            padding: 10px 0;
        }

        .download-csv-button {
            background-color: #0066cc;
            color: white;
            border: none;
            padding: 10px 20px;
            font-size: 14px;
            font-weight: 500;
            border-radius: 5px;
            cursor: pointer;
            transition: background-color 0.2s;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .download-csv-button:hover {
            background-color: #0052a3;
        }

        .download-csv-button:active {
            background-color: #003d7a;
            transform: translateY(1px);
        }
    </style>
"""

"""
    Table(chart_title::Symbol, df::DataFrame; notes::String="")

Create a Table display from a DataFrame with a download CSV button.

The table is self-contained and does not require the DataFrame to be added
to the JSPlotPage dataframes dictionary. The data is embedded directly in
the HTML table, and users can download it as CSV using the button.

# Arguments
- `chart_title::Symbol`: Unique identifier for this table
- `df::DataFrame`: The DataFrame to display
- `notes::String`: Optional descriptive text shown above the table

# Example
```julia
using DataFrames
df = DataFrame(name=["Alice", "Bob"], age=[25, 30], city=["NYC", "LA"])
table = Table(:people, df; notes="Employee information")
```
"""
struct Table <: JSPlotsType
    chart_title::Symbol
    df::DataFrame
    notes::String
    appearance_html::String
    functional_html::String

    function Table(chart_title::Symbol, df::DataFrame; notes::String="")
        table_id = replace(string(chart_title), " " => "_")

        # Generate HTML table
        table_html = dataframe_to_html_table(df)

        # Build appearance HTML
        appearance = replace(TABLE_TEMPLATE, "___TABLE_TITLE___" => string(chart_title))
        appearance = replace(appearance, "___NOTES___" => notes)
        appearance = replace(appearance, "___TABLE_CONTENT___" => table_html)
        appearance = replace(appearance, "___TABLE_ID___" => table_id)

        # Generate JavaScript for CSV download
        csv_data = dataframe_to_csv_string(df)
        # Escape for JavaScript string
        csv_data_escaped = replace(csv_data, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r")

        functional = """
            window.downloadTableCSV_$(table_id) = function() {
                const csvContent = "$(csv_data_escaped)";
                const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
                const link = document.createElement('a');
                const url = URL.createObjectURL(blob);
                link.setAttribute('href', url);
                link.setAttribute('download', '$(table_id).csv');
                link.style.visibility = 'hidden';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
                URL.revokeObjectURL(url);
            };
        """

        new(chart_title, df, notes, appearance, functional)
    end
end

"""
    dataframe_to_html_table(df::DataFrame)

Convert a DataFrame to an HTML table string.
"""
function dataframe_to_html_table(df::DataFrame)
    io = IOBuffer()

    write(io, "<table>\n")

    # Header row
    write(io, "  <thead>\n    <tr>")
    for col in names(df)
        write(io, "<th>$(html_escape(col))</th>")
    end
    write(io, "</tr>\n  </thead>\n")

    # Data rows
    write(io, "  <tbody>\n")
    for row in eachrow(df)
        write(io, "    <tr>")
        for col in names(df)
            val = row[col]
            val_str = ismissing(val) ? "" : string(val)
            write(io, "<td>$(html_escape(val_str))</td>")
        end
        write(io, "</tr>\n")
    end
    write(io, "  </tbody>\n")

    write(io, "</table>")

    return String(take!(io))
end

"""
    dataframe_to_csv_string(df::DataFrame)

Convert a DataFrame to a CSV string for download.
"""
function dataframe_to_csv_string(df::DataFrame)
    io = IOBuffer()
    CSV.write(io, df)
    return String(take!(io))
end

"""
    html_escape(s::AbstractString)

Escape HTML special characters in a string.
"""
function html_escape(s::AbstractString)
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "'" => "&#39;")
    return s
end

dependencies(a::Table) = []
js_dependencies(::Table) = vcat(JS_DEP_JQUERY)

