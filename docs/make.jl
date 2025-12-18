using Documenter, JSPlots

# Copy generated HTML examples to docs/src so Documenter includes them in build
examples_src = joinpath(@__DIR__, "..", "generated_html_examples")
examples_dest = joinpath(@__DIR__, "src", "examples_html")
if isdir(examples_src)
    cp(examples_src, examples_dest, force=true)
    println("Copied HTML examples to docs/src/examples_html/")
else
    @warn "Generated HTML examples directory not found at: $examples_src"
end

makedocs(
    format = Documenter.HTML(),
    sitename = "JSPlots",
    modules = [JSPlots],
    checkdocs = :exports,  # Only check exported functions, not internal helpers
    warnonly = [:cross_references, :missing_docs],  # Don't fail on link warnings
    pages = Any[
        "Introduction" => "index.md",
        "Examples" => "examples.md",
        "API" => "api.md"]
)

deploydocs(
    repo   = "github.com/s-baumann/JSPlots.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing
)
