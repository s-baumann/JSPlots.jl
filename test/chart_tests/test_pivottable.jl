using Test
using JSPlots
using DataFrames

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
