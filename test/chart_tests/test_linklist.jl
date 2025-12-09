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
end
