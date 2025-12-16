using Test
using JSPlots
using DataFrames
using Dates

@testset "Path" begin
    # Create test data similar to trading strategies example
    ll = []
    for strategy in [:carry, :momentum]
        for region in [:global, :em]
            dd = DataFrame(:year => collect(2015:2020))
            dd[!, :Sharpe] = rand(6) .* 0.5 .+ 0.5
            dd[!, :volatility] = rand(6) .* 0.5 .+ 0.5
            dd[!, :drawdown] = rand(6) .* 0.5 .+ 0.5
            dd[!, :region] .= region
            dd[!, :strategy] .= strategy
            push!(ll, dd)
        end
    end
    test_df = vcat(ll...)

    @testset "Basic creation" begin
        chart = Path(:test_path, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            color_cols = [:strategy],
            title = "Strategy Evolution"
        )
        @test chart.chart_title == :test_path
        @test chart.data_label == :test_df
        @test occursin("test_path", chart.functional_html)
        @test occursin("year", chart.functional_html)
        @test occursin("volatility", chart.functional_html)
        @test occursin("Sharpe", chart.functional_html)
    end

    @testset "With arrows enabled" begin
        chart = Path(:with_arrows, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            color_cols = [:strategy],
            show_arrows = true
        )
        @test occursin("arrowhead", chart.functional_html)
        @test occursin("true", chart.functional_html)
    end

    @testset "With arrows disabled" begin
        chart = Path(:no_arrows, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            color_cols = [:strategy],
            show_arrows = false
        )
        @test occursin("false", chart.functional_html)
    end

    @testset "Multiple x and y columns" begin
        chart = Path(:multi_dims, test_df, :test_df;
            x_cols = [:volatility, :Sharpe, :drawdown],
            y_cols = [:Sharpe, :volatility, :drawdown],
            order_col = :year,
            color_cols = [:strategy]
        )
        @test occursin("volatility", chart.appearance_html)
        @test occursin("Sharpe", chart.appearance_html)
        @test occursin("drawdown", chart.appearance_html)
    end

    @testset "Multiple color columns" begin
        chart = Path(:multi_color, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            color_cols = [:strategy, :region]
        )
        @test occursin("strategy", chart.appearance_html)
        @test occursin("region", chart.appearance_html)
    end

    @testset "With filters" begin
        df_filter = DataFrame(
            x = repeat(1:10, 4),
            y = rand(40),
            order = repeat(1:10, 4),
            category = repeat(["A", "B"], 20),
            group = repeat(["X", "Y"], 20)
        )
        chart = Path(:with_filters, df_filter, :df_filter;
            x_cols = [:x],
            y_cols = [:y],
            order_col = :order,
            color_cols = [:group],
            filters = Dict{Symbol,Any}(:category => "A")
        )
        @test occursin("category", chart.functional_html)
        @test occursin("A", chart.functional_html)
    end

    @testset "Faceting - single column" begin
        chart = Path(:facet_single, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            color_cols = [:strategy],
            facet_cols = [:region],
            default_facet_cols = [:region]
        )
        @test occursin("region", chart.appearance_html)
        @test occursin("FACET_COLS", chart.functional_html)
    end

    @testset "Faceting - multiple columns" begin
        chart = Path(:facet_multi, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            color_cols = [:strategy],
            facet_cols = [:region, :strategy],
            default_facet_cols = [:region]
        )
        @test occursin("region", chart.appearance_html)
        @test occursin("strategy", chart.appearance_html)
    end

    @testset "Custom line width and marker size" begin
        chart = Path(:custom_style, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            line_width = 3,
            marker_size = 12
        )
        @test occursin("3", chart.functional_html)
        @test occursin("12", chart.functional_html)
    end

    @testset "With notes" begin
        notes = "This path chart shows strategy evolution over time."
        chart = Path(:with_notes, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            notes = notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df_test = DataFrame(
                x = repeat(1:5, 2),
                y = rand(10),
                order = repeat(1:5, 2),
                group = repeat(["A", "B"], 5)
            )

            chart = Path(:page_path, df_test, :test_data;
                x_cols = [:x],
                y_cols = [:y],
                order_col = :order,
                color_cols = [:group],
                title = "Path Test"
            )

            page = JSPlotPage(Dict(:test_data => df_test), [chart])
            outfile = joinpath(tmpdir, "path_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Path Test", content)
            @test occursin("page_path", content)
        end
    end

    @testset "Dependencies method" begin
        chart = Path(:dep_test, test_df, :my_data;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year
        )
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_data]
        @test length(deps) == 1
    end

    @testset "Invalid order_col error" begin
        @test_throws ErrorException Path(:bad_order, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :nonexistent
        )
    end

    @testset "Invalid x_cols error" begin
        @test_throws ErrorException Path(:bad_x, test_df, :test_df;
            x_cols = [:nonexistent],
            y_cols = [:Sharpe],
            order_col = :year
        )
    end

    @testset "Invalid y_cols error" begin
        @test_throws ErrorException Path(:bad_y, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:nonexistent],
            order_col = :year
        )
    end

    @testset "Too many default facets error" begin
        @test_throws ErrorException Path(:too_many_facets, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            facet_cols = [:strategy, :region],
            default_facet_cols = [:strategy, :region, :drawdown]
        )
    end

    @testset "Default facets not in choices error" begin
        @test_throws ErrorException Path(:facet_mismatch, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            facet_cols = [:strategy],
            default_facet_cols = [:region]
        )
    end

    @testset "No color columns" begin
        df_no_color = DataFrame(
            x = 1:10,
            y = rand(10),
            order = 1:10
        )
        chart = Path(:no_color, df_no_color, :df_no_color;
            x_cols = [:x],
            y_cols = [:y],
            order_col = :order
        )
        @test occursin("__no_color__", chart.functional_html)
    end

    @testset "Single facet choice" begin
        chart = Path(:single_facet, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            facet_cols = :region
        )
        @test occursin("region", chart.appearance_html)
    end

    @testset "Date ordering column" begin
        df_dates = DataFrame(
            risk = rand(12),
            ret = rand(12),
            date = Date(2020, 1, 1):Month(1):Date(2020, 12, 1),
            fund = repeat(["Fund A"], 12)
        )
        chart = Path(:date_order, df_dates, :df_dates;
            x_cols = [:risk],
            y_cols = [:ret],
            order_col = :date,
            color_cols = [:fund]
        )
        @test occursin("date", chart.functional_html)
    end

    @testset "String ordering column" begin
        df_string = DataFrame(
            x = rand(5),
            y = rand(5),
            phase = ["Phase1", "Phase2", "Phase3", "Phase4", "Phase5"],
            category = repeat(["A"], 5)
        )
        chart = Path(:string_order, df_string, :df_string;
            x_cols = [:x],
            y_cols = [:y],
            order_col = :phase,
            color_cols = [:category]
        )
        @test occursin("phase", chart.functional_html)
    end

    @testset "Empty notes and custom title" begin
        chart = Path(:empty_notes, test_df, :test_df;
            x_cols = [:volatility],
            y_cols = [:Sharpe],
            order_col = :year,
            title = "Custom Title",
            notes = ""
        )
        @test occursin("Custom Title", chart.appearance_html)
    end

    @testset "Line width variations" begin
        for width in [1, 2, 4, 6]
            chart = Path(Symbol("width_$width"), test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                line_width = width
            )
            @test occursin(string(width), chart.functional_html)
        end
    end

    @testset "Marker size variations" begin
        for size in [4, 8, 12, 16]
            chart = Path(Symbol("size_$size"), test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                marker_size = size
            )
            @test occursin(string(size), chart.functional_html)
        end
    end

    @testset "Alpharange feature" begin
        @testset "use_alpharange=true" begin
            chart = Path(:alpharange_true, test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                use_alpharange = true
            )
            @test occursin("USE_ALPHARANGE = true", chart.functional_html)
            @test occursin("getAlphaValues", chart.functional_html)
            @test occursin("markerOpacity", chart.functional_html)
            @test occursin("0.3", chart.functional_html)  # Min alpha value
        end

        @testset "use_alpharange=false (default)" begin
            chart = Path(:alpharange_false, test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                use_alpharange = false
            )
            @test occursin("USE_ALPHARANGE = false", chart.functional_html)
            @test occursin("getAlphaValues", chart.functional_html)
        end

        @testset "Alpharange with arrows" begin
            chart = Path(:alpharange_with_arrows, test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                show_arrows = true,
                use_alpharange = true
            )
            @test occursin("USE_ALPHARANGE = true", chart.functional_html)
            @test occursin("arrowhead", chart.functional_html)
        end

        @testset "Alpharange without arrows" begin
            chart = Path(:alpharange_no_arrows, test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                show_arrows = false,
                use_alpharange = true
            )
            @test occursin("USE_ALPHARANGE = true", chart.functional_html)
            @test occursin("false", chart.functional_html)
        end

        @testset "Alpharange with faceting" begin
            chart = Path(:alpharange_facet, test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                use_alpharange = true,
                facet_cols = [:region],
                default_facet_cols = [:region]
            )
            @test occursin("USE_ALPHARANGE = true", chart.functional_html)
            @test occursin("markerOpacity", chart.functional_html)
            @test occursin("region", chart.appearance_html)
        end

        @testset "Alpharange with multiple color cols" begin
            chart = Path(:alpharange_multi_color, test_df, :test_df;
                x_cols = [:volatility],
                y_cols = [:Sharpe],
                order_col = :year,
                color_cols = [:strategy, :region],
                use_alpharange = true
            )
            @test occursin("USE_ALPHARANGE = true", chart.functional_html)
            @test occursin("strategy", chart.appearance_html)
            @test occursin("region", chart.appearance_html)
        end
    end

    @testset "Integration with alpharange" begin
        mktempdir() do tmpdir
            df_alpha = DataFrame(
                x = repeat(1:5, 2),
                y = rand(10),
                order = repeat(1:5, 2),
                group = repeat(["A", "B"], 5)
            )

            chart = Path(:alpha_page_test, df_alpha, :alpha_data;
                x_cols = [:x],
                y_cols = [:y],
                order_col = :order,
                color_cols = [:group],
                use_alpharange = true,
                title = "Alpha Range Test"
            )

            page = JSPlotPage(Dict(:alpha_data => df_alpha), [chart])
            outfile = joinpath(tmpdir, "alpharange_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Alpha Range Test", content)
            @test occursin("USE_ALPHARANGE = true", content)
            @test occursin("getAlphaValues", content)
        end
    end
end
