using Test
using JSPlots
using DataFrames
using StableRNGs
using RefinedSlippage

# Import functions explicitly
import JSPlots: ExecutionPlot, prepare_execution_data, get_execution_data_dict, dependencies

@testset "ExecutionPlot" begin
    # Create minimal test data
    rng = StableRNG(42)

    # Create simple fills data
    fills = DataFrame(
        time = [1.0, 2.0, 3.0, 4.0, 5.0],
        quantity = [100, 150, 200, 100, 150],
        price = [100.1, 100.2, 100.15, 100.25, 100.3],
        execution_name = fill("Test_Exec_1", 5),
        asset = fill(:AAPL, 5)
    )

    # Create metadata
    metadata = DataFrame(
        execution_name = ["Test_Exec_1"],
        arrival_price = [100.0],
        side = ["buy"],
        desired_quantity = [700]
    )

    # Create TOB (top of book) data
    tob = DataFrame(
        time = collect(0.5:0.5:5.5),
        symbol = fill(:AAPL, 11),
        bid_price = 99.9 .+ rand(rng, 11) .* 0.2,
        ask_price = 100.1 .+ rand(rng, 11) .* 0.2
    )

    @testset "ExecutionData creation and slippage calculation" begin
        # Create ExecutionData without peers (classical slippage only)
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        @test !ismissing(exec_data.fill_returns)
        @test !ismissing(exec_data.summary_bps)
        @test nrow(exec_data.fill_returns) == 5
    end

    @testset "prepare_execution_data function" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        prepared = prepare_execution_data(exec_data)

        @test prepared isa Dict{Symbol, Any}
        @test haskey(prepared, :fills)
        @test haskey(prepared, :tob)
        @test haskey(prepared, :summary_bps)
        @test haskey(prepared, :volume)
        @test haskey(prepared, :peer_cols)
        @test haskey(prepared, :has_counterfactual)
        @test haskey(prepared, :has_spread_cross)
        @test haskey(prepared, :has_vs_vwap)
        @test haskey(prepared, :has_volume)

        # Check cumulative columns were added
        fills_df = prepared[:fills]
        @test "cum_quantity" in names(fills_df)
        @test "pct_complete" in names(fills_df)
        @test "cum_classical_slippage_bps" in names(fills_df)
        @test "norm_fill_pos" in names(fills_df)
    end

    @testset "prepare_execution_data cumulative calculations" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        prepared = prepare_execution_data(exec_data)
        fills_df = prepared[:fills]

        # Sort by time
        sorted_fills = sort(fills_df, :time)

        # Check cumulative quantity increases
        @test all(diff(sorted_fills.cum_quantity) .>= 0)

        # Check pct_complete is between 0 and 1
        @test all(0 .<= sorted_fills.pct_complete .<= 1)

        # Check last pct_complete is 1.0
        @test sorted_fills.pct_complete[end] ≈ 1.0
    end

    @testset "Basic ExecutionPlot creation" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:test_exec, exec_data, :exec_data;
            title = "Test Execution"
        )

        @test exec_plot.chart_title == :test_exec
        @test exec_plot.data_label == :exec_data
        @test !isempty(exec_plot.functional_html)
        @test !isempty(exec_plot.appearance_html)

        # Check for key HTML elements
        @test occursin("Test Execution", exec_plot.appearance_html)
        @test occursin("exec_select_test_exec", exec_plot.appearance_html)
        @test occursin("top_panel_test_exec", exec_plot.appearance_html)
        @test occursin("Data Sources", exec_plot.appearance_html)
    end

    @testset "ExecutionPlot view buttons" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:view_test, exec_data, :view_data)

        # View buttons (6 views total)
        @test occursin("top_view_1_view_test", exec_plot.appearance_html)
        @test occursin("top_view_2_view_test", exec_plot.appearance_html)
        @test occursin("top_view_3_view_test", exec_plot.appearance_html)
        @test occursin("top_view_4_view_test", exec_plot.appearance_html)
        @test occursin("top_view_5_view_test", exec_plot.appearance_html)
        @test occursin("top_view_6_view_test", exec_plot.appearance_html)

        # Volume toggle button
        @test occursin("volume_toggle_view_test", exec_plot.appearance_html)
    end

    @testset "ExecutionPlot JavaScript functions" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:js_test, exec_data, :js_data)

        # Check for key JavaScript functions
        @test occursin("updateChart_js_test", exec_plot.functional_html)
        @test occursin("onExecChange_js_test", exec_plot.functional_html)
        @test occursin("onColorChange_js_test", exec_plot.functional_html)
        @test occursin("setTopView_js_test", exec_plot.functional_html)
        @test occursin("toggleVolume_js_test", exec_plot.functional_html)
        @test occursin("updateSummaryTable", exec_plot.functional_html)
        @test occursin("renderTopPanel", exec_plot.functional_html)
    end

    @testset "ExecutionPlot rendering functions" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:render_test, exec_data, :render_data)

        # Check for view rendering functions (6 views)
        @test occursin("renderBidAskView", exec_plot.functional_html)
        @test occursin("renderMidCounterfactualView", exec_plot.functional_html)
        @test occursin("renderPeersView", exec_plot.functional_html)
        @test occursin("renderProgressView", exec_plot.functional_html)
        @test occursin("renderSpreadPositionView", exec_plot.functional_html)
        @test occursin("renderSlippageView", exec_plot.functional_html)
    end

    @testset "ExecutionPlot summary table" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:summary_test, exec_data, :summary_data)

        # Check for summary table
        @test occursin("summary_table_summary_test", exec_plot.appearance_html)
        @test occursin("updateSummaryTable", exec_plot.functional_html)
    end

    @testset "get_execution_data_dict function" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:dict_test, exec_data, :dict_data)

        data_dict = get_execution_data_dict(exec_plot)

        @test data_dict isa Dict{Symbol, Any}
        @test haskey(data_dict, Symbol("dict_data.fills"))
        @test haskey(data_dict, Symbol("dict_data.tob"))
        @test haskey(data_dict, Symbol("dict_data.fill_returns"))
        @test haskey(data_dict, Symbol("dict_data.summary_bps"))
        # Volume key only present if has_volume is true
    end

    @testset "dependencies function" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:deps_test, exec_data, :deps_data)

        deps = dependencies(exec_plot)

        @test Symbol("deps_data.fills") in deps
        @test Symbol("deps_data.tob") in deps
        @test Symbol("deps_data.fill_returns") in deps
        @test Symbol("deps_data.summary_bps") in deps
    end

    @testset "ExecutionPlot with notes" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        notes = "These are custom notes for the execution plot"

        exec_plot = ExecutionPlot(:notes_test, exec_data, :notes_data;
            title = "Notes Test",
            notes = notes
        )

        @test occursin(notes, exec_plot.appearance_html)
    end

    @testset "ExecutionPlot error - slippage not calculated" begin
        exec_data = ExecutionData(fills, metadata, tob)
        # Don't calculate slippage

        @test_throws ErrorException ExecutionPlot(:error_test, exec_data, :error_data)
    end

    @testset "ExecutionPlot page integration" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:page_test, exec_data, :page_data;
            title = "Page Integration Test"
        )

        # Get prepared data
        data_dict = get_execution_data_dict(exec_plot)

        mktempdir() do tmpdir
            page = JSPlotPage(
                data_dict,
                [exec_plot];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "exec_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Page Integration Test", html_content)
            @test occursin("top_panel_page_test", html_content)
            @test occursin("Data Sources", html_content)
        end
    end

    @testset "ExecutionPlot with volume data" begin
        # Create volume data
        volume = DataFrame(
            time_from = [0.0, 1.0, 2.0, 3.0, 4.0],
            time_to = [1.0, 2.0, 3.0, 4.0, 5.0],
            symbol = fill(:AAPL, 5),
            volume = [10000, 12000, 8000, 15000, 11000]
        )

        exec_data = ExecutionData(fills, metadata, tob; volume=volume)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:volume_test, exec_data, :volume_data)

        @test exec_plot.prepared_data[:has_volume] == true

        # Check volume data is in the data dict
        data_dict = get_execution_data_dict(exec_plot)
        @test haskey(data_dict, Symbol("volume_data.volume"))
    end

    @testset "ExecutionPlot feature flags" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:flags_test, exec_data, :flags_data)

        # Without peers, has_counterfactual should be false
        @test exec_plot.prepared_data[:has_counterfactual] == false
        @test exec_plot.prepared_data[:has_spread_cross] == true
        @test exec_plot.prepared_data[:has_volume] == false

        # Check JavaScript uses these flags
        @test occursin("HAS_COUNTERFACTUAL", exec_plot.functional_html)
        @test occursin("HAS_SPREAD_CROSS", exec_plot.functional_html)
        @test occursin("HAS_VS_VWAP", exec_plot.functional_html)
        @test occursin("HAS_VOLUME", exec_plot.functional_html)
    end

    @testset "ExecutionPlot with color columns" begin
        # Create fills with color columns
        fills_with_colors = DataFrame(
            time = [1.0, 2.0, 3.0, 4.0, 5.0],
            quantity = [100, 150, 200, 100, 150],
            price = [100.1, 100.2, 100.15, 100.25, 100.3],
            execution_name = fill("Test_Exec_1", 5),
            asset = fill(:AAPL, 5),
            order_type = ["limit", "market", "limit", "market", "limit"],
            exchange = ["NYSE", "NASDAQ", "BATS", "NYSE", "ARCA"]
        )

        exec_data = ExecutionData(fills_with_colors, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:color_test, exec_data, :color_data)

        # Check color columns are detected and included in JavaScript
        @test occursin("order_type", exec_plot.functional_html)
        @test occursin("exchange", exec_plot.functional_html)
        @test occursin("COLOR_COLS", exec_plot.functional_html)

        # Check fills data has the color columns
        fills_df = exec_plot.prepared_data[:fills]
        @test "order_type" in names(fills_df)
        @test "exchange" in names(fills_df)
    end

    @testset "ExecutionPlot tooltip_cols parameter" begin
        # Create fills with extra columns for tooltips
        fills_with_extras = DataFrame(
            time = [1.0, 2.0, 3.0, 4.0, 5.0],
            quantity = [100, 150, 200, 100, 150],
            price = [100.1, 100.2, 100.15, 100.25, 100.3],
            execution_name = fill("Test_Exec_1", 5),
            asset = fill(:AAPL, 5),
            order_type = ["limit", "market", "limit", "market", "limit"],
            exchange = ["NYSE", "NASDAQ", "BATS", "NYSE", "ARCA"],
            broker = ["GS", "MS", "JPM", "GS", "MS"],
            strategy = ["TWAP", "VWAP", "TWAP", "IS", "VWAP"]
        )

        exec_data = ExecutionData(fills_with_extras, metadata, tob)
        calculate_slippage!(exec_data)

        # Create plot with explicit tooltip columns
        exec_plot = ExecutionPlot(:tooltip_test, exec_data, :tooltip_data;
            tooltip_cols = [:broker, :strategy]
        )

        # Check tooltip columns are in JavaScript (includes color_cols automatically)
        @test occursin("TOOLTIP_COLS", exec_plot.functional_html)
        @test occursin("order_type", exec_plot.functional_html)
        @test occursin("exchange", exec_plot.functional_html)
        @test occursin("broker", exec_plot.functional_html)
        @test occursin("strategy", exec_plot.functional_html)

        # Check buildFillTooltip function exists
        @test occursin("buildFillTooltip", exec_plot.functional_html)
    end

    @testset "ExecutionPlot tooltip combines color_cols and tooltip_cols" begin
        fills_test = DataFrame(
            time = [1.0, 2.0, 3.0],
            quantity = [100, 150, 200],
            price = [100.1, 100.2, 100.15],
            execution_name = fill("Test_Exec_1", 3),
            asset = fill(:AAPL, 3),
            category_a = ["A", "B", "A"],  # Will be auto-detected as color column
            extra_info = ["x", "y", "z"]   # Will be added via tooltip_cols
        )

        exec_data = ExecutionData(fills_test, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:combine_test, exec_data, :combine_data;
            tooltip_cols = [:extra_info]
        )

        # Both should be in TOOLTIP_COLS
        @test occursin("category_a", exec_plot.functional_html)
        @test occursin("extra_info", exec_plot.functional_html)
    end

    @testset "ExecutionPlot units dropdown" begin
        exec_data = ExecutionData(fills, metadata, tob)
        calculate_slippage!(exec_data)

        exec_plot = ExecutionPlot(:units_test, exec_data, :units_data)

        # Check units dropdown is in HTML
        @test occursin("units_select_units_test", exec_plot.appearance_html)
        @test occursin("onUnitsChange_units_test", exec_plot.appearance_html)

        # Check units options are in HTML
        @test occursin("value=\"bps\"", exec_plot.appearance_html)
        @test occursin("value=\"pct\"", exec_plot.appearance_html)
        @test occursin("value=\"usd\"", exec_plot.appearance_html)

        # Check JavaScript units handling
        @test occursin("currentUnits", exec_plot.functional_html)
        @test occursin("getSummaryData", exec_plot.functional_html)
        @test occursin("getUnitLabel", exec_plot.functional_html)
        @test occursin("summaryDataBps", exec_plot.functional_html)
        @test occursin("summaryDataPct", exec_plot.functional_html)
        @test occursin("summaryDataUsd", exec_plot.functional_html)
    end
end

println("ExecutionPlot tests completed successfully!")
