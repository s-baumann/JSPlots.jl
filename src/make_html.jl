
struct JSPlotPage
    dataframes::Dict{Symbol,DataFrame}
    pivot_tables::Vector
    tab_title::String
    page_header::String
    notes::String
    dataformat::Symbol
    function JSPlotPage(dataframes::Dict{Symbol,DataFrame}, pivot_tables::Vector; tab_title::String="JSPlots.jl", page_header::String="", notes::String="", dataformat::Symbol=:csv_embedded)
        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end
        new(dataframes, pivot_tables, tab_title, page_header, notes, dataformat)
    end
end

const DATASET_TEMPLATE = raw"""<script type="text/plain" id="___DDATA_LABEL___" data-format="___DATA_FORMAT___" data-src="___DATA_SRC___">___DATA1___</script>"""


const SEGMENT_SEPARATOR = """
<br>
<hr>
<br>
"""


const FULL_PAGE_TEMPLATE = raw"""
<!DOCTYPE html>
<html>
<head>
    <title>___TITLE_OF_PAGE___</title>
    <meta charset="UTF-8">
    <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/PapaParse/5.3.0/papaparse.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/apache-arrow@14.0.1/Arrow.es2015.min.js"></script>
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
    ___EXTRA_STYLES___

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

<script type="module">
// Import parquet-wasm for Parquet file support
import * as parquet from 'https://unpkg.com/parquet-wasm@0.6.1/esm/parquet_wasm.js';

// Initialize parquet-wasm
await parquet.default();

// Make parquet available globally for loadDataset
window.parquetWasm = parquet;
window.parquetReady = true;
console.log('Parquet-wasm library loaded successfully');
</script>

<script>
// Helper function to wait for parquet-wasm to be loaded
function waitForParquet() {
    return new Promise(function(resolve) {
        if (window.parquetReady) {
            resolve();
            return;
        }
        var checkInterval = setInterval(function() {
            if (window.parquetReady) {
                clearInterval(checkInterval);
                resolve();
            }
        }, 50);
    });
}

// Centralized data loading function
// This function parses data from embedded or external sources and returns a Promise
// Supports CSV (embedded/external), JSON (embedded/external), and Parquet (external) formats
// Usage: loadDataset('dataLabel').then(function(data) { /* use data */ });
function loadDataset(dataLabel) {
    return new Promise(function(resolve, reject) {
        var dataElement = document.getElementById(dataLabel);
        if (!dataElement) {
            reject(new Error('Data element not found: ' + dataLabel));
            return;
        }

        var format = dataElement.getAttribute('data-format') || 'csv_embedded';
        var dataSrc = dataElement.getAttribute('data-src');

        // Handle external JSON files
        if (format === 'json_external' && dataSrc) {
            fetch(dataSrc)
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Failed to load ' + dataSrc + ': ' + response.statusText);
                    }
                    return response.json();
                })
                .then(function(data) {
                    resolve(data);
                })
                .catch(function(error) {
                    console.error('Error loading external JSON:', error);
                    reject(error);
                });
            return;
        }

        // Handle external Parquet files
        if (format === 'parquet' && dataSrc) {
            // Wait for parquet-wasm to be loaded first
            waitForParquet()
                .then(function() {
                    return fetch(dataSrc);
                })
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Failed to load ' + dataSrc + ': ' + response.statusText);
                    }
                    return response.arrayBuffer();
                })
                .then(function(arrayBuffer) {
                    // Use parquet-wasm to read the file
                    var uint8Array = new Uint8Array(arrayBuffer);

                    // readParquet returns an Arrow Table
                    var wasmTable = window.parquetWasm.readParquet(uint8Array);

                    // Convert to Arrow IPC stream
                    var ipcStream = wasmTable.intoIPCStream();

                    // Use Apache Arrow JS to read the IPC stream
                    var arrowTable = window.Arrow.tableFromIPC(ipcStream);

                    // Convert Arrow Table to array of JavaScript objects
                    var data = [];
                    for (var i = 0; i < arrowTable.numRows; i++) {
                        var row = {};
                        arrowTable.schema.fields.forEach(function(field) {
                            var column = arrowTable.getChild(field.name);
                            var value = column.get(i);

                            // Convert BigInt to Number (Arrow returns BigInt for Int64)
                            if (typeof value === 'bigint') {
                                value = Number(value);
                            }

                            row[field.name] = value;
                        });
                        data.push(row);
                    }

                    resolve(data);
                })
                .catch(function(error) {
                    console.error('Error loading external Parquet:', error);
                    reject(error);
                });
            return;
        }

        // Handle external CSV files
        if (format === 'csv_external' && dataSrc) {
            fetch(dataSrc)
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Failed to load ' + dataSrc + ': ' + response.statusText);
                    }
                    return response.text();
                })
                .then(function(csvText) {
                    Papa.parse(csvText, {
                        header: true,
                        dynamicTyping: true,
                        skipEmptyLines: true,
                        complete: function(results) {
                            // Check for fatal errors only (not warnings)
                            var fatalErrors = results.errors.filter(function(err) {
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
                })
                .catch(function(error) {
                    console.error('Error loading external CSV:', error);
                    reject(error);
                });
            return;
        }

        // Handle embedded data
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

<hr><p align="right"><small>This page was created using <a href="https://github.com/s-baumann/JSPlots.jl">JSPlots.jl</a>.</small></p>
</body>
</html>
"""

