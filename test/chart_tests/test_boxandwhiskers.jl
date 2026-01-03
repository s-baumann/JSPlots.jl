using Test
using JSPlots
using DataFrames
using Random

# Explicitly import JSPlots types
import JSPlots: BoxAndWhiskers

@testset "BoxAndWhiskers" begin
    # Helper function to generate test data
    function generate_test_data(n_per_group=50)
        Random.seed!(123)
        DataFrame(
            group = repeat(["A", "B", "C", "D", "E", "F"], inner = n_per_group),
            value = vcat(
                randn(n_per_group) .+ 2,
                randn(n_per_group) .+ 5,
                randn(n_per_group) .+ 8,
                randn(n_per_group) .+ 3,
                randn(n_per_group) .+ 6,
                randn(n_per_group) .+ 9
            ),
            value2 = vcat(
                randn(n_per_group) .* 2,
                randn(n_per_group) .* 3,
                randn(n_per_group) .* 1.5,
                randn(n_per_group) .* 2.5,
                randn(n_per_group) .* 3.5,
                randn(n_per_group) .* 1.8
            ),
            country = repeat(["USA", "USA", "Brazil", "Brazil", "Argentina", "Argentina"], inner = n_per_group),
            industry = repeat(["Tech", "Finance", "Tech", "Finance", "Tech", "Finance"], inner = n_per_group),
            region = repeat(["North", "South"], inner = n_per_group * 3)
        )
    end

    @testset "Basic constructor" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:test_bw, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        @test bw.chart_title == :test_bw
        @test bw.data_label == :test_data
        @test !isempty(bw.functional_html)
        @test !isempty(bw.appearance_html)

        # Check for box plot elements (now using scatter traces)
        @test occursin("type: 'scatter'", bw.functional_html)
        @test occursin("computeStats", bw.functional_html)
        @test occursin("updateChart_test_bw", bw.functional_html)
    end

    @testset "Multiple value columns" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:multi_val, df, :test_data;
            x_cols = [:value, :value2],
            group_col = :group)

        @test occursin("xCols_multi_val", bw.functional_html)
        @test occursin("x_col_select_multi_val", bw.appearance_html)
        @test occursin("Value", bw.appearance_html)
    end

    @testset "Color columns" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:colored, df, :test_data;
            x_cols = [:value],
            color_cols = [:country, :industry],
            group_col = :group)

        @test occursin("colorCols_colored", bw.functional_html)
        @test occursin("color_col_select_colored", bw.appearance_html)
        @test occursin("Color by", bw.appearance_html)
        @test occursin("colorMaps_colored", bw.functional_html)
    end

    @testset "Grouping columns" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:grouped, df, :test_data;
            x_cols = [:value],
            grouping_cols = [:country, :industry],
            group_col = :group)

        @test occursin("groupingCols_grouped", bw.functional_html)
        @test occursin("grouping_col_select_grouped", bw.appearance_html)
        @test occursin("Group by", bw.appearance_html)
    end

    @testset "Combined color and grouping" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:combined, df, :test_data;
            x_cols = [:value],
            color_cols = [:country],
            grouping_cols = [:industry],
            group_col = :group)

        @test occursin("Color by", bw.appearance_html)
        @test occursin("Group by", bw.appearance_html)
        @test occursin("colorMaps_combined", bw.functional_html)
    end

    @testset "Filters" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:filtered, df, :test_data;
            x_cols = [:value],
            group_col = :group,
            filters = Dict(:country => ["USA", "Brazil"]))

        @test occursin("country_select_filtered", bw.appearance_html)
        @test occursin("categoricalFilters_filtered", bw.functional_html)
    end

    @testset "Title and notes" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:titled, df, :test_data;
            x_cols = [:value],
            group_col = :group,
            title = "Test Title",
            notes = "Test notes here")

        @test occursin("Test Title", bw.appearance_html)
        @test occursin("Test notes here", bw.appearance_html)
    end

    @testset "Statistics computation in JavaScript" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:stats_test, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Check for statistics functions
        @test occursin("computeStats", bw.functional_html)
        @test occursin("min:", bw.functional_html)
        @test occursin("q1:", bw.functional_html)
        @test occursin("median:", bw.functional_html)
        @test occursin("q3:", bw.functional_html)
        @test occursin("max:", bw.functional_html)
        @test occursin("mean:", bw.functional_html)
        @test occursin("stdev:", bw.functional_html)
    end

    @testset "Mean and stdev visualization" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:mean_stdev, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Check for wavy line and markers for mean/stdev (no longer using error bars)
        @test occursin("numWaves", bw.functional_html)
        @test occursin("symbol: 'diamond'", bw.functional_html)
        @test occursin("Mean ± StDev", bw.functional_html)
    end

    @testset "Group labeling" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:labels, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        @test occursin("annotations", bw.functional_html)
        @test occursin("text:", bw.functional_html)
    end

    @testset "Horizontal orientation" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:horizontal, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Check for horizontal layout (values on x-axis, groups on y-axis)
        @test occursin("xaxis:", bw.functional_html)
        @test occursin("yaxis:", bw.functional_html)
    end

    @testset "Aspect ratio control" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:aspect, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        @test occursin("setupAspectRatioControl", bw.functional_html)
        @test occursin("Aspect Ratio", bw.appearance_html)
    end

    @testset "Error handling for non-numeric columns" begin
        df = DataFrame(
            group = ["A", "B", "C"],
            value = ["not", "a", "number"]
        )

        @test_throws ErrorException BoxAndWhiskers(:bad_data, df, :test_data;
            x_cols = [:value],
            group_col = :group)
    end

    @testset "Error handling for missing columns" begin
        df = generate_test_data(30)

        @test_throws ErrorException BoxAndWhiskers(:missing_col, df, :test_data;
            x_cols = [:nonexistent],
            group_col = :group)
    end

    @testset "Chart title sanitization" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(Symbol("my-chart.test"), df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Should sanitize to my_chart_test
        @test occursin("updateChart_my_chart_test", bw.functional_html)
        @test occursin("my_chart_test", bw.appearance_html)
    end

    @testset "Dependencies function" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:deps_test, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        deps = JSPlots.dependencies(bw)
        @test deps == [:test_data]
    end

    @testset "Grouping section labels" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:grouping_labels, df, :test_data;
            x_cols = [:value],
            color_cols = [:country],
            grouping_cols = [:country],
            group_col = :group)

        # Should include code for grouping section labels
        @test occursin("currentGrouping", bw.functional_html)
        @test occursin("groupingStartY", bw.functional_html)
    end

    @testset "Dynamic height adjustment" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:dynamic_height, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Should dynamically set height based on number of groups
        @test occursin("height: Math.max", bw.functional_html)
    end

    @testset "Filter application" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:filter_apply, df, :test_data;
            x_cols = [:value],
            group_col = :group,
            filters = Dict(:region => ["North"]))

        @test occursin("applyFiltersWithCounting", bw.functional_html)
        @test occursin("filters_filter_apply", bw.functional_html)
    end

    @testset "No color or grouping columns" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:no_options, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Should work without color or grouping dropdowns
        @test !occursin("Color by", bw.appearance_html)
        @test !occursin("Group by", bw.appearance_html)
    end

    @testset "Single x column" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:single_x, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Should not show dropdown for single x column
        @test !occursin("x_col_select", bw.appearance_html)
    end

    @testset "Data grouping and sorting" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:sorting, df, :test_data;
            x_cols = [:value],
            grouping_cols = [:country],
            group_col = :group)

        # Should include sorting logic
        @test occursin("groupNames.sort", bw.functional_html)
        @test occursin("localeCompare", bw.functional_html)
    end

    @testset "Empty groups handling" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:empty_groups, df, :test_data;
            x_cols = [:value],
            group_col = :group,
            filters = Dict(:country => ["NonExistent"]))

        # Should handle case where filters result in empty groups
        @test occursin("if (!stats) return", bw.functional_html)
    end

    @testset "Color map generation" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:color_maps, df, :test_data;
            x_cols = [:value],
            color_cols = [:country, :industry],
            group_col = :group)

        # Should generate color maps for all color columns
        @test occursin("colorMaps_color_maps", bw.functional_html)
    end

    @testset "Plot attributes section" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:attributes, df, :test_data;
            x_cols = [:value, :value2],
            color_cols = [:country],
            grouping_cols = [:industry],
            group_col = :group)

        @test occursin("Plot Attributes", bw.appearance_html)
    end

    @testset "Legend for mean/stdev" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:legend, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        # Only first trace should show legend
        @test occursin("showlegend: index === 0", bw.functional_html)
    end

    @testset "Hover template" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:hover, df, :test_data;
            x_cols = [:value],
            group_col = :group)

        @test occursin("hovertemplate:", bw.functional_html)
        # Check for Greek symbols and marker labels used in new implementation
        @test occursin("μ", bw.functional_html)
        @test occursin("σ", bw.functional_html)
    end

    @testset "Spacing between grouping sections" begin
        df = generate_test_data(30)

        bw = BoxAndWhiskers(:spacing, df, :test_data;
            x_cols = [:value],
            grouping_cols = [:country],
            group_col = :group)

        # Should add extra spacing between different grouping values
        @test occursin("yPos--", bw.functional_html)
    end
end
