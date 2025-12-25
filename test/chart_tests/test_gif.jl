using Test
using JSPlots
using DataFrames
using Plots

@testset "Gif" begin
    mktempdir() do tmpdir
        # Create test GIF files following the pattern: prefix!group1!group2.gif
        println("Creating test GIF files...")
        regions = ["North", "South"]
        quarters = ["Q1", "Q2"]

        for region in regions
            for quarter in quarters
                # Create a simple animated plot
                filename = "test!$(region)!$(quarter).gif"
                filepath = joinpath(tmpdir, filename)

                # Create a very simple animation (just 3 frames to keep tests fast)
                anim = @animate for i in 1:3
                    plot([0, 1], [0, i],
                         title="$region - $quarter - Frame $i",
                         legend=false,
                         xlim=(0, 1),
                         ylim=(0, 3))
                end

                # Save as GIF
                gif(anim, filepath, fps=1, show_msg=false)
            end
        end

        @testset "Gif from directory pattern" begin
            gif_chart = Gif(:test_gifs, tmpdir, "test")

            @test gif_chart.chart_title == :test_gifs
            @test gif_chart.data_label == :no_data
            @test length(gif_chart.group_names) == 2
            @test gif_chart.group_names[1] == :group_1
            @test gif_chart.group_names[2] == :group_2
            @test gif_chart.is_temp == false

            # Check filter options
            @test haskey(gif_chart.filter_options, "group_1")
            @test haskey(gif_chart.filter_options, "group_2")
            @test Set(gif_chart.filter_options["group_1"]) == Set(["North", "South"])
            @test Set(gif_chart.filter_options["group_2"]) == Set(["Q1", "Q2"])

            # Check file mapping (no slide number, just groups)
            @test haskey(gif_chart.file_mapping, ("North", "Q1"))
            @test haskey(gif_chart.file_mapping, ("South", "Q2"))
            @test haskey(gif_chart.file_mapping, ("North", "Q2"))
            @test haskey(gif_chart.file_mapping, ("South", "Q1"))

            # Check HTML generation
            @test !isempty(gif_chart.functional_html)
            @test !isempty(gif_chart.appearance_html)
            @test occursin("test_gifs", gif_chart.functional_html)
            @test occursin("test_gifs", gif_chart.appearance_html)
            @test occursin("SuperGif", gif_chart.functional_html)
            @test occursin("switchGif", gif_chart.functional_html)
        end

        @testset "Gif with default filters" begin
            gif_chart = Gif(:filtered_gifs, tmpdir, "test";
                filters = Dict{Symbol,Any}(:group_1 => "South", :group_2 => "Q2"))

            @test occursin("South", gif_chart.appearance_html)
            @test occursin("Q2", gif_chart.appearance_html)
            @test occursin("selected", gif_chart.appearance_html)
        end

        @testset "Gif with custom options" begin
            gif_chart = Gif(:custom_gifs, tmpdir, "test";
                title = "Custom GIF Viewer",
                notes = "This is a test GIF viewer",
                autoplay = true,
                delay = 2.5,
                loop = false)

            @test occursin("Custom GIF Viewer", gif_chart.appearance_html)
            @test occursin("This is a test GIF viewer", gif_chart.appearance_html)
            @test occursin("gif-controls", gif_chart.appearance_html)
            @test occursin("loop-checkbox", gif_chart.appearance_html)

            # Check for controls in HTML
            @test occursin("Prev Frame", gif_chart.appearance_html)
            @test occursin("Next Frame", gif_chart.appearance_html)
            @test occursin("Play", gif_chart.appearance_html)
            @test occursin("Frame", gif_chart.appearance_html)
            @test occursin("Speed:", gif_chart.appearance_html)
            @test occursin("Loop", gif_chart.appearance_html)
        end

        @testset "Gif keyboard shortcuts info" begin
            gif_chart = Gif(:kb_gifs, tmpdir, "test")

            @test occursin("Keyboard shortcuts", gif_chart.appearance_html)
            @test occursin("Prev Frame", gif_chart.appearance_html)
            @test occursin("Next Frame", gif_chart.appearance_html)
            @test occursin("Play/Pause", gif_chart.appearance_html)
            @test occursin("Toggle Loop", gif_chart.appearance_html)
        end

        @testset "Gif from nonexistent directory" begin
            @test_throws ErrorException Gif(:bad, "/nonexistent/dir", "test")
        end

        @testset "Gif with no matching files" begin
            empty_dir = mktempdir()
            @test_throws ErrorException Gif(:empty, empty_dir, "test")
        end

        @testset "Gif HTML generation - embedded format" begin
            gif_chart = Gif(:embed_test, tmpdir, "test")

            # Test generate_gif_html with embedded format
            html = generate_gif_html(gif_chart, :csv_embedded, "")

            @test occursin("gif-image", html)
            @test occursin("data:image/gif;base64,", html)
            @test occursin("rel:animated_src", html)
            @test occursin("gif_canvas", html)
        end

        @testset "Gif HTML generation - external format" begin
            gif_chart = Gif(:external_test, tmpdir, "test")

            # Create a temp output directory for external files
            output_dir = mktempdir()
            html = generate_gif_html(gif_chart, :parquet, output_dir)

            # Check that gifs directory was created
            gifs_dir = joinpath(output_dir, "gifs")
            @test isdir(gifs_dir)

            # Check HTML references external files
            @test occursin("gif-image", html)
            @test occursin("gifs/", html)
            @test occursin(".gif", html)

            # Check that GIF files were copied
            copied_gifs = filter(f -> endswith(f, ".gif"), readdir(gifs_dir))
            @test length(copied_gifs) == 4  # 2 regions * 2 quarters
        end

        @testset "Gif dependencies function" begin
            gif_chart = Gif(:dep_test, tmpdir, "test")
            deps = dependencies(gif_chart)

            @test deps == [:no_data]
        end

        @testset "Gif with single group" begin
            # Create GIFs with only one group level
            for i in 1:2
                filename = "single!Group$(i).gif"
                filepath = joinpath(tmpdir, filename)

                anim = @animate for frame in 1:2
                    plot([0, 1], [0, frame],
                         title="Group $i - Frame $frame",
                         legend=false)
                end

                gif(anim, filepath, fps=1, show_msg=false)
            end

            gif_chart = Gif(:single_group, tmpdir, "single")

            @test length(gif_chart.group_names) == 1
            @test gif_chart.group_names[1] == :group_1
            @test haskey(gif_chart.filter_options, "group_1")
            @test Set(gif_chart.filter_options["group_1"]) == Set(["Group1", "Group2"])
        end

        @testset "Gif create_html integration test" begin
            gif_chart = Gif(:integration_test, tmpdir, "test";
                title = "Integration Test GIF",
                notes = "Testing full HTML generation")

            # Create a page with the GIF
            page = JSPlotPage(
                Dict{Symbol, DataFrame}(),
                [gif_chart]
            )

            # Generate HTML to a temp file
            output_file = joinpath(tmpdir, "test_output.html")
            create_html(page, output_file, dataformat=:csv_embedded)

            # Check that file was created
            @test isfile(output_file)

            # Read and check HTML content
            html_content = read(output_file, String)
            @test occursin("Integration Test GIF", html_content)
            @test occursin("libgif", html_content)  # Check for libgif.js library
            @test occursin("SuperGif", html_content)
            @test occursin("switchGif", html_content)
            @test occursin("gif_canvas", html_content)
            @test occursin("data:image/gif;base64,", html_content)
        end

        @testset "Gif multiple on same page" begin
            gif1 = Gif(:gif_one, tmpdir, "test";
                title = "First GIF",
                filters = Dict{Symbol,Any}(:group_1 => "North"))

            gif2 = Gif(:gif_two, tmpdir, "test";
                title = "Second GIF",
                filters = Dict{Symbol,Any}(:group_1 => "South"))

            page = JSPlotPage(
                Dict{Symbol, DataFrame}(),
                [gif1, gif2]
            )

            output_file = joinpath(tmpdir, "multi_gif.html")
            create_html(page, output_file, dataformat=:csv_embedded)

            @test isfile(output_file)
            html_content = read(output_file, String)

            # Check both GIFs are present
            @test occursin("First GIF", html_content)
            @test occursin("Second GIF", html_content)
            @test occursin("gif_one", html_content)
            @test occursin("gif_two", html_content)

            # Check that each has its own functions
            @test occursin("switchGif_gif_one", html_content)
            @test occursin("switchGif_gif_two", html_content)
        end
    end
end

println("Gif tests completed successfully!")
