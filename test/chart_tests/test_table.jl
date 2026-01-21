using Test
using JSPlots
using DataFrames

@testset "Table" begin
    table_df = DataFrame(
        name = ["Alice", "Bob", "Charlie"],
        age = [25, 30, 35],
        city = ["NYC", "LA", "Chicago"],
        salary = [75000, 85000, 95000]
    )

    @testset "Basic Table creation" begin
        tbl = Table(:test_table, table_df; notes="Employee data")
        @test tbl.chart_title == :test_table
        @test tbl.notes == "Employee data"
        @test occursin("<table id=\"table_test_table\">", tbl.appearance_html)
        @test occursin("Alice", tbl.appearance_html)
        @test occursin("sortTable", tbl.functional_html)
    end

    @testset "Table HTML structure" begin
        tbl = Table(:html_table, table_df)
        @test occursin("<thead>", tbl.appearance_html)
        @test occursin("<tbody>", tbl.appearance_html)
        @test occursin("<th>name<span class=\"sort-indicator\"></span></th>", tbl.appearance_html)
        @test occursin("<td>Alice</td>", tbl.appearance_html)
        @test occursin("sort-indicator", tbl.appearance_html)
    end

    @testset "Table sorting functionality" begin
        tbl = Table(:sortable_table, table_df)
        # Check that sorting JavaScript is included
        @test occursin("sortTable", tbl.functional_html)
        @test occursin("sort-asc", tbl.functional_html)
        @test occursin("sort-desc", tbl.functional_html)
        # Check sort indicators are in headers
        @test occursin("sort-indicator", tbl.appearance_html)
        # Check numeric sorting support
        @test occursin("parseFloat", tbl.functional_html)
    end

    @testset "Table with special characters" begin
        special_df = DataFrame(
            text = ["<script>alert('xss')</script>", "a & b", "quote\"test"],
            value = [1, 2, 3]
        )
        tbl = Table(:special_table, special_df)
        # Should escape HTML entities
        @test occursin("&lt;script&gt;", tbl.appearance_html)
        @test occursin("&amp;", tbl.appearance_html)
        @test occursin("&quot;", tbl.appearance_html)
    end

    @testset "Table with missing values" begin
        missing_df = DataFrame(
            a = [1, missing, 3],
            b = ["x", "y", missing]
        )
        tbl = Table(:missing_table, missing_df)
        @test occursin("<table id=\"table_missing_table\">", tbl.appearance_html)
        # Missing values should be rendered as empty cells
        @test occursin("<td></td>", tbl.appearance_html)
    end

    @testset "Table in HTML output" begin
        mktempdir() do tmpdir
            tbl = Table(:output_table, table_df)
            outfile = joinpath(tmpdir, "table_test.html")
            create_html(tbl, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("<table id=\"table_output_table\">", content)
            @test occursin("Alice", content)
            @test occursin("sortTable", content)
        end
    end

    @testset "Table convenience function" begin
        mktempdir() do tmpdir
            tbl = Table(:convenience_table, table_df)
            outfile = joinpath(tmpdir, "table_convenience.html")
            create_html(tbl, outfile)

            @test isfile(outfile)
        end
    end

    @testset "Multiple Tables on same page" begin
        mktempdir() do tmpdir
            df1 = DataFrame(a = [1, 2], b = [3, 4])
            df2 = DataFrame(x = ["a", "b"], y = ["c", "d"])

            tbl1 = Table(:table1, df1)
            tbl2 = Table(:table2, df2)

            page = JSPlotPage(Dict{Symbol,DataFrame}(), [tbl1, tbl2])
            outfile = joinpath(tmpdir, "multiple_tables.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("table_table1", content)
            @test occursin("table_table2", content)
            @test occursin("sortTable", content)
        end
    end

    @testset "Mixed content: Table, Picture, and other plots" begin
        mktempdir() do tmpdir
            # Use the real example image for testing
            test_png = joinpath(@__DIR__, "..", "..", "examples", "pictures", "images.jpeg")

            test_df = DataFrame(x = 1:5, y = rand(5))
            table_df_local = DataFrame(item = ["A", "B"], value = [10, 20])

            chart = LineChart(:line, test_df, :data; x_cols=[:x], y_cols=[:y])
            tbl = Table(:summary, table_df_local)
            pic = Picture(:image, test_png)
            text = TextBlock("<h2>Mixed Content Test</h2>")

            page = JSPlotPage(
                Dict{Symbol,DataFrame}(:data => test_df),
                [text, chart, tbl, pic]
            )
            outfile = joinpath(tmpdir, "mixed_content.html")
            create_html(page, outfile)

            content = read(outfile, String)
            @test occursin("Mixed Content Test", content)
            @test occursin("line", content)
            @test occursin("summary", content)
            @test occursin("image", content)
        end
    end
end
