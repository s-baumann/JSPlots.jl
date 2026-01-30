using Test
using JSPlots
using Dates
include("test_data.jl")

@testset "DrawdownPlot" begin
    @testset "Basic creation" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
            pnl = randn(91),
            strategy = repeat(["Alpha", "Beta", "Gamma"], 31)[1:91]
        )
        chart = DrawdownPlot(:test_drawdown, df, :test_df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            title = "Test Drawdown Chart"
        )
        @test chart.chart_title == :test_drawdown
        @test chart.data_label == :test_df
        @test occursin("test_drawdown", chart.functional_html)
        @test occursin("date", chart.functional_html)
        @test occursin("pnl", chart.functional_html)
    end

    @testset "Multiple y_transforms" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 1),
            pnl = randn(61),
            pnl_gross = randn(61),
            daily_return = 1 .+ randn(61) .* 0.01,
            strategy = repeat(["A", "B", "C"], 21)[1:61]
        )
        chart = DrawdownPlot(:multi_y, df, :df;
            x_col = :date,
            y_transforms = [
                (:pnl, "cumulative"),
                (:pnl_gross, "cumulative"),
                (:daily_return, "cumprod")
            ],
            color_cols = [:strategy],
            title = "Multiple Y Transforms"
        )
        @test occursin("pnl", chart.functional_html)
        @test occursin("pnl_gross", chart.functional_html)
        @test occursin("daily_return", chart.functional_html)
        @test occursin("y_transform_select", chart.appearance_html)  # Dropdown should appear
    end

    @testset "Single y_transform hides dropdown" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = DrawdownPlot(:single_y, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        # Hidden input instead of dropdown
        @test occursin("type=\"hidden\"", chart.appearance_html)
    end

    @testset "Multiple color columns" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 1),
            pnl = randn(61),
            strategy = repeat(["Alpha", "Beta", "Gamma"], 21)[1:61],
            region = repeat(["US", "EU"], 31)[1:61]
        )
        chart = DrawdownPlot(:multi_color, df, :df;
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
        chart = DrawdownPlot(:no_color, df, :df;
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
        chart = DrawdownPlot(:with_filters, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            filters = Dict{Symbol,Any}(:region => ["US"]),
            title = "With Filters"
        )
        @test occursin("region", chart.functional_html)
    end

    @testset "Day of week filter" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
            pnl = randn(91),
            strategy = repeat(["A", "B", "C"], 31)[1:91],
            day_of_week = dayname.(Date(2024, 1, 1):Day(1):Date(2024, 3, 31))
        )
        chart = DrawdownPlot(:day_filter, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            filters = [:day_of_week],
            title = "Day of Week Filter"
        )
        @test occursin("day_of_week", chart.functional_html)
    end

    @testset "With faceting" begin
        df = DataFrame(
            date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 1, 20), 4),
            pnl = randn(80),
            strategy = repeat(["A", "B"], 40),
            asset_class = repeat(["Equity", "Bond"], inner=40)
        )
        chart = DrawdownPlot(:with_facets, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            facet_cols = [:asset_class],
            title = "Faceted Chart"
        )
        @test occursin("asset_class", chart.appearance_html)
    end

    @testset "Fill option enabled (default)" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = DrawdownPlot(:fill_enabled, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            fill = true
        )
        @test occursin("tozeroy", chart.functional_html)
    end

    @testset "Fill option disabled" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = DrawdownPlot(:fill_disabled, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            fill = false
        )
        @test occursin("'none'", chart.functional_html)
    end

    @testset "Custom line width" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = DrawdownPlot(:custom_width, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            line_width = 4
        )
        @test occursin("width: 4", chart.functional_html)
    end

    @testset "Invalid x_col error" begin
        df = DataFrame(date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10), pnl = randn(10))
        @test_throws ErrorException DrawdownPlot(:bad_x, df, :df;
            x_col = :nonexistent,
            y_transforms = [(:pnl, "cumulative")]
        )
    end

    @testset "Invalid y_transforms column error" begin
        df = DataFrame(date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10), pnl = randn(10))
        @test_throws ErrorException DrawdownPlot(:bad_y, df, :df;
            x_col = :date,
            y_transforms = [(:nonexistent, "cumulative")]
        )
    end

    @testset "Invalid transform type error" begin
        df = DataFrame(date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10), pnl = randn(10))
        @test_throws ErrorException DrawdownPlot(:bad_transform, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "invalid_transform")]
        )
    end

    @testset "With notes" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        notes = "This chart shows drawdown from peak."
        chart = DrawdownPlot(:with_notes, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            notes = notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Numeric X axis (non-date)" begin
        df = DataFrame(
            x = 1:100,
            y = randn(100),
            group = repeat(["A", "B"], 50)
        )
        chart = DrawdownPlot(:numeric_x, df, :df;
            x_col = :x,
            y_transforms = [(:y, "cumulative")],
            color_cols = [:group],
            title = "Numeric X Axis"
        )
        @test occursin("x", chart.functional_html)
    end

    @testset "Drawdown computation function in JS" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = DrawdownPlot(:dd_compute_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("computeDrawdown", chart.functional_html)
        @test occursin("runningMax", chart.functional_html)
        @test occursin("maxDrawdown", chart.functional_html)
    end

    @testset "Max drawdown in tooltip" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = DrawdownPlot(:tooltip_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("Max Drawdown", chart.functional_html)
    end

    @testset "Cumulative transform in JS" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = DrawdownPlot(:cumulative_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("computeCumulativeSum", chart.functional_html)
    end

    @testset "Cumprod transform in JS" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            daily_return = 1 .+ randn(30) .* 0.01
        )
        chart = DrawdownPlot(:cumprod_test, df, :df;
            x_col = :date,
            y_transforms = [(:daily_return, "cumprod")]
        )
        @test occursin("computeCumulativeProduct", chart.functional_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df = DataFrame(
                date = Date(2024, 1, 1):Day(1):Date(2024, 3, 31),
                pnl = randn(91),
                strategy = repeat(["Alpha", "Beta", "Gamma"], 31)[1:91]
            )

            chart = DrawdownPlot(:page_drawdown, df, :test_data;
                x_col = :date,
                y_transforms = [(:pnl, "cumulative")],
                color_cols = [:strategy],
                title = "Drawdown Test"
            )

            page = JSPlotPage(Dict(:test_data => df), [chart])
            outfile = joinpath(tmpdir, "drawdown_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Drawdown Test", content)
            @test occursin("page_drawdown", content)
        end
    end

    @testset "Dependencies method" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
            pnl = randn(10)
        )
        chart = DrawdownPlot(:dep_test, df, :my_data;
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
        chart = DrawdownPlot(:js_dep_test, df, :df;
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
        chart = DrawdownPlot(:controls_test, df, :df;
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
        chart = DrawdownPlot(:interval_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")]
        )
        @test occursin("interval_display", chart.appearance_html)
    end

    @testset "Reset button in HTML" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30)
        )
        chart = DrawdownPlot(:reset_test, df, :df;
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
        chart = DrawdownPlot(:custom_colors, df, :df;
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
        chart = DrawdownPlot(:mixed_colors, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [(:strategy, :default), (:region, Dict("US" => "#ff0000", "EU" => "#0000ff"))]
        )
        @test occursin("strategy", chart.functional_html)
        @test occursin("region", chart.functional_html)
        @test occursin("#ff0000", chart.functional_html)
        @test occursin("#0000ff", chart.functional_html)
    end

    @testset "Y transform dropdown with multiple options" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30),
            pnl_gross = randn(30)
        )
        chart = DrawdownPlot(:y_dropdown_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative"), (:pnl_gross, "cumulative")]
        )
        @test occursin("y_transform_select", chart.appearance_html)
        @test occursin("Metric", chart.appearance_html)
        @test occursin("pnl (cumulative)", chart.appearance_html)
        @test occursin("pnl_gross (cumulative)", chart.appearance_html)
    end

    @testset "Y transform labels include transform type" begin
        df = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 30),
            pnl = randn(30),
            daily_return = 1 .+ randn(30) .* 0.01
        )
        chart = DrawdownPlot(:y_label_test, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative"), (:daily_return, "cumprod")]
        )
        @test occursin("pnl (cumulative)", chart.appearance_html)
        @test occursin("daily_return (cumprod)", chart.appearance_html)
    end

    @testset "Faceting with multiple facet columns" begin
        df = DataFrame(
            date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 1, 10), 8),
            pnl = randn(80),
            strategy = repeat(["A", "B"], 40),
            style = repeat(["Factor", "Alt"], inner=40),
            region = repeat(["US", "EU", "Asia", "Global"], inner=20)
        )
        chart = DrawdownPlot(:multi_facet, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            facet_cols = [:style, :region],
            title = "Multi-Facet Test"
        )
        @test occursin("facet1_select", chart.appearance_html)
        @test occursin("facet2_select", chart.appearance_html)
    end

    @testset "Default facet columns" begin
        df = DataFrame(
            date = repeat(Date(2024, 1, 1):Day(1):Date(2024, 1, 10), 4),
            pnl = randn(40),
            strategy = repeat(["A", "B"], 20),
            style = repeat(["Factor", "Alt"], inner=20)
        )
        chart = DrawdownPlot(:default_facet, df, :df;
            x_col = :date,
            y_transforms = [(:pnl, "cumulative")],
            color_cols = [:strategy],
            facet_cols = [:style],
            default_facet_cols = [:style],
            title = "Default Facet Test"
        )
        @test occursin("facet1_select", chart.appearance_html)
    end
end
