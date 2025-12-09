using Test
using JSPlots
using DataFrames

@testset "Scatter3D" begin
    df_scatter_3d = DataFrame(
        x = randn(50),
        y = randn(50),
        z = randn(50),
        w = randn(50),
        v = randn(50),
        category = repeat(["A", "B", "C"], 17)[1:50],
        group = repeat(["G1", "G2"], 25)
    )

    @testset "Basic creation" begin
        chart = Scatter3D(:test_3d_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            title = "3D Scatter Test"
        )
        @test chart.chart_title == :test_3d_scatter
        @test occursin("scatter3d", chart.functional_html)
        @test occursin("eigenvector", lowercase(chart.appearance_html))
    end

    @testset "Multiple dimensions" begin
        chart = Scatter3D(:multi_dim_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z, :w, :v];
            color_cols = [:category],
            show_eigenvectors = true
        )
        @test occursin("_x_col_select", chart.appearance_html)
        @test occursin("_y_col_select", chart.appearance_html)
        @test occursin("_z_col_select", chart.appearance_html)
    end

    @testset "With filtering" begin
        chart = Scatter3D(:filtered_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            slider_col = [:w, :group],
            show_eigenvectors = true
        )
        @test occursin("w", chart.appearance_html)
        @test occursin("_slider", chart.appearance_html)
        @test occursin("updatePlotWithFilters", chart.functional_html)
    end

    @testset "Eigenvector toggle" begin
        chart1 = Scatter3D(:eig_on, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            show_eigenvectors = true
        )
        @test occursin("showEigenvectors", chart1.functional_html)
        @test occursin("true", chart1.functional_html)

        chart2 = Scatter3D(:eig_off, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            show_eigenvectors = false
        )
        @test occursin("false", chart2.functional_html)
    end

    @testset "Custom marker settings" begin
        chart = Scatter3D(:custom_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            marker_size = 8,
            marker_opacity = 0.8
        )
        @test occursin("8", chart.functional_html)
        @test occursin("0.8", chart.functional_html)
    end

    @testset "Error handling" begin
        @test_throws ErrorException Scatter3D(:bad_dims, df_scatter_3d, :df_scatter_3d, [:x, :y])  # Not enough dimensions
        @test_throws ErrorException Scatter3D(:bad_col, df_scatter_3d, :df_scatter_3d, [:x, :y, :nonexistent])
        @test_throws ErrorException Scatter3D(:bad_color, df_scatter_3d, :df_scatter_3d, [:x, :y, :z]; color_cols=[:nonexistent])
    end
end
