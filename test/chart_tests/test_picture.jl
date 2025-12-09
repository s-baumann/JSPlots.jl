using Test
using JSPlots

@testset "Picture" begin
    mktempdir() do tmpdir
        # Use the real example image for testing
        test_png = joinpath(@__DIR__, "..", "..", "examples", "pictures", "images.jpeg")

        # Create a test SVG
        test_svg = joinpath(tmpdir, "test.svg")
        write(test_svg, """
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
          <rect width="100" height="100" fill="red"/>
        </svg>
        """)

        @testset "Picture from file path" begin
            pic = Picture(:test_pic, test_png; notes="Test image")
            @test pic.chart_title == :test_pic
            @test pic.notes == "Test image"
            @test pic.is_temp == false
            @test isfile(pic.image_path)
        end

        @testset "Picture from non-existent file" begin
            @test_throws ErrorException Picture(:bad, "/nonexistent/path.png")
        end

        @testset "Picture with custom save function" begin
            # Mock chart object
            mock_chart = Dict(:data => [1, 2, 3])
            save_func = (obj, path) -> write(path, "mock_png_data")

            pic = Picture(:custom, mock_chart, save_func; format=:png, notes="Custom save")
            @test pic.chart_title == :custom
            @test pic.is_temp == true
            @test isfile(pic.image_path)
            @test read(pic.image_path, String) == "mock_png_data"
        end

        @testset "Picture with invalid format" begin
            mock_chart = Dict(:data => [1, 2, 3])
            @test_throws ErrorException Picture(:bad_format, mock_chart, (o, p) -> nothing; format=:pdf)
        end

        @testset "Picture in embedded HTML" begin
            pic = Picture(:embedded_pic, test_png)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_embedded)
            outfile = joinpath(tmpdir, "picture_embedded.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("data:image/jpeg;base64", content)
            @test occursin("embedded_pic", content)
        end

        @testset "Picture in external HTML" begin
            pic = Picture(:external_pic, test_png)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_external)
            outfile = joinpath(tmpdir, "picture_external.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "picture_external")
            @test isdir(project_dir)

            pictures_dir = joinpath(project_dir, "pictures")
            @test isdir(pictures_dir)
            @test isfile(joinpath(pictures_dir, "external_pic.jpeg"))

            content = read(joinpath(project_dir, "picture_external.html"), String)
            @test occursin("pictures/external_pic.jpeg", content)
        end

        @testset "Picture with SVG (embedded)" begin
            pic = Picture(:svg_pic, test_svg)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic])
            outfile = joinpath(tmpdir, "svg_embedded.html")
            create_html(page, outfile)

            content = read(outfile, String)
            # SVG should be embedded directly as XML, not base64
            @test occursin("<svg", content)
            @test occursin("</svg>", content)
            @test !occursin("data:image", content) # Not base64 encoded
        end

        @testset "Picture convenience function" begin
            pic = Picture(:convenience, test_png)
            outfile = joinpath(tmpdir, "picture_convenience.html")
            create_html(pic, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("convenience", content)
        end

        @testset "Multiple Pictures on same page" begin
            pic1 = Picture(:pic1, test_png)
            pic2 = Picture(:pic2, test_svg)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic1, pic2])
            outfile = joinpath(tmpdir, "multiple_pictures.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("pic1", content)
            @test occursin("pic2", content)
        end
    end
end
