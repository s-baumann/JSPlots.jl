using Documenter, JSPlots

makedocs(
    format = Documenter.HTML(),
    sitename = "JSPlots",
    modules = [JSPlots],
    checkdocs = :exports,  # Only check exported functions, not internal helpers
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
