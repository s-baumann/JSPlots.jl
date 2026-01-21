"""
CodeBlock chart type for displaying code with syntax highlighting.

Supports multiple programming languages for display (Julia, Python, R, C++, C, Java, JavaScript, SQL, PostgreSQL).
Only Julia code can be executed.

Supports three modes:
1. From a function - displays the function's source code (Julia only)
2. From a file - displays the file's contents
3. From a code string - displays the provided code

All modes support execution via execute(codeblock) for Julia code only.
"""

# Mapping of supported languages to Prism.js language identifiers
const SUPPORTED_LANGUAGES = Dict(
    "julia" => "julia",
    "python" => "python",
    "r" => "r",
    "c++" => "cpp",
    "cpp" => "cpp",
    "c" => "c",
    "java" => "java",
    "javascript" => "javascript",
    "js" => "javascript",
    "sql" => "sql",
    "postgresql" => "plsql",
    "plpgsql" => "plsql",
    "pl/pgsql" => "plsql",
    "rust" => "rust"
)

# HTML template for CodeBlock
const CODEBLOCK_TEMPLATE = """
<div class="codeblock-container" id="___CHART_TITLE___">
    <div class="codeblock-header">
        <span class="codeblock-language">___LANGUAGE_DISPLAY___</span>
    </div>
    <pre><code class="___LANGUAGE_CLASS___">___CODE_CONTENT___</code></pre>
    ___FILE_METADATA___
    ___NOTES_SECTION___
</div>
"""

const CODEBLOCK_STYLE = """
<style>
.codeblock-container {
    margin: 20px 0;
    border: 1px solid #e1e4e8;
    border-radius: 6px;
    overflow: hidden;
    background-color: #ffffff;
}

.codeblock-header {
    background-color: #f6f8fa;
    padding: 8px 16px;
    border-bottom: 1px solid #e1e4e8;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
}

.codeblock-language {
    font-size: 12px;
    font-weight: 600;
    color: #586069;
    text-transform: uppercase;
}

.codeblock-container pre {
    margin: 0;
    padding: 16px;
    overflow-x: auto;
    background-color: #f6f8fa;
}

.codeblock-container code {
    font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
    font-size: 13px;
    line-height: 1.6;
}

.codeblock-notes {
    padding: 12px 16px;
    background-color: #fffbdd;
    border-top: 1px solid #e1e4e8;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    font-size: 14px;
    color: #24292e;
}

.codeblock-file-metadata {
    padding: 8px 16px;
    background-color: #f1f3f5;
    border-top: 1px solid #e1e4e8;
    font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
    font-size: 11px;
    color: #6a737d;
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
}

.codeblock-file-metadata span {
    white-space: nowrap;
}

.codeblock-file-metadata .file-label {
    color: #959da5;
    margin-right: 4px;
}
</style>
"""

"""
    CodeBlock

A chart type that displays code with syntax highlighting.

# Fields
- `chart_title::Symbol`: Unique identifier for the code block
- `code_content::String`: The code to display
- `language::String`: Programming language (e.g., "julia", "python", "r", "sql")
- `executable::Union{Function, String, Nothing}`: Function or file path for execution (Julia only)
- `notes::String`: Optional notes to display below the code
- `appearance_html::String`: HTML for rendering the code block
- `functional_html::String`: JavaScript (empty for CodeBlock)
"""
struct CodeBlock <: JSPlotsType
    chart_title::Symbol
    code_content::String
    language::String
    executable::Union{Function, String, Nothing}
    notes::String
    appearance_html::String
    functional_html::String
end

"""
    execute_codeblock(cb::CodeBlock)

Execute the code in the CodeBlock.

Only Julia code can be executed. Attempting to execute code in other languages will throw an error.

# Returns
- For function-based CodeBlocks: Returns the result of calling the function
- For file-based CodeBlocks: Returns the result of including the file
- For code-only CodeBlocks: Throws an error (not executable)

# Examples
```julia
cb = CodeBlock(my_function)
result = execute_codeblock(cb)

# Preferred: Use callable syntax
result = cb()

cb = CodeBlock("script.jl")
cb()
```
"""
function execute_codeblock(cb::CodeBlock)
    if lowercase(cb.language) != "julia"
        error("Cannot execute $(cb.language) code. Only Julia code can be executed. CodeBlock is for display purposes only for non-Julia languages.")
    end

    if cb.executable === nothing
        error("This CodeBlock is not executable. It only contains code for display.")
    elseif cb.executable isa Function
        return cb.executable()
    elseif cb.executable isa String  # file path
        return include(cb.executable)
    end
end

