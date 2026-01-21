"""
Ollama LLM utilities for file comparison and analysis.

This is a standalone file - not part of JSPlots module.
Requires Ollama to be installed and running locally.

Installation:
  - Mac: brew install ollama
  - Linux: curl -fsSL https://ollama.com/install.sh | sh

Usage:
  1. Start Ollama: `ollama serve` (or it may run automatically)
  2. Pull a model: `ollama pull llama3` or `ollama pull mistral`
  3. Use from Julia:

```julia
include("ollama.jl")

# Check if Ollama is running
ollama_status()

# List available models
list_models()

# Compare two files
result = compare_files("file1.jl", "file2.jl")
println(result)

# Ask a question about a file
result = ask_about_file("src/mycode.jl", "What does this code do?")

# General query
result = ollama_query("Explain what a DataFrame is in Julia")
```
"""

using HTTP
using JSON

const OLLAMA_BASE_URL = "http://localhost:11434"
const DEFAULT_MODEL = "llama3"

"""
    ollama_status() -> Bool

Check if Ollama is running and accessible.
"""
function ollama_status()
    try
        response = HTTP.get("$OLLAMA_BASE_URL/api/tags", connect_timeout=2, readtimeout=5)
        if response.status == 200
            println("Ollama is running")
            return true
        end
    catch e
        if e isa HTTP.Exceptions.ConnectError
            println("Ollama is not running. Start it with: ollama serve")
        else
            println("Error connecting to Ollama: $e")
        end
    end
    return false
end

"""
    list_models() -> Vector{String}

List all models available locally in Ollama.
"""
function list_models()
    try
        response = HTTP.get("$OLLAMA_BASE_URL/api/tags", connect_timeout=2, readtimeout=5)
        data = JSON.parse(String(response.body))
        models = [m["name"] for m in get(data, "models", [])]

        if isempty(models)
            println("No models installed. Install one with: ollama pull llama3")
        else
            println("Available models:")
            for m in models
                println("  - $m")
            end
        end

        return models
    catch e
        println("Error listing models: $e")
        return String[]
    end
end

"""
    ollama_query(prompt::String; model::String=DEFAULT_MODEL, verbose::Bool=false) -> String

Send a query to Ollama and return the response.

# Arguments
- `prompt::String`: The prompt to send
- `model::String`: Model to use (default: "$DEFAULT_MODEL")
- `verbose::Bool`: Print progress info (default: false)

# Example
```julia
result = ollama_query("What is the capital of France?")
```
"""
function ollama_query(prompt::String; model::String=DEFAULT_MODEL, verbose::Bool=false)
    verbose && println("Querying $model...")

    payload = Dict(
        "model" => model,
        "prompt" => prompt,
        "stream" => false
    )

    try
        response = HTTP.post(
            "$OLLAMA_BASE_URL/api/generate",
            ["Content-Type" => "application/json"],
            JSON.json(payload),
            connect_timeout=10,
            readtimeout=300  # LLMs can be slow
        )

        data = JSON.parse(String(response.body))
        return get(data, "response", "No response received")

    catch e
        if e isa HTTP.Exceptions.ConnectError
            return "Error: Ollama is not running. Start it with: ollama serve"
        elseif e isa HTTP.Exceptions.StatusError
            return "Error: Model '$model' may not be installed. Try: ollama pull $model"
        else
            return "Error: $e"
        end
    end
end

