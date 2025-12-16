using Test
using JSPlots
using DataFrames

@testset "PieChart" begin
    # Create basic test data
    test_df = DataFrame(
        category = ["A", "B", "C", "D"],
        value = [25, 30, 20, 25]
    )

    @testset "Basic creation" begin
        chart = PieChart(:test_pie, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            title = "Test Pie Chart"
        )
        @test chart.chart_title == :test_pie
        @test chart.data_label == :test_df
        @test occursin("test_pie", chart.functional_html)
        @test occursin("value", chart.functional_html)
        @test occursin("category", chart.functional_html)
        @test occursin("Test Pie Chart", chart.appearance_html)
    end

    @testset "With hole parameter (donut chart)" begin
        chart = PieChart(:donut_chart, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            hole = 0.4
        )
        @test occursin("0.4", chart.functional_html)
        @test occursin("HOLE", chart.functional_html)
    end

    @testset "Legend disabled" begin
        chart = PieChart(:no_legend, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            show_legend = false
        )
        @test occursin("false", chart.functional_html)
        @test occursin("SHOW_LEGEND", chart.functional_html)
    end

    @testset "Legend enabled" begin
        chart = PieChart(:with_legend, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            show_legend = true
        )
        @test occursin("true", chart.functional_html)
        @test occursin("SHOW_LEGEND", chart.functional_html)
    end

    @testset "With notes" begin
        chart = PieChart(:with_notes, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            notes = "This is a test note"
        )
        @test occursin("This is a test note", chart.appearance_html)
    end

    @testset "With filters" begin
        df_filter = DataFrame(
            category = repeat(["A", "B", "C"], 6),
            value = rand(18),
            region = repeat(["North", "South"], 9),
            year = repeat(["2023", "2024"], 9)
        )
        chart = PieChart(:with_filters, df_filter, :df_filter;
            value_col = :value,
            label_col = :category,
            filters = Dict{Symbol,Any}(:region => "North", :year => "2023")
        )
        @test occursin("region", chart.functional_html)
        @test occursin("year", chart.functional_html)
        @test occursin("North", chart.functional_html)
        @test occursin("2023", chart.functional_html)
        @test occursin("_select", chart.appearance_html)
    end

    @testset "With single facet column (facet wrap)" begin
        df_facet = DataFrame(
            category = repeat(["A", "B", "C"], 6),
            value = rand(18),
            region = repeat(["North", "South", "East"], 6)
        )
        chart = PieChart(:facet_wrap, df_facet, :df_facet;
            value_col = :value,
            label_col = :category,
            facet_cols = :region,
            default_facet_cols = :region
        )
        @test occursin("region", chart.functional_html)
        @test occursin("facet1_selector", chart.appearance_html)
        @test occursin("facet2_selector", chart.appearance_html)
        @test occursin("createFacetWrap", chart.functional_html)
    end

    @testset "With multiple facet columns (facet grid)" begin
        df_grid = DataFrame(
            category = repeat(["A", "B", "C"], 12),
            value = rand(36),
            region = repeat(["North", "South"], 18),
            year = repeat(["2023", "2024"], 18)
        )
        chart = PieChart(:facet_grid, df_grid, :df_grid;
            value_col = :value,
            label_col = :category,
            facet_cols = [:region, :year],
            default_facet_cols = [:region, :year]
        )
        @test occursin("region", chart.functional_html)
        @test occursin("year", chart.functional_html)
        @test occursin("facet1_selector", chart.appearance_html)
        @test occursin("facet2_selector", chart.appearance_html)
        @test occursin("createFacetGrid", chart.functional_html)
    end

    @testset "Facet cols as vector" begin
        df_facet = DataFrame(
            category = repeat(["A", "B"], 6),
            value = rand(12),
            region = repeat(["North", "South"], 6)
        )
        chart = PieChart(:facet_vec, df_facet, :df_facet;
            value_col = :value,
            label_col = :category,
            facet_cols = [:region],
            default_facet_cols = nothing
        )
        @test occursin("region", chart.appearance_html)
        @test occursin("None", chart.appearance_html)
    end

    @testset "No faceting (default)" begin
        chart = PieChart(:no_facet, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test !occursin("facet1_selector", chart.appearance_html)
        @test occursin("createPieChart", chart.functional_html)
    end

    @testset "Color mapping" begin
        chart = PieChart(:color_map, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("COLOR_MAP", chart.functional_html)
        @test occursin("#636efa", chart.functional_html) || occursin("#EF553B", chart.functional_html)
    end

    @testset "Aggregation functionality" begin
        # Test that data aggregation is included
        chart = PieChart(:aggregation, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("aggregateData", chart.functional_html)
    end

    @testset "Filter functionality" begin
        df_filter = DataFrame(
            category = repeat(["A", "B"], 4),
            value = rand(8),
            group = repeat(["X", "Y"], 4)
        )
        chart = PieChart(:filter_func, df_filter, :df_filter;
            value_col = :value,
            label_col = :category,
            filters = Dict{Symbol,Any}(:group => "X")
        )
        @test occursin("filterData", chart.functional_html)
        @test occursin("getFilterValues", chart.functional_html)
    end

    @testset "Event listeners" begin
        chart = PieChart(:listeners, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("addEventListener", chart.functional_html)
        @test occursin("jsplots_data_loaded", chart.functional_html)
    end

    @testset "Plotly chart types" begin
        chart = PieChart(:plotly_type, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("type: 'pie'", chart.functional_html)
        @test occursin("Plotly.newPlot", chart.functional_html)
    end

    @testset "Error: invalid value_col" begin
        @test_throws ErrorException PieChart(:error_test, test_df, :test_df;
            value_col = :nonexistent,
            label_col = :category
        )
    end

    @testset "Error: invalid label_col" begin
        @test_throws ErrorException PieChart(:error_test, test_df, :test_df;
            value_col = :value,
            label_col = :nonexistent
        )
    end

    @testset "Error: hole out of range (negative)" begin
        @test_throws ErrorException PieChart(:error_test, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            hole = -0.1
        )
    end

    @testset "Error: hole out of range (>= 1)" begin
        @test_throws ErrorException PieChart(:error_test, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            hole = 1.0
        )
    end

    @testset "Error: too many default facets" begin
        df_facet = DataFrame(
            category = repeat(["A", "B"], 4),
            value = rand(8),
            f1 = repeat(["X", "Y"], 4),
            f2 = repeat(["M", "N"], 4),
            f3 = repeat(["P", "Q"], 4)
        )
        @test_throws ErrorException PieChart(:error_test, df_facet, :df_facet;
            value_col = :value,
            label_col = :category,
            facet_cols = [:f1, :f2, :f3],
            default_facet_cols = [:f1, :f2, :f3]
        )
    end

    @testset "Error: default facet not in choices" begin
        df_facet = DataFrame(
            category = repeat(["A", "B"], 4),
            value = rand(8),
            f1 = repeat(["X", "Y"], 4),
            f2 = repeat(["M", "N"], 4)
        )
        @test_throws ErrorException PieChart(:error_test, df_facet, :df_facet;
            value_col = :value,
            label_col = :category,
            facet_cols = [:f1],
            default_facet_cols = :f2
        )
    end

    @testset "Chart with all features enabled" begin
        df_full = DataFrame(
            category = repeat(["A", "B", "C"], 12),
            value = rand(36),
            region = repeat(["North", "South"], 18),
            year = repeat(["2023", "2024"], 18),
            product = repeat(["P1", "P2"], 18)
        )
        chart = PieChart(:full_features, df_full, :df_full;
            value_col = :value,
            label_col = :category,
            filters = Dict{Symbol,Any}(:product => "P1"),
            facet_cols = [:region, :year],
            default_facet_cols = [:region],
            hole = 0.3,
            show_legend = true,
            title = "Full Feature Test",
            notes = "Testing all features together"
        )
        @test chart.chart_title == :full_features
        @test occursin("Full Feature Test", chart.appearance_html)
        @test occursin("Testing all features together", chart.appearance_html)
        @test occursin("product", chart.functional_html)
        @test occursin("region", chart.functional_html)
        @test occursin("year", chart.functional_html)
        @test occursin("0.3", chart.functional_html)
    end

    @testset "Multiple data points with same label (aggregation test)" begin
        df_agg = DataFrame(
            category = ["A", "A", "B", "B", "C"],
            value = [10, 15, 20, 25, 30]
        )
        chart = PieChart(:aggregation_test, df_agg, :df_agg;
            value_col = :value,
            label_col = :category
        )
        # Should aggregate A: 25, B: 45, C: 30
        @test occursin("aggregateData", chart.functional_html)
    end

    @testset "Empty filters dictionary" begin
        chart = PieChart(:empty_filters, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            filters = Dict{Symbol,Any}()
        )
        @test !occursin("_select", chart.appearance_html)
    end

    @testset "Hole at boundary (0.0)" begin
        chart = PieChart(:hole_zero, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            hole = 0.0
        )
        @test occursin("0.0", chart.functional_html)
    end

    @testset "Hole at boundary (0.99)" begin
        chart = PieChart(:hole_max, test_df, :test_df;
            value_col = :value,
            label_col = :category,
            hole = 0.99
        )
        @test occursin("0.99", chart.functional_html)
    end

    @testset "Sanitized chart title" begin
        chart = PieChart(Symbol("test-pie.chart"), test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("test_pie_chart", chart.functional_html)
    end

    @testset "Hover info" begin
        chart = PieChart(:hover_test, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("hoverinfo", chart.functional_html)
        @test occursin("label+value+percent", chart.functional_html)
    end

    @testset "Facet annotations" begin
        df_facet = DataFrame(
            category = repeat(["A", "B"], 4),
            value = rand(8),
            region = repeat(["North", "South"], 4)
        )
        chart = PieChart(:facet_annotations, df_facet, :df_facet;
            value_col = :value,
            label_col = :category,
            facet_cols = :region,
            default_facet_cols = :region
        )
        @test occursin("annotations", chart.functional_html)
    end

    @testset "Update plot function" begin
        chart = PieChart(:update_plot, test_df, :test_df;
            value_col = :value,
            label_col = :category
        )
        @test occursin("function updatePlot", chart.functional_html)
    end
end
