using Documenter, JSPlots

# Build minimal Documenter site (just for deployment infrastructure)
makedocs(;
    modules=[JSPlots],
    authors="Stuart Baumann",
    repo="https://github.com/s-baumann/JSPlots.jl/blob/{commit}{path}#{line}",
    sitename="JSPlots.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://s-baumann.github.io/JSPlots.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    checkdocs = :none,
    warnonly = true,
)

# Copy generated HTML examples to docs/build after makedocs
examples_src = joinpath(@__DIR__, "..", "generated_html_examples")
build_dir = joinpath(@__DIR__, "build")
if isdir(examples_src)
    # Copy each subdirectory/file from generated_html_examples to build
    for item in readdir(examples_src)
        src_path = joinpath(examples_src, item)
        dest_path = joinpath(build_dir, item)
        cp(src_path, dest_path, force=true)
    end
    println("Copied HTML examples to docs/build/")
else
    @warn "Generated HTML examples directory not found at: $examples_src"
end

# Deploy documentation
deploydocs(;
    repo="github.com/s-baumann/JSPlots.jl",
    devbranch="main",
)
