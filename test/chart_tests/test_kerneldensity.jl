using Test
using JSPlots
using DataFrames

@testset "KernelDensity" begin
    df_kde = DataFrame(value = randn(100))

    @testset "Basic creation" begin
        chart = KernelDensity(:test_kde, df_kde, :df_kde;
            value_cols = [:value],
            title = "KDE Test"
        )
        @test chart.chart_title == :test_kde
        @test occursin("value", chart.functional_html)
        @test occursin("kernelDensity", chart.functional_html)
    end

    @testset "With groups" begin
        df_grouped = DataFrame(
            value = randn(100),
            group = repeat(["A", "B"], 50)
        )
        chart = KernelDensity(:grouped_kde, df_grouped, :df_grouped;
            value_cols = [:value],
            color_cols = [:group]
        )
        @test occursin("group", chart.functional_html)
    end

    @testset "With facets" begin
        df_faceted = DataFrame(
            value = randn(100),
            facet1 = repeat(["X", "Y"], 50),
            facet2 = repeat(["P", "Q"], inner=50)
        )
        chart = KernelDensity(:faceted_kde, df_faceted, :df_faceted;
            value_cols = [:value],
            facet_cols = [:facet1, :facet2],
            default_facet_cols = :facet1
        )
        @test occursin("facet1", chart.functional_html)
        @test occursin("facet2", chart.functional_html)
    end

    @testset "With filters" begin
        df_filtered = DataFrame(
            value = randn(100),
            age = rand(18:80, 100),
            category = rand(["A", "B", "C"], 100)
        )
        chart = KernelDensity(:filtered_kde, df_filtered, :df_filtered;
            value_cols = [:value],
            filters = [:age, :category]
        )
        @test occursin("age", chart.appearance_html)
        @test occursin("category", chart.appearance_html)
    end

    @testset "Custom bandwidth and appearance" begin
        chart = KernelDensity(:custom_kde, df_kde, :df_kde;
            value_cols = [:value],
            bandwidth = 1.5,
            density_opacity = 0.7,
            fill_density = false
        )
        @test occursin("1.5", chart.functional_html)
        @test occursin("0.7", chart.functional_html)
        @test occursin("none", chart.functional_html)
    end
end
