using Test
using JSPlots

@testset "LinkList" begin
    @testset "Basic creation" begin
        links = LinkList([
            ("Page 1", "page1.html", "First page description"),
            ("Page 2", "page2.html", "Second page description")
        ])
        @test links.chart_title == :link_list
        @test occursin("<ul>", links.appearance_html)
        @test occursin("Page 1", links.appearance_html)
        @test occursin("page1.html", links.appearance_html)
        @test occursin("First page description", links.appearance_html)
        @test links.functional_html == ""
    end

    @testset "Custom chart title" begin
        links = LinkList(
            [("Test", "test.html", "Description")],
            chart_title = :custom_links
        )
        @test links.chart_title == :custom_links
    end

    @testset "Multiple links" begin
        link_data = [
            ("Analysis 1", "analysis1.html", "Revenue analysis"),
            ("Analysis 2", "analysis2.html", "Cost analysis"),
            ("Analysis 3", "analysis3.html", "Profit analysis")
        ]
        links = LinkList(link_data)

        @test occursin("Analysis 1", links.appearance_html)
        @test occursin("Analysis 2", links.appearance_html)
        @test occursin("Analysis 3", links.appearance_html)
        @test occursin("analysis1.html", links.appearance_html)
        @test occursin("analysis2.html", links.appearance_html)
        @test occursin("analysis3.html", links.appearance_html)
    end

    @testset "Links in HTML output" begin
        mktempdir() do tmpdir
            links = LinkList([("Test Page", "test.html", "Test description")])
            page = JSPlotPage(Dict{Symbol,DataFrame}(), [links])
            outfile = joinpath(tmpdir, "links_test.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("Test Page", content)
            @test occursin("test.html", content)
            @test occursin("Test description", content)
        end
    end

    @testset "Dependencies" begin
        links = LinkList([("Page", "page.html", "Description")])
        @test JSPlots.dependencies(links) == Symbol[]
    end

    @testset "With notes parameter" begin
        links = LinkList([
            ("Page 1", "page1.html", "First page"),
            ("Page 2", "page2.html", "Second page")
        ], notes="This is a note about the links")

        @test occursin("This is a note about the links", links.appearance_html)
        @test occursin("#fffbdd", links.appearance_html)  # Yellow background
        @test occursin("Page 1", links.appearance_html)
        @test occursin("Page 2", links.appearance_html)
    end

    @testset "Empty notes parameter" begin
        links = LinkList([("Page", "page.html", "Description")], notes="")
        # Should not have notes div if notes is empty
        @test !occursin("fffbdd", links.appearance_html)
    end

    @testset "OrderedDict constructor with subheadings" begin
        using OrderedCollections

        grouped_links = OrderedCollections.OrderedDict(
            "Plot Types" => [
                ("Scatter", "scatter.html", "Scatter plot examples"),
                ("Line", "line.html", "Line chart examples")
            ],
            "Documentation" => [
                ("API", "api.html", "API reference"),
                ("Guide", "guide.html", "User guide")
            ]
        )

        links = LinkList(grouped_links)

        # Check for subheadings
        @test occursin("Plot Types", links.appearance_html)
        @test occursin("Documentation", links.appearance_html)
        @test occursin("<h4", links.appearance_html)

        # Check for links
        @test occursin("Scatter", links.appearance_html)
        @test occursin("Line", links.appearance_html)
        @test occursin("API", links.appearance_html)
        @test occursin("Guide", links.appearance_html)

        # Check for all URLs
        @test occursin("scatter.html", links.appearance_html)
        @test occursin("line.html", links.appearance_html)
        @test occursin("api.html", links.appearance_html)
        @test occursin("guide.html", links.appearance_html)
    end

    @testset "OrderedDict with notes" begin
        using OrderedCollections

        grouped_links = OrderedCollections.OrderedDict(
            "Section 1" => [("Link A", "a.html", "Description A")],
            "Section 2" => [("Link B", "b.html", "Description B")]
        )

        links = LinkList(grouped_links, notes="Grouped links with notes")

        @test occursin("Section 1", links.appearance_html)
        @test occursin("Section 2", links.appearance_html)
        @test occursin("Grouped links with notes", links.appearance_html)
        @test occursin("#fffbdd", links.appearance_html)
    end

    @testset "OrderedDict with custom chart title" begin
        using OrderedCollections

        grouped_links = OrderedCollections.OrderedDict(
            "Group" => [("Link", "link.html", "Desc")]
        )

        links = LinkList(grouped_links, chart_title=:custom_grouped)
        @test links.chart_title == :custom_grouped
    end

    @testset "HTML structure verification" begin
        links = LinkList([
            ("Page 1", "page1.html", "Description 1"),
            ("Page 2", "page2.html", "Description 2")
        ])

        # Should have proper HTML structure
        @test occursin("<div style=", links.appearance_html)
        @test occursin("<h3>Pages</h3>", links.appearance_html)
        @test occursin("<ul>", links.appearance_html)
        @test occursin("</ul>", links.appearance_html)
        @test occursin("<li>", links.appearance_html)
        @test occursin("</li>", links.appearance_html)
        @test occursin("<strong>", links.appearance_html)
        @test occursin("<a href=", links.appearance_html)
    end

    @testset "OrderedDict HTML structure" begin
        using OrderedCollections

        grouped_links = OrderedCollections.OrderedDict(
            "Section" => [("Link", "link.html", "Description")]
        )

        links = LinkList(grouped_links)

        @test occursin("<h4 style=", links.appearance_html)
        @test occursin("Section</h4>", links.appearance_html)
        @test occursin("<ul>", links.appearance_html)
    end

    @testset "No data label" begin
        links = LinkList([("Page", "page.html", "Desc")])
        @test links.data_label == :no_data
    end

    @testset "No functional HTML" begin
        links = LinkList([("Page", "page.html", "Desc")])
        @test links.functional_html == ""
    end

    @testset "Link attributes preserved" begin
        link_tuple = ("Test Page", "test.html", "Test description with special chars: & < >")
        links = LinkList([link_tuple])

        @test occursin("Test Page", links.appearance_html)
        @test occursin("test.html", links.appearance_html)
        @test occursin("Test description with special chars: & < >", links.appearance_html)
    end
end