function dataset_to_html(data_label::Symbol, df::DataFrame, format::Symbol=:csv_embedded)
    data_string = ""
    data_src = ""

    if format == :csv_external
        # For external CSV, we just reference the file
        data_src = "data/$(string(data_label)).csv"
        # No data content needed for external format
    elseif format == :json_external
        # For external JSON, we just reference the file
        data_src = "data/$(string(data_label)).json"
        # No data content needed for external format
    elseif format == :parquet
        # For external Parquet, we just reference the file
        data_src = "data/$(string(data_label)).parquet"
        # No data content needed for external format
    elseif format == :csv_embedded
        io_buffer = IOBuffer()
        CSV.write(io_buffer, df)
        data_string = String(take!(io_buffer))
    elseif format == :json_embedded
        # Convert DataFrame to array of dictionaries for JSON
        rows = []
        for row in eachrow(df)
            row_dict = Dict(String(col) => row[col] for col in names(df))
            push!(rows, row_dict)
        end
        # Pretty print JSON with indentation for readability
        data_string = JSON.json(rows, 2)
    else
        error("Unsupported format: $format")
    end

    # Escape only </script> to prevent premature script tag closing
    # Using <\/script> is safe in script tags and won't interfere with CSV/JSON parsing
    if !isempty(data_string)
        data_string_safe = replace(data_string, "</script>" => "<\\/script>")
        html_str = replace(DATASET_TEMPLATE, "___DATA1___" => "\n" * data_string_safe * "\n")
    else
        html_str = replace(DATASET_TEMPLATE, "___DATA1___" => "")
    end

    html_str = replace(html_str, "___DDATA_LABEL___" => replace(string(data_label), " " => "_"))
    html_str = replace(html_str, "___DATA_FORMAT___" => string(format))
    html_str = replace(html_str, "___DATA_SRC___" => data_src)
    return html_str
end



function generate_bat_launcher(html_filename::String)
    """
    @echo off
    REM JSPlots Launcher Script for Windows
    REM Tries browsers in order: Brave, Chrome, Firefox, then system default

    set "HTML_FILE=%~dp0$(html_filename)"

    REM Try Brave Browser
    where brave.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Opening with Brave Browser...
        start brave.exe --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Chrome
    where chrome.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Opening with Google Chrome...
        start chrome.exe --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Chrome in Program Files
    if exist "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" (
        echo Opening with Google Chrome...
        start "" "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Chrome in Program Files (x86)
    if exist "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe" (
        echo Opening with Google Chrome...
        start "" "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe" --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Firefox
    where firefox.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Opening with Firefox...
        start firefox.exe "%HTML_FILE%"
        exit /b
    )

    REM Try Firefox in Program Files
    if exist "C:\\Program Files\\Mozilla Firefox\\firefox.exe" (
        echo Opening with Firefox...
        start "" "C:\\Program Files\\Mozilla Firefox\\firefox.exe" "%HTML_FILE%"
        exit /b
    )

    REM Fallback to default browser
    echo Opening with default browser...
    start "" "%HTML_FILE%"
    """
