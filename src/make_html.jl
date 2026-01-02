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

    <!-- Prism.js for code syntax highlighting -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    ___PRISM_LANGUAGES___

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
// Centralized date parsing function
// Converts ISO date strings to JavaScript Date objects
// This is the ONLY place in the package where date parsing happens
function parseDatesInData(data) {
    if (!data || data.length === 0) return data;

    // Regex patterns for ISO date formats
    var datePattern = /^\d{4}-\d{2}-\d{2}$/;  // YYYY-MM-DD
    var datetimePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;  // YYYY-MM-DDTHH:MM:SS
    var timePattern = /^\d{2}:\d{2}:\d{2}(\.\d+)?$/;  // HH:MM:SS or HH:MM:SS.sss

    // Check first row to identify date and time columns
    var firstRow = data[0];
    var dateColumns = [];
    var timeColumns = [];

    for (var key in firstRow) {
        if (firstRow.hasOwnProperty(key)) {
            var value = firstRow[key];
            if (typeof value === 'string') {
                if (datetimePattern.test(value) || datePattern.test(value)) {
                    dateColumns.push(key);
                } else if (timePattern.test(value)) {
                    timeColumns.push(key);
                }
            }
        }
    }

    // If no date or time columns found, return data unchanged
    if (dateColumns.length === 0 && timeColumns.length === 0) return data;

    // Convert date strings to Date objects and time strings to milliseconds in all rows
    return data.map(function(row) {
        var newRow = {};
        for (var key in row) {
            if (row.hasOwnProperty(key)) {
                if (dateColumns.indexOf(key) !== -1 && typeof row[key] === 'string') {
                    newRow[key] = new Date(row[key]);
                } else if (timeColumns.indexOf(key) !== -1 && typeof row[key] === 'string') {
                    // Convert HH:MM:SS or HH:MM:SS.sss to milliseconds since midnight
                    var parts = row[key].split(':');
                    var hours = parseInt(parts[0], 10);
                    var minutes = parseInt(parts[1], 10);
                    var seconds = parseFloat(parts[2]);  // Use parseFloat to handle decimal seconds
                    newRow[key] = (hours * 3600 + minutes * 60 + seconds) * 1000;
                } else {
                    newRow[key] = row[key];
                }
            }
        }
        return newRow;
    });
}

