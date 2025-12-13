using Test
using JSPlots
using Dates
include("test_data.jl")

@testset "LineChart" begin
    @testset "Basic creation" begin
        chart = LineChart(:test_chart, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            title = "Test Chart"
        )
        @test chart.chart_title == :test_chart
        @test chart.data_label == :test_df
        @test occursin("test_chart", chart.functional_html)
        @test occursin("x", chart.functional_html)
    end

    @testset "With color and filters" begin
        chart = LineChart(:color_chart, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = [:category],
            filters = Dict{Symbol,Any}(:category => "A"),
            title = "Colored Chart"
        )
        @test occursin("category", chart.functional_html)
        @test occursin("A", chart.functional_html)
    end

    @testset "Without color column" begin
        df_no_color = DataFrame(x = 1:10, y = rand(10))
        chart = LineChart(:no_color_chart, df_no_color, :df_no_color;
            x_cols = [:x],
            y_cols = [:y],
            title = "No Color Chart"
        )
        @test occursin("__no_color__", chart.functional_html)
        @test occursin("#000000", chart.functional_html)
    end

    @testset "Multiple x and y columns" begin
        df_multi = DataFrame(
            x1 = 1:20,
            x2 = 1:20,
            y1 = rand(20),
            y2 = rand(20) .+ 1,
            y3 = rand(20) .+ 2
        )
        chart = LineChart(:multi_xy, df_multi, :df_multi;
            x_cols = [:x1, :x2],
            y_cols = [:y1, :y2, :y3],
            title = "Multiple Series"
        )
        @test occursin("x1", chart.functional_html)
        @test occursin("y1", chart.functional_html)
        @test occursin("y2", chart.functional_html)
        @test occursin("y3", chart.functional_html)
    end

    @testset "Multiple color columns" begin
        df_colors = DataFrame(
            x = 1:30,
            y = rand(30),
            category = repeat(["A", "B", "C"], 10),
            region = repeat(["North", "South"], 15)
        )
        chart = LineChart(:multi_color, df_colors, :df_colors;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = [:category, :region],
            title = "Multiple Colors"
        )
        @test occursin("category", chart.functional_html)
        @test occursin("region", chart.functional_html)
    end

    @testset "With filters" begin
        df_filter = DataFrame(
            x = repeat(1:50, 2),
            y = rand(100),
            category = repeat(["A", "B"], 50)
        )
        chart = LineChart(:with_filters, df_filter, :df_filter;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = [:category],
            filters = Dict{Symbol,Any}(:category => "A")
        )
        @test occursin("category", chart.functional_html)
        @test occursin("A", chart.functional_html)
    end

    @testset "Faceting - single column" begin
        df_facet = DataFrame(
            x = repeat(1:20, 3),
            y = rand(60),
            facet = repeat(["A", "B", "C"], inner=20)
        )
        chart = LineChart(:facet_single, df_facet, :df_facet;
            x_cols = [:x],
            y_cols = [:y],
            facet_cols = [:facet],
            default_facet_cols = [:facet],
            title = "Faceted Chart"
        )
        @test occursin("facet", chart.functional_html)
        @test occursin("FACET_COLS", chart.functional_html)
    end

    @testset "Faceting - multiple columns" begin
        df_facet2 = DataFrame(
            x = repeat(1:10, 12),
            y = rand(120),
            category = repeat(["A", "B"], 60),
            region = repeat(["North", "South", "East"], inner=40)
        )
        chart = LineChart(:facet_multi, df_facet2, :df_facet2;
            x_cols = [:x],
            y_cols = [:y],
            facet_cols = [:category, :region],
            default_facet_cols = [:category],
            title = "Multi-Facet"
        )
        @test occursin("category", chart.appearance_html)
        @test occursin("region", chart.appearance_html)
    end

    @testset "Custom axis labels" begin
        chart = LineChart(:custom_labels, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            x_label = "Time (seconds)",
            y_label = "Response (mV)",
            title = "Custom Labels"
        )
        @test occursin("Time (seconds)", chart.functional_html)
        @test occursin("Response (mV)", chart.functional_html)
    end

    @testset "With notes" begin
        notes = "This line chart shows temporal trends in the data."
        chart = LineChart(:with_notes, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            notes = notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df_test = DataFrame(
                x = 1:30,
                y = cumsum(randn(30)),
                category = repeat(["A", "B", "C"], 10)
            )

            chart = LineChart(:page_line, df_test, :test_data;
                x_cols = [:x],
                y_cols = [:y],
                color_cols = [:category],
                title = "Line Test"
            )

            page = JSPlotPage(Dict(:test_data => df_test), [chart])
            outfile = joinpath(tmpdir, "linechart_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Line Test", content)
            @test occursin("page_line", content)
        end
    end

    @testset "Dependencies method" begin
        chart = LineChart(:dep_test, test_df, :my_data;
            x_cols = [:x],
            y_cols = [:y]
        )
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_data]
        @test length(deps) == 1
    end

    @testset "Time series with dates" begin
        df_ts = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
            sales = cumsum(randn(91)) .+ 1000,
            region = repeat(["North", "South"], 46)[1:91]
        )
        chart = LineChart(:timeseries, df_ts, :df_ts;
            x_cols = [:date],
            y_cols = [:sales],
            color_cols = [:region],
            title = "Sales Over Time"
        )
        @test occursin("date", chart.functional_html)
        @test occursin("sales", chart.functional_html)
    end

    @testset "Empty color_cols creates default group" begin
        chart = LineChart(:default_color, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = Symbol[]
        )
        @test occursin("__no_color__", chart.functional_html)
    end

    @testset "Multiple charts on same page" begin
        mktempdir() do tmpdir
            df1 = DataFrame(x = 1:10, y = rand(10))
            df2 = DataFrame(x = 1:10, y = rand(10) .+ 1)

            chart1 = LineChart(:chart1, df1, :data1;
                x_cols = [:x],
                y_cols = [:y],
                title = "First Chart"
            )

            chart2 = LineChart(:chart2, df2, :data2;
                x_cols = [:x],
                y_cols = [:y],
                title = "Second Chart"
            )

            page = JSPlotPage(
                Dict(:data1 => df1, :data2 => df2),
                [chart1, chart2]
            )
            outfile = joinpath(tmpdir, "multiple_lines.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("chart1", content)
            @test occursin("chart2", content)
            @test occursin("First Chart", content)
            @test occursin("Second Chart", content)
        end
    end
end