"""
    (cb::CodeBlock)()

Make CodeBlock callable. This is the preferred way to execute a CodeBlock.

# Examples
```julia
cb = CodeBlock(my_function)
result = cb()

# Multiple return values
chart, data = cb()
```
"""
function (ee::CodeBlock)()
    return execute_codeblock(ee)
end

"""
    get_function_source(func::Function) -> String

Attempt to extract source code from a function.

Uses CodeTracking.jl if available, otherwise tries to extract from source file.
"""
function get_function_source(func::Function)
    # Try to use CodeTracking.jl if available
    if isdefined(Main, :CodeTracking) && isdefined(Main.CodeTracking, :code_string)
        try
            code = Main.CodeTracking.code_string(func)
            if code !== nothing
                return code
            end
        catch e
            # Fall through to manual method
        end
    end

    # Fallback: Try to find the method and read from file
    try
        m = methods(func).ms[1]  # Get first method
        file = string(m.file)
        line = m.line

        # Check if it's a real file (not REPL or special location)
        if isfile(file)
            lines = readlines(file)

            if line > length(lines)
                throw(ErrorException("Line number out of bounds"))
            end

            # Extract the function
            func_lines = String[]
            start_line = line

            # Detect if it's a one-liner (function_name(...) = ...)
            first_line = lines[start_line]
            is_oneliner = occursin(r"^[\s]*\w+[\s]*\([^)]*\)[\s]*=(?!=)", first_line)

            if is_oneliner
                # For one-liner functions, just take that line
                return first_line
            else
                # For multi-line functions, need to find the matching 'end'
                # Count function/end pairs
                depth = 0
                found_start = false

                for i in start_line:length(lines)
                    current_line = lines[i]

                    # Check if this line starts a function/for/while/let/if/begin block
                    # We need to count these to properly match 'end' statements
                    if occursin(r"\b(function|for|while|let|if|begin|quote|module|struct|mutable\s+struct|abstract\s+type|primitive\s+type)\b", current_line)
                        depth += 1
                        found_start = true
                    end

                    # Add the line to our collection
                    if found_start
                        push!(func_lines, current_line)
                    end

                    # Check if this line has an 'end' keyword
                    # Count how many 'end' keywords are on this line
                    end_matches = collect(eachmatch(r"\bend\b", current_line))
                    depth -= length(end_matches)

                    # If we've matched all the blocks, we're done
                    if found_start && depth == 0
                        break
                    end
                end

                if !isempty(func_lines)
                    return join(func_lines, "\n")
                end
            end
        end
    catch e
        # Continue to fallback message
    end

    # If all else fails, provide instructions
    return """# Unable to extract source code automatically
#
# To display a function's source code, please use one of these approaches:
# 1. Install CodeTracking.jl: using Pkg; Pkg.add("CodeTracking")
# 2. Pass the code as a string: CodeBlock(\"\"\"your code here\"\"\")
# 3. Pass a file path: CodeBlock("path/to/file.jl")

$(func)"""
end

"""
    generate_file_metadata_html(file_path::String) -> String

Generate HTML for displaying file metadata (path, name, modification time).
"""
function generate_file_metadata_html(file_path::String)
    if !isfile(file_path)
        return ""
    end

    file_name = basename(file_path)
    abs_path = abspath(file_path)
    mod_time = Dates.unix2datetime(mtime(file_path))
    mod_time_str = Dates.format(mod_time, "yyyy-mm-dd HH:MM:SS")

    return """
    <div class="codeblock-file-metadata">
        <span><span class="file-label">File:</span>$(file_name)</span>
        <span><span class="file-label">Path:</span>$(abs_path)</span>
        <span><span class="file-label">Modified:</span>$(mod_time_str)</span>
    </div>
    """
end

"""
    generate_codeblock_html(code::String, language::String, notes::String, chart_title::Symbol; file_path::Union{String, Nothing}=nothing) -> String

Generate HTML for displaying a code block with syntax highlighting.
"""
function generate_codeblock_html(code::String, language::String, notes::String, chart_title::Symbol; file_path::Union{String, Nothing}=nothing)
    # Escape HTML in code
    code_escaped = replace(code, "&" => "&amp;")
    code_escaped = replace(code_escaped, "<" => "&lt;")
    code_escaped = replace(code_escaped, ">" => "&gt;")
    code_escaped = replace(code_escaped, "\"" => "&quot;")

    # Determine language class for Prism.js
    lang_lower = lowercase(language)
    lang_class = if haskey(SUPPORTED_LANGUAGES, lang_lower)
        "language-$(SUPPORTED_LANGUAGES[lang_lower])"
    else
        # For unsupported languages, still add a class but no highlighting will occur
        "language-plaintext"
    end

    # Generate file metadata section if file path provided
    file_metadata_html = if !isnothing(file_path) && isfile(file_path)
        generate_file_metadata_html(file_path)
    else
        ""
    end

    # Generate notes section if provided
    notes_html = if isempty(notes)
        ""
    else
        "<div class=\"codeblock-notes\">$(notes)</div>"
    end

    # Replace template placeholders
    html = replace(CODEBLOCK_TEMPLATE, "___CHART_TITLE___" => String(chart_title))
    html = replace(html, "___CODE_CONTENT___" => code_escaped)
    html = replace(html, "___LANGUAGE_DISPLAY___" => language)
    html = replace(html, "___LANGUAGE_CLASS___" => lang_class)
    html = replace(html, "___FILE_METADATA___" => file_metadata_html)
    html = replace(html, "___NOTES_SECTION___" => notes_html)

    return CODEBLOCK_STYLE * html