end

function generate_sh_launcher(html_filename::String)
    """
    #!/bin/bash
    # JSPlots Launcher Script for Linux/macOS
    # Tries browsers in order: Brave, Chrome, Firefox, then system default

    SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
    HTML_FILE="\$SCRIPT_DIR/$(html_filename)"

    # Create a temporary user data directory for Chromium-based browsers
    TEMP_USER_DIR="\$(mktemp -d)"

    # Try Brave Browser
    if command -v brave-browser &> /dev/null; then
        echo "Opening with Brave Browser..."
        brave-browser --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    elif command -v brave &> /dev/null; then
        echo "Opening with Brave Browser..."
        brave --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    fi

    # Try Google Chrome
    if command -v google-chrome &> /dev/null; then
        echo "Opening with Google Chrome..."
        google-chrome --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    elif command -v chrome &> /dev/null; then
        echo "Opening with Chrome..."
        chrome --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    fi

    # Try Chromium
    if command -v chromium-browser &> /dev/null; then
        echo "Opening with Chromium..."
        chromium-browser --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    elif command -v chromium &> /dev/null; then
        echo "Opening with Chromium..."
        chromium --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    fi

    # Try Firefox
    if command -v firefox &> /dev/null; then
        echo "Opening with Firefox..."
        firefox "\$HTML_FILE" &
        exit 0
    fi

    # Fallback to default browser
    echo "Opening with default browser..."
    if command -v xdg-open &> /dev/null; then
        xdg-open "\$HTML_FILE" &
    elif command -v open &> /dev/null; then
        # macOS
        open "\$HTML_FILE" &
    else
        echo "Could not find a suitable browser. Please open \$HTML_FILE manually."
        exit 1
    fi
    """
end

function generate_readme_content(html_filename::String)
    """
    # JSPlots Project Launcher Instructions

    This zip file was generated by JSPlots.jl and contains the necessary data files and HTML page to view your plots.

    ## Viewing the Plots

    To view the plots, it is suggested to use one of the launcher scripts to avoid permissions errros that can occur (if you open without heightened permissions the browser won't let the html load data stored on the local disk)
    
    If you cannot use the launcher scripts and cannot launch your browser with higher permissions then you can try to remake the plots with dataformat = :csv_embedded or :json_embedded in JSPlots.jl.
    This stores the data in plaintext in the html file so no special permissions are needed to view the plots. That does mean the files are huge though.

    ## Pull requests

    Pull requests are welcome if you find any improvements. Feel free to submit them on the [JSPlots.jl GitHub repository](https://github.com/s-baumann/JSPlots.jl).
    """
end


"""
    generate_data_source_attribution(data_label::Symbol, dataformat::Symbol)

Generate HTML for data source attribution text.
Returns a small text element showing the data source based on the dataformat.
"""
function generate_data_source_attribution(data_label::Symbol, dataformat::Symbol)
    data_text = if dataformat == :parquet
        "Data: $(string(data_label)).parquet"
    elseif dataformat == :csv_external
        "Data: $(string(data_label)).csv"
    elseif dataformat == :json_external
        "Data: $(string(data_label)).json"
    else  # embedded formats
        "Data: $(string(data_label))"
    end

    return """<p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">$data_text</p>"""
end

"""
    generate_picture_attribution(image_path::String)

Generate HTML for picture source attribution text.
Returns a small text element showing the picture filename.
"""
function generate_picture_attribution(image_path::String)
    filename = basename(image_path)
    return """<p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">$filename</p>"""
end

