using Test
using JSPlots
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
end
