using Test
using JSPlots
using DataFrames

@testset "Surface3D" begin
    df_3d = DataFrame(
        x = repeat(1:5, inner=5),
        y = repeat(1:5, outer=5),
        z = rand(25),
        w = rand(25),
        group = repeat(["A", "B"], 13)[1:25],
        category = repeat(["Type1", "Type2"], 13)[1:25]
    )

    @testset "Basic creation" begin
        chart = Surface3D(:test_3d, df_3d, :df_3d;
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
        chart = Surface3D(:grouped_3d, df_3d, :df_3d;
            x_col = :x,
            y_col = :y,
            z_col = :z,
            group_col = :group,
            title = "Grouped 3D"
        )
        @test chart.chart_title == :grouped_3d
        @test occursin("group", chart.functional_html)
    end

    @testset "With filtering" begin
        chart = Surface3D(:filtered_3d, df_3d, :df_3d;
            x_col = :x,
            y_col = :y,
            z_col = :z,
            group_col = :group,
            filters = Dict{Symbol, Any}(:w => [0.5], :category => ["Type1"]),
            title = "Filtered 3D"
        )
        @test occursin("w", chart.appearance_html)
        @test occursin("_select", chart.appearance_html)
        @test occursin("updatePlotWithFilters", chart.functional_html)
    end

    @testset "Error handling" begin
        @test_throws ErrorException Surface3D(:bad_col, df_3d, :df_3d; x_col=:nonexistent, y_col=:y, z_col=:z)
        @test_throws ErrorException Surface3D(:bad_group, df_3d, :df_3d; x_col=:x, y_col=:y, z_col=:z, group_col=:nonexistent)
    end
end
