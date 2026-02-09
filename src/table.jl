
const TABLE_TEMPLATE = raw"""
    <div class="jsplots-table-container">
        <h2>___TABLE_TITLE___</h2>
        <p>___NOTES___</p>
        <div class="table-wrapper">
            ___TABLE_CONTENT___
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
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
        }

        .jsplots-table-container th:hover {
            background-color: #e9ecef;
        }

        .jsplots-table-container th .sort-indicator {
            margin-left: 8px;
            font-size: 0.8em;
            color: #6c757d;
            display: inline-block;
            width: 12px;
        }

        .jsplots-table-container th.sort-asc .sort-indicator::after {
            content: "▲";
            color: #0066cc;
        }

        .jsplots-table-container th.sort-desc .sort-indicator::after {
            content: "▼";
            color: #0066cc;
        }

        .jsplots-table-container th:not(.sort-asc):not(.sort-desc) .sort-indicator::after {
            content: "⇅";
            opacity: 0.4;
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
    </style>
"""

"""
    Table(chart_title::Symbol, df::DataFrame; notes::String="")

Create a Table display from a DataFrame with sortable columns.

The table is self-contained and does not require the DataFrame to be added
to the JSPlotPage dataframes dictionary. The data is embedded directly in
the HTML table. Click column headers to sort.

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
        table_html = dataframe_to_html_table(df, table_id)

        # Build appearance HTML
        appearance = replace(TABLE_TEMPLATE, "___TABLE_TITLE___" => string(chart_title))
        appearance = replace(appearance, "___NOTES___" => notes)
        appearance = replace(appearance, "___TABLE_CONTENT___" => table_html)

        # Generate JavaScript for sorting
        functional = """
            // Table sorting functionality
            (function() {
                const table = document.getElementById('table_$(table_id)');
                if (!table) return;

                const headers = table.querySelectorAll('th');
                let currentSortCol = -1;
                let currentSortDir = 'none';

                headers.forEach(function(header, colIndex) {
                    header.addEventListener('click', function() {
                        sortTable(colIndex);
                    });
                });

                function sortTable(colIndex) {
                    const tbody = table.querySelector('tbody');
                    const rows = Array.from(tbody.querySelectorAll('tr'));

                    // Determine sort direction
                    let sortDir;
                    if (currentSortCol === colIndex) {
                        // Cycle: none -> asc -> desc -> none
                        if (currentSortDir === 'none' || currentSortDir === 'desc') {
                            sortDir = 'asc';
                        } else {
                            sortDir = 'desc';
                        }
                    } else {
                        sortDir = 'asc';
                    }

                    currentSortCol = colIndex;
                    currentSortDir = sortDir;

                    // Update header classes
                    headers.forEach(function(h, i) {
                        h.classList.remove('sort-asc', 'sort-desc');
                        if (i === colIndex) {
                            h.classList.add('sort-' + sortDir);
                        }
                    });

                    // Sort rows
                    rows.sort(function(a, b) {
                        const aVal = a.cells[colIndex].textContent.trim();
                        const bVal = b.cells[colIndex].textContent.trim();

                        // Try numeric comparison first
                        const aNum = parseFloat(aVal.replace(/,/g, ''));
                        const bNum = parseFloat(bVal.replace(/,/g, ''));

                        let comparison;
                        if (!isNaN(aNum) && !isNaN(bNum)) {
                            comparison = aNum - bNum;
                        } else {
                            // String comparison
                            comparison = aVal.localeCompare(bVal);
                        }

                        return sortDir === 'asc' ? comparison : -comparison;
                    });

                    // Re-append sorted rows
                    rows.forEach(function(row) {
                        tbody.appendChild(row);
                    });
                }
            })();
        """

        new(chart_title, df, notes, appearance, functional)
    end
end

"""
    dataframe_to_html_table(df::DataFrame, table_id::String)

Convert a DataFrame to an HTML table string with sortable headers.
"""
function dataframe_to_html_table(df::DataFrame, table_id::String)
    io = IOBuffer()

    write(io, "<table id=\"table_$(table_id)\">\n")

    # Header row with sort indicators
    write(io, "  <thead>\n    <tr>")
    for col in names(df)
        write(io, "<th>$(html_escape(col))<span class=\"sort-indicator\"></span></th>")
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

dependencies(a::Table) = Symbol[]
js_dependencies(::Table) = vcat(JS_DEP_JQUERY)

