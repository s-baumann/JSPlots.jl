
const DEFAULT_NOTES_TEMPLATE = "Add your notes here..."

const NOTES_STYLE = raw"""
<style>
    .notes-container {
        background-color: #fffde7;  /* Pale yellow background */
        border: 1px solid #f9e79f;
        border-radius: 8px;
        padding: 16px 20px;
        margin: 15px 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    }

    .notes-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;
        padding-bottom: 8px;
        border-bottom: 1px solid #f9e79f;
    }

    .notes-heading {
        font-size: 1.1em;
        font-weight: 600;
        color: #5d4e37;
        margin: 0;
    }

    .notes-modified {
        font-size: 0.85em;
        color: #8d7f5e;
        font-style: italic;
    }

    .notes-content {
        white-space: pre-wrap;
        font-size: 0.95em;
    }

    .notes-no-content {
        color: #999;
        font-style: italic;
    }

    .notes-file-info {
        font-size: 0.8em;
        color: #8d7f5e;
        margin-top: 10px;
        padding-top: 8px;
        border-top: 1px dashed #f9e79f;
    }
</style>
"""

# Template for embedded formats (static content)
const NOTES_EMBEDDED_TEMPLATE = raw"""
<div class="notes-container" id="notes_container___CHART_ID___">
    <div class="notes-header">
        <h4 class="notes-heading">___HEADING___</h4>
        <span class="notes-modified">Created on page generation</span>
    </div>
    <div class="notes-content">___CONTENT___</div>
</div>
"""

# Template for external formats (dynamically loaded)
const NOTES_EXTERNAL_TEMPLATE = raw"""
<div class="notes-container" id="notes_container___CHART_ID___">
    <div class="notes-header">
        <h4 class="notes-heading">___HEADING___</h4>
        <span class="notes-modified" id="notes_modified___CHART_ID___">Loading...</span>
    </div>
    <div class="notes-content" id="notes_content___CHART_ID___">Loading notes...</div>
    <div class="notes-file-info">
        Edit file: <code>notes/___FILENAME___</code>
    </div>
</div>
"""

# JavaScript for loading notes from external file
const NOTES_EXTERNAL_JS_TEMPLATE = raw"""
(function() {
    const notesFile = 'notes/___FILENAME___';
    const template = `___TEMPLATE___`;
    const contentDiv = document.getElementById('notes_content___CHART_ID___');
    const modifiedDiv = document.getElementById('notes_modified___CHART_ID___');

    fetch(notesFile)
        .then(response => {
            if (!response.ok) {
                throw new Error('Notes file not found');
            }
            // Get last modified time from response headers if available
            const lastModified = response.headers.get('Last-Modified');
            return response.text().then(text => ({ text, lastModified }));
        })
        .then(({ text, lastModified }) => {
            const content = text.trim();

            // Check if content is just the template (no user edits)
            if (content === template.trim() || content === '') {
                contentDiv.innerHTML = '<span class="notes-no-content">No notes provided</span>';
            } else {
                // Escape HTML and preserve newlines
                const escaped = content
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;')
                    .replace(/"/g, '&quot;');
                contentDiv.textContent = content;
            }

            // Display modification time
            if (lastModified) {
                const date = new Date(lastModified);
                modifiedDiv.textContent = 'Last modified: ' + date.toLocaleString();
            } else {
                // If no Last-Modified header, try to get file modification time via a second request
                modifiedDiv.textContent = '';
            }
        })
        .catch(error => {
            console.warn('Could not load notes file:', error);
            contentDiv.innerHTML = '<span class="notes-no-content">No notes provided</span>';
            modifiedDiv.textContent = 'File not found';
        });
})();
"""

