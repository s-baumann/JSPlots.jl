using Test
using JSPlots
include("test_data.jl")

@testset "AreaChart" begin
    @testset "Basic creation" begin
        chart = AreaChart(:test_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            title = "Test Area Chart"
        )
        @test chart.chart_title == :test_area
        @test chart.data_label == :test_df
        @test occursin("test_area", chart.functional_html)
        @test occursin("x", chart.functional_html)
    end

    @testset "With grouping and filters" begin
        chart = AreaChart(:grouped_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            group_cols = [:category],
            filters = Dict{Symbol,Any}(:category => "A"),
            title = "Grouped Area Chart"
        )
        @test occursin("category", chart.functional_html)
        @test occursin("A", chart.functional_html)
    end

    @testset "Without group column" begin
        df_no_group = DataFrame(x = 1:10, y = rand(10))
        chart = AreaChart(:no_group_area, df_no_group, :df_no_group;
            x_cols = [:x],
            y_cols = [:y],
            title = "No Group Area Chart"
        )
        @test occursin("__no_group__", chart.functional_html)
    end

    @testset "Stack mode options" begin
        for mode in ["unstack", "stack", "normalised_stack"]
            chart = AreaChart(:stack_test, test_df, :test_df;
                x_cols = [:x],
                y_cols = [:y],
                group_cols = [:category],
                stack_mode = mode,
                title = "Stack Mode: $mode"
            )
            @test occursin(mode, chart.functional_html)
        end
    end

    @testset "With faceting" begin
        chart = AreaChart(:facet_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            group_cols = [:category],
            facet_cols = [:color],
            default_facet_cols = [:color],
            title = "Faceted Area Chart"
        )
        @test occursin("color", chart.functional_html)
        @test occursin("FACET_COLS", chart.functional_html)
    end

    @testset "Custom fill opacity" begin
        chart = AreaChart(:opacity_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            fill_opacity = 0.8,
            title = "Custom Opacity"
        )
        @test occursin("0.8", chart.functional_html)
    end


    @testset "Multiple dimension options" begin
        df_multi = DataFrame(
            x1 = 1:10,
            x2 = 11:20,
            y1 = rand(10),
            y2 = rand(10),
            group1 = repeat(["A", "B"], 5),
            group2 = repeat(["X", "Y"], 5)
        )
        chart = AreaChart(:multi_area, df_multi, :df_multi;
            x_cols = [:x1, :x2],
            y_cols = [:y1, :y2],
            group_cols = [:group1, :group2],
            title = "Multiple Dimensions"
        )
        @test occursin("x1", chart.functional_html)
        @test occursin("x2", chart.functional_html)
        @test occursin("y1", chart.functional_html)
        @test occursin("y2", chart.functional_html)
        @test occursin("group1", chart.functional_html)
        @test occursin("group2", chart.functional_html)
    end
end
