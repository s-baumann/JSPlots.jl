using Test
using JSPlots
using DataFrames

@testset "RadarChart" begin
    @testset "Basic creation with required parameters" begin
        df = DataFrame(
            label = ["Product A", "Product B", "Product C"],
            Quality = [8.5, 7.2, 6.8],
            Price = [6.0, 9.0, 7.5],
            Features = [9.0, 7.5, 8.0],
            Support = [7.5, 8.0, 6.5]
        )

        radar = RadarChart(:test_radar, :test_data;
            value_cols = [:Quality, :Price, :Features, :Support],
            label_col = :label,
            title = "Product Comparison"
        )

        @test radar.chart_id == :test_radar
        @test radar.data_label == :test_data
        @test !isempty(radar.functional_html)
        @test !isempty(radar.appearance_html)

        # Check for D3-related content
        @test occursin("d3.select", radar.functional_html)
        @test occursin("loadDataset", radar.functional_html)
        @test occursin("radar_test_radar", radar.functional_html)
    end

    @testset "Minimum value columns validation" begin
        df = DataFrame(
            label = ["A", "B"],
            val1 = [1.0, 2.0],
            val2 = [3.0, 4.0]
        )

        # Exactly 2 columns - should throw error
        @test_throws ErrorException RadarChart(:error_test, :data;
            value_cols = [:val1, :val2],
            label_col = :label
        )

        # Exactly 3 columns - should work
        df2 = DataFrame(
            label = ["A", "B"],
            val1 = [1.0, 2.0],
            val2 = [3.0, 4.0],
            val3 = [5.0, 6.0]
        )

        radar = RadarChart(:ok_test, :data;
            value_cols = [:val1, :val2, :val3],
            label_col = :label
        )
        @test radar.chart_id == :ok_test
    end

    @testset "HTML content generation" begin
        df = DataFrame(
            label = ["A", "B"],
            X = [1.0, 2.0],
            Y = [3.0, 4.0],
            Z = [5.0, 6.0]
        )

        radar = RadarChart(:html_test, :test_data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            title = "Test Title",
            notes = "Test notes here"
        )

        # Check appearance HTML
        @test occursin("Test Title", radar.appearance_html)
        @test occursin("Test notes here", radar.appearance_html)
        @test occursin("container_html_test", radar.appearance_html)
        @test occursin("radar_html_test", radar.appearance_html)
        @test occursin("label_select_html_test", radar.appearance_html)

        # Check functional HTML
        @test occursin("VALUE_COLS", radar.functional_html)
        @test occursin("LABEL_COL", radar.functional_html)
        @test occursin("\"X\"", radar.functional_html)
        @test occursin("\"Y\"", radar.functional_html)
        @test occursin("\"Z\"", radar.functional_html)
    end

    @testset "Scenario column support" begin
        df = DataFrame(
            label = ["A", "A", "B", "B"],
            scenario = ["Base", "Optimistic", "Base", "Optimistic"],
            X = [1.0, 1.5, 2.0, 2.5],
            Y = [3.0, 3.5, 4.0, 4.5],
            Z = [5.0, 5.5, 6.0, 6.5]
        )

        radar = RadarChart(:scenario_test, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            scenario_col = :scenario,
            title = "Scenario Test"
        )

        # Check for scenario selector in appearance HTML
        @test occursin("scenario_select_scenario_test", radar.appearance_html)
        @test occursin("Scenario:", radar.appearance_html)

        # Check functional HTML has scenario handling
        @test occursin("SCENARIO_COL", radar.functional_html)
        @test occursin("\"scenario\"", radar.functional_html)
    end

    @testset "Variable selector" begin
        df = DataFrame(
            label = ["A", "B"],
            V1 = [1.0, 2.0], V2 = [3.0, 4.0], V3 = [5.0, 6.0],
            V4 = [7.0, 8.0], V5 = [9.0, 10.0], V6 = [11.0, 12.0]
        )

        radar = RadarChart(:var_select_test, :data;
            value_cols = [:V1, :V2, :V3, :V4, :V5, :V6],
            label_col = :label,
            variable_selector = true,
            title = "Variable Selector Test"
        )

        # Check for variable selector in appearance HTML
        @test occursin("var_select_var_select_test", radar.appearance_html)
        @test occursin("Select variables", radar.appearance_html)
        @test occursin("multiple", radar.appearance_html)

        # Check functional HTML
        @test occursin("VARIABLE_SELECTOR", radar.functional_html)
        @test occursin("true", radar.functional_html)
    end

    @testset "Max variables" begin
        df = DataFrame(
            label = ["A"],
            V1 = [1.0], V2 = [2.0], V3 = [3.0], V4 = [4.0], V5 = [5.0]
        )

        radar = RadarChart(:max_var_test, :data;
            value_cols = [:V1, :V2, :V3, :V4, :V5],
            label_col = :label,
            variable_selector = true,
            max_variables = 3,
            title = "Max Variables Test"
        )

        @test occursin("MAX_VARIABLES", radar.functional_html)
        @test occursin("3", radar.functional_html)
    end

    @testset "Color column" begin
        df = DataFrame(
            label = ["A", "B", "C"],
            category = ["Type1", "Type2", "Type1"],
            X = [1.0, 2.0, 3.0],
            Y = [4.0, 5.0, 6.0],
            Z = [7.0, 8.0, 9.0]
        )

        radar = RadarChart(:color_test, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            color_col = :category,
            title = "Color Test"
        )

        @test occursin("COLOR_COL", radar.functional_html)
        @test occursin("\"category\"", radar.functional_html)
        @test occursin("colorMap", radar.functional_html)
    end

    @testset "Custom default color" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        radar = RadarChart(:default_color_test, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            default_color = "#ff5500",
            title = "Default Color Test"
        )

        @test occursin("DEFAULT_COLOR", radar.functional_html)
        @test occursin("#ff5500", radar.functional_html)
    end

    @testset "Group mapping" begin
        df = DataFrame(
            label = ["A"],
            Speed = [8.0], Power = [7.0], Handling = [9.0],
            Acceleration = [6.0], TopSpeed = [8.5], Braking = [7.5]
        )

        radar = RadarChart(:group_test, :data;
            value_cols = [:Speed, :Power, :Handling, :Acceleration, :TopSpeed, :Braking],
            label_col = :label,
            group_mapping = Dict(
                :Speed => "Performance",
                :Power => "Performance",
                :Acceleration => "Performance",
                :Handling => "Control",
                :Braking => "Control"
            ),
            title = "Group Mapping Test"
        )

        @test occursin("GROUP_MAPPING", radar.functional_html)
        @test occursin("Performance", radar.functional_html)
        @test occursin("Control", radar.functional_html)
    end

    @testset "Variable limits" begin
        df = DataFrame(
            label = ["A"],
            Score = [95.0], Percentage = [0.85], Rating = [4.5]
        )

        radar = RadarChart(:limits_test, :data;
            value_cols = [:Score, :Percentage, :Rating],
            label_col = :label,
            variable_limits = Dict(:Score => 100.0, :Percentage => 1.0, :Rating => 5.0),
            title = "Variable Limits Test"
        )

        @test occursin("VARIABLE_LIMITS", radar.functional_html)
        @test occursin("100", radar.functional_html) || occursin("100.0", radar.functional_html)
    end

    @testset "Max value global" begin
        df = DataFrame(
            label = ["A"],
            X = [5.0], Y = [6.0], Z = [7.0]
        )

        radar = RadarChart(:max_val_test, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            max_value = 10.0,
            title = "Max Value Test"
        )

        @test occursin("MAX_VALUE", radar.functional_html)
        @test occursin("10", radar.functional_html)
    end

    @testset "Show legend option" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        # With legend
        radar_legend = RadarChart(:legend_on, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            show_legend = true
        )
        @test occursin("SHOW_LEGEND", radar_legend.functional_html)
        @test occursin("addLegend_", radar_legend.functional_html)

        # Without legend
        radar_no_legend = RadarChart(:legend_off, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            show_legend = false
        )
        @test occursin("SHOW_LEGEND = false", radar_no_legend.functional_html)
    end

    @testset "Show grid labels option" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        # With grid labels
        radar_labels = RadarChart(:grid_on, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            show_grid_labels = true
        )
        @test occursin("SHOW_GRID_LABELS = true", radar_labels.functional_html)

        # Without grid labels
        radar_no_labels = RadarChart(:grid_off, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            show_grid_labels = false
        )
        @test occursin("SHOW_GRID_LABELS = false", radar_no_labels.functional_html)
    end

    @testset "Empty notes" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        radar = RadarChart(:no_notes, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            title = "No Notes Test",
            notes = ""
        )

        # Empty notes should not create a <p> tag for notes
        @test !occursin("<p></p>", radar.appearance_html)
    end

    @testset "dependencies function" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        radar = RadarChart(:deps_test, :my_radar_data;
            value_cols = [:X, :Y, :Z],
            label_col = :label
        )

        deps = dependencies(radar)
        @test :my_radar_data in deps
    end

    @testset "js_dependencies function" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        radar = RadarChart(:js_deps_test, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label
        )

        js_deps = js_dependencies(radar)
        # Should include jQuery and D3
        @test length(js_deps) >= 2
        @test any(dep -> occursin("jquery", lowercase(dep)), js_deps)
        @test any(dep -> occursin("d3", lowercase(dep)), js_deps)
    end

    @testset "HTML generation for page integration" begin
        df = DataFrame(
            label = ["Product A", "Product B"],
            Quality = [8.5, 7.2],
            Price = [6.0, 9.0],
            Features = [9.0, 7.5],
            Support = [7.5, 8.0]
        )

        radar = RadarChart(:page_test, :page_data;
            value_cols = [:Quality, :Price, :Features, :Support],
            label_col = :label,
            title = "Page Integration Test"
        )

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, Any}(:page_data => df),
                [radar];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "radar_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Page Integration Test", html_content)
            @test occursin("d3", html_content)
            @test occursin("radar_page_test", html_content)
            @test occursin("Product A", html_content)
            @test occursin("Quality", html_content)
        end
    end

    @testset "Complex radar chart with all options" begin
        df = DataFrame(
            label = ["Team A", "Team B", "Team C", "Team D"],
            scenario = ["Current", "Current", "Projected", "Projected"],
            category = ["Division 1", "Division 1", "Division 2", "Division 2"],
            Speed = [85.0, 78.0, 92.0, 88.0],
            Accuracy = [90.0, 95.0, 82.0, 87.0],
            Endurance = [75.0, 80.0, 88.0, 72.0],
            Teamwork = [88.0, 70.0, 85.0, 90.0],
            Strategy = [92.0, 88.0, 78.0, 82.0]
        )

        radar = RadarChart(:complex_test, :complex_data;
            value_cols = [:Speed, :Accuracy, :Endurance, :Teamwork, :Strategy],
            label_col = :label,
            scenario_col = :scenario,
            color_col = :category,
            group_mapping = Dict(
                :Speed => "Physical",
                :Endurance => "Physical",
                :Accuracy => "Skill",
                :Strategy => "Skill"
            ),
            variable_limits = Dict(:Speed => 100.0, :Accuracy => 100.0, :Endurance => 100.0),
            variable_selector = true,
            max_variables = 4,
            default_color = "#336699",
            title = "Team Performance Analysis",
            notes = "Comprehensive performance metrics",
            max_value = 100.0,
            show_legend = true,
            show_grid_labels = true
        )

        @test radar.chart_id == :complex_test
        @test radar.data_label == :complex_data

        # Verify all options are present in HTML
        @test occursin("scenario_select_complex_test", radar.appearance_html)
        @test occursin("var_select_complex_test", radar.appearance_html)
        @test occursin("Team Performance Analysis", radar.appearance_html)
        @test occursin("Comprehensive performance metrics", radar.appearance_html)

        @test occursin("\"scenario\"", radar.functional_html)
        @test occursin("\"category\"", radar.functional_html)
        @test occursin("Physical", radar.functional_html)
        @test occursin("Skill", radar.functional_html)
        @test occursin("#336699", radar.functional_html)
        @test occursin("MAX_VALUE = 100", radar.functional_html)
        @test occursin("MAX_VARIABLES = 4", radar.functional_html)
    end

    @testset "Multiple radar charts on same page" begin
        df1 = DataFrame(
            label = ["A", "B"],
            X = [1.0, 2.0], Y = [3.0, 4.0], Z = [5.0, 6.0]
        )

        df2 = DataFrame(
            label = ["C", "D"],
            P = [10.0, 20.0], Q = [30.0, 40.0], R = [50.0, 60.0]
        )

        radar1 = RadarChart(:radar_one, :data1;
            value_cols = [:X, :Y, :Z],
            label_col = :label,
            title = "First Radar"
        )

        radar2 = RadarChart(:radar_two, :data2;
            value_cols = [:P, :Q, :R],
            label_col = :label,
            title = "Second Radar"
        )

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, Any}(:data1 => df1, :data2 => df2),
                [radar1, radar2];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "multi_radar_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("First Radar", html_content)
            @test occursin("Second Radar", html_content)
            @test occursin("radar_radar_one", html_content)
            @test occursin("radar_radar_two", html_content)
        end
    end

    @testset "JavaScript function generation" begin
        df = DataFrame(
            label = ["A"],
            X = [1.0], Y = [2.0], Z = [3.0]
        )

        radar = RadarChart(:js_test, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :label
        )

        # Check key JavaScript functions are generated
        @test occursin("initializeRadarChart_js_test", radar.functional_html)
        @test occursin("updateRadarChart_js_test", radar.functional_html)
        @test occursin("renderRadarChart_js_test", radar.functional_html)
        @test occursin("drawSingleRadar_js_test", radar.functional_html)
        @test occursin("addLegend_js_test", radar.functional_html)

        # Check D3 drawing operations
        @test occursin("svg.append", radar.functional_html)
        @test occursin("circle", radar.functional_html)
        @test occursin("path", radar.functional_html)
        @test occursin("line", radar.functional_html)
        @test occursin("text", radar.functional_html)
    end

    @testset "Default label column" begin
        df = DataFrame(
            label = ["A", "B"],
            X = [1.0, 2.0], Y = [3.0, 4.0], Z = [5.0, 6.0]
        )

        # Should use :label as default
        radar = RadarChart(:default_label, :data;
            value_cols = [:X, :Y, :Z]
        )

        @test occursin("LABEL_COL = \"label\"", radar.functional_html)
    end

    @testset "Custom label column" begin
        df = DataFrame(
            name = ["Product 1", "Product 2"],
            X = [1.0, 2.0], Y = [3.0, 4.0], Z = [5.0, 6.0]
        )

        radar = RadarChart(:custom_label, :data;
            value_cols = [:X, :Y, :Z],
            label_col = :name
        )

        @test occursin("LABEL_COL = \"name\"", radar.functional_html)
    end
end

println("RadarChart tests completed successfully!")
