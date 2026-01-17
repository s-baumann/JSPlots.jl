using Test
using JSPlots
using DataFrames
using Dates

@testset "CandlestickChart" begin
    # Test data with all required columns
    dates = Date(2024, 1, 1):Day(1):Date(2024, 1, 31)
    n = length(dates)

    test_df = DataFrame(
        time_from = dates,
        time_to = dates,
        symbol = fill("AAPL", n),
        open = 150.0 .+ cumsum(randn(n)),
        high = 155.0 .+ cumsum(randn(n)),
        low = 145.0 .+ cumsum(randn(n)),
        close = 150.0 .+ cumsum(randn(n)),
        volume = rand(1000000:5000000, n)
    )

    @testset "Basic creation with all columns" begin
        chart = CandlestickChart(:test_candlestick, test_df, :test_data;
            time_from_col=:time_from,
            time_to_col=:time_to,
            symbol_col=:symbol,
            open_col=:open,
            high_col=:high,
            low_col=:low,
            close_col=:close,
            volume_col=:volume,
            title="Test Candlestick Chart"
        )
        @test chart.chart_title == :test_candlestick
        @test chart.data_label == :test_data
        @test occursin("test_candlestick", chart.functional_html)
        @test occursin("TIME_FROM_COL", chart.functional_html)
        @test occursin("OPEN_COL", chart.functional_html)
        @test occursin("candlestick", chart.functional_html)
    end

    @testset "Construction without volume (volume_col=nothing)" begin
        chart = CandlestickChart(:no_volume, test_df, :test_data;
            time_from_col=:time_from,
            time_to_col=:time_to,
            symbol_col=:symbol,
            open_col=:open,
            high_col=:high,
            low_col=:low,
            close_col=:close,
            volume_col=nothing,
            title="Candlestick Without Volume"
        )
        @test occursin("HAS_VOLUME = false", chart.functional_html)
        @test occursin("Candlestick Without Volume", chart.appearance_html)
        @test !occursin("show_volume_checkbox", chart.appearance_html)
    end

    @testset "Multiple symbols with overlay mode" begin
        multi_df = vcat(
            DataFrame(
                time_from = dates,
                time_to = dates,
                symbol = fill("AAPL", n),
                open = 150.0 .+ cumsum(randn(n)),
                high = 155.0 .+ cumsum(randn(n)),
                low = 145.0 .+ cumsum(randn(n)),
                close = 150.0 .+ cumsum(randn(n)),
                volume = rand(1000000:5000000, n)
            ),
            DataFrame(
                time_from = dates,
                time_to = dates,
                symbol = fill("GOOGL", n),
                open = 2800.0 .+ cumsum(randn(n) .* 10),
                high = 2850.0 .+ cumsum(randn(n) .* 10),
                low = 2750.0 .+ cumsum(randn(n) .* 10),
                close = 2800.0 .+ cumsum(randn(n) .* 10),
                volume = rand(500000:3000000, n)
            )
        )

        chart = CandlestickChart(:multi_overlay, multi_df, :multi_data;
            display_mode="Overlay",
            title="Multiple Symbols Overlay"
        )
        @test occursin("Overlay", chart.functional_html)
        @test occursin("renderOverlay", chart.functional_html)
    end

    @testset "Multiple symbols with faceted mode" begin
        multi_df = vcat(
            DataFrame(
                time_from = dates,
                time_to = dates,
                symbol = fill("AAPL", n),
                open = 150.0 .+ cumsum(randn(n)),
                high = 155.0 .+ cumsum(randn(n)),
                low = 145.0 .+ cumsum(randn(n)),
                close = 150.0 .+ cumsum(randn(n)),
                volume = rand(1000000:5000000, n)
            ),
            DataFrame(
                time_from = dates,
                time_to = dates,
                symbol = fill("MSFT", n),
                open = 380.0 .+ cumsum(randn(n) .* 2),
                high = 385.0 .+ cumsum(randn(n) .* 2),
                low = 375.0 .+ cumsum(randn(n) .* 2),
                close = 380.0 .+ cumsum(randn(n) .* 2),
                volume = rand(800000:4000000, n)
            )
        )

        chart = CandlestickChart(:multi_faceted, multi_df, :multi_data;
            display_mode="Faceted",
            title="Multiple Symbols Faceted"
        )
        @test occursin("Faceted", chart.functional_html)
        @test occursin("renderFaceted", chart.functional_html)
    end

    @testset "Candlestick bar type instead of candlestick" begin
        chart = CandlestickChart(:candlestick_bars, test_df, :test_data;
            chart_type="candlestick",
            title="Candlestick Bars"
        )
        @test occursin("candlestick", chart.functional_html)
        @test occursin("CHART_TYPE", chart.functional_html)
    end

    @testset "Integer time periods" begin
        quarters = 1:12
        quarter_df = DataFrame(
            quarter = quarters,
            quarter_end = quarters,
            ticker = fill("XYZ", length(quarters)),
            open_price = 100.0 .+ cumsum(randn(length(quarters))),
            high_price = 105.0 .+ cumsum(randn(length(quarters))),
            low_price = 95.0 .+ cumsum(randn(length(quarters))),
            close_price = 100.0 .+ cumsum(randn(length(quarters))),
            vol = rand(100000:500000, length(quarters))
        )

        chart = CandlestickChart(:quarters, quarter_df, :quarter_data;
            time_from_col=:quarter,
            time_to_col=:quarter_end,
            symbol_col=:ticker,
            open_col=:open_price,
            high_col=:high_price,
            low_col=:low_price,
            close_col=:close_price,
            volume_col=:vol,
            title="Quarterly Data"
        )
        @test occursin("quarter", chart.functional_html)
        @test occursin("open_price", chart.functional_html)
    end

    @testset "Invalid column error - missing time_from" begin
        bad_df = DataFrame(
            time_to = dates,
            symbol = fill("A", n),
            open = rand(n),
            high = rand(n),
            low = rand(n),
            close = rand(n)
        )
        @test_throws ErrorException CandlestickChart(:bad, bad_df, :bad_data)
    end

    @testset "Invalid column error - missing open" begin
        bad_df = DataFrame(
            time_from = dates,
            time_to = dates,
            symbol = fill("A", n),
            high = rand(n),
            low = rand(n),
            close = rand(n)
        )
        @test_throws ErrorException CandlestickChart(:bad, bad_df, :bad_data)
    end

    @testset "Invalid display_mode error" begin
        @test_throws ErrorException CandlestickChart(:bad_mode, test_df, :test_data;
            display_mode="InvalidMode"
        )
    end

    @testset "Invalid chart_type error" begin
        @test_throws ErrorException CandlestickChart(:bad_type, test_df, :test_data;
            chart_type="bar"
        )
    end

    @testset "Non-numeric Candlestick column error" begin
        bad_df = DataFrame(
            time_from = dates,
            time_to = dates,
            symbol = fill("A", n),
            open = fill("not_a_number", n),
            high = rand(n),
            low = rand(n),
            close = rand(n)
        )
        @test_throws ErrorException CandlestickChart(:bad_numeric, bad_df, :bad_data)
    end

    @testset "Dependencies method" begin
        chart = CandlestickChart(:dep_test, test_df, :my_candlestick_data)
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_candlestick_data]
        @test length(deps) == 1
    end

    @testset "With notes" begin
        notes = "This chart shows Candlestick candlestick data with volume bars."
        chart = CandlestickChart(:with_notes, test_df, :test_data;
            notes=notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Checkboxes in appearance HTML" begin
        chart = CandlestickChart(:checkboxes, test_df, :test_data;
            show_volume=true
        )
        @test occursin("renormalize_checkbox", chart.appearance_html)
        @test occursin("show_volume_checkbox", chart.appearance_html)
        @test occursin("log_volume_checkbox", chart.appearance_html)
    end

    @testset "Renormalization logic in JavaScript" begin
        chart = CandlestickChart(:renorm, test_df, :test_data)
        @test occursin("firstBarOpenPrices", chart.functional_html)
        @test occursin("RENORMALIZE", chart.functional_html)
        @test occursin("/ base", chart.functional_html)
    end

    @testset "Volume subplot configuration" begin
        chart = CandlestickChart(:volume_subplot, test_df, :test_data;
            show_volume=true
        )
        @test occursin("yaxis2", chart.functional_html)
        @test occursin("domain: [0.3, 1]", chart.functional_html)
        @test occursin("domain: [0, 0.25]", chart.functional_html)
        @test occursin("barmode", chart.functional_html)  # Check barmode exists
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            chart = CandlestickChart(:page_candlestick, test_df, :stock_data;
                title="Candlestick Test"
            )

            page = JSPlotPage(Dict(:stock_data => test_df), [chart])
            outfile = joinpath(tmpdir, "candlestickchart_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Candlestick Test", content)
            @test occursin("page_candlestick", content)
        end
    end
end
