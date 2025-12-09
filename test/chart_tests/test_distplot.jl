using Test
using JSPlots
using DataFrames

@testset "DistPlot" begin
    df_dist = DataFrame(value = randn(100))

    @testset "Basic creation" begin
        chart = DistPlot(:test_dist, df_dist, :df_dist;
            value_cols = :value,
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
            value_cols = :value,
            group_cols = :group
        )
        @test occursin("group", chart.functional_html)
    end

    @testset "Custom appearance" begin
        chart = DistPlot(:custom_dist, df_dist, :df_dist;
            value_cols = :value,
            show_box = false,
            show_rug = false,
            histogram_bins = 50,
            box_opacity = 0.7
        )
        @test occursin("50", chart.functional_html)
        @test occursin("false", lowercase(chart.functional_html))
    end
end
