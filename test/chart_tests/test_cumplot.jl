using Test
using JSPlots
using Dates
include("test_data.jl")

@testset "CumPlot" begin
    @testset "Basic creation" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
            pnl = randn(91),
            strategy = repeat(["Alpha", "Beta", "Gamma"], 31)[1:91]
        )
        chart = CumPlot(:test_cumchart, df, :test_df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            title = "Test Cumulative Chart"
        )
        @test chart.chart_title == :test_cumchart
        @test chart.data_label == :test_df
        @test occursin("test_cumchart", chart.functional_html)
        @test occursin("date", chart.functional_html)
        @test occursin("pnl", chart.functional_html)
    end

    @testset "Multiple y_transforms" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30),
            pnl_gross = randn(30) .+ 0.1,
            returns = 1 .+ randn(30) .* 0.01,
            strategy = repeat(["A", "B"], 15)
        )
        chart = CumPlot(:multi_y, df, :df;
            x_col = :date,
            y_transforms = [
                (:pnl, "cumulative"),
                (:pnl_gross, "cumulative"),
                (:returns, "cumprod")
            ],
            color_cols = [:strategy],
            title = "Multiple Y Transforms"
        )
        @test occursin("pnl", chart.functional_html)
        @test occursin("pnl_gross", chart.functional_html)
        @test occursin("returns", chart.functional_html)
        @test occursin("cumulative", chart.functional_html)
        @test occursin("cumprod", chart.functional_html)
    end

    @testset "Multiple color columns" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 1),
            pnl = randn(61),
            strategy = repeat(["Alpha", "Beta", "Gamma"], 21)[1:61],
            region = repeat(["US", "EU"], 31)[1:61]
        )
        chart = CumPlot(:multi_color, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy, :region],
            title = "Multiple Colors"
        )
        @test occursin("strategy", chart.functional_html)
        @test occursin("region", chart.functional_html)
    end

    @testset "No color column" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = CumPlot(:no_color, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            title = "No Color"
        )
        @test occursin("__no_color__", chart.functional_html)
    end

    @testset "With filters" begin
        df = DataFrame(
            date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 1, 30), 2),
            pnl = randn(60),
            strategy = repeat(["A", "B"], 30),
            region = repeat(["US", "EU"], 30)
        )
        chart = CumPlot(:with_filters, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            filters = Dict{Symbol,Any}(:region => ["US"]),
            title = "With Filters"
        )
        @test occursin("region", chart.functional_html)
    end

    @testset "With faceting" begin
        df = DataFrame(
            date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 1, 20), 4),
            pnl = randn(80),
            strategy = repeat(["A", "B"], 40),
            asset_class = repeat(["Equity", "Bond"], inner=40)
        )
        chart = CumPlot(:with_facets, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            facet_cols = [:asset_class],
            title = "Faceted Chart"
        )
        @test occursin("asset_class", chart.appearance_html)
    end

    @testset "Single y_transform with cumulative" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = CumPlot(:default_cum, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("cumulative", chart.functional_html)
    end

    @testset "Single y_transform with cumprod" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            returns = 1 .+ randn(10) .* 0.01
        )
        chart = CumPlot(:default_cumprod, df, :df;
            x_col = :date,
            y_transforms = [(:returns, "cumprod")]
        )
        @test occursin("cumprod", chart.functional_html)
    end

    @testset "Invalid transform error" begin
        df = DataFrame(date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10), pnl = randn(10))
        @test_throws ErrorException CumPlot(:bad_transform, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "invalid")]
        )
    end

    @testset "Invalid x_col error" begin
        df = DataFrame(date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10), pnl = randn(10))
        @test_throws ErrorException CumPlot(:bad_x, df, :df;
            x_col = :nonexistent,
            y_transforms = [(:pnl, "cumulative")]
        )
    end

    @testset "Invalid y_transforms column error" begin
        df = DataFrame(date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10), pnl = randn(10))
        @test_throws ErrorException CumPlot(:bad_y, df, :df;
            x_col = :date,
            y_transforms = [(:nonexistent, "cumulative")]
        )
    end

    @testset "Custom line width and marker size" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = CumPlot(:custom_style, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            line_width = 3,
            marker_size = 8
        )
        @test occursin("3", chart.functional_html)
        @test occursin("8", chart.functional_html)
    end

    @testset "With notes" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        notes = "This chart shows cumulative performance."
        chart = CumPlot(:with_notes, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            notes = notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Numeric X axis (non-date)" begin
        df = DataFrame(
            x = 1:100,
            y = cumsum(randn(100)),
            group = repeat(["A", "B"], 50)
        )
        chart = CumPlot(:numeric_x, df, :df;
            x_col = :x,
            y_transforms = [(:y, "cumulative")],
            color_cols = [:group],
            title = "Numeric X Axis"
        )
        @test occursin("x", chart.functional_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df = DataFrame(
                date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
                pnl = cumsum(randn(91)),
                strategy = repeat(["Alpha", "Beta", "Gamma"], 31)[1:91]
            )

            chart = CumPlot(:page_cumchart, df, :test_data;
                x_col = :date,
                y_transforms = [(:pnl, "cumulative")],
                color_cols = [:strategy],
                title = "Cumulative Test"
            )

            page = JSPlotPage(Dict(:test_data => df), [chart])
            outfile = joinpath(tmpdir, "cumulativechart_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Cumulative Test", content)
            @test occursin("page_cumchart", content)
        end
    end

    @testset "Dependencies method" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = CumPlot(:dep_test, df, :my_data;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_data]
        @test length(deps) == 1
    end

    @testset "JS dependencies" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = CumPlot(:js_dep_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        js_deps = JSPlots.js_dependencies(chart)
        @test length(js_deps) > 0
        @test any(occursin("plotly", lowercase(d)) for d in js_deps)
    end

    @testset "Step and duration controls in HTML" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = CumPlot(:controls_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            title = "Controls Test"
        )
        @test occursin("duration_input", chart.appearance_html)
        @test occursin("step_input", chart.appearance_html)
        @test occursin("Step Back", chart.appearance_html)
        @test occursin("Step Forward", chart.appearance_html)
    end

    @testset "Interval display in HTML" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = CumPlot(:interval_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("interval_display", chart.appearance_html)
    end

    @testset "Time unit detection in JS" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 12, 31),
            pnl = randn(366)
        )
        chart = CumPlot(:unit_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("determineTimeUnit", chart.functional_html)
        @test occursin("days", chart.functional_html)
        @test occursin("hours", chart.functional_html)
        @test occursin("minutes", chart.functional_html)
        @test occursin("seconds", chart.functional_html)
    end

    @testset "Metric dropdown shown for multiple transforms" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10),
            returns = 1 .+ randn(10) .* 0.01
        )
        chart = CumPlot(:multi_transform_options, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative"), (:returns, "cumprod")]
        )
        @test occursin("Metric", chart.appearance_html)
        @test occursin("pnl (cumulative)", chart.appearance_html)
        @test occursin("returns (cumprod)", chart.appearance_html)
    end

    @testset "No metric dropdown for single transform" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = CumPlot(:single_transform, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        # Should have hidden input, not a visible dropdown with "Metric" label
        @test !occursin("Metric:", chart.appearance_html)
        @test occursin("type=\"hidden\"", chart.appearance_html)
    end

    @testset "Reset button in HTML" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = CumPlot(:reset_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("Reset", chart.appearance_html)
        @test occursin("resetRange_", chart.functional_html)
    end

    @testset "Custom color maps" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30),
            strategy = repeat(["Alpha", "Beta", "Gamma"], 10)
        )
        chart = CumPlot(:custom_colors, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [(:strategy, Dict("Alpha" => "#ff0000", "Beta" => "#00ff00", "Gamma" => "#0000ff"))]
        )
        @test occursin("#ff0000", chart.functional_html)
        @test occursin("#00ff00", chart.functional_html)
        @test occursin("#0000ff", chart.functional_html)
    end

    @testset "Mixed color specs (:default and custom)" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30),
            strategy = repeat(["A", "B", "C"], 10),
            region = repeat(["US", "EU"], 15)
        )
        chart = CumPlot(:mixed_colors, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [(:strategy, :default), (:region, Dict("US" => "#ff0000", "EU" => "#0000ff"))]
        )
        @test occursin("strategy", chart.functional_html)
        @test occursin("region", chart.functional_html)
        @test occursin("#ff0000", chart.functional_html)
        @test occursin("#0000ff", chart.functional_html)
    end

    @testset "Legacy Vector{Symbol} format still works" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30),
            strategy = repeat(["A", "B", "C"], 10)
        )
        chart = CumPlot(:legacy_format, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy]
        )
        @test occursin("strategy", chart.functional_html)
        @test chart.chart_title == :legacy_format
    end
end
