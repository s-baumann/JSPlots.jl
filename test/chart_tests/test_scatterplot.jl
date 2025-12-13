using Test
using JSPlots
using Dates
include("test_data.jl")

@testset "ScatterPlot" begin
    @testset "Basic creation" begin
        chart = ScatterPlot(:test_scatter, test_df, :test_df, [:x, :y];
            title = "Scatter Test"
        )
        @test chart.chart_title == :test_scatter
        @test occursin("scatter", chart.functional_html)
    end

    @testset "With sliders" begin
        chart = ScatterPlot(:slider_scatter, test_df, :test_df, [:x, :y];
            slider_col = [:category, :date],
            color_cols = [:category]
        )
        @test occursin("category", chart.functional_html)
        @test occursin("date", chart.functional_html)
    end

    @testset "Custom marker settings" begin
        chart = ScatterPlot(:custom_scatter, test_df, :test_df, [:x, :y];
            marker_size = 10,
            marker_opacity = 0.5,
            show_density = false
        )
        @test occursin("10", chart.functional_html)
        @test occursin("0.5", chart.functional_html)
    end

    @testset "Slider filters - continuous" begin
        df_slider = DataFrame(
            x = randn(100),
            y = randn(100),
            color = repeat(["A", "B"], 50),
            temperature = rand(100) .* 30 .+ 10,
            pressure = rand(100) .* 100 .+ 900
        )
        chart = ScatterPlot(:slider_continuous, df_slider, :df_slider, [:x, :y];
            slider_col = [:temperature, :pressure]
        )
        @test occursin("temperature", chart.appearance_html)
        @test occursin("pressure", chart.appearance_html)
        @test occursin("slider", lowercase(chart.appearance_html))
    end

    @testset "Slider filters - dates" begin
        nrows = 100
        df_dates = DataFrame(
            x = randn(nrows),
            y = randn(nrows),
            color = repeat(["A", "B"], div(nrows, 2)),
            date = Date(2024, 1, 1):Day(1):Date(2024, 4, 9),  # 100 days
            month = repeat(1:4, 25)
        )
        chart = ScatterPlot(:slider_dates, df_dates, :df_dates, [:x, :y];
            slider_col = [:date, :month]
        )
        @test occursin("date", chart.appearance_html)
        @test occursin("month", chart.appearance_html)
        @test occursin("slider", lowercase(chart.appearance_html))
    end

    @testset "Slider filters - integers" begin
        df_int = DataFrame(
            x = rand(80),
            y = rand(80),
            color = repeat(["A", "B"], 40),
            count = rand(1:100, 80),
            year = rand(2020:2024, 80)
        )
        chart = ScatterPlot(:slider_int, df_int, :df_int, [:x, :y];
            slider_col = [:count, :year]
        )
        @test occursin("count", chart.appearance_html)
        @test occursin("year", chart.appearance_html)
    end

    @testset "Multiple color columns" begin
        df_colors = DataFrame(
            x = randn(60),
            y = randn(60),
            category = repeat(["A", "B", "C"], 20),
            region = repeat(["North", "South"], 30)
        )
        chart = ScatterPlot(:multi_color, df_colors, :df_colors, [:x, :y];
            color_cols = [:category, :region]
        )
        @test occursin("category", chart.appearance_html)
        @test occursin("region", chart.appearance_html)
    end

    @testset "With marginal density plots" begin
        df_density = DataFrame(
            x = randn(100),
            y = randn(100),
            color = repeat(["A"], 100)
        )
        chart = ScatterPlot(:with_density, df_density, :df_density, [:x, :y];
            show_density = true
        )
        @test occursin("scatter", lowercase(chart.functional_html))
    end

    @testset "Without marginal density plots" begin
        df_no_density = DataFrame(
            x = randn(50),
            y = randn(50),
            color = repeat(["A"], 50)
        )
        chart = ScatterPlot(:no_density, df_no_density, :df_no_density, [:x, :y];
            show_density = false
        )
        @test chart.functional_html != ""
    end

    @testset "Custom marker sizes" begin
        for size in [3, 5, 8, 12, 15]
            chart = ScatterPlot(Symbol("size_$size"), test_df, :test_df, [:x, :y];
                marker_size = size
            )
            @test occursin(string(size), chart.functional_html)
        end
    end

    @testset "Custom marker opacity" begin
        for opacity in [0.2, 0.4, 0.6, 0.8, 1.0]
            chart = ScatterPlot(Symbol("opacity_$(Int(opacity*10))"), test_df, :test_df, [:x, :y];
                marker_opacity = opacity
            )
            @test occursin(string(opacity), chart.functional_html)
        end
    end

    @testset "With notes" begin
        notes = "This scatter plot shows the correlation between variables."
        chart = ScatterPlot(:with_notes, test_df, :test_df, [:x, :y];
            notes = notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df_test = DataFrame(
                x = randn(50),
                y = randn(50),
                category = repeat(["A", "B"], 25),
                color = repeat(["Red", "Blue"], 25)
            )

            chart = ScatterPlot(:page_scatter, df_test, :test_data, [:x, :y];
                color_cols = [:color],
                title = "Scatter Test"
            )

            page = JSPlotPage(Dict(:test_data => df_test), [chart])
            outfile = joinpath(tmpdir, "scatterplot_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Scatter Test", content)
            @test occursin("page_scatter", content)
        end
    end

    @testset "Dependencies method" begin
        chart = ScatterPlot(:dep_test, test_df, :my_data, [:x, :y])
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_data]
        @test length(deps) == 1
    end

    @testset "Multiple scatter plots on same page" begin
        mktempdir() do tmpdir
            df1 = DataFrame(x = randn(30), y = randn(30), color = repeat(["A"], 30))
            df2 = DataFrame(x = randn(30), y = randn(30) .+ 1, color = repeat(["B"], 30))

            chart1 = ScatterPlot(:scatter1, df1, :data1, [:x, :y];
                title = "First Scatter"
            )

            chart2 = ScatterPlot(:scatter2, df2, :data2, [:x, :y];
                title = "Second Scatter"
            )

            page = JSPlotPage(
                Dict(:data1 => df1, :data2 => df2),
                [chart1, chart2]
            )
            outfile = joinpath(tmpdir, "multiple_scatters.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("scatter1", content)
            @test occursin("scatter2", content)
        end
    end

    @testset "Default color column" begin
        # test_df has :color column which is the default
        chart = ScatterPlot(:default_color, test_df, :test_df, [:x, :y])
        @test chart.functional_html != ""
        @test occursin("color", chart.functional_html)
    end

    @testset "Large dataset handling" begin
        df_large = DataFrame(
            x = randn(1000),
            y = randn(1000),
            category = repeat(["A", "B", "C", "D"], 250)
        )
        chart = ScatterPlot(:large_scatter, df_large, :df_large, [:x, :y];
            color_cols = [:category],
            marker_size = 3,
            marker_opacity = 0.3
        )
        @test chart.chart_title == :large_scatter
        @test occursin("category", chart.functional_html)
    end
end
