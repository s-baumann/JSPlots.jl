using Test
using JSPlots

@testset "TextBlock" begin
    @testset "Basic creation" begin
        block = TextBlock("<h1>Test Header</h1><p>Test paragraph</p>")
        @test occursin("Test Header", block.appearance_html)
        @test occursin("Test paragraph", block.appearance_html)
        @test block.functional_html == ""
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
end