"""
    Notes(; template::String, heading::String, textfilename::String)

A notes block that displays editable text content from an external file.

When using external data formats (csv_external, json_external, parquet), Notes creates
a text file that can be edited after the HTML is generated. The notes are then
displayed in the HTML with a pale yellow background. This allows users to add
commentary or observations to their visualizations.

When using embedded data formats, Notes behaves like a static text block showing
the template content.

# Arguments
- `template::String`: Initial text content to populate the notes file (default: "Add your notes here...")
- `heading::String`: Header text displayed at the top left of the notes box (default: "Notes")
- `textfilename::String`: Name of the text file to create/read (default: "notes.txt")

# Display Features
- Pale yellow background for visibility
- Heading displayed in the top left
- Last modification time displayed in the top right
- If the file content matches the template exactly, shows "No notes provided"
- For external formats, shows the file path so users know where to edit

# Examples
```julia
# Basic notes with default settings
notes = Notes()

# Custom notes for a specific chart
notes = Notes(
    template = "Observations about the correlation analysis:\\n- \\n- \\n",
    heading = "Analysis Notes",
    textfilename = "correlation_observations.txt"
)

# Multiple notes sections
notes1 = Notes(heading = "Methods", textfilename = "methods.txt")
notes2 = Notes(heading = "Results", textfilename = "results.txt")
notes3 = Notes(heading = "Conclusions", textfilename = "conclusions.txt")
```
"""
struct Notes <: JSPlotsType
    template::String
    heading::String
    textfilename::String
    chart_id::Symbol
    appearance_html::String
    functional_html::String
end

function Notes(;
    template::String = DEFAULT_NOTES_TEMPLATE,
    heading::String = "Notes",
    textfilename::String = "notes.txt"
)
    # Generate a unique chart_id from the filename
    chart_id = Symbol(replace(splitext(textfilename)[1], r"[^a-zA-Z0-9_]" => "_"))

    # For construction, we create placeholder HTML
    # The actual HTML depends on the dataformat which is known at create_html time
    appearance_html = ""
    functional_html = ""

    Notes(template, heading, textfilename, chart_id, appearance_html, functional_html)
end

"""
    generate_notes_html(notes::Notes, dataformat::Symbol, project_dir::String="")

Generate HTML and JavaScript for a Notes block based on the data format.

For embedded formats: Creates static HTML with the template content.
For external formats: Creates a notes file and JavaScript to load it dynamically.
"""
function generate_notes_html(notes::Notes, dataformat::Symbol, project_dir::String="")
    chart_id_str = string(notes.chart_id)

    if dataformat in [:csv_embedded, :json_embedded]
        # Embedded format - static content
        content = if isempty(strip(notes.template))
            "<span class=\"notes-no-content\">No notes provided</span>"
        else
            html_escape(notes.template)
        end

        html = replace(NOTES_EMBEDDED_TEMPLATE, "___CHART_ID___" => chart_id_str)
        html = replace(html, "___HEADING___" => notes.heading)
        html = replace(html, "___CONTENT___" => content)

        return (html = html, js = "")
    else
        # External format - create file and load dynamically
        # Create notes directory if needed
        notes_dir = joinpath(project_dir, "notes")
        if !isdir(notes_dir)
            mkpath(notes_dir)
        end

        # Write the template to the file (only if file doesn't exist)
        notes_path = joinpath(notes_dir, notes.textfilename)
        if !isfile(notes_path)
            open(notes_path, "w") do f
                write(f, notes.template)
            end
            println("  Notes file created: $notes_path")
        else
            println("  Notes file exists (preserving): $notes_path")
        end

        # Generate HTML
        html = replace(NOTES_EXTERNAL_TEMPLATE, "___CHART_ID___" => chart_id_str)
        html = replace(html, "___HEADING___" => notes.heading)
        html = replace(html, "___FILENAME___" => notes.textfilename)

        # Generate JavaScript
        js = replace(NOTES_EXTERNAL_JS_TEMPLATE, "___CHART_ID___" => chart_id_str)
        js = replace(js, "___FILENAME___" => notes.textfilename)
        # Escape the template for JavaScript string
        escaped_template = replace(replace(notes.template, "\\" => "\\\\"), "`" => "\\`")
        js = replace(js, "___TEMPLATE___" => escaped_template)

        return (html = html, js = js)
    end
end

dependencies(::Notes) = Symbol[]
js_dependencies(::Notes) = String[]
