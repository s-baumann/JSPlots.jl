"""
ReportIndex - A JSPlotsType for displaying links to reports from a CSV manifest.

The manifest CSV has required columns: path, html_filename, description, date
Plus an auto-generated: added_to_manifest (datetime when entry was added)
Plus any number of additional custom columns.

Usage:
1. Add entries to manifest when creating reports:
   ```julia
   add_to_manifest("/path/to/manifest.csv",
       path="2024-01-15",
       html_filename="index.html",
       description="Daily Analysis",
       date=Date(2024,1,15))
   ```

2. Or use ManifestEntry with make_html:
   ```julia
   entry = ManifestEntry(path="2024-01-15", html_filename="report.html",
                         description="Daily Report", date=today())
   create_html(page, "/reports/2024-01-15/report.html";
               manifest_file="/reports/manifest.csv", manifest_entry=entry)
   ```

3. Create index page:
   ```julia
   index = ReportIndex(:report_index, "/path/to/manifest.csv", title="My Reports")
   page = JSPlotPage(Dict{Symbol,Any}(), [index])
   create_html(page, "/path/to/index.html")
   ```
"""

using CSV
using DataFrames

# Required columns in manifest
const MANIFEST_REQUIRED_COLS = [:path, :html_filename, :description, :date]

"""
    ManifestEntry

Struct for adding an entry to a manifest. Used with make_html for automatic manifest updates.

# Required Fields
- `path::String`: Relative path/folder containing the report
- `html_filename::String`: Name of the HTML file
- `description::String`: Description of the report
- `date::Date`: Date associated with the report

# Optional Fields
- `extra_columns::Dict{Symbol,Any}`: Additional columns to include

# Example
```julia
entry = ManifestEntry(
    path = "2024-01-15",
    html_filename = "index.html",
    description = "Daily Market Analysis",
    date = Date(2024, 1, 15),
    extra_columns = Dict(:category => "daily", :author => "Stuart")
)
```
"""
struct ManifestEntry
    path::String
    html_filename::String
    description::String
    date::Date
    extra_columns::Dict{Symbol,Any}

    function ManifestEntry(; path::String, html_filename::String, description::String,
                            date::Date, extra_columns::Dict=Dict{Symbol,Any}())
        # Convert any Dict to Dict{Symbol,Any}
        converted = Dict{Symbol,Any}(Symbol(k) => v for (k, v) in extra_columns)
        new(path, html_filename, description, date, converted)
    end
end

"""
    add_to_manifest(manifest_path::String; path::String, html_filename::String,
                    description::String, date::Date, fill_missing::Bool=false, kwargs...)

Add a single entry to the manifest CSV file.

# Required Arguments
- `manifest_path::String`: Path to the manifest CSV file
- `path::String`: Relative path/folder containing the report
- `html_filename::String`: Name of the HTML file
- `description::String`: Description of the report
- `date::Date`: Date associated with the report

# Optional Arguments
- `fill_missing::Bool`: If true, fill missing extra columns with `missing` (default: false)
- `kwargs...`: Additional columns to include in the manifest

# Example
```julia
add_to_manifest("reports/manifest.csv",
    path = "2024-01-15",
    html_filename = "index.html",
    description = "Daily Analysis Report",
    date = Date(2024, 1, 15),
    category = "daily",
    author = "Stuart"
)
```
"""
function add_to_manifest(manifest_path::String;
                         path::String,
                         html_filename::String,
                         description::String,
                         date::Date,
                         fill_missing::Bool=false,
                         kwargs...)

    # Create entry dict with required columns
    entry = Dict{Symbol,Any}(
        :path => path,
        :html_filename => html_filename,
        :description => description,
        :date => date,
        :added_to_manifest => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )

    # Add extra columns from kwargs
    for (k, v) in kwargs
        entry[k] = v
    end

    # Load existing manifest or create new one
    if isfile(manifest_path)
        # Specify types to prevent auto-parsing of date-like strings
        df = CSV.read(manifest_path, DataFrame;
            types=Dict(:path => String, :html_filename => String, :description => String))

        # Check for extra columns in existing manifest
        existing_cols = Symbol.(names(df))
        for col in existing_cols
            if !haskey(entry, col) && col != :added_to_manifest
                if fill_missing
                    entry[col] = missing
                else
                    error("Manifest has column '$col' but no value provided. Set fill_missing=true or provide a value.")
                end
            end
        end

        # Remove existing entry with same path AND html_filename (no duplicates)
        df = filter(row -> !(string(row.path) == path && string(row.html_filename) == html_filename), df)

        # Add new columns to df if needed
        for (k, v) in entry
            if !(k in existing_cols)
                df[!, k] = Vector{Union{typeof(v), Missing}}(missing, nrow(df))
            end
        end

        # Append new entry
        new_row = DataFrame(entry)
        df = vcat(df, new_row, cols=:union)
    else
        # Create new manifest
        mkpath(dirname(manifest_path))
        df = DataFrame(entry)
    end

    # Sort by date descending
    sort!(df, :date, rev=true)

    # Write back
    CSV.write(manifest_path, df)

    return manifest_path
