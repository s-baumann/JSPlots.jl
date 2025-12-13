using Test
using JSPlots
using DataFrames

@testset "TextBlock" begin
    @testset "Basic creation" begin
        block = TextBlock("<h1>Test Header</h1><p>Test paragraph</p>")
        @test occursin("Test Header", block.appearance_html)
        @test occursin("Test paragraph", block.appearance_html)
        @test block.functional_html == ""
        @test isempty(block.images)
    end

    @testset "With HTML elements" begin
        html = """
        <h2>Section</h2>
        <ul>
            <li>Item 1</li>
            <li>Item 2</li>
        </ul>
        <table>
            <tr><td>Cell</td></tr>
        </table>
        """
        block = TextBlock(html)
        @test occursin("<h2>Section</h2>", block.appearance_html)
        @test occursin("<ul>", block.appearance_html)
        @test occursin("<table>", block.appearance_html)
    end

    @testset "Empty content" begin
        block = TextBlock("")
        @test block.appearance_html != ""
        @test occursin("textblock-content", block.appearance_html)
    end

    @testset "Special characters" begin
        block = TextBlock("<p>Special &lt;chars&gt; &amp; symbols</p>")
        @test occursin("&lt;chars&gt;", block.appearance_html)
        @test occursin("&amp;", block.appearance_html)
    end

    @testset "With images - embedded formats" begin
        mktempdir() do tmpdir
            # Create test image files
            img_path = joinpath(tmpdir, "test.png")
            write(img_path, UInt8[137, 80, 78, 71])  # PNG header

            # Create TextBlock with image
            block = TextBlock(
                "<h2>Plot</h2><p>{{IMAGE:plot1}}</p>",
                Dict("plot1" => img_path)
            )
            @test haskey(block.images, "plot1")
            @test block.images["plot1"] == img_path

            # Test embedded format
            html = JSPlots.generate_textblock_html(block, :csv_embedded, tmpdir)
            @test occursin("data:image/png;base64,", html)
            @test occursin("<h2>Plot</h2>", html)
            @test !occursin("{{IMAGE:plot1}}", html)
        end
    end

    @testset "With images - external formats" begin
        mktempdir() do tmpdir
            # Create test image file
            img_path = joinpath(tmpdir, "test.jpg")
            write(img_path, UInt8[255, 216, 255, 224])  # JPEG header

            # Create TextBlock with image
            block = TextBlock(
                "<p>Image: {{IMAGE:photo}}</p>",
                Dict("photo" => img_path)
            )

            # Test external format
            html = JSPlots.generate_textblock_html(block, :parquet, tmpdir)
            @test occursin("pictures/photo.jpg", html)
            @test occursin("<img src", html)
            @test !occursin("{{IMAGE:photo}}", html)
            @test isdir(joinpath(tmpdir, "pictures"))
            @test isfile(joinpath(tmpdir, "pictures", "photo.jpg"))
        end
    end

    @testset "SVG embedding" begin
        mktempdir() do tmpdir
            # Create test SVG file
            svg_path = joinpath(tmpdir, "test.svg")
            svg_content = """<svg width="100" height="100"><circle cx="50" cy="50" r="40"/></svg>"""
            write(svg_path, svg_content)

            block = TextBlock(
                "<div>{{IMAGE:svg1}}</div>",
                Dict("svg1" => svg_path)
            )

            # Test embedded SVG
            html = JSPlots.generate_textblock_html(block, :json_embedded, tmpdir)
            @test occursin("<svg", html)
            @test occursin("circle", html)
            @test !occursin("base64", html)
        end
    end

    @testset "Multiple images" begin
        mktempdir() do tmpdir
            img1 = joinpath(tmpdir, "img1.png")
            img2 = joinpath(tmpdir, "img2.png")
            write(img1, UInt8[137, 80, 78, 71])
            write(img2, UInt8[137, 80, 78, 71])

            block = TextBlock(
                "<p>First: {{IMAGE:img1}}, Second: {{IMAGE:img2}}</p>",
                Dict("img1" => img1, "img2" => img2)
            )

            html = JSPlots.generate_textblock_html(block, :csv_embedded, tmpdir)
            @test occursin("data:image/png;base64,", html)
            @test !occursin("{{IMAGE:img1}}", html)
            @test !occursin("{{IMAGE:img2}}", html)
        end
    end

    @testset "Error handling - missing image file" begin
        @test_throws Exception TextBlock(
            "<p>{{IMAGE:missing}}</p>",
            Dict("missing" => "/nonexistent/path.png")
        )
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            # Create TextBlock
            block1 = TextBlock("<h1>Introduction</h1><p>This is the intro.</p>")
            block2 = TextBlock("<h2>Conclusion</h2><p>Summary here.</p>")

            # Create page with multiple TextBlocks
            page = JSPlotPage(Dict{Symbol, DataFrame}(), [block1, block2])

            # Generate HTML
            outfile = joinpath(tmpdir, "textblocks.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Introduction", content)
            @test occursin("Conclusion", content)
            @test occursin("textblock-content", content)
        end
    end

    @testset "Dependencies" begin
        block = TextBlock("<p>Test</p>")
        @test isempty(JSPlots.dependencies(block))
    end
end
