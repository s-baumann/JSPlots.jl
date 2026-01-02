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
        @test occursin("x_col_select", chart.appearance_html)
        @test occursin("y_col_select", chart.appearance_html)
        @test occursin("z_col_select", chart.appearance_html)
    end

    @testset "With filtering" begin
        chart = Scatter3D(:filtered_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            filters = Dict{Symbol, Any}(:w => [0.0], :group => ["G1"]),
            show_eigenvectors = true
        )
        @test occursin("w", chart.appearance_html)
        @test occursin("_select", chart.appearance_html)
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

    @testset "With notes" begin
        chart = Scatter3D(:with_notes, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            notes = "This is a test note"
        )
        @test occursin("This is a test note", chart.appearance_html)
    end

    @testset "With title" begin
        chart = Scatter3D(:with_title, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            title = "Custom 3D Title"
        )
        @test occursin("Custom 3D Title", chart.appearance_html)
    end

    @testset "Multiple color columns" begin
        chart = Scatter3D(:multi_color, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category, :group]
        )
        @test occursin("category", chart.appearance_html)
        @test occursin("group", chart.appearance_html)
        @test occursin("color_col_select", chart.appearance_html)
    end

    @testset "Single color column (no dropdown)" begin
        chart = Scatter3D(:single_color, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        # With only one color option, there should be no dropdown
        @test !occursin("color_col_select", chart.appearance_html)
    end

    @testset "Exactly 3 dimensions (no dropdowns)" begin
        chart = Scatter3D(:three_dims, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        # With exactly 3 dimensions, there should be no x/y/z dropdowns
        @test !occursin("_x_col_select", chart.appearance_html)
        @test !occursin("_y_col_select", chart.appearance_html)
        @test !occursin("_z_col_select", chart.appearance_html)
    end

    @testset "Shared camera true" begin
        chart = Scatter3D(:shared_cam_on, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            shared_camera = true
        )
        @test occursin("true", chart.functional_html)
    end

    @testset "Shared camera false" begin
        chart = Scatter3D(:shared_cam_off, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            shared_camera = false
        )
        @test occursin("false", chart.functional_html)
    end

    @testset "Facet wrap (single facet)" begin
        chart = Scatter3D(:facet_wrap, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            facet_cols = :group,
            default_facet_cols = :group
        )
        @test occursin("group", chart.appearance_html)
        @test occursin("facet1_select", chart.appearance_html)
    end

    @testset "Facet grid (two facets)" begin
        chart = Scatter3D(:facet_grid, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            facet_cols = [:category, :group],
            default_facet_cols = [:category, :group]
        )
        @test occursin("category", chart.appearance_html)
        @test occursin("group", chart.appearance_html)
        @test occursin("facet1_select", chart.appearance_html)
        @test occursin("facet2_select", chart.appearance_html)
    end

    @testset "Facet cols as vector" begin
        chart = Scatter3D(:facet_vec, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            facet_cols = [:category, :group],
            default_facet_cols = nothing
        )
        @test occursin("None", chart.appearance_html)
    end

    @testset "Filter with single column" begin
        chart = Scatter3D(:filter_single, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            filters = Dict{Symbol, Any}(:w => [0.0])
        )
        @test occursin("w", chart.appearance_html)
        # Filter controls can be either dropdowns (_select) or range sliders (_range) depending on data type
        @test occursin("_select", chart.appearance_html) || occursin("_range", chart.appearance_html)
    end

    @testset "Filter with multiple columns" begin
        chart = Scatter3D(:filter_multi, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            filters = Dict{Symbol, Any}(:w => [0.0], :v => [0.0])
        )
        @test occursin("w", chart.appearance_html)
        @test occursin("v", chart.appearance_html)
    end

    @testset "Marker opacity boundaries" begin
        chart1 = Scatter3D(:opacity_low, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            marker_opacity = 0.1
        )
        @test occursin("0.1", chart1.functional_html)

        chart2 = Scatter3D(:opacity_high, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            marker_opacity = 1.0
        )
        @test occursin("1.0", chart2.functional_html)
    end

    @testset "Marker size variations" begin
        chart1 = Scatter3D(:size_small, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            marker_size = 2
        )
        @test occursin("2", chart1.functional_html)

        chart2 = Scatter3D(:size_large, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            marker_size = 10
        )
        @test occursin("10", chart2.functional_html)
    end

    @testset "Chart title sanitization" begin
        chart = Scatter3D(Symbol("test-3d.scatter"), df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("test_3d_scatter", chart.functional_html)
    end

    @testset "Data label in functional HTML" begin
        chart = Scatter3D(:data_label_test, df_scatter_3d, :custom_label, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("custom_label", chart.functional_html)
    end

    @testset "Dimensions in functional HTML" begin
        chart = Scatter3D(:dims_test, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("x", chart.functional_html)
        @test occursin("y", chart.functional_html)
        @test occursin("z", chart.functional_html)
    end

    @testset "Eigenvector button text" begin
        chart1 = Scatter3D(:eig_btn_show, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            show_eigenvectors = true
        )
        @test occursin("Hide", chart1.appearance_html)

        chart2 = Scatter3D(:eig_btn_hide, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            show_eigenvectors = false
        )
        @test occursin("Show", chart2.appearance_html)
    end

    @testset "Update function in functional HTML" begin
        chart = Scatter3D(:update_fn, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("updatePlotWithFilters", chart.functional_html)
    end

    @testset "Color map in functional HTML" begin
        chart = Scatter3D(:color_map_test, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("#636efa", chart.functional_html) || occursin("#EF553B", chart.functional_html)
    end

    @testset "Plotly chart types" begin
        chart = Scatter3D(:plotly_test, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("scatter3d", chart.functional_html)
        @test occursin("Plotly", chart.functional_html)
    end

    @testset "Error: too many default facets" begin
        @test_throws ErrorException Scatter3D(:too_many_facets, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            facet_cols = [:category, :group, :w],
            default_facet_cols = [:category, :group, :w]
        )
    end

    @testset "Error: default facet not in choices" begin
        @test_throws ErrorException Scatter3D(:facet_mismatch, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            facet_cols = [:category],
            default_facet_cols = :group
        )
    end

    @testset "Error: invalid facet column" begin
        @test_throws ErrorException Scatter3D(:bad_facet, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            facet_cols = :nonexistent
        )
    end

    @testset "Error: invalid filter column" begin
        @test_throws ErrorException Scatter3D(:bad_filter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            filters = Dict{Symbol, Any}(:nonexistent => [0.0])
        )
    end

    @testset "Four dimensions with dropdowns" begin
        chart = Scatter3D(:four_dims, df_scatter_3d, :df_scatter_3d, [:x, :y, :z, :w];
            color_cols = [:category]
        )
        @test occursin("x_col_select", chart.appearance_html)
        @test occursin("y_col_select", chart.appearance_html)
        @test occursin("z_col_select", chart.appearance_html)
    end

    @testset "All features combined" begin
        chart = Scatter3D(:all_features, df_scatter_3d, :df_scatter_3d, [:x, :y, :z, :w, :v];
            color_cols = [:category, :group],
            filters = Dict{Symbol, Any}(:w => [0.0], :v => [0.0]),
            facet_cols = [:category, :group],
            default_facet_cols = :category,
            show_eigenvectors = true,
            shared_camera = true,
            marker_size = 6,
            marker_opacity = 0.7,
            title = "All Features Test",
            notes = "Testing all features together"
        )
        @test occursin("All Features Test", chart.appearance_html)
        @test occursin("Testing all features together", chart.appearance_html)
        @test occursin("category", chart.appearance_html)
        @test occursin("group", chart.appearance_html)
        @test occursin("6", chart.functional_html)
        @test occursin("0.7", chart.functional_html)
    end

    @testset "Empty notes" begin
        chart = Scatter3D(:empty_notes, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category],
            notes = ""
        )
        @test occursin("", chart.appearance_html)
    end

    @testset "HTML structure" begin
        chart = Scatter3D(:html_struct, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
            color_cols = [:category]
        )
        @test occursin("<div", chart.appearance_html)
        @test occursin("<button", chart.appearance_html)
        @test occursin("eigenvector_toggle", chart.appearance_html)
    end
end