end

"""
    add_to_manifest(manifest_path::String, entry::ManifestEntry; fill_missing::Bool=false)

Add a ManifestEntry to the manifest CSV file.
"""
function add_to_manifest(manifest_path::String, entry::ManifestEntry; fill_missing::Bool=false)
    add_to_manifest(manifest_path;
        path=entry.path,
        html_filename=entry.html_filename,
        description=entry.description,
        date=entry.date,
        fill_missing=fill_missing,
        entry.extra_columns...
    )
end

"""
    ReportIndex <: JSPlotsType

A chart type that displays links to reports from a CSV manifest file.

The manifest CSV should have columns: path, html_filename, description, date
Plus optional additional columns that can be used for grouping/sorting.

# Constructor
```julia
ReportIndex(chart_title::Symbol, manifest_path::String;
            title::String="Report Archive",
            default_group_by::Union{Symbol,Nothing}=nothing,
            default_then_group_by::Union{Symbol,Nothing}=nothing,
            default_sort_by::Symbol=:date)
```

# Example
```julia
index = ReportIndex(:my_index, "reports/manifest.csv",
    title="Daily Reports Archive",
    default_group_by=:category,
    default_then_group_by=:date,
    default_sort_by=:date
)

page = JSPlotPage(Dict{Symbol,Any}(), [index])
create_html(page, "reports/index.html")
```
"""
struct ReportIndex <: JSPlotsType
    chart_title::Symbol
    manifest_path::String
    title::String
    default_group_by::Union{Symbol,Nothing}
    default_then_group_by::Union{Symbol,Nothing}
    default_sort_by::Symbol
    appearance_html::String
    functional_html::String

    function ReportIndex(chart_title::Symbol, manifest_path::String;
                         title::String="Report Archive",
                         default_group_by::Union{Symbol,Nothing}=nothing,
                         default_then_group_by::Union{Symbol,Nothing}=nothing,
                         default_sort_by::Symbol=:date)

        if !isfile(manifest_path)
            @warn "Manifest file does not exist yet: $manifest_path"
        end

        chart_title_str = string(chart_title)

        appearance_html = build_reportindex_appearance_html(chart_title_str, title)
        functional_html = build_reportindex_functional_html(
            chart_title_str, manifest_path,
            default_group_by, default_then_group_by, default_sort_by
        )

        new(chart_title, manifest_path, title,
            default_group_by, default_then_group_by, default_sort_by,
            appearance_html, functional_html)
    end
end

