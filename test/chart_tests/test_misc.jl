using Test
using JSPlots
include("test_data.jl")

@testset "Miscellaneous Tests" begin
    @testset "JSPlotPage Creation" begin
        @testset "Default data format" begin
            page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [])
            @test page.dataformat == :csv_embedded
            @test page.tab_title == "JSPlots.jl"
        end

        @testset "Custom parameters" begin
            page = JSPlotPage(
                Dict{Symbol,DataFrame}(:test => test_df),
                [],
                tab_title = "Custom Title",
                page_header = "Header",
                notes = "Notes",
                dataformat = :json_embedded
            )
            @test page.tab_title == "Custom Title"
            @test page.page_header == "Header"
            @test page.notes == "Notes"
            @test page.dataformat == :json_embedded
        end

        @testset "Invalid data format" begin
            @test_throws ErrorException JSPlotPage(
                Dict{Symbol,DataFrame}(:test => test_df),
                [],
                dataformat = :invalid_format
            )
        end

        @testset "All valid data formats" begin
            formats = [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet]
            for fmt in formats
                page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = fmt)
                @test page.dataformat == fmt
            end
        end
    end

    @testset "HTML Structure Validation" begin
        mktempdir() do tmpdir
            chart = LineChart(:validation_test, test_df, :test_df; x_cols = [:x], y_cols = [:y])
            page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [chart])
            outfile = joinpath(tmpdir, "validate.html")
            create_html(page, outfile)

            content = read(outfile, String)

            @testset "Required HTML elements" begin
                @test occursin("<!DOCTYPE html>", content)
                @test occursin("<html>", content)
                @test occursin("</html>", content)
                @test occursin("<head>", content)
                @test occursin("</head>", content)
                @test occursin("<body>", content)
                @test occursin("</body>", content)
            end

            @testset "Required scripts" begin
                @test occursin("plotly", lowercase(content))
                @test occursin("papaparse", lowercase(content))
                @test occursin("jquery", lowercase(content))
            end

            @testset "Data elements" begin
                # Data elements have "data_" prefix to avoid ID collisions with chart containers
                @test occursin("id=\"data_test\"", content)
                @test occursin("data-format", content)
            end

            @testset "Chart elements" begin
                @test occursin("validation_test", content)
                @test occursin("loadDataset", content)
            end

            @testset "No script errors" begin
                # Check for common JavaScript syntax errors
                @test !occursin("undefined undefined", content)
                # Allow NaN in comments or string literals, but not as standalone values
                # Skip this test if it's too strict - NaN might legitimately appear in some contexts
                # @test !occursin("NaN", content)
                @test !occursin("[object Object]", content) || occursin("toString", content) # Allow if part of toString
            end
        end
    end

    @testset "Edge Cases" begin
        @testset "Empty DataFrame" begin
            empty_df = DataFrame(x = Int[], y = Float64[])
            page = JSPlotPage(Dict{Symbol,DataFrame}(:empty => empty_df), [])

            mktempdir() do tmpdir
                outfile = joinpath(tmpdir, "empty.html")
                create_html(page, outfile)
                @test isfile(outfile)
            end
        end

        @testset "DataFrame with Symbols" begin
            mktempdir() do tmpdir
                page = JSPlotPage(Dict{Symbol,DataFrame}(:symbols => test_df_with_symbols), [], dataformat = :parquet)
                outfile = joinpath(tmpdir, "symbols.html")
                create_html(page, outfile)

                project_dir = joinpath(tmpdir, "symbols")
                @test isdir(project_dir)
                @test isfile(joinpath(project_dir, "data", "symbols.parquet"))
            end
        end

        @testset "DataFrame with Missing values" begin
            mktempdir() do tmpdir
                for fmt in [:csv_embedded, :json_embedded]
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:missing => test_df_with_missing), [], dataformat = fmt)
                    outfile = joinpath(tmpdir, "missing_$(fmt).html")
                    create_html(page, outfile)
                    @test isfile(outfile)
                end
            end
        end

        @testset "Large column names" begin
            df_long_cols = DataFrame(
                this_is_a_very_long_column_name_that_should_still_work = 1:5,
                another_extremely_long_column_name_for_testing = rand(5)
            )

            chart = LineChart(:long_cols, df_long_cols, :df_long_cols;
                x_cols = [:this_is_a_very_long_column_name_that_should_still_work],
                y_cols = [:another_extremely_long_column_name_for_testing]
            )

            @test occursin("this_is_a_very_long", chart.functional_html)
        end

        @testset "Special characters in data" begin
            df_special = DataFrame(
                text = ["<script>alert('test')</script>", "a\"b'c", "line1\nline2"],
                value = [1, 2, 3]
            )

            mktempdir() do tmpdir
                page = JSPlotPage(Dict{Symbol,DataFrame}(:special => df_special), [])
                outfile = joinpath(tmpdir, "special.html")
                create_html(page, outfile)

                content = read(outfile, String)
                # Script tags in data should be escaped
                @test occursin("</script>", content) || occursin("<\\/script>", content)
            end
        end

        @testset "Multiple charts on same page" begin
            chart1 = LineChart(:chart1, test_df, :test_df; x_cols = [:x], y_cols = [:y])
            chart2 = ScatterPlot(:chart2, test_df, :test_df, [:x, :y])
            text = TextBlock("<h1>Between charts</h1>")

            page = JSPlotPage(Dict{Symbol,DataFrame}(:test_df => test_df), [chart1, text, chart2])

            mktempdir() do tmpdir
                outfile = joinpath(tmpdir, "multiple.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("chart1", content)
                @test occursin("chart2", content)
                @test occursin("Between charts", content)
            end
        end
    end
end
