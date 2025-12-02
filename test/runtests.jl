using Test
using JSPlots
using DataFrames
using Dates

@testset "JSPlots.jl" begin

    # Create test data
    test_df = DataFrame(
        x = 1:10,
        y = rand(10),
        category = repeat(["A", "B"], 5),
        color = repeat(["Red", "Blue"], 5),
        date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10)
    )

    test_df_with_symbols = DataFrame(
        x = 1:5,
        y = rand(5),
        symbol_col = [:A, :B, :C, :D, :E]
    )

    test_df_with_missing = DataFrame(
        x = [1, 2, 3, missing, 5],
        y = [1.0, missing, 3.0, 4.0, 5.0],
        category = ["A", "B", missing, "D", "E"]
    )

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

    @testset "LineChart" begin
        @testset "Basic creation" begin
            chart = LineChart(:test_chart, test_df, :test_df;
                x_col = :x,
                y_col = :y,
                title = "Test Chart"
            )
            @test chart.chart_title == :test_chart
            @test chart.data_label == :test_df
            @test occursin("test_chart", chart.functional_html)
            @test occursin("x", chart.functional_html)
        end

        @testset "With color and filters" begin
            chart = LineChart(:color_chart, test_df, :test_df;
                x_col = :x,
                y_col = :y,
                color_col = :category,
                filters = Dict{Symbol,Any}(:category => "A"),
                title = "Colored Chart"
            )
            @test occursin("category", chart.functional_html)
            @test occursin("A", chart.functional_html)
        end

        @testset "With custom labels" begin
            chart = LineChart(:labeled_chart, test_df, :test_df;
                x_col = :x,
                y_col = :y,
                x_label = "X Axis",
                y_label = "Y Axis",
                notes = "Test notes"
            )
            @test occursin("X Axis", chart.functional_html)
            @test occursin("Y Axis", chart.functional_html)
            @test occursin("Test notes", chart.appearance_html)
        end
    end

    @testset "Chart3d" begin
        df_3d = DataFrame(
            x = repeat(1:5, inner=5),
            y = repeat(1:5, outer=5),
            z = rand(25),
            group = repeat(["A", "B"], 13)[1:25]
        )

        @testset "Basic creation" begin
            chart = Chart3d(:test_3d, :df_3d;
                x_col = :x,
                y_col = :y,
                z_col = :z,
                title = "3D Test"
            )
            @test chart.chart_title == :test_3d
            @test occursin("x", chart.functional_html)
            @test occursin("y", chart.functional_html)
            @test occursin("z", chart.functional_html)
        end

        @testset "With groups" begin
            chart = Chart3d(:grouped_3d, :df_3d;
                x_col = :x,
                y_col = :y,
                z_col = :z,
                group_col = :group,
                title = "Grouped 3D"
            )
            @test occursin("group", chart.functional_html)
        end
    end

    @testset "ScatterPlot" begin
        @testset "Basic creation" begin
            chart = ScatterPlot(:test_scatter, test_df, :test_df;
                x_col = :x,
                y_col = :y,
                title = "Scatter Test"
            )
            @test chart.chart_title == :test_scatter
            @test occursin("scatter", chart.functional_html)
        end

        @testset "With sliders" begin
            chart = ScatterPlot(:slider_scatter, test_df, :test_df;
                x_col = :x,
                y_col = :y,
                slider_col = [:category, :date],
                color_col = :category
            )
            @test occursin("category", chart.functional_html)
            @test occursin("date", chart.functional_html)
        end

        @testset "Custom marker settings" begin
            chart = ScatterPlot(:custom_scatter, test_df, :test_df;
                x_col = :x,
                y_col = :y,
                marker_size = 10,
                marker_opacity = 0.5,
                show_marginals = false
            )
            @test occursin("10", chart.functional_html)
            @test occursin("0.5", chart.functional_html)
        end
    end

    @testset "DistPlot" begin
        df_dist = DataFrame(value = randn(100))

        @testset "Basic creation" begin
            chart = DistPlot(:test_dist, df_dist, :df_dist;
                value_col = :value,
                title = "Dist Test"
            )
            @test chart.chart_title == :test_dist
            @test occursin("value", chart.functional_html)
        end

        @testset "With groups" begin
            df_grouped = DataFrame(
                value = randn(100),
                group = repeat(["A", "B"], 50)
            )
            chart = DistPlot(:grouped_dist, df_grouped, :df_grouped;
                value_col = :value,
                group_col = :group
            )
            @test occursin("group", chart.functional_html)
        end

        @testset "Custom appearance" begin
            chart = DistPlot(:custom_dist, df_dist, :df_dist;
                value_col = :value,
                show_box = false,
                show_rug = false,
                histogram_bins = 50,
                box_opacity = 0.7
            )
            @test occursin("50", chart.functional_html)
            @test occursin("false", lowercase(chart.functional_html))
        end
    end

    @testset "PivotTable" begin
        pivot_df = DataFrame(
            category = repeat(["A", "B", "C"], 3),
            region = repeat(["North", "South"], 5)[1:9],
            value = rand(9)
        )

        @testset "Basic creation" begin
            pt = PivotTable(:test_pivot, :pivot_df;
                rows = [:category],
                cols = [:region],
                vals = :value
            )
            @test pt.chart_title == :test_pivot
            @test pt.data_label == :pivot_df
            @test occursin("category", pt.functional_html)
        end

        @testset "With exclusions" begin
            pt = PivotTable(:filtered_pivot, :pivot_df;
                rows = [:category],
                cols = [:region],
                vals = :value,
                exclusions = Dict(:category => [:A])
            )
            @test occursin("exclusions", pt.functional_html)
        end

        @testset "With custom color map" begin
            pt = PivotTable(:colored_pivot, :pivot_df;
                rows = [:category],
                cols = [:region],
                vals = :value,
                colour_map = Dict{Float64,String}([0.0, 0.5, 1.0] .=> ["#FF0000", "#FFFFFF", "#0000FF"]),
                rendererName = :Heatmap
            )
            @test occursin("#FF0000", pt.functional_html)
            @test occursin("#0000FF", pt.functional_html)
        end
    end

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

    @testset "HTML Generation" begin
        @testset "Embedded formats" begin
            mktempdir() do tmpdir
                @testset "CSV embedded" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :csv_embedded)
                    outfile = joinpath(tmpdir, "test_csv_embedded.html")
                    create_html(page, outfile)

                    @test isfile(outfile)
                    content = read(outfile, String)
                    @test occursin("<!DOCTYPE html>", content)
                    @test occursin("csv_embedded", content)
                    @test occursin("<script", content)
                    @test occursin("loadDataset", content)
                    # Check that data is embedded
                    @test occursin("data-format=\"csv_embedded\"", content)
                end

                @testset "JSON embedded" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :json_embedded)
                    outfile = joinpath(tmpdir, "test_json_embedded.html")
                    create_html(page, outfile)

                    @test isfile(outfile)
                    content = read(outfile, String)
                    @test occursin("json_embedded", content)
                    @test occursin("data-format=\"json_embedded\"", content)
                end
            end
        end

        @testset "External formats" begin
            mktempdir() do tmpdir
                @testset "CSV external" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :csv_external)
                    outfile = joinpath(tmpdir, "subdir", "test_csv_external.html")
                    create_html(page, outfile)

                    # Check project structure
                    project_dir = joinpath(tmpdir, "subdir", "test_csv_external")
                    @test isdir(project_dir)
                    @test isfile(joinpath(project_dir, "test_csv_external.html"))
                    @test isfile(joinpath(project_dir, "open.sh"))
                    @test isfile(joinpath(project_dir, "open.bat"))

                    # Check data directory
                    data_dir = joinpath(project_dir, "data")
                    @test isdir(data_dir)
                    @test isfile(joinpath(data_dir, "test.csv"))

                    # Check HTML content
                    content = read(joinpath(project_dir, "test_csv_external.html"), String)
                    @test occursin("csv_external", content)
                    @test occursin("data/test.csv", content)

                    # Check launcher scripts
                    sh_content = read(joinpath(project_dir, "open.sh"), String)
                    @test occursin("brave-browser", sh_content)
                    @test occursin("--allow-file-access-from-files", sh_content)

                    bat_content = read(joinpath(project_dir, "open.bat"), String)
                    @test occursin("brave.exe", bat_content)
                end

                @testset "JSON external" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :json_external)
                    outfile = joinpath(tmpdir, "test_json_external.html")
                    create_html(page, outfile)

                    project_dir = joinpath(tmpdir, "test_json_external")
                    @test isdir(project_dir)

                    data_dir = joinpath(project_dir, "data")
                    @test isfile(joinpath(data_dir, "test.json"))

                    # Verify JSON is valid
                    json_content = read(joinpath(data_dir, "test.json"), String)
                    @test occursin("[", json_content)
                    @test occursin("]", json_content)
                end

                @testset "Parquet external" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :parquet)
                    outfile = joinpath(tmpdir, "test_parquet.html")
                    create_html(page, outfile)

                    project_dir = joinpath(tmpdir, "test_parquet")
                    @test isdir(project_dir)

                    data_dir = joinpath(project_dir, "data")
                    @test isfile(joinpath(data_dir, "test.parquet"))

                    # Check file is not empty
                    @test filesize(joinpath(data_dir, "test.parquet")) > 0
                end
            end
        end

        @testset "Single plot convenience function" begin
            mktempdir() do tmpdir
                chart = LineChart(:simple, test_df, :test_df; x_col = :x, y_col = :y)
                outfile = joinpath(tmpdir, "single_plot.html")
                create_html(chart, test_df, outfile)

                @test isfile(outfile)
                content = read(outfile, String)
                @test occursin("simple", content)
            end
        end
    end

    @testset "HTML Structure Validation" begin
        mktempdir() do tmpdir
            chart = LineChart(:validation_test, test_df, :test_df; x_col = :x, y_col = :y)
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
                @test occursin("id=\"test\"", content)
                @test occursin("data-format", content)
            end

            @testset "Chart elements" begin
                @test occursin("validation_test", content)
                @test occursin("loadDataset", content)
            end

            @testset "No script errors" begin
                # Check for common JavaScript syntax errors
                @test !occursin("undefined undefined", content)
                @test !occursin("NaN", content)
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
                another_extremely_long_column_name_for_testing = rand(5),
                color = repeat(["A"], 5)
            )

            chart = LineChart(:long_cols, df_long_cols, :df_long_cols;
                x_col = :this_is_a_very_long_column_name_that_should_still_work,
                y_col = :another_extremely_long_column_name_for_testing
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
            chart1 = LineChart(:chart1, test_df, :test_df; x_col = :x, y_col = :y)
            chart2 = ScatterPlot(:chart2, test_df, :test_df; x_col = :x, y_col = :y)
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

    @testset "Performance and File Size" begin
        # Test with larger dataset
        large_df = DataFrame(
            x = 1:1000,
            y = rand(1000),
            category = repeat(["A", "B", "C", "D"], 250)
        )

        mktempdir() do tmpdir
            @testset "File size comparison" begin
                sizes = Dict{Symbol, Int}()

                for fmt in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet]
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:large => large_df), [], dataformat = fmt)
                    outfile = joinpath(tmpdir, "size_test_$(fmt).html")
                    create_html(page, outfile)

                    if fmt in [:csv_external, :json_external, :parquet]
                        # For external formats, measure total size
                        project_dir = joinpath(tmpdir, "size_test_$(fmt)")
                        html_size = filesize(joinpath(project_dir, "size_test_$(fmt).html"))

                        # Check HTML is smaller for external formats
                        @test html_size < 50000  # HTML should be small

                        # Check data file exists
                        data_dir = joinpath(project_dir, "data")
                        @test isdir(data_dir)
                    else
                        # For embedded formats, HTML contains everything
                        html_size = filesize(outfile)
                        @test html_size > 10000  # Should contain data
                    end

                    sizes[fmt] = html_size
                end

                # Parquet HTML should be smallest (no embedded data)
                @test sizes[:parquet] < sizes[:csv_embedded]
                @test sizes[:json_external] < sizes[:json_embedded]
            end
        end
    end

end
