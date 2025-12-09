using Test
using JSPlots
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
end
