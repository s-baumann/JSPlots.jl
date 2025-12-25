# Copy generated HTML examples to docs/src so Documenter includes them in build.
# That is all we need to do as these example htmls are the documentation
examples_src = joinpath(@__DIR__, "..", "generated_html_examples")
examples_dest = joinpath(@__DIR__, "src", "examples_html")
if isdir(examples_src)
    cp(examples_src, examples_dest, force=true)
    println("Copied HTML examples to docs/src/examples_html/")
else
    @warn "Generated HTML examples directory not found at: $examples_src"
end
