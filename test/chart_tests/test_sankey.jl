using Test
using JSPlots
using DataFrames
using CategoricalArrays

# Explicitly import JSPlots types to avoid conflict with Makie
import JSPlots: SanKey

@testset "SanKey" begin
    # Create test data with proper panel structure
    df = DataFrame(
        person_id = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4],
        year = [2020, 2021, 2022, 2020, 2021, 2022, 2020, 2021, 2022, 2020, 2021, 2022],
        party = ["Rep", "Rep", "Dem", "Dem", "Ind", "Ind", "Rep", "Rep", "Rep", "Dem", "Dem", "Rep"],
        employment = ["Employed", "Employed", "Unemployed", "Employed", "Employed", "Employed",
                     "Unemployed", "Employed", "Employed", "Employed", "Unemployed", "Employed"],
        value = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100],
        region = repeat(["North", "South"], 6)
    )

    @testset "Basic sankey creation with id_col" begin
        sankey = SanKey(:test_sankey, df, :test_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value])

        @test sankey.chart_title == :test_sankey
        @test sankey.data_label == :test_data
        @test !isempty(sankey.functional_html)
        @test !isempty(sankey.appearance_html)

        # Check for sankey-specific elements
        @test occursin("type: \"sankey\"", sankey.functional_html)
        @test occursin("ID_COL", sankey.functional_html)
        @test occursin("TIME_COL", sankey.functional_html)
        @test occursin("COLOR_COL", sankey.functional_html)
        @test occursin("processSankeyData", sankey.functional_html)
    end

    @testset "Sankey without id_col (auto-generated)" begin
        # Create budget-style data where each row is independent
        budget_df = DataFrame(
            stage = ["Revenue", "Revenue", "Total", "Spending", "Spending"],
            category = ["Sales", "Services", "Total", "Rent", "Salaries"],
            value = [100, 50, 150, 60, 90]
        )
        budget_df[!, :stage] = categorical(budget_df.stage; levels = ["Revenue", "Total", "Spending"])

        sankey = SanKey(:budget, budget_df, :budget_data;
            time_col = :stage,
            color_cols = [:category],
            value_cols = [:value])

        @test sankey.chart_title == :budget
        @test !isempty(sankey.functional_html)
        @test occursin("_auto_id", sankey.functional_html)
        @test occursin("ID_COL", sankey.functional_html)
    end

    @testset "Sankey with multiple color columns" begin
        sankey = SanKey(:multi_color, df, :multi_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party, :employment],
            value_cols = [:value])

        @test occursin("color_col", sankey.appearance_html)
        @test occursin("Affiliation", sankey.appearance_html)
        @test occursin("COLOR_COLS", sankey.functional_html)
        @test occursin("party", sankey.functional_html)
        @test occursin("employment", sankey.functional_html)
    end

    @testset "Sankey with multiple value columns" begin
        df_multi = copy(df)
        df_multi.sales = rand(1:1000, 12)

        sankey = SanKey(:multi_val, df_multi, :multi_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value, :sales])

        @test occursin("value_col", sankey.appearance_html)
        @test occursin("Weight By", sankey.appearance_html)
        @test occursin("VALUE_COLS", sankey.functional_html)
    end

    @testset "Sankey with filters" begin
        sankey = SanKey(:filtered, df, :filter_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value],
            filters = Dict{Symbol,Any}(:region => ["North"]))

        @test occursin("region_select", sankey.appearance_html)
        @test occursin("North", sankey.appearance_html)
        @test occursin("CATEGORICAL_FILTERS", sankey.functional_html) || occursin("CONTINUOUS_FILTERS", sankey.functional_html)
    end

    @testset "Sankey with equal weighting (no value column)" begin
        sankey = SanKey(:count_mode, df, :count_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party])

        @test occursin("USE_COUNT", sankey.functional_html)
        @test occursin("true", sankey.functional_html)
        @test !occursin("value_col", sankey.appearance_html)
    end

    @testset "Sankey with two time periods (minimum)" begin
        df_two = filter(row -> row.year in [2020, 2021], df)

        sankey = SanKey(:two_stage, df_two, :two_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value])

        @test sankey.chart_title == :two_stage
        @test !isempty(sankey.functional_html)
    end

    @testset "Error handling - nonexistent id_col" begin
        @test_throws ErrorException SanKey(:bad, df, :bad_data;
            id_col = :nonexistent,
            time_col = :year,
            color_cols = [:party])
    end

    @testset "Error handling - nonexistent time_col" begin
        @test_throws ErrorException SanKey(:bad, df, :bad_data;
            id_col = :person_id,
            time_col = :nonexistent,
            color_cols = [:party])
    end

    @testset "Error handling - nonexistent color_col" begin
        @test_throws ErrorException SanKey(:bad, df, :bad_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:nonexistent])
    end

    @testset "Error handling - nonexistent value column" begin
        @test_throws ErrorException SanKey(:bad, df, :bad_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:nonexistent])
    end

    @testset "HTML generation with different data formats" begin
        sankey = SanKey(:format_test, df, :format_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value])

        # Test embedded format
        page_embedded = JSPlotPage(
            Dict{Symbol,DataFrame}(:format_data => df),
            [sankey];
            dataformat=:csv_embedded
        )
        outfile_embedded = tempname() * ".html"
        create_html(page_embedded, outfile_embedded)
        @test isfile(outfile_embedded)

        # Test external format
        mktempdir() do tmpdir
            page_external = JSPlotPage(
                Dict{Symbol,DataFrame}(:format_data => df),
                [sankey];
                dataformat=:csv_external
            )
            outfile_external = joinpath(tmpdir, "sankey_test.html")
            create_html(page_external, outfile_external)
            # External format creates a project directory
            expected_path = joinpath(tmpdir, "sankey_test", "sankey_test.html")
            @test isfile(expected_path)
        end
    end

    @testset "Multiple sankeys on same page" begin
        sankey1 = SanKey(:sankey_a, df, :data_a;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value])

        sankey2 = SanKey(:sankey_b, df, :data_b;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:employment],
            value_cols = [:value])

        page = JSPlotPage(
            Dict{Symbol,DataFrame}(
                :data_a => df,
                :data_b => df
            ),
            [sankey1, sankey2];
            dataformat=:csv_embedded
        )

        outfile = tempname() * ".html"
        create_html(page, outfile)
        @test isfile(outfile)
    end

    @testset "Title and notes" begin
        sankey = SanKey(:titled, df, :titled_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value],
            title = "Test Sankey Title",
            notes = "These are test notes")

        @test occursin("Test Sankey Title", sankey.appearance_html)
        @test occursin("These are test notes", sankey.appearance_html)
    end

    @testset "Sankey dependencies function" begin
        sankey = SanKey(:dep_test, df, :dep_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party])

        deps = JSPlots.dependencies(sankey)
        @test deps == [:dep_data]
    end

    @testset "Sankey with categorical time column" begin
        budget_df = DataFrame(
            stage = ["Revenue", "Revenue", "Budget", "Budget", "Spending", "Spending"],
            item = ["Sales", "Services", "Sales", "Services", "Rent", "Salaries"],
            value = [100, 50, 100, 50, 60, 90]
        )
        budget_df[!, :stage] = categorical(budget_df.stage; levels = ["Revenue", "Budget", "Spending"])

        sankey = SanKey(:categorical_time, budget_df, :cat_data;
            time_col = :stage,
            color_cols = [:item],
            value_cols = [:value])

        @test sankey.chart_title == :categorical_time
        @test !isempty(sankey.functional_html)
    end

    @testset "Sankey integration test" begin
        sankey = SanKey(:integration, df, :integration_data;
            id_col = :person_id,
            time_col = :year,
            color_cols = [:party],
            value_cols = [:value],
            title = "Integration Test Sankey",
            notes = "Testing full integration")

        page = JSPlotPage(
            Dict{Symbol, DataFrame}(:integration_data => df),
            [sankey];
            dataformat=:csv_embedded
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "test_sankey.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Integration Test Sankey", html_content)
            @test occursin("type: \"sankey\"", html_content)
            @test occursin("plotly", html_content)
            @test occursin("processSankeyData", html_content)
        end
    end
end

println("SanKey tests completed successfully!")