end

"""
    CodeBlock(func::Function; notes::String="", chart_title::Symbol=gensym("codeblock"))

Create a CodeBlock from a Julia function.

The function's source code will be extracted and displayed. The function can be
executed using `cb()` syntax.

# Examples
```julia
function my_example()
    x = [1, 2, 3]
    y = [4, 5, 6]
    return x, y
end

cb = CodeBlock(my_example, notes="This generates example data")
a, b = cb()
```
"""
function CodeBlock(func::Function; notes::String="", chart_title::Symbol=gensym("codeblock"))
    code_content = get_function_source(func)
    language = "Julia"
    appearance_html = generate_codeblock_html(code_content, language, notes, chart_title)
    return CodeBlock(chart_title, code_content, language, func, notes, appearance_html, "")
end

"""
    CodeBlock(file_path::String; language::String="julia", notes::String="", chart_title::Symbol=gensym("codeblock"), executable::Bool=true)

Create a CodeBlock from a source file.

The file's contents will be displayed. If `executable=true` and `language="julia"`, the file can be
executed using `cb()` syntax. Non-Julia files can only be displayed, not executed.

# Parameters
- `file_path::String`: Path to the source file
- `language::String`: Programming language (default: "julia"). Supported: julia, python, r, c++, c, java, javascript, sql, postgresql
- `notes::String`: Optional notes (default: "")
- `chart_title::Symbol`: Unique identifier (default: auto-generated)
- `executable::Bool`: Whether Julia files can be executed with `cb()` (default: `true`)

# Examples
```julia
# Julia file (executable)
cb = CodeBlock("examples/my_script.jl", notes="Example script")
cb()

# Python file (display only)
cb = CodeBlock("script.py", language="python", notes="Python implementation")

# SQL file (display only)
cb = CodeBlock("query.sql", language="sql", notes="Database query")
```
"""
function CodeBlock(file_path::String; language::String="julia", notes::String="", chart_title::Symbol=gensym("codeblock"), executable::Bool=true)
    if !isfile(file_path)
        error("File not found: $(file_path)")
    end

    code_content = read(file_path, String)
    appearance_html = generate_codeblock_html(code_content, language, notes, chart_title; file_path=file_path)

    # Only Julia files can be executable
    exec = if lowercase(language) == "julia" && executable
        file_path
    else
        nothing
    end

    return CodeBlock(chart_title, code_content, language, exec, notes, appearance_html, "")
end

# Mapping of file extensions to languages
const EXTENSION_TO_LANGUAGE = Dict(
    ".jl" => "julia",
    ".py" => "python",
    ".r" => "r",
    ".R" => "r",
    ".cpp" => "c++",
    ".cxx" => "c++",
    ".cc" => "c++",
    ".c" => "c",
    ".h" => "c",
    ".hpp" => "c++",
    ".java" => "java",
    ".js" => "javascript",
    ".ts" => "javascript",
    ".sql" => "sql",
    ".rs" => "rust"
)

"""
    detect_language_from_extension(file_path::String) -> String

Detect programming language from file extension.
Returns "plaintext" if extension is not recognized.
"""
function detect_language_from_extension(file_path::String)
    ext = splitext(file_path)[2]
    return get(EXTENSION_TO_LANGUAGE, ext, "plaintext")
end