"""
    compare_files(path1::String, path2::String; model::String=DEFAULT_MODEL, verbose::Bool=true) -> String

Compare two files and describe the differences in plain English.

# Arguments
- `path1::String`: Path to the first file
- `path2::String`: Path to the second file
- `model::String`: Ollama model to use (default: "$DEFAULT_MODEL")
- `verbose::Bool`: Print progress info (default: true)

# Example
```julia
diff = compare_files("old_version.jl", "new_version.jl")
println(diff)
```
"""
function compare_files(path1::String, path2::String; model::String=DEFAULT_MODEL, verbose::Bool=true)
    # Check files exist
    if !isfile(path1)
        return "Error: File not found: $path1"
    end
    if !isfile(path2)
        return "Error: File not found: $path2"
    end

    verbose && println("Reading files...")
    content1 = read(path1, String)
    content2 = read(path2, String)

    # Check file sizes aren't too large
    max_chars = 50000  # Roughly 12k tokens
    if length(content1) + length(content2) > max_chars
        verbose && println("Warning: Files are large, truncating to fit context window")
        content1 = first(content1, max_chars ÷ 2)
        content2 = first(content2, max_chars ÷ 2)
    end

    name1 = basename(path1)
    name2 = basename(path2)

    prompt = """
You are comparing two files. Describe the differences between them in plain English.
Focus on:
1. What was added, removed, or changed
2. The purpose/intent of the changes if apparent
3. Any notable patterns in the changes

Be concise but thorough. Use bullet points for clarity.

=== File 1: $name1 ===
$content1

=== File 2: $name2 ===
$content2

Describe the differences between these two files:
"""

    verbose && println("Analyzing differences with $model (this may take a moment)...")

    result = ollama_query(prompt; model=model, verbose=false)

    verbose && println("Done.")

    return result
end

"""
    ask_about_file(path::String, question::String; model::String=DEFAULT_MODEL, verbose::Bool=true) -> String

Ask a question about a file's contents.

# Arguments
- `path::String`: Path to the file
- `question::String`: Question to ask about the file
- `model::String`: Ollama model to use (default: "$DEFAULT_MODEL")
- `verbose::Bool`: Print progress info (default: true)

# Example
```julia
answer = ask_about_file("src/utils.jl", "What functions are defined in this file?")
```
"""
function ask_about_file(path::String, question::String; model::String=DEFAULT_MODEL, verbose::Bool=true)
    if !isfile(path)
        return "Error: File not found: $path"
    end

    verbose && println("Reading file...")
    content = read(path, String)

    # Truncate if too large
    max_chars = 60000
    if length(content) > max_chars
        verbose && println("Warning: File is large, truncating")
        content = first(content, max_chars)
    end

    name = basename(path)

    prompt = """
Here is the contents of a file named "$name":

$content

Question: $question

Answer:
"""

    verbose && println("Analyzing with $model...")

    result = ollama_query(prompt; model=model, verbose=false)

    verbose && println("Done.")

    return result
end

"""
    summarize_file(path::String; model::String=DEFAULT_MODEL, verbose::Bool=true) -> String

Get a summary of what a file does/contains.

# Example
```julia
summary = summarize_file("src/complex_module.jl")
```
"""
function summarize_file(path::String; model::String=DEFAULT_MODEL, verbose::Bool=true)
    return ask_about_file(path, "Provide a concise summary of this file. What is its purpose? What are the main components/functions?"; model=model, verbose=verbose)
end

"""
    explain_code(code::String; model::String=DEFAULT_MODEL, verbose::Bool=false) -> String

Explain a snippet of code in plain English.

# Example
```julia
explanation = explain_code(\"\"\"
function fibonacci(n)
    n <= 1 ? n : fibonacci(n-1) + fibonacci(n-2)
end
\"\"\")
```
"""
function explain_code(code::String; model::String=DEFAULT_MODEL, verbose::Bool=false)
    prompt = """
Explain this code in plain English. Be concise.

```
$code
```

Explanation:
"""

    return ollama_query(prompt; model=model, verbose=verbose)
end


# Quick test function
function test_ollama()
    println("Testing Ollama connection...")
    println()

    if !ollama_status()
        return false
    end

    println()
    models = list_models()

    if isempty(models)
        return false
    end

    println()
    println("Testing simple query...")
    result = ollama_query("Say 'Hello from Ollama!' and nothing else.", verbose=true)
    println("Response: $result")

    return true
end