// Helper function to convert temporal values back to string format for categorical filtering
// Takes a value and returns the appropriate string representation
function temporalValueToString(value) {
    if (value instanceof Date) {
        // Convert Date to ISO string
        var year = value.getFullYear();
        var month = String(value.getMonth() + 1).padStart(2, '0');
        var day = String(value.getDate()).padStart(2, '0');
        var hours = String(value.getHours()).padStart(2, '0');
        var minutes = String(value.getMinutes()).padStart(2, '0');
        var seconds = String(value.getSeconds()).padStart(2, '0');

        // Check if this is a date-only value (time is midnight UTC)
        if (hours === '00' && minutes === '00' && seconds === '00') {
            return year + '-' + month + '-' + day;
        } else {
            return year + '-' + month + '-' + day + 'T' + hours + ':' + minutes + ':' + seconds;
        }
    } else if (typeof value === 'number' && value >= 0 && value < 86400000) {
        // Likely a Time value (milliseconds since midnight, less than 24 hours)
        var totalSeconds = Math.floor(value / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        var milliseconds = value % 1000;

        var timeStr = String(hours).padStart(2, '0') + ':' +
                      String(minutes).padStart(2, '0') + ':' +
                      String(seconds).padStart(2, '0');

        // Add decimal part if there are milliseconds
        if (milliseconds > 0) {
            timeStr += '.' + String(milliseconds);
        }

        return timeStr;
    } else {
        // Return as-is for other types
        return String(value);
    }
}

// Centralized observation counting and filtering function
// Applies filters incrementally while updating observation count displays
// Returns filtered data
function applyFiltersWithCounting(allData, chartTitle, categoricalFilters, continuousFilters, filters, rangeFilters) {
    var totalObs = allData.length;

    // Update total observation count
    var totalObsElement = document.getElementById(chartTitle + '_total_obs');
    if (totalObsElement) {
        totalObsElement.textContent = totalObs + ' observations';
    }

    // Apply filters incrementally to track observation counts
    var currentData = allData;

    // Apply categorical filters and update counts
    categoricalFilters.forEach(function(col) {
        if (filters[col] && filters[col].length > 0) {
            currentData = currentData.filter(function(row) {
                var rowValueStr = temporalValueToString(row[col]);
                return filters[col].includes(rowValueStr);
            });
        }

        var countElement = document.getElementById(col + '_select_' + chartTitle + '_obs_count');
        if (countElement) {
            var pct = totalObs > 0 ? Math.round((currentData.length / totalObs) * 100) : 100;
            countElement.textContent = pct + '% (' + currentData.length + ') remaining';
        }
    });

    // Apply continuous filters and update counts
    continuousFilters.forEach(function(col) {
        if (rangeFilters[col]) {
            var range = rangeFilters[col];
            currentData = currentData.filter(function(row) {
                var rawValue = row[col];
                var value;
                if (rawValue instanceof Date) {
                    value = rawValue.getTime();
                } else {
                    value = parseFloat(rawValue);
                }
                return value >= range.min && value <= range.max;
            });
        }

        var countElement = document.getElementById(col + '_range_' + chartTitle + '_obs_count');
        if (countElement) {
            var pct = totalObs > 0 ? Math.round((currentData.length / totalObs) * 100) : 100;
            countElement.textContent = pct + '% (' + currentData.length + ') remaining';
        }
    });

    return currentData;
}

// Axis transformation functions
// These transform data values according to selected transformation type
function applyAxisTransform(values, transformType) {
    if (!values || values.length === 0) return [];

    switch(transformType) {
        case 'identity':
            return values;

        case 'log':
            return values.map(function(v) {
                return v > 0 ? Math.log(v) : NaN;
            });

        case 'z_score':
            // Z-score standardization: (x - mean) / std
            var numericVals = values.filter(function(v) { return !isNaN(v) && isFinite(v); });
            if (numericVals.length === 0) return values;

            var mean = numericVals.reduce(function(a, b) { return a + b; }, 0) / numericVals.length;
            var variance = numericVals.reduce(function(sum, v) {
                return sum + Math.pow(v - mean, 2);
            }, 0) / numericVals.length;
            var std = Math.sqrt(variance);

            if (std === 0) return values;

            return values.map(function(v) {
                if (isNaN(v) || !isFinite(v)) return NaN;
                return (v - mean) / std;
            });

        default:
            return values;
    }
}

// Normal CDF (cumulative distribution function) for standard normal
function normalCDF(x) {
    // Using error function approximation
    var t = 1 / (1 + 0.2316419 * Math.abs(x));
    var d = 0.3989423 * Math.exp(-x * x / 2);
    var prob = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    return x > 0 ? 1 - prob : prob;
}

// Inverse normal CDF (quantile function) for standard normal
function inverseNormalCDF(p) {
    // Rational approximation for inverse normal CDF
    // Valid for 0 < p < 1
    if (p <= 0 || p >= 1) {
        return NaN;
    }

    var a = [0, -3.969683028665376e+01, 2.209460984245205e+02,
             -2.759285104469687e+02, 1.383577518672690e+02,
             -3.066479806614716e+01, 2.506628277459239e+00];
    var b = [0, -5.447609879822406e+01, 1.615858368580409e+02,
             -1.556989798598866e+02, 6.680131188771972e+01,
             -1.328068155288572e+01];
    var c = [0, -7.784894002430293e-03, -3.223964580411365e-01,
             -2.400758277161838e+00, -2.549732539343734e+00,
             4.374664141464968e+00, 2.938163982698783e+00];
    var d = [0, 7.784695709041462e-03, 3.224671290700398e-01,
             2.445134137142996e+00, 3.754408661907416e+00];

    var q, r, result;

    if (p < 0.02425) {
        q = Math.sqrt(-2 * Math.log(p));
        result = (((((c[1] * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) * q + c[6]) /
                 ((((d[1] * q + d[2]) * q + d[3]) * q + d[4]) * q + 1);
    } else if (p > 0.97575) {
        q = Math.sqrt(-2 * Math.log(1 - p));
        result = -(((((c[1] * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) * q + c[6]) /
                  ((((d[1] * q + d[2]) * q + d[3]) * q + d[4]) * q + 1);
    } else {
        q = p - 0.5;
        r = q * q;
        result = (((((a[1] * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * r + a[6]) * q /
                 (((((b[1] * r + b[2]) * r + b[3]) * r + b[4]) * r + b[5]) * r + 1);
    }

    return result;
}

// Get axis label with transformation applied
function getAxisLabel(originalLabel, transformType) {
    switch(transformType) {
        case 'log':
            return 'log(' + originalLabel + ')';
        case 'z_score':
            return 'z(' + originalLabel + ')';
        default:
            return originalLabel;
    }
}

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
                    // Parse dates in JSON data (centralized)
                    resolve(parseDatesInData(data));
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
                                // Parse dates in CSV data (centralized)
                                resolve(parseDatesInData(results.data));
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
                // Parse dates in JSON data (centralized)
                resolve(parseDatesInData(data));
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
                        // Parse dates in CSV data (centralized)
                        resolve(parseDatesInData(results.data));
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

<hr><p align="right"><small>This page was created using <a href="https://github.com/s-baumann/JSPlots.jl">JSPlots.jl</a> v___VERSION___.</small></p>
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

"""
    create_html(obj, [df], outfile_path::String)

Creates an HTML file from a JSPlotPage, Pages, or a single plot.

# Arguments
- `obj`: A JSPlotPage, Pages object, or a single plot (PivotTable, LineChart, etc.)
- `df`: DataFrame (required for single plots that need data)
- `outfile_path::String`: Path where the HTML file will be saved (default: `"pivottable.html"`)

# Single Plot Usage
```julia
create_html(plot, dataframe, "output.html")
```

# JSPlotPage Usage
```julia
page = JSPlotPage(dataframes_dict, plots_array)
create_html(page, "output.html")
```

# Pages (Multi-page) Usage
```julia
report = Pages(coverpage, [page1, page2])
create_html(report, "index.html")
```
"""
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

    # Collect Prism.js language components needed for CodeBlocks
    prism_languages = JSPlots.get_languages_from_codeblocks(pt.pivot_tables)
    prism_scripts = if isempty(prism_languages)
        ""
    else
        join(["""    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-$lang.min.js"></script>"""
              for lang in prism_languages], "\n")
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

        # Get list of dataframes referenced by charts
        referenced_data = reduce(vcat, dependencies.(pt.pivot_tables); init=Symbol[])
        # If no charts reference any data, save all dataframes; otherwise only save referenced ones
        files_to_do = isempty(referenced_data) ? collect(keys(pt.dataframes)) : intersect(collect(keys(pt.dataframes)), referenced_data)
        # Save all dataframes as separate files based on format
        for data_label in files_to_do
            df = pt.dataframes[data_label]
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
                    # Check if the column type is ZonedDateTime or Union{Missing, ZonedDateTime} or similar
                    if col_type <: ZonedDateTime || (col_type isa Union && ZonedDateTime in Base.uniontypes(col_type))
                        df_converted[!, col] = [ismissing(x) ? missing : x.utc_datetime for x in df_converted[!, col] ]
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
                if !isempty(pti.functional_html)
                    functional_bit *= pti.functional_html
                end
                table_bit *= sp * generate_picture_html(pti, pt.dataformat, project_dir)
                # Add picture attribution only for single-image Pictures
                if pti.image_path !== nothing
                    table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
                end
            elseif isa(pti, TextBlock)
                # Generate TextBlock HTML, handling images if present
                if !isempty(pti.images)
                    table_bit *= sp * generate_textblock_html(pti, pt.dataformat, project_dir)
                else
                    # No images, use original appearance_html for backward compatibility
                    table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
                end
                # TextBlock has no functional HTML
            elseif isa(pti, Slides)
                # Generate Slides HTML based on dataformat
                functional_bit *= pti.functional_html
                table_bit *= sp * generate_slides_html(pti, pt.dataformat, project_dir)
                # Slides has no data attribution (uses :no_data label)
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

        # Get package version
        version_str = try
            string(pkgversion(JSPlots))
        catch
            "unknown"
        end

        full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
        full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
        full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
        full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
        full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
        full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)
        full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)
        full_page_html = replace(full_page_html, "___PRISM_LANGUAGES___" => prism_scripts)
        full_page_html = replace(full_page_html, "___VERSION___" => version_str)

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


    else
        # Original embedded format logic
        data_set_bit   = isempty(pt.dataframes) ? "" : reduce(*, [dataset_to_html(k, v, pt.dataformat) for (k,v) in pt.dataframes])
        functional_bit = ""
        table_bit = ""



        for (i, pti) in enumerate(pt.pivot_tables)
            sp = i == 1 ? "" : SEGMENT_SEPARATOR
            if isa(pti, Picture)
                # Generate Picture HTML based on dataformat (embedded)
                if !isempty(pti.functional_html)
                    functional_bit *= pti.functional_html
                end
                table_bit *= sp * generate_picture_html(pti, pt.dataformat, "")
                # Add picture attribution only for single-image Pictures
                if pti.image_path !== nothing
                    table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
                end
            elseif isa(pti, TextBlock)
                # Generate TextBlock HTML, handling images if present
                if !isempty(pti.images)
                    table_bit *= sp * generate_textblock_html(pti, pt.dataformat, "")
                else
                    # No images, use original template for backward compatibility
                    table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
                end
                # TextBlock has no functional HTML
            elseif isa(pti, Slides)
                # Generate Slides HTML based on dataformat (embedded)
                functional_bit *= pti.functional_html
                table_bit *= sp * generate_slides_html(pti, pt.dataformat, "")
                # Slides has no data attribution (uses :no_data label)
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

        # Get package version
        version_str = try
            string(pkgversion(JSPlots))
        catch
            "unknown"
        end

        full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
        full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
        full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
        full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
        full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
        full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)
        full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)
        full_page_html = replace(full_page_html, "___PRISM_LANGUAGES___" => prism_scripts)
        full_page_html = replace(full_page_html, "___VERSION___" => version_str)

        open(outfile_path, "w") do outfile
            write(outfile, full_page_html)
        end

        println("Saved to $outfile_path")
    end

    # Clean up temporary files for Picture and Slides objects
    for pti in pt.pivot_tables
        if isa(pti, Picture) && pti.is_temp
            try
                rm(pti.image_path, force=true)
            catch e
                @warn "Could not delete temporary file $(pti.image_path): $e"
            end
        elseif isa(pti, Slides) && pti.is_temp
            # Clean up temp directory with all generated slides
            for img_file in pti.image_files
                try
                    rm(img_file, force=true)
                catch e
                    @warn "Could not delete temporary slide file $(img_file): $e"
                end
            end
            # Try to remove the temp directory if empty
            try
                temp_dir = dirname(first(pti.image_files))
                if isdir(temp_dir)
                    rm(temp_dir, force=true, recursive=true)
                end
            catch e
                @warn "Could not delete temporary directory: $e"
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

"""
    generate_page_html(page::JSPlotPage, dataframes::Dict{Symbol,DataFrame}, dataformat::Symbol, project_dir::String="")

Helper function to generate HTML content for a single page without creating folders.
Returns the HTML string directly.
"""
function generate_page_html(page::JSPlotPage, dataframes::Dict{Symbol,DataFrame}, dataformat::Symbol, project_dir::String="")
    # Collect extra styles
    extra_styles = ""
    has_textblock = any(p -> isa(p, TextBlock), page.pivot_tables)
    has_picture = any(p -> isa(p, Picture), page.pivot_tables)
    has_table = any(p -> isa(p, Table), page.pivot_tables)

    if has_textblock
        extra_styles *= TEXTBLOCK_STYLE
    end
    if has_picture
        extra_styles *= PICTURE_STYLE
    end
    if has_table
        extra_styles *= TABLE_STYLE
    end

    # Collect Prism.js language components needed for CodeBlocks
    prism_languages = JSPlots.get_languages_from_codeblocks(page.pivot_tables)
    prism_scripts = if isempty(prism_languages)
        ""
    else
        join(["""    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-$lang.min.js"></script>"""
              for lang in prism_languages], "\n")
    end

    # Generate datasets HTML
    data_set_bit = isempty(dataframes) ? "" : reduce(*, [dataset_to_html(k, v, dataformat) for (k,v) in dataframes])

    # Generate functional and appearance HTML for plots
    functional_bit = ""
    table_bit = ""

    for (i, pti) in enumerate(page.pivot_tables)
        sp = i == 1 ? "" : SEGMENT_SEPARATOR

        if isa(pti, Picture)
            # Pictures are embedded as base64 for simplicity in multi-page context
            if !isempty(pti.functional_html)
                functional_bit *= pti.functional_html
            end
            table_bit *= sp * generate_picture_html(pti, :csv_embedded, "")
            if pti.image_path !== nothing
                table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
            end
        elseif isa(pti, TextBlock)
            if !isempty(pti.images)
                table_bit *= sp * generate_textblock_html(pti, :csv_embedded, "")
            else
                table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
            end
        elseif isa(pti, Slides)
            # Slides always use external images in slides/ directory
            functional_bit *= pti.functional_html
            table_bit *= sp * generate_slides_html(pti, dataformat, project_dir)
        elseif isa(pti, Table)
            functional_bit *= pti.functional_html
            table_bit *= sp * pti.appearance_html
            table_bit *= """<br><p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">Data: $(string(pti.chart_title))</p>"""
        elseif hasfield(typeof(pti), :data_label)
            functional_bit *= pti.functional_html
            table_bit *= sp * pti.appearance_html
            table_bit *= "<br>" * generate_data_source_attribution(pti.data_label, dataformat)
        else
            if hasfield(typeof(pti), :functional_html)
                functional_bit *= pti.functional_html
            end
            table_bit *= sp * pti.appearance_html
        end
    end

    # Build full page HTML
    # Get package version
    version_str = try
        string(pkgversion(@__MODULE__))
    catch
        "unknown"
    end

    full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
    full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
    full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
    full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => page.tab_title)
    full_page_html = replace(full_page_html, "___PAGE_HEADER___" => page.page_header)
    full_page_html = replace(full_page_html, "___NOTES___" => page.notes)
    full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)
    full_page_html = replace(full_page_html, "___PRISM_LANGUAGES___" => prism_scripts)
    full_page_html = replace(full_page_html, "___VERSION___" => version_str)

    return full_page_html
end

"""
    save_dataframe(data_label::Symbol, df::DataFrame, data_dir::String, dataformat::Symbol)

Helper function to save a single DataFrame in the specified format.
"""
function save_dataframe(data_label::Symbol, df::DataFrame, data_dir::String, dataformat::Symbol)
    if dataformat == :csv_external
        file_path = joinpath(data_dir, "$(string(data_label)).csv")
        CSV.write(file_path, df)
        println("  Data saved to $file_path")
    elseif dataformat == :json_external
        file_path = joinpath(data_dir, "$(string(data_label)).json")
        rows = []
        for row in eachrow(df)
            row_dict = Dict(String(col) => row[col] for col in names(df))
            push!(rows, row_dict)
        end
        open(file_path, "w") do f
            write(f, JSON.json(rows, 2))
        end
        println("  Data saved to $file_path")
    elseif dataformat == :parquet
        file_path = joinpath(data_dir, "$(string(data_label)).parquet")
        con = DBInterface.connect(DuckDB.DB)

        # Convert Symbol columns to String
        df_converted = copy(df)
        for col in names(df_converted)
            col_type = eltype(df_converted[!, col])
            if col_type <: Symbol || (col_type isa Union && Symbol in Base.uniontypes(col_type))
                df_converted[!, col] = string.(df_converted[!, col])
            end
            if col_type <: ZonedDateTime || (col_type isa Union && ZonedDateTime in Base.uniontypes(col_type))
                df_converted[!, col] = [ismissing(x) ? missing : x.utc_datetime for x in df_converted[!, col] ]
            end
        end

        DuckDB.register_data_frame(con, df_converted, "temp_table")
        DBInterface.execute(con, "COPY temp_table TO '$file_path' (FORMAT PARQUET)")
        DBInterface.close!(con)
        println("  Data saved to $file_path")
    end
end

# Method for Pages - creates multiple HTML files with shared data in a flat structure
function create_html(jsp::Pages, outfile_path::String="index.html")
    # Extract directory and base name
    original_dir = dirname(outfile_path)
    original_name = basename(outfile_path)
    name_without_ext = splitext(original_name)[1]

    # Create project folder (flat structure: all HTML files at same level)
    project_dir = isempty(original_dir) ? name_without_ext : joinpath(original_dir, name_without_ext)
    if !isdir(project_dir)
        mkpath(project_dir)
    end

    # Collect all unique dataframes across all pages
    all_dataframes = Dict{Symbol, DataFrame}()
    merge!(all_dataframes, jsp.coverpage.dataframes)
    for page in jsp.pages
        merge!(all_dataframes, page.dataframes)
    end

    # If using external data format, create data directory and save each datasource once
    if jsp.dataformat in [:csv_external, :json_external, :parquet]
        data_dir = joinpath(project_dir, "data")
        if !isdir(data_dir)
            mkpath(data_dir)
        end

        # Collect all data dependencies across all pages
        all_dependencies = Set{Symbol}()
        for pt in jsp.coverpage.pivot_tables
            union!(all_dependencies, dependencies(pt))
        end
        for page in jsp.pages
            for pt in page.pivot_tables
                union!(all_dependencies, dependencies(pt))
            end
        end

        # Save each unique datasource only once
        for data_label in all_dependencies
            if haskey(all_dataframes, data_label)
                save_dataframe(data_label, all_dataframes[data_label], data_dir, jsp.dataformat)
            end
        end
    end

    # Generate coverpage HTML
    coverpage_path = joinpath(project_dir, original_name)
    coverpage_html = generate_page_html(jsp.coverpage, all_dataframes, jsp.dataformat, project_dir)
    open(coverpage_path, "w") do f
        write(f, coverpage_html)
    end
    println("Created coverpage: $coverpage_path")

    # Generate each subpage HTML using sanitized tab_title
    # Note: We need to use the same sanitize_filename function used in Pages.jl
    # to ensure links match filenames
    for (i, page) in enumerate(jsp.pages)
        sanitized_name = sanitize_filename(page.tab_title)
        page_filename = "$(sanitized_name).html"
        page_path = joinpath(project_dir, page_filename)
        page_html = generate_page_html(page, all_dataframes, jsp.dataformat, project_dir)
        open(page_path, "w") do f
            write(f, page_html)
        end
        println("Created page '$(page.tab_title)': $page_path")
    end

    # Generate launcher scripts at project root
    bat_path = joinpath(project_dir, "open.bat")
    sh_path = joinpath(project_dir, "open.sh")
    readme_path = joinpath(project_dir, "README.md")

    open(bat_path, "w") do f
        write(f, generate_bat_launcher(original_name))
    end

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

    println("\nMulti-page project created:")
    println("  Location: $project_dir")
    println("  Main page: $original_name")
    println("  Subpages: $(length(jsp.pages))")
    for page in jsp.pages
        sanitized_name = sanitize_filename(page.tab_title)
        println("    - $(page.tab_title): $(sanitized_name).html")
    end
    if jsp.dataformat in [:csv_external, :json_external, :parquet]
        println("  Data format: $(jsp.dataformat) (shared in data/ folder)")
    else
        println("  Data format: $(jsp.dataformat) (embedded in each HTML)")
    end
end
