using Test
using JSPlots
using DataFrames

# Explicitly import JSPlots types to avoid conflict with Makie
import JSPlots: Waterfall

@testset "Waterfall" begin
    # Create simple test data
    df = DataFrame(
        item = ["Revenue", "COGS", "OpEx", "Net"],
        category = ["Income", "Costs", "Costs", "Total"],
        value = [1000, -400, -200, 400],
        region = repeat(["North"], 4),
        year = repeat([2024], 4)
    )

    @testset "Basic waterfall creation" begin
        wf = Waterfall(:test_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value)

        @test wf.chart_title == :test_wf
        @test wf.data_label == :test_data
        @test !isempty(wf.functional_html)
        @test !isempty(wf.appearance_html)

        # Check for waterfall-specific elements
        @test occursin("type: 'bar'", wf.functional_html)  # Now uses bar chart
        @test occursin("calculateWaterfall", wf.functional_html)
        @test occursin("ITEM_COL", wf.functional_html)
        @test occursin("CATEGORY_COL", wf.functional_html)
        @test occursin("VALUE_COL", wf.functional_html)
    end

    @testset "Waterfall with table" begin
        wf = Waterfall(:table_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            show_table = true)

        @test occursin("waterfall-table", wf.appearance_html)
        @test occursin("Calculation Table", wf.appearance_html)
        @test occursin("Reset", wf.appearance_html)
        @test occursin("updateTable", wf.functional_html)
    end

    @testset "Waterfall without table" begin
        wf = Waterfall(:no_table_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            show_table = false)

        @test !occursin("Calculation Table", wf.appearance_html)
        @test !occursin("Reset", wf.appearance_html)
    end

    @testset "Waterfall with totals" begin
        wf = Waterfall(:totals_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            show_totals = true)

        @test occursin("SHOW_TOTALS = true", wf.functional_html)
        @test occursin("Total", wf.functional_html)
    end

    @testset "Waterfall without totals" begin
        wf = Waterfall(:no_totals_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            show_totals = false)

        @test occursin("SHOW_TOTALS = false", wf.functional_html)
    end

    @testset "Waterfall with custom title and notes" begin
        wf = Waterfall(:custom_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            title = "Custom Waterfall Title",
            notes = "These are custom notes")

        @test occursin("Custom Waterfall Title", wf.appearance_html)
        @test occursin("These are custom notes", wf.appearance_html)
    end

    @testset "Waterfall with filters (single-select)" begin
        wf = Waterfall(:filtered_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            filters = Dict{Symbol,Any}(:region => ["North"]))

        @test occursin("region", wf.functional_html)
        @test occursin("region_select", wf.appearance_html)
        # Check it's single-select (no multiple attribute)
        @test !occursin("multiple", wf.appearance_html)
    end

    @testset "Waterfall error - missing item column" begin
        @test_throws ErrorException Waterfall(:error_wf, df, :test_data;
            item_col = :nonexistent,
            color_cols = [:category],
            value_col = :value)
    end

    @testset "Waterfall error - missing category column" begin
        @test_throws ErrorException Waterfall(:error_wf, df, :test_data;
            item_col = :item,
            color_cols = [:nonexistent],
            value_col = :value)
    end

    @testset "Waterfall error - missing value column" begin
        @test_throws ErrorException Waterfall(:error_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :nonexistent)
    end

    @testset "Waterfall dependencies function" begin
        wf = Waterfall(:dep_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value)

        deps = JSPlots.dependencies(wf)
        @test deps == [:test_data]
    end

    @testset "Waterfall click-to-remove functionality" begin
        wf = Waterfall(:clickable_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value)

        # Check for click handler functions
        @test occursin("toggleItem", wf.functional_html)
        @test occursin("toggleCategoryGroup", wf.functional_html)
        @test occursin("resetWaterfall", wf.functional_html)
        @test occursin("removedItems", wf.functional_html)
        @test occursin("removedCategories", wf.functional_html)
        @test occursin("plotly_click", wf.functional_html)
    end

    @testset "Waterfall color scheme" begin
        wf = Waterfall(:colors_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value)

        # Check for new color definitions
        @test occursin("#4CAF50", wf.functional_html)  # Green for positive
        @test occursin("#F44336", wf.functional_html)  # Red for negative
        @test occursin("#000000", wf.functional_html)  # Black for total
        @test occursin("Color By", wf.appearance_html)  # Color mode dropdown
    end

    @testset "Waterfall styles" begin
        wf = Waterfall(:styles_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value)

        # Check for CSS styles
        @test occursin("waterfall-layout", wf.appearance_html)
        @test occursin("flex-direction: column", wf.appearance_html)
        @test occursin("positive", wf.appearance_html)
        @test occursin("negative", wf.appearance_html)
        @test occursin("removed", wf.appearance_html)
    end

    @testset "Waterfall create_html integration test" begin
        wf = Waterfall(:integration_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            title = "Integration Test Waterfall",
            show_table = true)

        page = JSPlotPage(
            Dict{Symbol, DataFrame}(:test_data => df),
            [wf];
            dataformat=:csv_embedded
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "test_waterfall.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Integration Test Waterfall", html_content)
            @test occursin("type: 'bar'", html_content)
            @test occursin("plotly", html_content)
            @test occursin("calculateWaterfall", html_content)
            @test occursin("waterfall-table", html_content)
        end
    end

    @testset "Waterfall multiple on same page" begin
        wf1 = Waterfall(:wf_one, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            title = "First Waterfall")

        wf2 = Waterfall(:wf_two, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            title = "Second Waterfall")

        page = JSPlotPage(
            Dict{Symbol, DataFrame}(:test_data => df),
            [wf1, wf2];
            dataformat=:csv_embedded
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "multi_waterfall.html")
            create_html(page, output_file)

            @test isfile(output_file)
            html_content = read(output_file, String)

            # Check both waterfalls are present
            @test occursin("First Waterfall", html_content)
            @test occursin("Second Waterfall", html_content)
            @test occursin("wf_one", html_content)
            @test occursin("wf_two", html_content)

            # Check that each has its own functions
            @test occursin("updateChart_wf_one", html_content)
            @test occursin("updateChart_wf_two", html_content)
            @test occursin("resetWaterfall_wf_one", html_content)
            @test occursin("resetWaterfall_wf_two", html_content)
        end
    end

    @testset "Waterfall external format" begin
        wf = Waterfall(:external_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value)

        page = JSPlotPage(
            Dict{Symbol, DataFrame}(:test_data => df),
            [wf];
            dataformat=:parquet
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "external_waterfall.html")
            create_html(page, output_file)

            # External format creates a project directory
            expected_html = joinpath(tmpdir, "external_waterfall", "external_waterfall.html")
            @test isfile(expected_html)

            # Check that data directory was created
            data_dir = joinpath(tmpdir, "external_waterfall", "data")
            @test isdir(data_dir)

            # Check HTML references external data
            html_content = read(expected_html, String)
            @test occursin("loadDataset", html_content)
        end
    end

    @testset "Waterfall with integer filters" begin
        # Test that integer filter values work correctly
        wf = Waterfall(:int_filter_wf, df, :test_data;
            item_col = :item,
            color_cols = [:category],
            value_col = :value,
            filters = Dict{Symbol,Any}(:year => [2024]))

        @test occursin("year_select", wf.appearance_html)
        @test occursin("2024", wf.appearance_html)
    end
end

println("Waterfall tests completed successfully!")