function create_html(pt::JSPlotPage, outfile_path::String="pivottable.html")
    # Collect extra styles needed for TextBlock, Picture, and Table
    extra_styles = ""
    has_textblock = any(p -> isa(p, TextBlock), pt.pivot_tables)
    has_picture = any(p -> isa(p, Picture), pt.pivot_tables)
    has_table = any(p -> isa(p, Table), pt.pivot_tables)

    if has_textblock
        extra_styles *= TEXTBLOCK_STYLE
    end
    if has_picture
        extra_styles *= PICTURE_STYLE
    end
    if has_table
        extra_styles *= TABLE_STYLE
    end

    # Handle external formats (csv_external, json_external, parquet) differently
    if pt.dataformat in [:csv_external, :json_external, :parquet]
        # For external formats, create a subfolder structure
        # e.g., "generated_html_examples/pivottable.html" becomes
        #       "generated_html_examples/pivottable/pivottable.html"

        original_dir = dirname(outfile_path)
        original_name = basename(outfile_path)
        name_without_ext = splitext(original_name)[1]

        # Create the project folder: original_dir/name_without_ext/
        project_dir = isempty(original_dir) ? name_without_ext : joinpath(original_dir, name_without_ext)
        if !isdir(project_dir)
            mkpath(project_dir)
        end

        # HTML file goes in the project folder with the same name
        actual_html_path = joinpath(project_dir, original_name)

        # Create data subdirectory within project folder
        data_dir = joinpath(project_dir, "data")
        if !isdir(data_dir)
            mkpath(data_dir)
        end

        # Save all dataframes as separate files based on format
        for (data_label, df) in pt.dataframes
            if pt.dataformat == :csv_external
                file_path = joinpath(data_dir, "$(string(data_label)).csv")
                CSV.write(file_path, df)
                println("  Data saved to $file_path")
            elseif pt.dataformat == :json_external
                file_path = joinpath(data_dir, "$(string(data_label)).json")
                # Convert DataFrame to array of dictionaries
                rows = []
                for row in eachrow(df)
                    row_dict = Dict(String(col) => row[col] for col in names(df))
                    push!(rows, row_dict)
                end
                open(file_path, "w") do f
                    write(f, JSON.json(rows, 2))
                end
                println("  Data saved to $file_path")
            elseif pt.dataformat == :parquet
                file_path = joinpath(data_dir, "$(string(data_label)).parquet")
                # Use DuckDB to write Parquet file
                con = DBInterface.connect(DuckDB.DB)

                # Convert Symbol columns to String (DuckDB doesn't support Symbol type)
                df_converted = copy(df)
                for col in names(df_converted)
                    col_type = eltype(df_converted[!, col])
                    # Check if the column type is Symbol or Union{Missing, Symbol} or similar
                    if col_type <: Symbol || (col_type isa Union && Symbol in Base.uniontypes(col_type))
                        df_converted[!, col] = string.(df_converted[!, col])
                    end
                end

                # Register the DataFrame with DuckDB
                DuckDB.register_data_frame(con, df_converted, "temp_table")
                # Write to Parquet file
                DBInterface.execute(con, "COPY temp_table TO '$file_path' (FORMAT PARQUET)")
                DBInterface.close!(con)
                println("  Data saved to $file_path")
            end
        end

        # Generate HTML content - handle Picture types specially
        data_set_bit   = isempty(pt.dataframes) ? "" : reduce(*, [dataset_to_html(k, v, pt.dataformat) for (k,v) in pt.dataframes])
        functional_bit = ""
        table_bit = ""

        for (i, pti) in enumerate(pt.pivot_tables)
            sp = i == 1 ? "" : SEGMENT_SEPARATOR
            if isa(pti, Picture)
                # Generate Picture HTML based on dataformat
                table_bit *= sp * generate_picture_html(pti, pt.dataformat, project_dir)
                # Add picture attribution
                table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
                # Picture has no functional HTML
            elseif isa(pti, TextBlock)
                # Generate TextBlock HTML, handling images if present
                if !isempty(pti.images)
                    table_bit *= sp * generate_textblock_html(pti, pt.dataformat, project_dir)
                else
                    # No images, use original appearance_html for backward compatibility
                    table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
                end
                # TextBlock has no functional HTML
            elseif isa(pti, Table)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add table attribution (Table is self-contained, use chart_title)
                table_bit *= """<br><p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">Data: $(string(pti.chart_title))</p>"""
            elseif hasfield(typeof(pti), :data_label)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add data source attribution for charts with data_label
                table_bit *= "<br>" * generate_data_source_attribution(pti.data_label, pt.dataformat)
            else
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
            end
        end

        full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
        full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
        full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
        full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
        full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
        full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)
        full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)

        # Save HTML file
        open(actual_html_path, "w") do outfile
            write(outfile, full_page_html)
        end
        println("HTML page saved to $actual_html_path")

        # Generate launcher scripts in the project folder
        bat_path = joinpath(project_dir, "open.bat")
        sh_path = joinpath(project_dir, "open.sh")
        readme_path = joinpath(project_dir, "README.md")

        open(bat_path, "w") do f
            write(f, generate_bat_launcher(original_name))
        end
        println("Windows launcher saved to $bat_path")

        open(sh_path, "w") do f
            write(f, generate_sh_launcher(original_name))
        end
        open(readme_path, "w") do f
            write(f, generate_readme_content(original_name))
        end
        # Make shell script executable on Unix-like systems
        try
            chmod(sh_path, 0o755)
        catch
            # Silently fail on Windows
        end
        println("Linux/macOS launcher saved to $sh_path")

        println("\nProject created in: $project_dir")
        println("To view the plots:")
        println("  Windows: Run $bat_path")
        println("  Linux/macOS: Run $sh_path")
        println("\nIMPORTANT: Do not open the HTML file directly!")
        println("Use the launcher scripts to avoid CORS errors.")

    else
        # Original embedded format logic
        data_set_bit   = isempty(pt.dataframes) ? "" : reduce(*, [dataset_to_html(k, v, pt.dataformat) for (k,v) in pt.dataframes])
        functional_bit = ""
        table_bit = ""



        for (i, pti) in enumerate(pt.pivot_tables)
            sp = i == 1 ? "" : SEGMENT_SEPARATOR
            if isa(pti, Picture)
                # Generate Picture HTML based on dataformat (embedded)
                table_bit *= sp * generate_picture_html(pti, pt.dataformat, "")
                # Add picture attribution
                table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
                # Picture has no functional HTML
            elseif isa(pti, TextBlock)
                # Generate TextBlock HTML, handling images if present
                if !isempty(pti.images)
                    table_bit *= sp * generate_textblock_html(pti, pt.dataformat, "")
                else
                    # No images, use original template for backward compatibility
                    table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
                end
                # TextBlock has no functional HTML
            elseif isa(pti, Table)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add table attribution (Table is self-contained, use chart_title)
                table_bit *= """<br><p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">Data: $(string(pti.chart_title))</p>"""
            elseif hasfield(typeof(pti), :data_label)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add data source attribution for charts with data_label
                table_bit *= "<br>" * generate_data_source_attribution(pti.data_label, pt.dataformat)
            else
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
            end
        end

        full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
        full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
        full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
        full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
        full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
        full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)
        full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)

        open(outfile_path, "w") do outfile
            write(outfile, full_page_html)
        end

        println("Pivot table page saved to $outfile_path")
    end

    # Clean up temporary files for Picture objects
    for pti in pt.pivot_tables
        if isa(pti, Picture) && pti.is_temp
            try
                rm(pti.image_path, force=true)
            catch e
                @warn "Could not delete temporary file $(pti.image_path): $e"
            end
        end
    end
end

function create_html(pt::JSPlotsType, dd::DataFrame, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(pt.data_label => dd), [pt])
    create_html(pge,outfile_path)
end

# Convenience method for Table (no DataFrame needed - it's embedded in the Table)
function create_html(pt::Table, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(), [pt])
    create_html(pge,outfile_path)
end

# Convenience method for Picture (no DataFrame needed)
function create_html(pt::Picture, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(), [pt])
    create_html(pge,outfile_path)
end
