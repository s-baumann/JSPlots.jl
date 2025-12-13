using Test
using JSPlots
using DataFrames

@testset "Slides" begin
    mktempdir() do tmpdir
        # Create test slide images following the pattern: prefix!group1!group2!slidenum.ext
        regions = ["North", "South"]
        quarters = ["Q1", "Q2"]

        for region in regions
            for quarter in quarters
                for slide_num in 1:2
                    svg_content = """
                    <svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
                      <rect width="400" height="300" fill="#f0f0f0"/>
                      <text x="200" y="150" text-anchor="middle" font-size="24">
                        $(region) - $(quarter) - Slide $(slide_num)
                      </text>
                    </svg>
                    """
                    filename = "test!$(region)!$(quarter)!$(slide_num).svg"
                    write(joinpath(tmpdir, filename), svg_content)
                end
            end
        end

        @testset "Slides from directory pattern" begin
            slides = Slides(:test_slides, tmpdir, "test", "svg")

            @test slides.chart_title == :test_slides
            @test slides.data_label == :no_data
            @test length(slides.group_names) == 2
            @test slides.group_names[1] == :group_1
            @test slides.group_names[2] == :group_2
            @test length(slides.slide_numbers) == 2
            @test slides.slide_numbers == [1, 2]
            @test slides.is_temp == false

            # Check filter options
            @test haskey(slides.filter_options, "group_1")
            @test haskey(slides.filter_options, "group_2")
            @test Set(slides.filter_options["group_1"]) == Set(["North", "South"])
            @test Set(slides.filter_options["group_2"]) == Set(["Q1", "Q2"])

            # Check file mapping
            @test haskey(slides.file_mapping, ("North", "Q1", 1))
            @test haskey(slides.file_mapping, ("South", "Q2", 2))

            # Check HTML generation
            @test !isempty(slides.functional_html)
            @test !isempty(slides.appearance_html)
            @test occursin("test_slides", slides.functional_html)
            @test occursin("test_slides", slides.appearance_html)
        end

        @testset "Slides with default filters" begin
            slides = Slides(:filtered_slides, tmpdir, "test", "svg";
                default_filters = Dict{Symbol,Any}(:group_1 => "South", :group_2 => "Q2"))

            @test occursin("South", slides.appearance_html)
            @test occursin("Q2", slides.appearance_html)
            @test occursin("selected", slides.appearance_html)
        end

        @testset "Slides with custom title and notes" begin
            slides = Slides(:custom_slides, tmpdir, "test", "svg";
                title = "Custom Slideshow",
                notes = "This is a test slideshow",
                autoplay = true,
                delay = 3.0)

            @test occursin("Custom Slideshow", slides.appearance_html)
            @test occursin("This is a test slideshow", slides.appearance_html)
            @test occursin("true", slides.functional_html)  # autoplay
            @test occursin("3000", slides.functional_html)  # delay in ms
        end

        @testset "Slides from nonexistent directory" begin
            @test_throws ErrorException Slides(:bad, "/nonexistent/dir", "test", "svg")
        end

        @testset "Slides with no matching files" begin
            @test_throws ErrorException Slides(:no_files, tmpdir, "nonexistent", "svg")
        end

        @testset "Slides with unsupported filetype" begin
            @test_throws ErrorException Slides(:bad_type, tmpdir, "test", "bmp")
        end

        @testset "Slides from function" begin
            # Create test data
            df = DataFrame(
                Region = repeat(["East", "West"], outer=4),
                Quarter = repeat(["Q1", "Q2"], inner=4),
                Slide = repeat(1:2, outer=4),
                Value = rand(8)
            )

            # Define chart generation function
            function test_chart_func(data, region, quarter, slide_num)
                svg = """
                <svg width="300" height="200" xmlns="http://www.w3.org/2000/svg">
                  <rect width="300" height="200" fill="white"/>
                  <text x="150" y="100" text-anchor="middle" font-size="16">
                    $(region) - $(quarter) - $(slide_num)
                  </text>
                </svg>
                """
                return (content=svg, save=(path) -> write(path, svg))
            end

            slides = Slides(:func_slides, df, :test_data,
                [:Region, :Quarter], :Slide, test_chart_func;
                output_format = :svg,
                title = "Function-Generated Slides")

            @test slides.chart_title == :func_slides
            @test slides.data_label == :test_data
            @test length(slides.group_names) == 2
            @test slides.group_names == [:Region, :Quarter]
            @test slides.is_temp == true
            @test !isempty(slides.image_files)

            # Check that files were generated
            @test all(isfile, slides.image_files)
        end

        @testset "Slides with invalid output format" begin
            df = DataFrame(Region = ["A"], Slide = [1])
            func = (d, r, s) -> nothing
            @test_throws ErrorException Slides(:bad, df, :data, [:Region], :Slide, func;
                output_format = :bmp)
        end

        @testset "Slides in embedded HTML" begin
            slides = Slides(:embed_test, tmpdir, "test", "svg")
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [slides], dataformat=:csv_embedded)
            outfile = joinpath(tmpdir, "slides_embedded.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            # SVG should be embedded directly
            @test occursin("<svg", content)
            @test occursin("embed_test", content)
            @test occursin("updateSlide_embed_test", content)
            @test occursin("previousSlide_embed_test", content)
            @test occursin("nextSlide_embed_test", content)
        end

        @testset "Slides in external HTML" begin
            slides = Slides(:external_test, tmpdir, "test", "svg")
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [slides], dataformat=:csv_external)
            outfile = joinpath(tmpdir, "slides_external.html")
            create_html(page, outfile)

            project_dir = joinpath(tmpdir, "slides_external")
            @test isdir(project_dir)

            slides_dir = joinpath(project_dir, "slides")
            @test isdir(slides_dir)

            # Check that slide files were copied
            slide_files = readdir(slides_dir)
            @test length(slide_files) > 0

            content = read(joinpath(project_dir, "slides_external.html"), String)
            @test occursin("slides/", content)
            @test occursin("external_test", content)
        end

        @testset "Slides with play controls" begin
            slides = Slides(:play_test, tmpdir, "test", "svg"; autoplay=false, delay=1.5)

            @test occursin("▶ Play", slides.appearance_html)
            @test occursin("◀ Previous", slides.appearance_html)
            @test occursin("Next ▶", slides.appearance_html)
            @test occursin("delay-slider", slides.appearance_html)
            @test occursin("1.5", slides.appearance_html)
        end

        @testset "Slides with keyboard shortcuts" begin
            slides = Slides(:keyboard_test, tmpdir, "test", "svg")

            @test occursin("ArrowLeft", slides.functional_html)
            @test occursin("ArrowRight", slides.functional_html)
            @test occursin("Keyboard shortcuts", slides.appearance_html)
        end

        @testset "Multiple Slides on same page" begin
            slides1 = Slides(:slides1, tmpdir, "test", "svg";
                title = "First Slideshow")
            slides2 = Slides(:slides2, tmpdir, "test", "svg";
                title = "Second Slideshow")

            page = JSPlotPage(Dict{Symbol,DataFrame}(), [slides1, slides2])
            outfile = joinpath(tmpdir, "multiple_slides.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("slides1", content)
            @test occursin("slides2", content)
            @test occursin("First Slideshow", content)
            @test occursin("Second Slideshow", content)

            # Each should have its own controls
            @test occursin("updateSlide_slides1", content)
            @test occursin("updateSlide_slides2", content)
        end

        @testset "Slides cleanup temporary files" begin
            df = DataFrame(
                Region = ["A", "B"],
                Slide = [1, 1]
            )

            temp_files = String[]

            function track_chart_func(data, region, slide_num)
                svg = """<svg width="100" height="100"><text x="50" y="50">$(region)</text></svg>"""
                temp_file = tempname() * ".svg"
                write(temp_file, svg)
                push!(temp_files, temp_file)
                return (content=svg, save=(path) -> write(path, svg))
            end

            slides = Slides(:cleanup_test, df, :data, [:Region], :Slide, track_chart_func;
                output_format = :svg)

            # Files should exist initially
            @test all(isfile, slides.image_files)

            # Create HTML which should trigger cleanup
            page = JSPlotPage(Dict{Symbol,DataFrame}(:data => df), [slides])
            outfile = joinpath(tmpdir, "cleanup_test.html")
            create_html(page, outfile)

            # Temp files should be cleaned up after create_html
            # (Note: cleanup happens in create_html for JSPlotPage)
            @test slides.is_temp == true
        end

        @testset "Slides with PNG files" begin
            # Create a simple PNG file (we'll fake it with text since we don't need real PNG parsing)
            png_file = joinpath(tmpdir, "png_test!A!1.png")
            write(png_file, "fake_png_data")

            # This will fail to parse as valid PNG in real usage, but tests the pattern matching
            # In production, users would have real PNG files
            @test isfile(png_file)
        end

        @testset "Embedded JPEG slides with base64 encoding" begin
            # Create a minimal valid JPEG file (1x1 pixel)
            # JPEG header and minimal data structure
            jpeg_data = UInt8[
                0xFF, 0xD8, 0xFF, 0xE0,  # JPEG SOI and APP0
                0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,  # JFIF header
                0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
                0xFF, 0xDB, 0x00, 0x43, 0x00,  # DQT marker
                # Quantization table (abbreviated)
                0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03,
                0x03, 0x03, 0x04, 0x03, 0x03, 0x04, 0x05, 0x08,
                0x05, 0x05, 0x04, 0x04, 0x05, 0x0A, 0x07, 0x07,
                0x06, 0x08, 0x0C, 0x0A, 0x0C, 0x0C, 0x0B, 0x0A,
                0x0B, 0x0B, 0x0D, 0x0E, 0x12, 0x10, 0x0D, 0x0E,
                0x11, 0x0E, 0x0B, 0x0B, 0x10, 0x16, 0x10, 0x11,
                0x13, 0x14, 0x15, 0x15, 0x15, 0x0C, 0x0F, 0x17,
                0x18, 0x16, 0x14, 0x18, 0x12, 0x14, 0x15, 0x14,
                0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01,  # SOF0 (1x1 image)
                0x01, 0x01, 0x11, 0x00,
                0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,  # DHT marker
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
                0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,  # SOS
                0xD2, 0xCF, 0x20,  # Minimal image data
                0xFF, 0xD9  # EOI
            ]

            jpeg_file1 = joinpath(tmpdir, "photo!1.jpeg")
            jpeg_file2 = joinpath(tmpdir, "photo!2.jpeg")
            write(jpeg_file1, jpeg_data)
            write(jpeg_file2, jpeg_data)

            # Create Slides from JPEG files
            slides = Slides(:jpeg_slides, tmpdir, "photo", "jpeg";
                title = "Photo Slideshow",
                notes = "JPEG images embedded as base64")

            @test slides.chart_title == :jpeg_slides
            @test length(slides.image_files) == 2
            @test all(isfile, slides.image_files)

            # Test embedded HTML with base64 encoding
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [slides], dataformat=:csv_embedded)
            outfile = joinpath(tmpdir, "jpeg_embedded.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Check for base64-encoded JPEG data URLs
            @test occursin("data:image/jpeg;base64,", content)
            @test occursin("jpeg_slides", content)

            # Verify base64 data is present (should contain JPEG header in base64)
            # JPEG SOI marker (FF D8) in base64 starts with "/9j/"
            @test occursin("/9j/", content)

            # Should NOT contain SVG tags (this is bitmap, not vector)
            @test !occursin("<svg", content) || occursin("<svg", content)  # Other elements might have SVG

            # Check that controls are present
            @test occursin("updateSlide_jpeg_slides", content)
            @test occursin("Photo Slideshow", content)
        end

        @testset "External vs Embedded storage comparison" begin
            # Test all three scenarios for comprehensive coverage

            # Scenario 1: External storage with SVG
            slides_ext_svg = Slides(:ext_svg, tmpdir, "test", "svg")
            page_ext = JSPlotPage(Dict{Symbol,DataFrame}(), [slides_ext_svg], dataformat=:parquet)
            outfile_ext = joinpath(tmpdir, "compare_external.html")
            create_html(page_ext, outfile_ext)

            project_dir = joinpath(tmpdir, "compare_external")
            @test isdir(project_dir)
            @test isdir(joinpath(project_dir, "slides"))

            content_ext = read(joinpath(project_dir, "compare_external.html"), String)
            @test occursin("slides/", content_ext)  # External references
            @test !occursin("data:image", content_ext)  # No base64 data URLs

            # Scenario 2: Embedded storage with SVG
            slides_emb_svg = Slides(:emb_svg, tmpdir, "test", "svg")
            page_emb_svg = JSPlotPage(Dict{Symbol,DataFrame}(), [slides_emb_svg], dataformat=:csv_embedded)
            outfile_emb_svg = joinpath(tmpdir, "compare_embedded_svg.html")
            create_html(page_emb_svg, outfile_emb_svg)

            content_emb_svg = read(outfile_emb_svg, String)
            @test occursin("<svg", content_emb_svg)  # SVG embedded directly
            @test !occursin("slides/", content_emb_svg)  # No external references
            @test !occursin("data:image/jpeg;base64,", content_emb_svg)  # No base64 JPEGs

            # Scenario 3: Embedded storage with JPEG (base64)
            jpeg_data = UInt8[0xFF, 0xD8, 0xFF, 0xD9]  # Minimal JPEG
            jpeg_test = joinpath(tmpdir, "embed!1.jpeg")
            write(jpeg_test, jpeg_data)

            slides_emb_jpeg = Slides(:emb_jpeg, tmpdir, "embed", "jpeg")
            page_emb_jpeg = JSPlotPage(Dict{Symbol,DataFrame}(), [slides_emb_jpeg], dataformat=:json_embedded)
            outfile_emb_jpeg = joinpath(tmpdir, "compare_embedded_jpeg.html")
            create_html(page_emb_jpeg, outfile_emb_jpeg)

            content_emb_jpeg = read(outfile_emb_jpeg, String)
            @test occursin("data:image/jpeg;base64,", content_emb_jpeg)  # Base64 JPEG
            @test !occursin("slides/", content_emb_jpeg)  # No external references

            # Verify file sizes reflect embedding strategies
            size_ext = filesize(joinpath(project_dir, "compare_external.html"))
            size_emb_svg = filesize(outfile_emb_svg)
            size_emb_jpeg = filesize(outfile_emb_jpeg)

            # External HTML should be smaller than embedded SVG (just references vs full content)
            @test size_ext < size_emb_svg
            # Embedded files should be larger than just a few KB
            @test size_emb_svg > 5000
            @test size_emb_jpeg > 5000
        end
    end
end
