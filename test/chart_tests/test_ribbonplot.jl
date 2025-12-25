using Test
using JSPlots
using DataFrames

@testset "RibbonPlot" begin
    # Create test data
    df = DataFrame(
        stage1 = repeat(["A", "B"], 10),
        stage2 = repeat(["X", "Y"], 10),
        stage3 = repeat(["P", "Q"], 10),
        value = rand(1:100, 20),
        region = repeat(["North", "South"], 10)
    )

    @testset "Basic ribbon plot creation" begin
        ribbon = RibbonPlot(:test_ribbon, df, :test_data;
            timestage_cols = [:stage1, :stage2, :stage3],
            value_cols = :value)

        @test ribbon.chart_title == :test_ribbon
        @test ribbon.data_label == :test_data
        @test !isempty(ribbon.functional_html)
        @test !isempty(ribbon.appearance_html)

        # Check for ribbon-specific elements
        @test occursin("sankey", ribbon.functional_html)
        @test occursin("TIMESTAGE_COLS", ribbon.functional_html)
        @test occursin("processRibbonData", ribbon.functional_html)
    end

    @testset "Ribbon plot with multiple value columns" begin
        df_multi = copy(df)
        df_multi.sales = rand(1:1000, 20)

        ribbon = RibbonPlot(:multi_val, df_multi, :multi_data;
            timestage_cols = [:stage1, :stage2, :stage3],
            value_cols = [:value, :sales])

        @test occursin("value_col", ribbon.appearance_html)
        @test occursin("Weight By", ribbon.appearance_html)
        @test occursin("VALUE_COLS", ribbon.functional_html)
    end

    @testset "Ribbon plot with filters" begin
        ribbon = RibbonPlot(:filtered, df, :filter_data;
            timestage_cols = [:stage1, :stage2, :stage3],
            value_cols = :value,
            filters = Dict{Symbol,Any}(:region => ["North"]))

        @test occursin("region_select", ribbon.appearance_html)
        @test occursin("North", ribbon.appearance_html)
        @test occursin("FILTER_COLS", ribbon.functional_html)
    end

    @testset "Ribbon plot with equal weighting (no value column)" begin
        ribbon = RibbonPlot(:count_mode, df, :count_data;
            timestage_cols = [:stage1, :stage2, :stage3])

        @test occursin("USE_COUNT", ribbon.functional_html)
        @test !occursin("value_col", ribbon.appearance_html)
    end

    @testset "Ribbon plot with two stages (minimum)" begin
        ribbon = RibbonPlot(:two_stage, df, :two_data;
            timestage_cols = [:stage1, :stage2],
            value_cols = :value)

        @test ribbon.chart_title == :two_stage
        @test !isempty(ribbon.functional_html)
    end

    @testset "Ribbon plot with four stages" begin
        ribbon = RibbonPlot(:four_stage, df, :four_data;
            timestage_cols = [:stage1, :stage2, :stage3, :region],
            value_cols = :value)

        @test occursin("stage1", ribbon.functional_html)
        @test occursin("stage2", ribbon.functional_html)
        @test occursin("stage3", ribbon.functional_html)
        @test occursin("region", ribbon.functional_html)
    end

    @testset "Error handling - insufficient timestage columns" begin
        @test_throws ErrorException RibbonPlot(:bad, df, :bad_data;
            timestage_cols = [:stage1])
    end

    @testset "Error handling - nonexistent timestage column" begin
        @test_throws ErrorException RibbonPlot(:bad, df, :bad_data;
            timestage_cols = [:stage1, :nonexistent])
    end

    @testset "Error handling - nonexistent value column" begin
        @test_throws ErrorException RibbonPlot(:bad, df, :bad_data;
            timestage_cols = [:stage1, :stage2],
            value_cols = :nonexistent)
    end

    @testset "HTML generation with different data formats" begin
        ribbon = RibbonPlot(:format_test, df, :format_data;
            timestage_cols = [:stage1, :stage2, :stage3],
            value_cols = :value)

        # Test embedded format
        page_embedded = JSPlotPage(
            Dict{Symbol,DataFrame}(:format_data => df),
            [ribbon];
            dataformat=:csv_embedded
        )
        outfile_embedded = tempname() * ".html"
        create_html(page_embedded, outfile_embedded)
        @test isfile(outfile_embedded)

        # Test external format
        mktempdir() do tmpdir
            page_external = JSPlotPage(
                Dict{Symbol,DataFrame}(:format_data => df),
                [ribbon];
                dataformat=:csv_external
            )
            outfile_external = joinpath(tmpdir, "ribbon_test.html")
            create_html(page_external, outfile_external)
            # External format creates a project directory
            expected_path = joinpath(tmpdir, "ribbon_test", "ribbon_test.html")
            @test isfile(expected_path)
        end
    end

    @testset "Multiple ribbons on same page" begin
        ribbon1 = RibbonPlot(:ribbon_a, df, :data_a;
            timestage_cols = [:stage1, :stage2, :stage3],
            value_cols = :value)

        ribbon2 = RibbonPlot(:ribbon_b, df, :data_b;
            timestage_cols = [:stage1, :stage2],
            value_cols = :value)

        page = JSPlotPage(
            Dict{Symbol,DataFrame}(
                :data_a => df,
                :data_b => df
            ),
            [ribbon1, ribbon2];
            dataformat=:csv_embedded
        )

        outfile = tempname() * ".html"
        create_html(page, outfile)
        @test isfile(outfile)
    end

    @testset "Title and notes" begin
        ribbon = RibbonPlot(:titled, df, :titled_data;
            timestage_cols = [:stage1, :stage2, :stage3],
            value_cols = :value,
            title = "Test Ribbon Title",
            notes = "These are test notes")

        @test occursin("Test Ribbon Title", ribbon.appearance_html)
        @test occursin("These are test notes", ribbon.appearance_html)
    end
end
