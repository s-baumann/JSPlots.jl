using Test
using JSPlots
using DataFrames
using Dates

@testset "ExecutionPlot" begin
    # Generate test data
    start_time = DateTime(2024, 1, 15, 10, 0, 0)
    time_points = [start_time + Second(i*30) for i in 0:60]

    # Top of book data
    test_tob_df = DataFrame(
        time = time_points,
        bid = 100.0 .+ rand(length(time_points)) .* 2,
        ask = 100.2 .+ rand(length(time_points)) .* 2
    )

    # Volume data
    volume_times = [start_time + Minute(i*5) for i in 0:5]
    test_volume_df = DataFrame(
        time_from = volume_times[1:end-1],
        time_to = volume_times[2:end],
        volume = rand(50000:100000, length(volume_times)-1)
    )

    # Fills data
    fill_times = sort(start_time .+ Second.(rand(100:1500, 15)))
    test_fills_df = DataFrame(
        time = fill_times,
        quantity = rand(100:500, 15),
        price = rand(100.0:0.01:100.3, 15),
        execution_name = fill("Test_Exec", 15),
        venue = rand(["NYSE", "NASDAQ"], 15),
        urgency = rand(["High", "Low"], 15)
    )

    # Metadata with arrival price
    test_metadata_df = DataFrame(
        execution_name = ["Test_Exec"],
        arrival_price = [100.0],
        side = ["buy"],
        desired_quantity = [5000]
    )

    @testset "Basic creation with arrival price" begin
        chart = ExecutionPlot(:test_exec, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob1, :vol1, :fills1, :meta1);
                                 title="Test Execution")

        @test chart.chart_title == :test_exec
        @test chart.data_labels == (:tob1, :vol1, :fills1, :meta1)
        @test occursin("test_exec", chart.functional_html)
        @test occursin("TIME_COL", chart.functional_html)
        @test occursin("BID_COL", chart.functional_html)
        @test occursin("ASK_COL", chart.functional_html)
        @test occursin("QUANTITY_COL", chart.functional_html)
        @test occursin("PRICE_COL", chart.functional_html)
        @test occursin("Test Execution", chart.appearance_html)
    end

    @testset "Without arrival price" begin
        metadata_no_arrival = DataFrame(
            execution_name = ["Test_Exec"],
            side = ["buy"],
            desired_quantity = [5000]
        )

        chart = ExecutionPlot(:no_arrival, test_tob_df, test_volume_df, test_fills_df,
                                 metadata_no_arrival, (:tob2, :vol2, :fills2, :meta2))

        @test occursin("HAS_ARRIVAL = false", chart.functional_html)
        @test occursin("First Fill Mid", chart.appearance_html)
        @test !occursin("Arrival", chart.appearance_html)
    end

    @testset "With color columns" begin
        chart = ExecutionPlot(:colored, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob3, :vol3, :fills3, :meta3);
                                 color_cols=[:venue, :urgency])

        @test occursin("COLOR_COLS", chart.functional_html)
        @test occursin("venue", chart.functional_html)
        @test occursin("urgency", chart.functional_html)
        @test occursin("COLOR_MAPS", chart.functional_html)
    end

    @testset "Buy side execution" begin
        chart = ExecutionPlot(:buy_exec, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob4, :vol4, :fills4, :meta4))

        @test occursin("buy", chart.functional_html)
        @test occursin("sideMultiplier = side === 'buy' ? 1 : -1", chart.functional_html)
    end

    @testset "Sell side execution" begin
        metadata_sell = DataFrame(
            execution_name = ["Sell_Exec"],
            arrival_price = [100.0],
            side = ["sell"],
            desired_quantity = [3000]
        )

        fills_sell = copy(test_fills_df)
        fills_sell.execution_name .= "Sell_Exec"

        chart = ExecutionPlot(:sell_exec, test_tob_df, test_volume_df, fills_sell,
                                 metadata_sell, (:tob5, :vol5, :fills5, :meta5))

        @test occursin("sell", chart.functional_html)
    end

    @testset "Multiple executions" begin
        # Add second execution
        fills_multi = vcat(
            test_fills_df,
            DataFrame(
                time = sort(start_time .+ Second.(rand(200:1600, 10))),
                quantity = rand(150:400, 10),
                price = rand(100.0:0.01:100.3, 10),
                execution_name = fill("Second_Exec", 10),
                venue = rand(["NYSE", "NASDAQ"], 10),
                urgency = rand(["High", "Low"], 10)
            )
        )

        metadata_multi = DataFrame(
            execution_name = ["Test_Exec", "Second_Exec"],
            arrival_price = [100.0, 100.1],
            side = ["buy", "buy"],
            desired_quantity = [5000, 4000]
        )

        chart = ExecutionPlot(:multi_exec, test_tob_df, test_volume_df, fills_multi,
                                 metadata_multi, (:tob6, :vol6, :fills6, :meta6))

        @test occursin("Test_Exec", chart.appearance_html)
        @test occursin("Second_Exec", chart.appearance_html)
        @test occursin("execution_select", chart.appearance_html)
    end

    @testset "VWAP calculation function" begin
        chart = ExecutionPlot(:vwap_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob7, :vol7, :fills7, :meta7))

        @test occursin("calculateRollingVWAP", chart.functional_html)
        @test occursin("totalValue += fill[PRICE_COL] * fill[QUANTITY_COL]", chart.functional_html)
        @test occursin("totalQty += fill[QUANTITY_COL]", chart.functional_html)
    end

    @testset "Spread crossing calculation" begin
        chart = ExecutionPlot(:spread_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob8, :vol8, :fills8, :meta8))

        @test occursin("getSpreadCrossing", chart.functional_html)
        @test occursin("(fillPrice - bid) / spread", chart.functional_html)
        @test occursin("(ask - fillPrice) / spread", chart.functional_html)
    end

    @testset "Implementation shortfall calculations" begin
        chart = ExecutionPlot(:shortfall_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob9, :vol9, :fills9, :meta9))

        @test occursin("impShortfall = sideMultiplier * (price - benchmarkPrice) * qty", chart.functional_html)
        @test occursin("vwapShortfall = sideMultiplier * (price - rollingVWAP) * qty", chart.functional_html)
        @test occursin("cumImpShortfall", chart.functional_html)
        @test occursin("cumVwapShortfall", chart.functional_html)
    end

    @testset "Fills table with all columns" begin
        chart = ExecutionPlot(:table_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob10, :vol10, :fills10, :meta10);
                                 color_cols=[:venue])

        @test occursin("Fill Details", chart.functional_html)
        @test occursin("Imp. Shortfall", chart.functional_html)
        @test occursin("VWAP Shortfall", chart.functional_html)
        @test occursin("Spread Cross %", chart.functional_html)
        @test occursin("Remaining %", chart.functional_html)
    end

    @testset "Summary table by category" begin
        chart = ExecutionPlot(:summary_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob11, :vol11, :fills11, :meta11);
                                 color_cols=[:venue, :urgency])

        @test occursin("renderSummaryTable", chart.functional_html)
        @test occursin("Summary by Category", chart.functional_html)
        @test occursin("Avg Spread Cross %", chart.functional_html)
        @test occursin("Overall", chart.functional_html)
    end

    @testset "Fill deselection toggle" begin
        chart = ExecutionPlot(:toggle_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob12, :vol12, :fills12, :meta12))

        @test occursin("toggleFill_", chart.functional_html)
        @test occursin("deselectedFills", chart.functional_html)
        @test occursin("onclick=\"toggleFill_", chart.functional_html)
    end

    @testset "Hover highlighting" begin
        chart = ExecutionPlot(:hover_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob13, :vol13, :fills13, :meta13))

        @test occursin("highlightFill_", chart.functional_html)
        @test occursin("onmouseover=\"highlightFill_", chart.functional_html)
        @test occursin("onmouseout=\"highlightFill_", chart.functional_html)
        @test occursin("Plotly.restyle", chart.functional_html)
    end

    @testset "Volume subplot" begin
        chart = ExecutionPlot(:volume_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob14, :vol14, :fills14, :meta14))

        @test occursin("show_volume_checkbox", chart.appearance_html)
        @test occursin("Show Volume", chart.appearance_html)
        @test occursin("yaxis2", chart.functional_html)
        @test occursin("yaxis3", chart.functional_html)  # Shortfall timeline subplot
    end

    @testset "Benchmark selector" begin
        chart = ExecutionPlot(:benchmark_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob15, :vol15, :fills15, :meta15))

        @test occursin("benchmark_select", chart.appearance_html)
        @test occursin("Benchmark:", chart.appearance_html)
        @test occursin("arrival", chart.functional_html)
        @test occursin("first", chart.functional_html)
    end

    @testset "Invalid time column error" begin
        @test_throws ErrorException ExecutionPlot(:bad_time, test_tob_df, test_volume_df,
                                                     test_fills_df, test_metadata_df,
                                                     (:tob, :vol, :fills, :meta);
                                                     time_col=:nonexistent)
    end

    @testset "Invalid bid column error" begin
        @test_throws ErrorException ExecutionPlot(:bad_bid, test_tob_df, test_volume_df,
                                                     test_fills_df, test_metadata_df,
                                                     (:tob, :vol, :fills, :meta);
                                                     bid_col=:nonexistent)
    end

    @testset "Invalid quantity column error" begin
        @test_throws ErrorException ExecutionPlot(:bad_qty, test_tob_df, test_volume_df,
                                                     test_fills_df, test_metadata_df,
                                                     (:tob, :vol, :fills, :meta);
                                                     quantity_col=:nonexistent)
    end

    @testset "Invalid color column error" begin
        @test_throws ErrorException ExecutionPlot(:bad_color, test_tob_df, test_volume_df,
                                                     test_fills_df, test_metadata_df,
                                                     (:tob, :vol, :fills, :meta);
                                                     color_cols=[:nonexistent])
    end

    @testset "Dependencies method" begin
        chart = ExecutionPlot(:dep_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:my_tob, :my_vol, :my_fills, :my_meta))

        deps = JSPlots.dependencies(chart)
        @test deps == [:my_tob, :my_vol, :my_fills, :my_meta]
        @test length(deps) == 4
    end

    @testset "With notes" begin
        notes = "This chart analyzes trade execution quality with implementation shortfall and VWAP metrics."
        chart = ExecutionPlot(:notes_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob16, :vol16, :fills16, :meta16);
                                 notes=notes)

        @test occursin(notes, chart.appearance_html)
    end

    @testset "Custom column names" begin
        # Rename columns
        tob_custom = rename(test_tob_df, :time => :timestamp, :bid => :bid_price, :ask => :ask_price)
        vol_custom = rename(test_volume_df, :time_from => :start_time, :time_to => :end_time, :volume => :vol)
        fills_custom = rename(test_fills_df, :time => :fill_time, :quantity => :qty, :price => :fill_price)

        chart = ExecutionPlot(:custom_cols, tob_custom, vol_custom, fills_custom,
                                 test_metadata_df, (:tob17, :vol17, :fills17, :meta17);
                                 time_col=:timestamp,
                                 bid_col=:bid_price,
                                 ask_col=:ask_price,
                                 time_from_col=:start_time,
                                 time_to_col=:end_time,
                                 volume_col=:vol,
                                 fill_time_col=:fill_time,
                                 quantity_col=:qty,
                                 price_col=:fill_price)

        @test occursin("TIME_COL = 'timestamp'", chart.functional_html)
        @test occursin("BID_COL = 'bid_price'", chart.functional_html)
        @test occursin("QUANTITY_COL = 'qty'", chart.functional_html)
    end

    @testset "Log-scaled marker sizing" begin
        chart = ExecutionPlot(:size_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob18, :vol18, :fills18, :meta18))

        @test occursin("Math.log(f[QUANTITY_COL] + 1)", chart.functional_html)
        @test occursin("Math.max(5,", chart.functional_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            chart = ExecutionPlot(:page_exec, test_tob_df, test_volume_df, test_fills_df,
                                     test_metadata_df, (:tob_page, :vol_page, :fills_page, :meta_page);
                                     title="Page Test")

            page = JSPlotPage(
                Dict(
                    :tob_page => test_tob_df,
                    :vol_page => test_volume_df,
                    :fills_page => test_fills_df,
                    :meta_page => test_metadata_df
                ),
                [chart]
            )

            outfile = joinpath(tmpdir, "executionplot_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Page Test", content)
            @test occursin("page_exec", content)
        end
    end

    @testset "Remaining percentage calculation" begin
        chart = ExecutionPlot(:remaining_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob19, :vol19, :fills19, :meta19))

        @test occursin("remaining = Math.max(0, (desiredQty - cumQty) / desiredQty * 100)", chart.functional_html)
        @test occursin("Remaining %", chart.functional_html)
    end

    @testset "Bid/ask line traces" begin
        chart = ExecutionPlot(:traces_test, test_tob_df, test_volume_df, test_fills_df,
                                 test_metadata_df, (:tob20, :vol20, :fills20, :meta20))

        @test occursin("name: 'Bid'", chart.functional_html)
        @test occursin("name: 'Ask'", chart.functional_html)
        @test occursin("type: 'scatter'", chart.functional_html)
        @test occursin("mode: 'lines'", chart.functional_html)
    end
end
