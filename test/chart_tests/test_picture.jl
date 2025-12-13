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

        # Create a test PNG
        test_png_small = joinpath(tmpdir, "test.png")
        # Create a minimal valid PNG (1x1 pixel, white)
        png_data = UInt8[
            0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,  # PNG signature
            0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  # 1x1 dimensions
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,  # IDAT chunk
            0x54, 0x08, 0xd7, 0x63, 0xf8, 0xff, 0xff, 0x3f,
            0x00, 0x05, 0xfe, 0x02, 0xfe, 0xdc, 0xcc, 0x59,
            0xe7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,  # IEND chunk
            0x44, 0xae, 0x42, 0x60, 0x82
        ]
        write(test_png_small, png_data)

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

        @testset "Dependencies method" begin
            pic = Picture(:dep_test, test_png)
            deps = JSPlots.dependencies(pic)
            @test deps == []
            @test length(deps) == 0
        end

        @testset "PNG format with embedded data" begin
            pic = Picture(:png_embedded, test_png_small)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_embedded)
            outfile = joinpath(tmpdir, "png_embedded.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("data:image/png;base64", content)
            @test occursin("png_embedded", content)
        end

        @testset "PNG format with external data" begin
            pic = Picture(:png_external, test_png_small)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_external)
            outfile = joinpath(tmpdir, "png_external.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "png_external")
            pictures_dir = joinpath(project_dir, "pictures")
            @test isfile(joinpath(pictures_dir, "png_external.png"))

            content = read(joinpath(project_dir, "png_external.html"), String)
            @test occursin("pictures/png_external.png", content)
        end

        @testset "SVG format with external data" begin
            pic = Picture(:svg_external, test_svg)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_external)
            outfile = joinpath(tmpdir, "svg_external.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "svg_external")
            pictures_dir = joinpath(project_dir, "pictures")
            @test isfile(joinpath(pictures_dir, "svg_external.svg"))

            content = read(joinpath(project_dir, "svg_external.html"), String)
            @test occursin("pictures/svg_external.svg", content)
        end

        @testset "JPEG format variations" begin
            # Test both .jpg and .jpeg extensions
            for ext in ["jpg", "jpeg"]
                test_jpeg = joinpath(tmpdir, "test.$ext")
                cp(test_png, test_jpeg, force=true)

                pic = Picture(Symbol("jpeg_$ext"), test_jpeg)
                page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_embedded)
                outfile = joinpath(tmpdir, "jpeg_$ext.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("data:image/jpeg;base64", content)
            end
        end

        @testset "Custom save function with SVG format" begin
            mock_chart = Dict(:svg => true)
            save_func = (obj, path) -> write(path, """
                <svg width="50" height="50">
                  <circle cx="25" cy="25" r="20" fill="blue"/>
                </svg>
            """)

            pic = Picture(:custom_svg, mock_chart, save_func; format=:svg)
            @test pic.is_temp == true
            @test isfile(pic.image_path)
            @test occursin("<svg", read(pic.image_path, String))
        end

        @testset "Custom save function with JPEG format" begin
            mock_chart = Dict(:jpeg => true)
            save_func = (obj, path) -> write(path, "mock_jpeg_data")

            pic = Picture(:custom_jpeg, mock_chart, save_func; format=:jpeg)
            @test pic.chart_title == :custom_jpeg
            @test pic.is_temp == true
            @test endswith(pic.image_path, ".jpeg")
        end

        @testset "Custom save function with JPG format" begin
            mock_chart = Dict(:jpg => true)
            save_func = (obj, path) -> write(path, "mock_jpg_data")

            pic = Picture(:custom_jpg, mock_chart, save_func; format=:jpg)
            @test pic.is_temp == true
            @test endswith(pic.image_path, ".jpg")
        end

        @testset "Save function error handling" begin
            mock_chart = Dict(:data => [1, 2, 3])
            bad_save_func = (obj, path) -> error("Save failed!")

            @test_throws ErrorException Picture(:bad_save, mock_chart, bad_save_func; format=:png)
        end

        @testset "Save function that doesn't create file" begin
            mock_chart = Dict(:data => [1, 2, 3])
            no_file_func = (obj, path) -> nothing  # Does nothing

            @test_throws ErrorException Picture(:no_file, mock_chart, no_file_func; format=:png)
        end

        @testset "Notes rendering in HTML" begin
            notes_text = "This is a detailed description of the picture with special chars: <>&\""
            pic = Picture(:notes_test, test_png; notes=notes_text)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic])
            outfile = joinpath(tmpdir, "notes_test.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("This is a detailed description", content)
        end

        @testset "Empty notes" begin
            pic = Picture(:no_notes, test_png)
            @test pic.notes == ""
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic])
            outfile = joinpath(tmpdir, "no_notes.html")
            create_html(page, outfile)
            @test isfile(outfile)
        end

        @testset "JSON embedded format" begin
            pic = Picture(:json_embedded, test_png)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:json_embedded)
            outfile = joinpath(tmpdir, "json_embedded.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("data:image/jpeg;base64", content)
        end

        @testset "JSON external format" begin
            pic = Picture(:json_external, test_png)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:json_external)
            outfile = joinpath(tmpdir, "json_external.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "json_external")
            pictures_dir = joinpath(project_dir, "pictures")
            @test isdir(pictures_dir)
            @test isfile(joinpath(pictures_dir, "json_external.jpeg"))
        end

        @testset "Parquet format" begin
            pic = Picture(:parquet_format, test_png)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:parquet)
            outfile = joinpath(tmpdir, "parquet_format.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "parquet_format")
            pictures_dir = joinpath(project_dir, "pictures")
            @test isdir(pictures_dir)
            @test isfile(joinpath(pictures_dir, "parquet_format.jpeg"))
        end

        @testset "Chart title in HTML" begin
            pic = Picture(:title_test, test_png)
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic])
            outfile = joinpath(tmpdir, "title_test.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("title_test", content)
        end

        @testset "Mixed formats on same page" begin
            pic1 = Picture(:mixed1, test_png)
            pic2 = Picture(:mixed2, test_svg)
            pic3 = Picture(:mixed3, test_png_small)

            page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic1, pic2, pic3])
            outfile = joinpath(tmpdir, "mixed_formats.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("mixed1", content)
            @test occursin("mixed2", content)
            @test occursin("mixed3", content)
        end

        @testset "Temporary file flag" begin
            # From file path - not temp
            pic1 = Picture(:not_temp, test_png)
            @test pic1.is_temp == false

            # From save function - is temp
            pic2 = Picture(:is_temp, Dict(), (o, p) -> write(p, "data"); format=:png)
            @test pic2.is_temp == true
        end
    end
end
