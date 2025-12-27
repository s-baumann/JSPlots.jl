using Test
using JSPlots

# Define test structs at top level
struct FakeChart end
struct UnknownChart end

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

        @testset "Auto-detect VegaLite" begin
            # This tests the auto-detection path for VegaLite
            # We can't test actual VegaLite without adding it as a dependency,
            # but we can test the error path
            @test_throws ErrorException Picture(:fake, FakeChart())
        end

        @testset "Error message for undetected type" begin
            unknown = UnknownChart()
            try
                Picture(:unknown, unknown)
                @test false  # Should not reach here
            catch e
                @test occursin("Could not auto-detect", e.msg)
                @test occursin("UnknownChart", e.msg)
            end
        end

        @testset "Generate picture HTML function" begin
            pic = Picture(:gen_test, test_png)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("gen_test", html)
            @test occursin("data:image/jpeg;base64", html)
            @test occursin("picture-container", html)
        end

        @testset "Generate SVG picture HTML" begin
            pic = Picture(:svg_gen, test_svg)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("svg_gen", html)
            @test occursin("<svg", html)
            @test !occursin("data:image", html)
        end

        @testset "Generate external picture HTML" begin
            pic = Picture(:ext_gen, test_png)
            html = JSPlots.generate_picture_html(pic, :csv_external, tmpdir)
            @test occursin("pictures/ext_gen.jpeg", html)
            @test isfile(joinpath(tmpdir, "pictures", "ext_gen.jpeg"))
        end

        @testset "Check image size function (small)" begin
            # Test with small image - should not warn
            @test_nowarn JSPlots.check_image_size(test_png_small, :csv_embedded)
        end

        @testset "Check image size function (large)" begin
            # Create a "large" image file (>5MB)
            large_file = joinpath(tmpdir, "large.png")
            # Write 6MB of data
            write(large_file, zeros(UInt8, 6_000_000))
            # Should warn for large embedded images
            @test_logs (:warn, r"Large image.*MB.*embedded") JSPlots.check_image_size(large_file, :csv_embedded)
        end

        @testset "Check image size - external format (no warning)" begin
            # Should not warn for external formats even if large
            large_file = joinpath(tmpdir, "large2.png")
            write(large_file, zeros(UInt8, 6_000_000))
            @test_nowarn JSPlots.check_image_size(large_file, :csv_external)
        end

        @testset "MIME type detection - PNG" begin
            pic = Picture(:mime_png, test_png_small)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("data:image/png;base64", html)
        end

        @testset "MIME type detection - JPEG (.jpeg)" begin
            jpeg_file = joinpath(tmpdir, "test.jpeg")
            cp(test_png, jpeg_file, force=true)
            pic = Picture(:mime_jpeg, jpeg_file)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("data:image/jpeg;base64", html)
        end

        @testset "MIME type detection - JPEG (.jpg)" begin
            jpg_file = joinpath(tmpdir, "test.jpg")
            cp(test_png, jpg_file, force=true)
            pic = Picture(:mime_jpg, jpg_file)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("data:image/jpeg;base64", html)
        end

        @testset "MIME type detection - JPEG case insensitive" begin
            jpeg_upper = joinpath(tmpdir, "test.JPEG")
            cp(test_png, jpeg_upper, force=true)
            pic = Picture(:mime_upper, jpeg_upper)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("data:image/jpeg;base64", html)
        end

        @testset "Picture template replacement" begin
            pic = Picture(:template_test, test_png; notes="Test notes content")
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("template_test", html)
            @test occursin("Test notes content", html)
            @test occursin("picture-container", html)
        end

        @testset "Picture style constant" begin
            @test occursin(".picture-container", JSPlots.PICTURE_STYLE)
            @test occursin(".picture-container h2", JSPlots.PICTURE_STYLE)
            @test occursin(".picture-container img", JSPlots.PICTURE_STYLE)
            @test occursin(".picture-container svg", JSPlots.PICTURE_STYLE)
        end

        @testset "Picture template constant" begin
            @test occursin("___PICTURE_TITLE___", JSPlots.PICTURE_TEMPLATE)
            @test occursin("___NOTES___", JSPlots.PICTURE_TEMPLATE)
            @test occursin("___IMAGE_CONTENT___", JSPlots.PICTURE_TEMPLATE)
            @test occursin("picture-container", JSPlots.PICTURE_TEMPLATE)
        end

        @testset "External format creates pictures directory" begin
            new_tmpdir = joinpath(tmpdir, "new_project")
            pic = Picture(:new_pic, test_png)
            html = JSPlots.generate_picture_html(pic, :parquet, new_tmpdir)
            @test isdir(joinpath(new_tmpdir, "pictures"))
            @test isfile(joinpath(new_tmpdir, "pictures", "new_pic.jpeg"))
        end

        @testset "Picture with different file extensions" begin
            # Test that file extension is preserved
            for (ext, expected_mime) in [(".png", "png"), (".svg", "svg"), (".jpg", "jpeg"), (".jpeg", "jpeg")]
                test_file = joinpath(tmpdir, "test_ext$ext")
                if ext == ".svg"
                    write(test_file, "<svg></svg>")
                else
                    cp(test_png, test_file, force=true)
                end
                pic = Picture(Symbol("ext$ext"), test_file)
                project = joinpath(tmpdir, "ext_test$ext")
                html = JSPlots.generate_picture_html(pic, :csv_external, project)
                @test occursin("pictures/ext$ext$ext", html)
            end
        end

        @testset "Picture HTML contains alt attribute" begin
            pic = Picture(:alt_test, test_png)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("alt=\"alt_test\"", html)
        end

        @testset "Multiple format specifications" begin
            for fmt in [:png, :svg, :jpeg, :jpg]
                mock_chart = Dict(:format => fmt)
                save_func = (obj, path) -> write(path, "test_data")
                pic = Picture(Symbol("fmt_$fmt"), mock_chart, save_func; format=fmt)
                @test endswith(pic.image_path, "." * string(fmt))
            end
        end

        @testset "Base64 encoding integrity" begin
            # Test that base64 encoding is valid
            pic = Picture(:b64_test, test_png_small)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin(r"data:image/png;base64,[A-Za-z0-9+/=]+", html)
        end

        @testset "Copy file with force=true" begin
            # Test that copying to existing file works
            pic = Picture(:copy_test, test_png)
            dest_dir = joinpath(tmpdir, "copy_dest")
            mkpath(joinpath(dest_dir, "pictures"))
            # Create existing file
            existing = joinpath(dest_dir, "pictures", "copy_test.jpeg")
            write(existing, "old content")
            # Generate HTML should overwrite
            html = JSPlots.generate_picture_html(pic, :csv_external, dest_dir)
            @test isfile(existing)
            @test read(existing) != b"old content"
        end

        @testset "Empty notes in template" begin
            pic = Picture(:empty_notes_template, test_png; notes="")
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("<p></p>", html)
        end

        @testset "Notes with special characters in template" begin
            special_notes = "Notes with <tags> & special \"chars\""
            pic = Picture(:special_notes, test_png; notes=special_notes)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            # Notes should be in the HTML (might be escaped by browser)
            @test occursin(special_notes, html)
        end

        @testset "SVG lowercase extension check" begin
            svg_upper = joinpath(tmpdir, "test.SVG")
            write(svg_upper, "<svg></svg>")
            pic = Picture(:svg_upper_ext, svg_upper)
            html = JSPlots.generate_picture_html(pic, :csv_embedded, "")
            @test occursin("<svg", html)
            @test !occursin("data:image", html)
        end

        @testset "Picture fields" begin
            pic = Picture(:fields_test, test_png; notes="Test notes")
            @test pic.chart_title == :fields_test
            @test pic.image_path == test_png
            @test pic.notes == "Test notes"
            @test pic.is_temp == false
            @test pic.appearance_html == ""
            @test pic.functional_html == ""
        end

        @testset "Internal constructor" begin
            pic = JSPlots.Picture(:internal, test_png, "Internal Title", "Internal notes", true)
            @test pic.chart_title == :internal
            @test pic.image_path == test_png
            @test pic.notes == "Internal notes"
            @test pic.is_temp == true
        end
    end
end