function build_reportindex_appearance_html(chart_title_str::String, title::String)
    return """
    <style>
        .reportindex-container-$chart_title_str {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
        }

        .reportindex-container-$chart_title_str h2 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }

        .reportindex-controls-$chart_title_str {
            display: flex;
            gap: 20px;
            align-items: center;
            flex-wrap: wrap;
            margin-bottom: 20px;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 8px;
        }

        .reportindex-controls-$chart_title_str label {
            font-weight: 600;
            color: #495057;
            margin-right: 5px;
        }

        .reportindex-controls-$chart_title_str select {
            padding: 8px 12px;
            border: 1px solid #ced4da;
            border-radius: 4px;
            font-size: 14px;
            min-width: 150px;
        }

        .reportindex-stats-$chart_title_str {
            display: flex;
            gap: 15px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }

        .reportindex-stat-$chart_title_str {
            background: white;
            padding: 12px 20px;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }

        .reportindex-stat-value-$chart_title_str {
            font-size: 24px;
            font-weight: 700;
            color: #3498db;
        }

        .reportindex-stat-label-$chart_title_str {
            font-size: 11px;
            color: #7f8c8d;
            text-transform: uppercase;
        }

        .reportindex-group-$chart_title_str {
            margin-bottom: 25px;
        }

        .reportindex-group-header-$chart_title_str {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 20px;
            border-radius: 8px 8px 0 0;
            font-size: 18px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .reportindex-group-header-$chart_title_str:hover {
            opacity: 0.95;
        }

        .reportindex-group-header-$chart_title_str .toggle {
            transition: transform 0.3s ease;
        }

        .reportindex-group-header-$chart_title_str.collapsed .toggle {
            transform: rotate(-90deg);
        }

        .reportindex-subgroup-$chart_title_str {
            border-bottom: 1px solid #ecf0f1;
        }

        .reportindex-subgroup-header-$chart_title_str {
            background-color: #f1f3f5;
            padding: 10px 20px;
            font-weight: 600;
            color: #495057;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .reportindex-subgroup-header-$chart_title_str:hover {
            background-color: #e9ecef;
        }

        .reportindex-subgroup-header-$chart_title_str .count {
            background-color: #6c757d;
            color: white;
            padding: 2px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: normal;
        }

        .reportindex-group-content-$chart_title_str {
            background: white;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }

        .reportindex-group-content-$chart_title_str.hidden {
            display: none;
        }

        .reportindex-subgroup-content-$chart_title_str.hidden {
            display: none;
        }

        .reportindex-list-$chart_title_str {
            list-style: none;
            padding: 0;
            margin: 0;
        }

        .reportindex-item-$chart_title_str {
            padding: 12px 20px 12px 30px;
            border-bottom: 1px solid #f1f3f5;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: background-color 0.2s;
        }

        .reportindex-item-$chart_title_str:last-child {
            border-bottom: none;
        }

        .reportindex-item-$chart_title_str:hover {
            background-color: #f8f9fa;
        }

        .reportindex-link-$chart_title_str {
            color: #2980b9;
            text-decoration: none;
            font-weight: 500;
        }

        .reportindex-link-$chart_title_str:hover {
            color: #1a5276;
            text-decoration: underline;
        }

        .reportindex-link-missing-$chart_title_str {
            color: #e74c3c;
            text-decoration: none;
            font-weight: 500;
        }

        .reportindex-link-missing-$chart_title_str:hover {
            color: #c0392b;
            text-decoration: underline;
        }

        .reportindex-link-missing-$chart_title_str::after {
            content: " (missing)";
            font-size: 11px;
            font-weight: normal;
        }

        .reportindex-meta-$chart_title_str {
            color: #95a5a6;
            font-size: 12px;
        }

        .reportindex-description-$chart_title_str {
            color: #7f8c8d;
            font-size: 13px;
            margin-left: 10px;
        }

        .reportindex-loading-$chart_title_str {
            text-align: center;
            padding: 40px;
            color: #7f8c8d;
        }

        .reportindex-error-$chart_title_str {
            text-align: center;
            padding: 40px;
            color: #e74c3c;
            background-color: #fdf2f2;
            border-radius: 8px;
        }

        .reportindex-empty-$chart_title_str {
            text-align: center;
            padding: 40px;
            color: #7f8c8d;
        }
    </style>

    <div class="reportindex-container-$chart_title_str">
        <h2>$title</h2>

        <div class="reportindex-controls-$chart_title_str">
            <div>
                <label for="groupby1_$chart_title_str">Group by:</label>
                <select id="groupby1_$chart_title_str" onchange="updateDisplay_$chart_title_str()">
                    <option value="none">No grouping</option>
                </select>
            </div>
            <div>
                <label for="groupby2_$chart_title_str">Then by:</label>
                <select id="groupby2_$chart_title_str" onchange="updateDisplay_$chart_title_str()">
                    <option value="none">No second grouping</option>
                </select>
            </div>
            <div>
                <label for="sortby_$chart_title_str">Sort by:</label>
                <select id="sortby_$chart_title_str" onchange="updateDisplay_$chart_title_str()">
                </select>
            </div>
        </div>

        <div class="reportindex-stats-$chart_title_str" id="stats_$chart_title_str"></div>

        <div id="content_$chart_title_str">
            <div class="reportindex-loading-$chart_title_str">Loading reports...</div>
        </div>
    </div>
    """