"""
    CodeBlock(file_paths::Vector{String}; languages::Union{Vector{String}, Nothing}=nothing, notes::String="", chart_title::Symbol=gensym("codeblock"))

Create a Vector of CodeBlocks from multiple source files.

Languages are auto-detected from file extensions if not specified.
Each file will be displayed with its file metadata (path, name, modification time).

# Parameters
- `file_paths::Vector{String}`: Paths to the source files
- `languages::Union{Vector{String}, Nothing}`: Programming languages for each file (default: auto-detect from extension)
- `notes::String`: Optional notes to display on the last CodeBlock (default: "")
- `chart_title::Symbol`: Base identifier - each CodeBlock gets a unique suffix (default: auto-generated)

# Supported file extensions
- `.jl` → Julia
- `.py` → Python
- `.r`, `.R` → R
- `.cpp`, `.cxx`, `.cc`, `.hpp` → C++
- `.c`, `.h` → C
- `.java` → Java
- `.js`, `.ts` → JavaScript
- `.sql` → SQL
- `.rs` → Rust

# Examples
```julia
# Auto-detect languages from extensions
cbs = CodeBlock(["src/main.jl", "lib/utils.py", "queries/data.sql"])

# Specify languages explicitly
cbs = CodeBlock(["file1.txt", "file2.txt"], languages=["julia", "python"])

# Add to a page
page = JSPlotPage(Dict{Symbol,Any}(), cbs)
```
"""
function CodeBlock(file_paths::Vector{String}; languages::Union{Vector{String}, Nothing}=nothing, notes::String="", chart_title::Symbol=gensym("codeblock"))
    if isempty(file_paths)
        error("file_paths cannot be empty")
    end

    # Validate languages if provided
    if !isnothing(languages) && length(languages) != length(file_paths)
        error("Length of languages ($(length(languages))) must match length of file_paths ($(length(file_paths)))")
    end

    codeblocks = CodeBlock[]

    for (i, file_path) in enumerate(file_paths)
        if !isfile(file_path)
            error("File not found: $(file_path)")
        end

        # Determine language
        lang = if !isnothing(languages)
            languages[i]
        else
            detect_language_from_extension(file_path)
        end

        # Only add notes to the last CodeBlock
        file_notes = (i == length(file_paths)) ? notes : ""

        # Create unique chart title for each file
        file_chart_title = Symbol(string(chart_title) * "_" * string(i))

        push!(codeblocks, CodeBlock(file_path; language=lang, notes=file_notes, chart_title=file_chart_title, executable=false))
    end

    return codeblocks
end

"""
    CodeBlock(code::String, ::Val{:code}; language::String="julia", notes::String="", chart_title::Symbol=gensym("codeblock"))

Create a CodeBlock from a code string (display-only, not executable).

# Parameters
- `code::String`: The code to display
- `Val(:code)`: Type tag to indicate this is a code string
- `language::String`: Programming language (default: "julia"). Supported: julia, python, r, c++, c, java, javascript, sql, postgresql
- `notes::String`: Optional notes (default: "")
- `chart_title::Symbol`: Unique identifier (default: auto-generated)

# Examples
```julia
# Julia code
julia_code = \"\"\"
function example()
    println("Hello, World!")
end
\"\"\"
cb = CodeBlock(julia_code, Val(:code), notes="Example Julia function")

# Python code
python_code = \"\"\"
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
\"\"\"
cb = CodeBlock(python_code, Val(:code), language="python", notes="Fibonacci in Python")

# SQL code
sql_code = \"\"\"
SELECT customers.name, COUNT(orders.id) as order_count
FROM customers
LEFT JOIN orders ON customers.id = orders.customer_id
GROUP BY customers.id
HAVING order_count > 5;
\"\"\"
cb = CodeBlock(sql_code, Val(:code), language="sql", notes="Customer orders query")
```
"""
function CodeBlock(code::String, ::Val{:code}; language::String="julia", notes::String="", chart_title::Symbol=gensym("codeblock"))
    appearance_html = generate_codeblock_html(code, language, notes, chart_title)
    return CodeBlock(chart_title, code, language, nothing, notes, appearance_html, "")
end

"""
    get_languages_from_codeblocks(charts::Vector) -> Vector{String}

Extract unique languages from all CodeBlocks in a collection of charts.
Returns the Prism.js language identifiers that need to be loaded.

# Examples
```julia
charts = [cb1, cb2, linechart, cb3]
languages = get_languages_from_codeblocks(charts)
# Returns e.g., ["julia", "python", "sql"]
```
"""
function get_languages_from_codeblocks(charts::Vector)
    languages = Set{String}()

    for chart in charts
        if chart isa CodeBlock
            lang_lower = lowercase(chart.language)
            if haskey(SUPPORTED_LANGUAGES, lang_lower)
                push!(languages, SUPPORTED_LANGUAGES[lang_lower])
            end
        end
    end

    return collect(languages)
end

dependencies(a::CodeBlock) = []
js_dependencies(::CodeBlock) = vcat(JS_DEP_JQUERY, JS_DEP_PRISM)
