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

    @testset "Alternate constructor (automatic LinkList)" begin
        mktempdir() do tmpdir
            df1 = DataFrame(x = 1:5, y = rand(5))
            df2 = DataFrame(a = 1:3, b = rand(3))

            page1_alt = JSPlotPage(
                Dict(:data1 => df1),
                [LineChart(:c1, df1, :data1; x_cols=[:x], y_cols=[:y])],
                tab_title = "Page One"
            )

            page2_alt = JSPlotPage(
                Dict(:data2 => df2),
                [LineChart(:c2, df2, :data2; x_cols=[:a], y_cols=[:b])],
                tab_title = "Page Two"
            )

            # Use alternate constructor
            pages = Pages(
                [TextBlock("<h1>Home</h1><p>Welcome to the report</p>")],
                [page1_alt, page2_alt],
                tab_title = "Main Page",
                page_header = "Main Header",
                dataformat = :json_external
            )

            @test pages.coverpage.tab_title == "Main Page"
            @test pages.dataformat == :json_external
            @test length(pages.pages) == 2

            outfile = joinpath(tmpdir, "auto.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "auto")
            coverpage_content = read(joinpath(project_dir, "auto.html"), String)

            # Should have auto-generated links
            @test occursin("Page One", coverpage_content) || occursin("page_one", coverpage_content)
            @test occursin("Page Two", coverpage_content) || occursin("page_two", coverpage_content)
            @test occursin("Home", coverpage_content)
        end
    end

    @testset "sanitize_filename function" begin
        # Basic sanitization
        @test sanitize_filename("Revenue Report") == "revenue_report"
        @test sanitize_filename("Cost-Analysis") == "cost_analysis"
        @test sanitize_filename("Q1 2024") == "q1_2024"

        # Special characters
        @test sanitize_filename("Test/File\\Name") == "test_file_name"
        @test sanitize_filename("Data:Sheet.xlsx") == "data_sheet_xlsx"

        # Empty string
        @test sanitize_filename("") == "page"
        @test sanitize_filename("!!!") == "page"

        # Long names
        long_name = "A" * "B" ^ 100
        result = sanitize_filename(long_name)
        @test length(result) == 50
        @test result[1] == 'a'  # Should be lowercase

        # Unicode characters (accents are preserved, then removed by regex)
        @test sanitize_filename("Données Français") == "données_français"

        # Spaces and punctuation (leading/trailing spaces become underscores)
        @test sanitize_filename("  My   Report  ") == "__my___report__"
    end

    @testset "Page with notes and page_header" begin
        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            page_with_notes = JSPlotPage(
                Dict(:data => df),
                [TextBlock("<p>Content</p>")],
                tab_title = "Test",
                page_header = "Test Page Header",
                notes = "These are important notes about this page."
            )

            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Cover</h1>")]
            )

            pages = Pages(coverpage, [page_with_notes])
            outfile = joinpath(tmpdir, "notes.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "notes")
            page_content = read(joinpath(project_dir, "test.html"), String)

            @test occursin("Test Page Header", page_content)
            @test occursin("These are important notes", page_content)
        end
    end

    @testset "Multiple pages with same tab_title" begin
        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            # Two pages with the same title should result in same filename
            # (second one will overwrite first)
            page1_dup = JSPlotPage(
                Dict(:data1 => df),
                [TextBlock("<p>First</p>")],
                tab_title = "Same Title"
            )

            page2_dup = JSPlotPage(
                Dict(:data2 => df),
                [TextBlock("<p>Second</p>")],
                tab_title = "Same Title"
            )

            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Cover</h1>")]
            )

            pages = Pages(coverpage, [page1_dup, page2_dup])
            outfile = joinpath(tmpdir, "dup.html")

            # This should work but will overwrite - just verify no crash
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "dup")
            @test isdir(project_dir)
            @test isfile(joinpath(project_dir, "same_title.html"))
        end
    end

    @testset "Pages with complex mixed content" begin
        mktempdir() do tmpdir
            df = DataFrame(x = 1:10, y = rand(10), cat = repeat(["A", "B"], 5))

            # Create a page with multiple chart types
            mixed_page = JSPlotPage(
                Dict(:data => df),
                [
                    TextBlock("<h2>Analysis</h2>"),
                    LineChart(:line, df, :data; x_cols=[:x], y_cols=[:y]),
                    TextBlock("<p>Intermediate text</p>"),
                    PivotTable(:pivot, :data)
                ],
                tab_title = "Mixed Content",
                page_header = "Multi-Chart Page"
            )

            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Report</h1>")]
            )

            pages = Pages(coverpage, [mixed_page])
            outfile = joinpath(tmpdir, "mixed.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "mixed")
            page_content = read(joinpath(project_dir, "mixed_content.html"), String)

            @test occursin("Analysis", page_content)
            @test occursin("line", page_content)
            @test occursin("Intermediate text", page_content)
            @test occursin("pivot", page_content)
        end
    end

    @testset "OrderedDict constructor with grouped pages" begin
        using OrderedCollections

        mktempdir() do tmpdir
            df1 = DataFrame(x = 1:5, y = rand(5))
            df2 = DataFrame(x = 1:3, y = rand(3))
            df3 = DataFrame(x = 1:4, y = rand(4))

            page1 = JSPlotPage(
                Dict(:data1 => df1),
                [TextBlock("<h2>Scatter Page</h2>")],
                tab_title = "Scatter Analysis",
                notes = "Scatter plot details"
            )

            page2 = JSPlotPage(
                Dict(:data2 => df2),
                [TextBlock("<h2>Line Page</h2>")],
                tab_title = "Line Analysis",
                notes = "Line chart details"
            )

            page3 = JSPlotPage(
                Dict(:data3 => df3),
                [TextBlock("<h2>API Page</h2>")],
                tab_title = "API Reference",
                notes = "API documentation"
            )

            grouped_pages = OrderedCollections.OrderedDict(
                "Plot Types" => [page1, page2],
                "Documentation" => [page3]
            )

            pages = Pages(
                [TextBlock("<h1>Welcome</h1>"), TextBlock("<p>Grouped navigation</p>")],
                grouped_pages,
                tab_title = "Home",
                page_header = "Main Page"
            )

            @test pages.coverpage.tab_title == "Home"
            @test length(pages.pages) == 3

            outfile = joinpath(tmpdir, "grouped.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "grouped")
            coverpage_content = read(joinpath(project_dir, "grouped.html"), String)

            # Check for grouped headings
            @test occursin("Plot Types", coverpage_content)
            @test occursin("Documentation", coverpage_content)
            @test occursin("<h4", coverpage_content)

            # Check for links
            @test occursin("Scatter Analysis", coverpage_content)
            @test occursin("Line Analysis", coverpage_content)
            @test occursin("API Reference", coverpage_content)

            # Check for descriptions
            @test occursin("Scatter plot details", coverpage_content)
            @test occursin("Line chart details", coverpage_content)
            @test occursin("API documentation", coverpage_content)

            # Verify individual pages were created
            @test isfile(joinpath(project_dir, "scatter_analysis.html"))
            @test isfile(joinpath(project_dir, "line_analysis.html"))
            @test isfile(joinpath(project_dir, "api_reference.html"))
        end
    end

    @testset "OrderedDict with custom dataformat" begin
        using OrderedCollections

        mktempdir() do tmpdir
            df = DataFrame(x = 1:10, y = rand(10))

            page1 = JSPlotPage(
                Dict(:data => df),
                [TextBlock("<h2>Page 1</h2>")],
                tab_title = "First"
            )

            page2 = JSPlotPage(
                Dict(:data => df),
                [TextBlock("<h2>Page 2</h2>")],
                tab_title = "Second"
            )

            grouped = OrderedCollections.OrderedDict(
                "Section A" => [page1],
                "Section B" => [page2]
            )

            pages = Pages(
                [TextBlock("<h1>Home</h1>")],
                grouped,
                dataformat = :parquet
            )

            @test pages.dataformat == :parquet

            outfile = joinpath(tmpdir, "format.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "format")
            @test isdir(project_dir)

            # Check that pages were created
            @test isfile(joinpath(project_dir, "first.html"))
            @test isfile(joinpath(project_dir, "second.html"))
        end
    end

    @testset "OrderedDict with empty group" begin
        using OrderedCollections

        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            page1 = JSPlotPage(
                Dict(:data => df),
                [TextBlock("<p>Content</p>")],
                tab_title = "Page"
            )

            # One group empty, one with content
            grouped = OrderedCollections.OrderedDict(
                "Empty Section" => JSPlotPage[],
                "Full Section" => [page1]
            )

            pages = Pages(
                [TextBlock("<h1>Test</h1>")],
                grouped
            )

            @test length(pages.pages) == 1

            outfile = joinpath(tmpdir, "empty_group.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "empty_group")
            coverpage_content = read(joinpath(project_dir, "empty_group.html"), String)

            # Both headings should appear even if one is empty
            @test occursin("Empty Section", coverpage_content)
            @test occursin("Full Section", coverpage_content)
        end
    end

    @testset "OrderedDict preserves order" begin
        using OrderedCollections

        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            # Create pages in specific order
            pages_list = [
                JSPlotPage(Dict(:d1 => df), [TextBlock("<p>Z</p>")], tab_title = "Z Page"),
                JSPlotPage(Dict(:d2 => df), [TextBlock("<p>A</p>")], tab_title = "A Page"),
                JSPlotPage(Dict(:d3 => df), [TextBlock("<p>M</p>")], tab_title = "M Page")
            ]

            grouped = OrderedCollections.OrderedDict(
                "Third Section" => [pages_list[1]],
                "First Section" => [pages_list[2]],
                "Second Section" => [pages_list[3]]
            )

            pages = Pages(
                [TextBlock("<h1>Order Test</h1>")],
                grouped
            )

            outfile = joinpath(tmpdir, "order.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "order")
            coverpage_content = read(joinpath(project_dir, "order.html"), String)

            # Find positions of each heading
            pos_third = findfirst("Third Section", coverpage_content)
            pos_first = findfirst("First Section", coverpage_content)
            pos_second = findfirst("Second Section", coverpage_content)

            # Verify order is preserved (Third -> First -> Second)
            @test !isnothing(pos_third)
            @test !isnothing(pos_first)
            @test !isnothing(pos_second)
            @test pos_third < pos_first
            @test pos_first < pos_second
        end
    end

    @testset "OrderedDict with page_header override" begin
        using OrderedCollections

        df = DataFrame(x = 1:5, y = rand(5))

        page1 = JSPlotPage(
            Dict(:data => df),
            [TextBlock("<p>Content</p>")],
            tab_title = "Page 1"
        )

        grouped = OrderedCollections.OrderedDict(
            "Section" => [page1]
        )

        pages = Pages(
            [TextBlock("<h1>Welcome</h1>")],
            grouped,
            page_header = "Custom Header"
        )

        @test pages.coverpage.page_header == "Custom Header"
    end

    @testset "Automatic LinkList with multiple pages" begin
        mktempdir() do tmpdir
            df1 = DataFrame(x = 1:5, y = rand(5))
            df2 = DataFrame(x = 1:3, y = rand(3))
            df3 = DataFrame(x = 1:7, y = rand(7))

            page1 = JSPlotPage(
                Dict(:data1 => df1),
                [TextBlock("<p>First</p>")],
                tab_title = "Revenue",
                notes = "Revenue analysis and trends"
            )

            page2 = JSPlotPage(
                Dict(:data2 => df2),
                [TextBlock("<p>Second</p>")],
                tab_title = "Costs",
                notes = "Cost breakdown by category"
            )

            page3 = JSPlotPage(
                Dict(:data3 => df3),
                [TextBlock("<p>Third</p>")],
                tab_title = "Profit",
                notes = "Net profit calculations"
            )

            pages = Pages(
                [TextBlock("<h1>Dashboard</h1>")],
                [page1, page2, page3],
                tab_title = "Home"
            )

            outfile = joinpath(tmpdir, "auto_links.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "auto_links")
            coverpage_content = read(joinpath(project_dir, "auto_links.html"), String)

            # Check that all page titles appear
            @test occursin("Revenue", coverpage_content)
            @test occursin("Costs", coverpage_content)
            @test occursin("Profit", coverpage_content)

            # Check that all notes appear
            @test occursin("Revenue analysis and trends", coverpage_content)
            @test occursin("Cost breakdown by category", coverpage_content)
            @test occursin("Net profit calculations", coverpage_content)

            # Check that links are properly formed
            @test occursin("revenue.html", coverpage_content)
            @test occursin("costs.html", coverpage_content)
            @test occursin("profit.html", coverpage_content)
        end
    end

    @testset "OrderedDict with single page per group" begin
        using OrderedCollections

        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            pages_vec = [
                JSPlotPage(Dict(:d1 => df), [TextBlock("<p>1</p>")], tab_title = "Page 1"),
                JSPlotPage(Dict(:d2 => df), [TextBlock("<p>2</p>")], tab_title = "Page 2"),
                JSPlotPage(Dict(:d3 => df), [TextBlock("<p>3</p>")], tab_title = "Page 3")
            ]

            grouped = OrderedCollections.OrderedDict(
                "Group A" => [pages_vec[1]],
                "Group B" => [pages_vec[2]],
                "Group C" => [pages_vec[3]]
            )

            pages = Pages([TextBlock("<h1>Test</h1>")], grouped)

            @test length(pages.pages) == 3

            outfile = joinpath(tmpdir, "single_per_group.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "single_per_group")
            coverpage_content = read(joinpath(project_dir, "single_per_group.html"), String)

            @test occursin("Group A", coverpage_content)
            @test occursin("Group B", coverpage_content)
            @test occursin("Group C", coverpage_content)
        end
    end

    @testset "OrderedDict with many pages in one group" begin
        using OrderedCollections

        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            # Create 5 pages in one group
            many_pages = [
                JSPlotPage(Dict(Symbol("d$i") => df), [TextBlock("<p>$i</p>")], tab_title = "Page $i")
                for i in 1:5
            ]

            grouped = OrderedCollections.OrderedDict(
                "Large Group" => many_pages
            )

            pages = Pages([TextBlock("<h1>Many Pages</h1>")], grouped)

            @test length(pages.pages) == 5

            outfile = joinpath(tmpdir, "many.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "many")
            coverpage_content = read(joinpath(project_dir, "many.html"), String)

            @test occursin("Large Group", coverpage_content)
            for i in 1:5
                @test occursin("Page $i", coverpage_content)
            end
        end
    end

    @testset "File existence checks" begin
        mktempdir() do tmpdir
            df = DataFrame(x = 1:5, y = rand(5))

            page1 = JSPlotPage(
                Dict(:data => df),
                [TextBlock("<h2>Content</h2>")],
                tab_title = "Test Page"
            )

            pages = Pages(
                [TextBlock("<h1>Cover</h1>")],
                [page1]
            )

            outfile = joinpath(tmpdir, "files.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "files")

            # Check all expected files exist
            @test isfile(joinpath(project_dir, "files.html"))
            @test isfile(joinpath(project_dir, "test_page.html"))
            @test isfile(joinpath(project_dir, "open.sh"))
            @test isfile(joinpath(project_dir, "open.bat"))
            @test isfile(joinpath(project_dir, "README.md"))

            # Check launcher scripts have proper permissions on Unix
            if Sys.isunix()
                @test isexecutable(joinpath(project_dir, "open.sh"))
            end
        end
    end

    @testset "Data directory structure" begin
        mktempdir() do tmpdir
            df1 = DataFrame(x = 1:5, y = rand(5))
            df2 = DataFrame(a = 1:3, b = rand(3))

            page1 = JSPlotPage(
                Dict(:dataset1 => df1),
                [TextBlock("<p>1</p>")],
                tab_title = "P1"
            )

            page2 = JSPlotPage(
                Dict(:dataset2 => df2),
                [TextBlock("<p>2</p>")],
                tab_title = "P2"
            )

            pages = Pages(
                [TextBlock("<h1>Test</h1>")],
                [page1, page2],
                dataformat = :csv_embedded
            )

            outfile = joinpath(tmpdir, "data_struct.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "data_struct")

            # Verify project directory and pages were created
            @test isdir(project_dir)
            @test isfile(joinpath(project_dir, "p1.html"))
            @test isfile(joinpath(project_dir, "p2.html"))
        end
    end

    @testset "Coverpage with no additional pages" begin
        mktempdir() do tmpdir
            pages = Pages(
                [TextBlock("<h1>Standalone Cover</h1>"), TextBlock("<p>No other pages</p>")],
                JSPlotPage[]
            )

            @test length(pages.pages) == 0

            outfile = joinpath(tmpdir, "standalone.html")
            create_html(pages, outfile)

            project_dir = joinpath(tmpdir, "standalone")
            @test isfile(joinpath(project_dir, "standalone.html"))

            content = read(joinpath(project_dir, "standalone.html"), String)
            @test occursin("Standalone Cover", content)
            @test occursin("No other pages", content)
        end
    end
end
