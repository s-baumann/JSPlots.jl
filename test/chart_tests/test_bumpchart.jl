using Test
using JSPlots
using DataFrames
using Dates

@testset "BumpChart" begin
    # Test data with basic ranking information
    periods = 1:10
    entities = ["Entity A", "Entity B", "Entity C", "Entity D"]

    test_df_parts = []
    for entity in entities
        push!(test_df_parts, DataFrame(
            period = periods,
            entity = fill(entity, length(periods)),
            performance = rand(50.0:100.0, length(periods)),
            score = rand(1.0:10.0, length(periods))
        ))
    end
    test_df = vcat(test_df_parts...)

    @testset "Basic creation with minimal inputs" begin
        chart = BumpChart(:test_bump, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            title="Test Bump Chart"
        )
        @test chart.chart_title == :test_bump
        @test chart.data_label == :test_data
        @test occursin("test_bump", chart.functional_html)
        @test occursin("X_COL", chart.functional_html)
        @test occursin("PERFORMANCE_COLS", chart.functional_html)
        @test occursin("ENTITY_COL", chart.functional_html)
    end

    @testset "Multiple performance metrics" begin
        chart = BumpChart(:multi_metrics, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance, :score],
            entity_col=:entity,
            title="Multiple Metrics"
        )
        @test occursin("performance", chart.functional_html)
        @test occursin("score", chart.functional_html)
        @test occursin("perf_col_select", chart.appearance_html)
    end

    @testset "With faceting (1 facet)" begin
        df_facet = copy(test_df)
        df_facet.region = repeat(["North", "South"], nrow(df_facet) ÷ 2)

        chart = BumpChart(:one_facet, df_facet, :facet_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            facet_cols=[:region],
            default_facet_cols=:region,
            title="One Facet"
        )
        @test occursin("region", chart.appearance_html)
        @test occursin("renderOneFacet", chart.functional_html)
    end

    @testset "With faceting (2 facets)" begin
        df_facet = copy(test_df)
        df_facet.region = repeat(["North", "South"], nrow(df_facet) ÷ 2)
        df_facet.category = repeat(["A", "B", "C", "D"], nrow(df_facet) ÷ 4)

        chart = BumpChart(:two_facets, df_facet, :facet_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            facet_cols=[:region, :category],
            default_facet_cols=[:region],
            title="Two Facets"
        )
        @test occursin("region", chart.appearance_html)
        @test occursin("category", chart.appearance_html)
        @test occursin("renderTwoFacets", chart.functional_html)
    end

    @testset "Ranking mode (default)" begin
        chart = BumpChart(:ranking_mode, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            y_mode="Ranking",
            title="Ranking Mode"
        )
        @test occursin("Ranking", chart.functional_html)
        @test occursin("calculateDenseRanks", chart.functional_html)
        @test occursin("autorange:", chart.functional_html)  # Check autorange exists
        @test occursin("reversed", chart.functional_html)     # Check reversed value exists
    end

    @testset "Absolute mode" begin
        chart = BumpChart(:absolute_mode, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            y_mode="Absolute",
            title="Absolute Mode"
        )
        @test occursin("Absolute", chart.functional_html)
        @test occursin("y_value: row[PERF_COL]", chart.functional_html)
    end

    @testset "Dense ranking implementation" begin
        chart = BumpChart(:dense_rank, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            y_mode="Ranking"
        )
        @test occursin("calculateDenseRanks", chart.functional_html)
        @test occursin("uniqueValues", chart.functional_html)
        @test occursin("valueToRank", chart.functional_html)
        @test occursin("idx + 1", chart.functional_html)  # Dense rank formula
    end

    @testset "Cross-facet hover highlighting" begin
        chart = BumpChart(:highlighting, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            title="Hover Highlighting"
        )
        @test occursin("setupCrossFacetHighlighting", chart.functional_html)
        @test occursin("plotly_hover", chart.functional_html)
        @test occursin("plotly_unhover", chart.functional_html)
        @test occursin("rgba(200, 200, 200, 0.3)", chart.functional_html)
    end

    @testset "Custom line width" begin
        chart = BumpChart(:custom_width, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            line_width=5
        )
        @test occursin("width: 5", chart.functional_html)
    end

    @testset "With filters" begin
        chart = BumpChart(:with_filters, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            filters=Dict(:entity => ["Entity A", "Entity B"])
        )
        @test occursin("Entity A", chart.functional_html)
        @test occursin("Entity B", chart.functional_html)
    end

    @testset "Invalid entity_col error" begin
        @test_throws ErrorException BumpChart(:bad_entity, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:nonexistent
        )
    end

    @testset "Invalid y_mode error" begin
        @test_throws ErrorException BumpChart(:bad_mode, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            y_mode="InvalidMode"
        )
    end

    @testset "Invalid x_col error" begin
        @test_throws ErrorException BumpChart(:bad_x, test_df, :test_data;
            x_col=:nonexistent,
            performance_cols=[:performance],
            entity_col=:entity
        )
    end

    @testset "Invalid performance_cols error" begin
        @test_throws ErrorException BumpChart(:bad_perf, test_df, :test_data;
            x_col=:period,
            performance_cols=[:nonexistent],
            entity_col=:entity
        )
    end

    @testset "Empty performance_cols error" begin
        @test_throws ErrorException BumpChart(:empty_perf, test_df, :test_data;
            x_col=:period,
            performance_cols=Symbol[],
            entity_col=:entity
        )
    end

    @testset "Dependencies method" begin
        chart = BumpChart(:dep_test, test_df, :my_bump_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity
        )
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_bump_data]
        @test length(deps) == 1
    end

    @testset "With notes" begin
        notes = "This bump chart shows rankings over time with dense ranking (no gaps for ties)."
        chart = BumpChart(:with_notes, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            notes=notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Date-based x-axis" begin
        dates = Date(2024, 1, 1):Month(1):Date(2024, 12, 1)
        df_dates_parts = []
        for entity in entities[1:3]
            push!(df_dates_parts, DataFrame(
                date = dates,
                entity = fill(entity, length(dates)),
                revenue = rand(100.0:500.0, length(dates))
            ))
        end
        df_dates = vcat(df_dates_parts...)

        chart = BumpChart(:date_axis, df_dates, :date_data;
            x_col=:date,
            performance_cols=[:revenue],
            entity_col=:entity,
            title="Date-based Rankings"
        )
        @test occursin("date", chart.functional_html)
        @test occursin("revenue", chart.functional_html)
    end

    @testset "Y-axis mode dropdown" begin
        chart = BumpChart(:y_mode_dropdown, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            y_mode="Ranking"
        )
        @test occursin("y_mode_select", chart.appearance_html)
        @test occursin("Ranking", chart.appearance_html)
        @test occursin("Absolute", chart.appearance_html)
    end

    @testset "Legendgroup for cross-facet linking" begin
        df_facet = copy(test_df)
        df_facet.region = repeat(["North", "South"], nrow(df_facet) ÷ 2)

        chart = BumpChart(:legendgroup, df_facet, :facet_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            facet_cols=[:region],
            default_facet_cols=:region
        )
        @test occursin("legendgroup: entity", chart.functional_html)
        @test occursin("showlegend: idx === 0", chart.functional_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            chart = BumpChart(:page_bump, test_df, :ranking_data;
                x_col=:period,
                performance_cols=[:performance],
                entity_col=:entity,
                title="Bump Test"
            )

            page = JSPlotPage(Dict(:ranking_data => test_df), [chart])
            outfile = joinpath(tmpdir, "bumpchart_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Bump Test", content)
            @test occursin("page_bump", content)
        end
    end

    @testset "Hover template with rank and value" begin
        chart = BumpChart(:hover_template, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance],
            entity_col=:entity,
            y_mode="Ranking"
        )
        @test occursin("hovertemplate", chart.functional_html)
        @test occursin("Rank: %{y}", chart.functional_html)
        @test occursin("Value: %{customdata}", chart.functional_html)
    end

    @testset "Default column selection" begin
        chart = BumpChart(:defaults, test_df, :test_data;
            x_col=:period,
            performance_cols=[:performance, :score],
            entity_col=:entity,
            default_performance_col=:score
        )
        @test occursin("DEFAULT_PERF_COL = 'score'", chart.functional_html)
        @test occursin("X_COL = 'period'", chart.functional_html)
    end
end