end

function build_reportindex_functional_html(chart_title_str::String, manifest_path::String,
                                           default_group_by, default_then_group_by, default_sort_by)

    # Get the manifest filename for the data label
    manifest_filename = basename(manifest_path)
    manifest_dir = dirname(manifest_path)

    default_group1 = isnothing(default_group_by) ? "none" : string(default_group_by)
    default_group2 = isnothing(default_then_group_by) ? "none" : string(default_then_group_by)
    default_sort = string(default_sort_by)

    return """
    (function() {
        const MANIFEST_FILE = '$manifest_filename';
        const DEFAULT_GROUP_BY_1 = '$default_group1';
        const DEFAULT_GROUP_BY_2 = '$default_group2';
        const DEFAULT_SORT_BY = '$default_sort';

        let allReports = [];
        let allColumns = [];

        // Load manifest CSV
        async function loadManifest() {
            try {
                const response = await fetch(MANIFEST_FILE);
                if (!response.ok) {
                    throw new Error('Manifest not found');
                }
                const csvText = await response.text();

                // Parse CSV
                const lines = csvText.trim().split('\\n');
                if (lines.length < 1) {
                    throw new Error('Empty manifest');
                }

                // Parse header
                allColumns = parseCSVLine(lines[0]);

                // Parse data rows
                allReports = [];
                for (let i = 1; i < lines.length; i++) {
                    if (lines[i].trim() === '') continue;
                    const values = parseCSVLine(lines[i]);
                    const row = {};
                    for (let j = 0; j < allColumns.length; j++) {
                        row[allColumns[j]] = values[j] || '';
                    }
                    allReports.push(row);
                }

                populateSelectors();
                updateDisplay_$chart_title_str();
                updateStats();

            } catch (error) {
                document.getElementById('content_$chart_title_str').innerHTML =
                    '<div class="reportindex-error-$chart_title_str">' +
                    '<h3>Could not load manifest</h3>' +
                    '<p>Error: ' + error.message + '</p>' +
                    '<p>Make sure ' + MANIFEST_FILE + ' exists.</p>' +
                    '</div>';
            }
        }

        // Simple CSV line parser (handles quoted fields)
        function parseCSVLine(line) {
            const result = [];
            let current = '';
            let inQuotes = false;

            for (let i = 0; i < line.length; i++) {
                const char = line[i];
                if (char === '"') {
                    if (inQuotes && line[i+1] === '"') {
                        current += '"';
                        i++;
                    } else {
                        inQuotes = !inQuotes;
                    }
                } else if (char === ',' && !inQuotes) {
                    result.push(current.trim());
                    current = '';
                } else {
                    current += char;
                }
            }
            result.push(current.trim());
            return result;
        }

        function populateSelectors() {
            const groupby1 = document.getElementById('groupby1_$chart_title_str');
            const groupby2 = document.getElementById('groupby2_$chart_title_str');
            const sortby = document.getElementById('sortby_$chart_title_str');

            // Clear and repopulate
            groupby1.innerHTML = '<option value="none">No grouping</option>';
            groupby2.innerHTML = '<option value="none">No second grouping</option>';
            sortby.innerHTML = '';

            allColumns.forEach(col => {
                groupby1.innerHTML += '<option value="' + col + '">' + col + '</option>';
                groupby2.innerHTML += '<option value="' + col + '">' + col + '</option>';
                sortby.innerHTML += '<option value="' + col + '">' + col + '</option>';
            });

            // Set defaults
            if (DEFAULT_GROUP_BY_1 !== 'none') {
                groupby1.value = DEFAULT_GROUP_BY_1;
            }
            if (DEFAULT_GROUP_BY_2 !== 'none') {
                groupby2.value = DEFAULT_GROUP_BY_2;
            }
            sortby.value = DEFAULT_SORT_BY;
        }

        function updateStats() {
            const statsDiv = document.getElementById('stats_$chart_title_str');
            if (allReports.length === 0) {
                statsDiv.innerHTML = '';
                return;
            }

            const uniqueDates = new Set(allReports.map(r => r.date ? r.date.substring(0, 7) : ''));

            statsDiv.innerHTML =
                '<div class="reportindex-stat-$chart_title_str">' +
                '<div class="reportindex-stat-value-$chart_title_str">' + allReports.length + '</div>' +
                '<div class="reportindex-stat-label-$chart_title_str">Total Reports</div></div>' +
                '<div class="reportindex-stat-$chart_title_str">' +
                '<div class="reportindex-stat-value-$chart_title_str">' + uniqueDates.size + '</div>' +
                '<div class="reportindex-stat-label-$chart_title_str">Months</div></div>';
        }

        window.updateDisplay_$chart_title_str = function() {
            const groupBy1 = document.getElementById('groupby1_$chart_title_str').value;
            const groupBy2 = document.getElementById('groupby2_$chart_title_str').value;
            const sortBy = document.getElementById('sortby_$chart_title_str').value;

            if (allReports.length === 0) {
                document.getElementById('content_$chart_title_str').innerHTML =
                    '<div class="reportindex-empty-$chart_title_str">No reports in manifest.</div>';
                return;
            }

            // Sort reports
            const sorted = [...allReports].sort((a, b) => {
                const aVal = a[sortBy] || '';
                const bVal = b[sortBy] || '';
                // Try date comparison first
                if (aVal.match(/^\\d{4}-\\d{2}-\\d{2}/)) {
                    return bVal.localeCompare(aVal); // Descending for dates
                }
                return aVal.localeCompare(bVal);
            });

            let html = '';

            if (groupBy1 === 'none') {
                // No grouping - flat list
                html = '<div class="reportindex-group-content-$chart_title_str">';
                html += '<ul class="reportindex-list-$chart_title_str">';
                sorted.forEach(report => {
                    html += renderReportItem(report);
                });
                html += '</ul></div>';
            } else if (groupBy2 === 'none') {
                // Single level grouping
                const groups = groupReports(sorted, groupBy1);
                const groupKeys = Object.keys(groups).sort((a, b) => {
                    if (a.match(/^\\d{4}/)) return b.localeCompare(a);
                    return a.localeCompare(b);
                });

                groupKeys.forEach(key => {
                    html += renderGroup(key, groups[key], groups[key].length);
                });
            } else {
                // Two level grouping
                const groups1 = groupReports(sorted, groupBy1);
                const groupKeys1 = Object.keys(groups1).sort((a, b) => {
                    if (a.match(/^\\d{4}/)) return b.localeCompare(a);
                    return a.localeCompare(b);
                });

                groupKeys1.forEach(key1 => {
                    const subgroups = groupReports(groups1[key1], groupBy2);
                    const totalCount = groups1[key1].length;

                    html += '<div class="reportindex-group-$chart_title_str">';
                    html += '<div class="reportindex-group-header-$chart_title_str" onclick="toggleGroup_$chart_title_str(this)">';
                    html += '<span>' + key1 + ' <span style="font-size:13px;font-weight:normal;">(' + totalCount + ')</span></span>';
                    html += '<span class="toggle">▼</span></div>';
                    html += '<div class="reportindex-group-content-$chart_title_str">';

                    const subKeys = Object.keys(subgroups).sort((a, b) => {
                        if (a.match(/^\\d{4}/)) return b.localeCompare(a);
                        return a.localeCompare(b);
                    });

                    subKeys.forEach(key2 => {
                        html += renderSubgroup(key2, subgroups[key2]);
                    });

                    html += '</div></div>';
                });
            }

            document.getElementById('content_$chart_title_str').innerHTML = html;
        };

        function groupReports(reports, field) {
            const groups = {};
            reports.forEach(report => {
                const key = report[field] || '(empty)';
                if (!groups[key]) groups[key] = [];
                groups[key].push(report);
            });
            return groups;
        }

        function renderGroup(title, reports, count) {
            let html = '<div class="reportindex-group-$chart_title_str">';
            html += '<div class="reportindex-group-header-$chart_title_str" onclick="toggleGroup_$chart_title_str(this)">';
            html += '<span>' + title + ' <span style="font-size:13px;font-weight:normal;">(' + count + ')</span></span>';
            html += '<span class="toggle">▼</span></div>';
            html += '<div class="reportindex-group-content-$chart_title_str">';
            html += '<ul class="reportindex-list-$chart_title_str">';
            reports.forEach(report => {
                html += renderReportItem(report);
            });
            html += '</ul></div></div>';
            return html;
        }

        function renderSubgroup(title, reports) {
            let html = '<div class="reportindex-subgroup-$chart_title_str">';
            html += '<div class="reportindex-subgroup-header-$chart_title_str" onclick="toggleSubgroup_$chart_title_str(this)">';
            html += '<span>' + title + '</span>';
            html += '<span class="count">' + reports.length + '</span></div>';
            html += '<div class="reportindex-subgroup-content-$chart_title_str">';
            html += '<ul class="reportindex-list-$chart_title_str">';
            reports.forEach(report => {
                html += renderReportItem(report);
            });
            html += '</ul></div></div>';
            return html;
        }

        function renderReportItem(report) {
            const link = report.path + '/' + report.html_filename;
            const displayText = report.date || report.path;
            const description = report.description ? '<span class="reportindex-description-$chart_title_str">- ' + report.description + '</span>' : '';

            // Check if file exists by trying to fetch it (we'll mark as potentially missing)
            // For now, we'll use a data attribute and check via JS
            let html = '<li class="reportindex-item-$chart_title_str" data-link="' + link + '">';
            html += '<span>';
            html += '<a class="reportindex-link-$chart_title_str" href="' + link + '" data-check-exists="true">' + displayText + '</a>';
            html += description;
            html += '</span>';
            html += '<span class="reportindex-meta-$chart_title_str">' + report.path + '</span>';
            html += '</li>';
            return html;
        }

        window.toggleGroup_$chart_title_str = function(header) {
            header.classList.toggle('collapsed');
            const content = header.nextElementSibling;
            content.classList.toggle('hidden');
        };

        window.toggleSubgroup_$chart_title_str = function(header) {
            const content = header.nextElementSibling;
            content.classList.toggle('hidden');
        };

        // Check for missing files after rendering
        async function checkMissingFiles() {
            const links = document.querySelectorAll('[data-check-exists="true"]');
            for (const link of links) {
                try {
                    const response = await fetch(link.href, { method: 'HEAD' });
                    if (!response.ok) {
                        link.classList.remove('reportindex-link-$chart_title_str');
                        link.classList.add('reportindex-link-missing-$chart_title_str');
                    }
                } catch (e) {
                    link.classList.remove('reportindex-link-$chart_title_str');
                    link.classList.add('reportindex-link-missing-$chart_title_str');
                }
            }
        }

        // Load on startup
        loadManifest().then(() => {
            // Check for missing files after a short delay
            setTimeout(checkMissingFiles, 500);
        });
    })();
    """
end

# JSPlotsType interface
dependencies(r::ReportIndex) = Symbol[]
js_dependencies(::ReportIndex) = JS_DEP_JQUERY

"""
    get_manifest_columns(manifest_path::String) -> Vector{Symbol}

Get the column names from an existing manifest file.
"""
function get_manifest_columns(manifest_path::String)
    if !isfile(manifest_path)
        return MANIFEST_REQUIRED_COLS
    end
    df = CSV.read(manifest_path, DataFrame, limit=0)
    return Symbol.(names(df))
end

export ReportIndex, ManifestEntry, add_to_manifest, get_manifest_columns, MANIFEST_REQUIRED_COLS
