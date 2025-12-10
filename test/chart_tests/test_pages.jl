using Test
using JSPlots
using DataFrames

@testset "Pages" begin
    # Create test data and pages
    test_data = DataFrame(x = 1:10, y = rand(10), category = repeat(["A", "B"], 5))

    page1 = JSPlotPage(
        Dict{Symbol,DataFrame}(:data1 => test_data),
        [TextBlock("<h2>Page 1</h2>")],
        tab_title = "First Page"
    )

    page2 = JSPlotPage(
        Dict{Symbol,DataFrame}(:data2 => test_data),
        [TextBlock("<h2>Page 2</h2>")],
        tab_title = "Second Page"
    )

    @testset "Basic creation" begin
        coverpage = JSPlotPage(
            Dict{Symbol,DataFrame}(),
            [TextBlock("<h1>Cover</h1>")],
            tab_title = "Cover"
        )

        pages = Pages(coverpage, [page1, page2])
        @test pages.coverpage.tab_title == "Cover"
        @test length(pages.pages) == 2
        @test pages.dataformat == :csv_embedded  # Default from coverpage
    end

    @testset "With explicit dataformat override" begin
        coverpage = JSPlotPage(
            Dict{Symbol,DataFrame}(),
            [TextBlock("<h1>Cover</h1>")],
            dataformat = :csv_embedded
        )

        # Override with parquet
        pages = Pages(coverpage, [page1, page2], dataformat = :parquet)
        @test pages.dataformat == :parquet
    end

    @testset "Invalid dataformat" begin
        coverpage = JSPlotPage(Dict{Symbol,DataFrame}(), [TextBlock("<h1>Cover</h1>")])
        @test_throws ErrorException Pages(coverpage, [page1], dataformat = :invalid)
    end

    @testset "Multi-page HTML generation" begin
        mktempdir() do tmpdir
            # Create pages with different content
            df1 = DataFrame(x = 1:5, y = rand(5))
            df2 = DataFrame(a = 1:5, b = rand(5))

            chart1 = LineChart(:chart1, df1, :data1; x_cols=[:x], y_cols=[:y])
            chart2 = LineChart(:chart2, df2, :data2; x_cols=[:a], y_cols=[:b])

            page1_local = JSPlotPage(
                Dict{Symbol,DataFrame}(:data1 => df1),
                [chart1],
                tab_title = "Revenue",
                page_header = "Revenue Analysis"
            )

            page2_local = JSPlotPage(
                Dict{Symbol,DataFrame}(:data2 => df2),
                [chart2],
                tab_title = "Costs",
                page_header = "Cost Analysis"
            )

            # Use sanitize_filename to create links that match the actual filenames
            links = LinkList([
                ("Revenue", "$(sanitize_filename("Revenue")).html", "Revenue analysis page"),
                ("Costs", "$(sanitize_filename("Costs")).html", "Cost analysis page")
            ])

            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Annual Report</h1>"), links],
                tab_title = "Home"
            )

            pages = Pages(coverpage, [page1_local, page2_local], dataformat = :parquet)
            outfile = joinpath(tmpdir, "index.html")
            create_html(pages, outfile)

            # Check flat project structure (all files at same level)
            project_dir = joinpath(tmpdir, "index")
            @test isdir(project_dir)

            # Check main page exists at project root
            @test isfile(joinpath(project_dir, "index.html"))

            # Check individual pages exist at same level (named after tab_title)
            @test isfile(joinpath(project_dir, "revenue.html"))
            @test isfile(joinpath(project_dir, "costs.html"))

            # Check data directory and data files
            data_dir = joinpath(project_dir, "data")
            @test isdir(data_dir)
            @test isfile(joinpath(data_dir, "data1.parquet"))
            @test isfile(joinpath(data_dir, "data2.parquet"))

            # Check launcher scripts at project root
            @test isfile(joinpath(project_dir, "open.sh"))
            @test isfile(joinpath(project_dir, "open.bat"))
            @test isfile(joinpath(project_dir, "README.md"))

            # Check coverpage content
            coverpage_content = read(joinpath(project_dir, "index.html"), String)
            @test occursin("Annual Report", coverpage_content)
            @test occursin("revenue.html", coverpage_content)
            @test occursin("costs.html", coverpage_content)
            @test occursin("Revenue analysis page", coverpage_content)

            # Check page 1 content (revenue.html)
            page1_content = read(joinpath(project_dir, "revenue.html"), String)
            @test occursin("Revenue Analysis", page1_content)
            @test occursin("chart1", page1_content)

            # Check page 2 content (costs.html)
            page2_content = read(joinpath(project_dir, "costs.html"), String)
            @test occursin("Cost Analysis", page2_content)
            @test occursin("chart2", page2_content)

            # Verify flat structure (no nested page folders)
            @test !isdir(joinpath(project_dir, "revenue"))
            @test !isdir(joinpath(project_dir, "costs"))
        end
    end

    @testset "Shared data is saved only once" begin
        mktempdir() do tmpdir
            # Both pages use the same data
            shared_df = DataFrame(x = 1:100, y = rand(100), category = rand(["A", "B"], 100))

            chart1 = LineChart(:c1, shared_df, :shared_data; x_cols=[:x], y_cols=[:y])
            chart2 = LineChart(:c2, shared_df, :shared_data; x_cols=[:x], y_cols=[:y])

            page1_shared = JSPlotPage(Dict(:shared_data => shared_df), [chart1], tab_title="P1")
            page2_shared = JSPlotPage(Dict(:shared_data => shared_df), [chart2], tab_title="P2")

            coverpage = JSPlotPage(Dict{Symbol,DataFrame}(), [TextBlock("<h1>Test</h1>")])
            pages = Pages(coverpage, [page1_shared, page2_shared], dataformat = :csv_external)

            outfile = joinpath(tmpdir, "shared.html")
            create_html(pages, outfile)

            # Check that data file exists only once
            data_dir = joinpath(tmpdir, "shared", "data")
            @test isdir(data_dir)
            data_files = readdir(data_dir)
            @test length(filter(f -> contains(f, "shared_data"), data_files)) == 1
        end
    end

    @testset "Pages with different dataformats use override" begin
        mktempdir() do tmpdir
            test_data_local = DataFrame(x = 1:10, y = rand(10))

            # Create charts that actually use the data
            chart1 = LineChart(:chart1, test_data_local, :data; x_cols=[:x], y_cols=[:y])
            chart2 = LineChart(:chart2, test_data_local, :data; x_cols=[:x], y_cols=[:y])

            # Create pages with different embedded formats
            page1_fmt = JSPlotPage(
                Dict(:data => test_data_local),
                [TextBlock("<h2>P1</h2>"), chart1],
                dataformat = :csv_embedded  # This will be overridden
            )

            page2_fmt = JSPlotPage(
                Dict(:data => test_data_local),
                [TextBlock("<h2>P2</h2>"), chart2],
                dataformat = :json_embedded  # This will be overridden
            )

            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Cover</h1>")],
                dataformat = :csv_embedded
            )

            # Override all with JSON external
            pages = Pages(coverpage, [page1_fmt, page2_fmt], dataformat = :json_external)
            outfile = joinpath(tmpdir, "override.html")
            create_html(pages, outfile)

            # All should use JSON external
            data_dir = joinpath(tmpdir, "override", "data")
            @test isdir(data_dir)
            @test isfile(joinpath(data_dir, "data.json"))
        end
    end

    @testset "Empty pages list" begin
        mktempdir() do tmpdir
            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Only Cover</h1>")],
                tab_title = "Cover Only"
            )

            # Pages with empty pages list
            pages = Pages(coverpage, JSPlotPage[])
            outfile = joinpath(tmpdir, "empty_pages.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "empty_pages")
            @test isdir(project_dir)
            @test isfile(joinpath(project_dir, "empty_pages.html"))
            # No additional page files should exist
            html_files = filter(f -> endswith(f, ".html"), readdir(project_dir))
            @test length(html_files) == 1  # Only the main file
        end
    end
end
