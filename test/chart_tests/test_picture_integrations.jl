using Test
using JSPlots
using DataFrames
using VegaLite
using Plots
using GLMakie

@testset "Picture Plotting Library Integrations" begin
    mktempdir() do tmpdir

        @testset "VegaLite Integration" begin
            # Create a simple VegaLite plot
            data = DataFrame(x = 1:10, y = rand(10))
            vl_plot = data |> @vlplot(:point, x=:x, y=:y, width=400, height=300)

            # Test PNG format
            pic_png = Picture(:vegalite_png, vl_plot; format=:png, notes="VegaLite PNG")
            @test pic_png.chart_title == :vegalite_png
            @test pic_png.notes == "VegaLite PNG"
            @test pic_png.is_temp == true
            @test isfile(pic_png.image_path)
            @test endswith(pic_png.image_path, ".png")

            # Test SVG format (recommended for VegaLite)
            pic_svg = Picture(:vegalite_svg, vl_plot; format=:svg, notes="VegaLite SVG")
            @test pic_svg.chart_title == :vegalite_svg
            @test pic_svg.is_temp == true
            @test isfile(pic_svg.image_path)
            @test endswith(pic_svg.image_path, ".svg")

            # Test that SVG file contains valid SVG
            svg_content = read(pic_svg.image_path, String)
            @test occursin("<svg", svg_content)
            @test occursin("</svg>", svg_content)

            # Test creating HTML with VegaLite plot (embedded)
            page_embedded = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_svg], dataformat=:csv_embedded)
            outfile_embedded = joinpath(tmpdir, "vegalite_embedded.html")
            create_html(page_embedded, outfile_embedded)
            @test isfile(outfile_embedded)

            content = read(outfile_embedded, String)
            @test occursin("vegalite_svg", content)
            @test occursin("<svg", content)  # SVG should be embedded directly

            # Test creating HTML with VegaLite plot (external)
            page_external = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_png], dataformat=:csv_external)
            outfile_external = joinpath(tmpdir, "vegalite_external.html")
            create_html(page_external, outfile_external)

            project_dir = joinpath(tmpdir, "vegalite_external")
            @test isdir(project_dir)
            @test isfile(joinpath(project_dir, "pictures", "vegalite_png.png"))

        end

        @testset "Plots.jl Integration" begin
            # Create a simple Plots.jl plot
            plots_plot = Plots.plot(1:10, rand(10),
                                    title="Test Plot",
                                    xlabel="X",
                                    ylabel="Y",
                                    linewidth=2)

            # Test PNG format
            pic_png = Picture(:plots_png, plots_plot; format=:png, notes="Plots.jl PNG")
            @test pic_png.chart_title == :plots_png
            @test pic_png.notes == "Plots.jl PNG"
            @test pic_png.is_temp == true
            @test isfile(pic_png.image_path)
            @test endswith(pic_png.image_path, ".png")

            # Test SVG format
            pic_svg = Picture(:plots_svg, plots_plot; format=:svg, notes="Plots.jl SVG")
            @test pic_svg.chart_title == :plots_svg
            @test pic_svg.is_temp == true
            @test isfile(pic_svg.image_path)
            @test endswith(pic_svg.image_path, ".svg")

            # Test creating HTML with Plots.jl plot
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_png], dataformat=:csv_embedded)
            outfile = joinpath(tmpdir, "plots_embedded.html")
            create_html(page, outfile)
            @test isfile(outfile)

            content = read(outfile, String)
            @test occursin("plots_png", content)
            @test occursin("data:image/png;base64", content)

            # Test external format
            page_ext = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_svg], dataformat=:csv_external)
            outfile_ext = joinpath(tmpdir, "plots_external.html")
            create_html(page_ext, outfile_ext)

            project_dir = joinpath(tmpdir, "plots_external")
            @test isdir(project_dir)
            @test isfile(joinpath(project_dir, "pictures", "plots_svg.svg"))
        end

        @testset "GLMakie Integration" begin
            # Create a simple GLMakie figure
            fig = Figure(size = (600, 400))
            ax = Axis(fig[1, 1], title = "Test Makie Plot", xlabel = "X", ylabel = "Y")
            GLMakie.lines!(ax, 1:10, rand(10), linewidth = 3, color = :blue)

            # Test PNG format
            pic_png = Picture(:makie_png, fig; format=:png, notes="Makie PNG")
            @test pic_png.chart_title == :makie_png
            @test pic_png.notes == "Makie PNG"
            @test pic_png.is_temp == true
            @test isfile(pic_png.image_path)
            @test endswith(pic_png.image_path, ".png")

            # Test with another plot type
            fig2 = Figure(size = (600, 400))
            ax2 = Axis(fig2[1, 1], title = "Scatter Test")
            GLMakie.scatter!(ax2, 1:10, rand(10))
            pic_scatter = Picture(:makie_scatter, fig2; format=:png, notes="Makie Scatter")
            @test pic_scatter.chart_title == :makie_scatter
            @test pic_scatter.is_temp == true
            @test isfile(pic_scatter.image_path)
            @test endswith(pic_scatter.image_path, ".png")

            # Test creating HTML with Makie plot
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_png], dataformat=:csv_embedded)
            outfile = joinpath(tmpdir, "makie_embedded.html")
            create_html(page, outfile)
            @test isfile(outfile)

            content = read(outfile, String)
            @test occursin("makie_png", content)
            @test occursin("data:image/png;base64", content)

            # Test external format
            page_ext = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_scatter], dataformat=:csv_external)
            outfile_ext = joinpath(tmpdir, "makie_external.html")
            create_html(page_ext, outfile_ext)

            project_dir = joinpath(tmpdir, "makie_external")
            @test isdir(project_dir)
            @test isfile(joinpath(project_dir, "pictures", "makie_scatter.png"))

        end

        @testset "Mixed Plotting Libraries on Same Page" begin
            # Create plots from different libraries
            vl_data = DataFrame(x = 1:5, y = [1, 2, 3, 2, 1])
            vl_plot = vl_data |> @vlplot(:line, x=:x, y=:y, width=300, height=200)
            pic_vl = Picture(:mixed_vl, vl_plot; format=:svg)

            plots_plot = Plots.plot(1:5, [2, 4, 3, 5, 4], marker=:circle)
            pic_plots = Picture(:mixed_plots, plots_plot; format=:png)

            fig = Figure(size = (400, 300))
            ax = Axis(fig[1, 1])
            GLMakie.barplot!(ax, 1:5, [3, 1, 4, 1, 5])
            pic_makie = Picture(:mixed_makie, fig; format=:png)

            # Create page with all three
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic_vl, pic_plots, pic_makie])
            outfile = joinpath(tmpdir, "mixed_libraries.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("mixed_vl", content)
            @test occursin("mixed_plots", content)
            @test occursin("mixed_makie", content)
        end

        @testset "Different Formats from Same Library" begin
            # Test that we can create multiple pictures with different formats
            vl_data = DataFrame(a = ["A", "B", "C"], b = [1, 2, 3])
            vl_plot = vl_data |> @vlplot(:bar, x=:a, y=:b)

            pic1 = Picture(:same_vl_png, vl_plot; format=:png)
            pic2 = Picture(:same_vl_svg, vl_plot; format=:svg)

            @test endswith(pic1.image_path, ".png")
            @test endswith(pic2.image_path, ".svg")
            @test all(isfile.([pic1.image_path, pic2.image_path]))
        end

        @testset "Notes Rendering with Library Plots" begin
            vl_data = DataFrame(x = 1:3, y = [1, 2, 3])
            vl_plot = vl_data |> @vlplot(:point, x=:x, y=:y)
            notes_text = "This is a VegaLite plot showing some data"
            pic = Picture(:notes_vl, vl_plot; format=:svg, notes=notes_text)

            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic])
            outfile = joinpath(tmpdir, "notes_vl.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin(notes_text, content)
        end

        @testset "Parquet Format with Library Plots" begin
            plots_plot = Plots.scatter(1:10, rand(10))
            pic = Picture(:parquet_plots, plots_plot; format=:png)

            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:parquet)
            outfile = joinpath(tmpdir, "parquet_plots.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "parquet_plots")
            @test isdir(joinpath(project_dir, "pictures"))
            @test isfile(joinpath(project_dir, "pictures", "parquet_plots.png"))
        end

        @testset "JSON Embedded with Library Plots" begin
            fig = Figure()
            ax = Axis(fig[1, 1])
            GLMakie.lines!(ax, 1:5, [1, 4, 2, 5, 3])
            pic = Picture(:json_makie, fig; format=:png)

            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:json_embedded)
            outfile = joinpath(tmpdir, "json_makie.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("data:image/png;base64", content)
        end

        @testset "Verify Temp Files are Created" begin
            # All auto-detected library plots should create temp files
            vl_data = DataFrame(x = [1, 2], y = [1, 2])
            vl_plot = vl_data |> @vlplot(:line, x=:x, y=:y)
            plots_plot = Plots.plot([1, 2], [1, 2])
            fig = Figure()

            pic_vl = Picture(:temp_vl, vl_plot; format=:png)
            pic_plots = Picture(:temp_plots, plots_plot; format=:png)
            pic_makie = Picture(:temp_makie, fig; format=:png)

            @test all([pic_vl.is_temp, pic_plots.is_temp, pic_makie.is_temp])
        end

        @testset "Type Detection Messages" begin
            # All three libraries should be detected without errors
            vl_data = DataFrame(x = [1], y = [1])
            vl_plot = vl_data |> @vlplot(:point, x=:x, y=:y)
            @test_nowarn Picture(:detect_vl, vl_plot; format=:png)

            plots_plot = Plots.plot([1], [1])
            @test_nowarn Picture(:detect_plots, plots_plot; format=:png)

            fig = Figure()
            @test_nowarn Picture(:detect_makie, fig; format=:png)
        end
    end
end
