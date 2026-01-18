using Test
using JSPlots
using DataFrames
using StableRNGs

# Explicitly import to avoid conflicts
import JSPlots: Graph, GraphScenario, calculate_smart_cutoff, dependencies

@testset "Graph" begin
    # Create test data
    rng = StableRNG(42)

    @testset "GraphScenario creation" begin
        node_labels = ["A", "B", "C", "D"]

        # Valid correlation scenario
        scenario_corr = GraphScenario("Test Correlation", true, node_labels)
        @test scenario_corr.name == "Test Correlation"
        @test scenario_corr.is_correlation == true
        @test scenario_corr.node_labels == node_labels

        # Valid distance scenario
        scenario_dist = GraphScenario("Test Distance", false, node_labels)
        @test scenario_dist.name == "Test Distance"
        @test scenario_dist.is_correlation == false
        @test scenario_dist.node_labels == node_labels
    end

    @testset "calculate_smart_cutoff basic functionality" begin
        # Create test graph data
        df = DataFrame(
            node1 = ["A", "A", "A", "B", "B", "C"],
            node2 = ["B", "C", "D", "C", "D", "D"],
            strength = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4],
            scenario = fill("test", 6)
        )

        # Test correlation data (higher = stronger)
        # Sorted descending: [0.9, 0.8, 0.7, 0.6, 0.5, 0.4]
        # 50% of 6 edges = 3 edges, so we want threshold at index 3 = 0.7
        cutoff = calculate_smart_cutoff(df, "test", true, 0.5)
        @test cutoff ≈ 0.7

        # Test with 33% target
        # 33% of 6 ≈ 2 edges, so we want threshold at index 2 = 0.8
        cutoff_33 = calculate_smart_cutoff(df, "test", true, 0.33)
        @test cutoff_33 ≈ 0.8

        # Test distance data (lower = stronger)
        # Sorted ascending: [0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
        # 50% of 6 edges = 3 edges, so we want threshold at index 3 = 0.6
        cutoff_dist = calculate_smart_cutoff(df, "test", false, 0.5)
        @test cutoff_dist ≈ 0.6
    end

    @testset "calculate_smart_cutoff with missing scenario" begin
        df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8],
            scenario = fill("exists", 2)
        )

        # Should warn and return default 0.5
        @test_logs (:warn, r"No data found") begin
            cutoff = calculate_smart_cutoff(df, "nonexistent", true, 0.15)
            @test cutoff == 0.5
        end
    end

    @testset "calculate_smart_cutoff edge cases" begin
        # Single edge
        df_single = DataFrame(
            node1 = ["A"],
            node2 = ["B"],
            strength = [0.9],
            scenario = ["test"]
        )
        cutoff = calculate_smart_cutoff(df_single, "test", true, 0.5)
        @test cutoff ≈ 0.9

        # Many edges
        n = 100
        # Generate node names (A pairs with B, C, D, ... and then AA, AB, AC, ...)
        node2_names = String[]
        for i in 1:n
            if i <= 26
                push!(node2_names, string('A' + i - 1))
            else
                idx = i - 26
                push!(node2_names, string('A', 'A' + idx - 1))
            end
        end

        df_many = DataFrame(
            node1 = repeat(["A"], n),
            node2 = node2_names,
            strength = range(1.0, 0.0, length=n),
            scenario = fill("test", n)
        )
        cutoff_15 = calculate_smart_cutoff(df_many, "test", true, 0.15)
        @test cutoff_15 > 0.8  # Should be in top 15%
    end

    @testset "Basic Graph creation with single scenario" begin
        # Create simple graph data
        graph_data = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            sector = ["Tech", "Tech", "Tech"],
            scenario = fill("Test", 3)
        )

        node_labels = ["A", "B", "C"]
        scenario = GraphScenario("Test", true, node_labels)

        graph = Graph(:test_graph, [scenario], :test_data;
                     title = "Test Graph",
                     cutoff = 0.5,
                     color_cols = [:sector],
                     default_color_col = :sector,
                     show_edge_labels = false,
                     layout = :cose)

        @test graph.chart_title == :test_graph
        @test graph.data_label == :test_data
        @test !isempty(graph.functional_html)
        @test !isempty(graph.appearance_html)

        # Check for key HTML elements
        @test occursin("Test Graph", graph.appearance_html)
        @test occursin("graph_test_graph", graph.appearance_html)
        @test occursin("cytoscape", graph.functional_html)
        @test occursin("loadDataset", graph.functional_html)
    end

    @testset "Graph with multiple scenarios" begin
        # Create graph data with two scenarios
        graph_data = DataFrame(
            node1 = ["A", "A", "B", "A", "A", "B"],
            node2 = ["B", "C", "C", "B", "C", "C"],
            strength = [0.9, 0.7, 0.6, 0.85, 0.75, 0.65],
            sector = repeat(["Tech", "Tech", "Tech"], 2),
            scenario = [fill("Short", 3); fill("Long", 3)]
        )

        node_labels = ["A", "B", "C"]
        scenario1 = GraphScenario("Short", true, node_labels)
        scenario2 = GraphScenario("Long", true, node_labels)

        graph = Graph(:multi_scenario, [scenario1, scenario2], :multi_data;
                     title = "Multi-Scenario Graph",
                     default_scenario = "Short")

        @test graph.chart_title == :multi_scenario

        # Check for scenario selector
        @test occursin("scenario_select_multi_scenario", graph.appearance_html)
        @test occursin("Short", graph.appearance_html)
        @test occursin("Long", graph.appearance_html)
        @test occursin("updateEdges_multi_scenario", graph.functional_html)
    end

    @testset "Graph with single scenario - no scenario selector" begin
        graph_data = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8],
            scenario = fill("Only", 2)
        )

        scenario = GraphScenario("Only", true, ["A", "B", "C"])

        graph = Graph(:single_scenario, [scenario], :single_data)

        # Should not have scenario dropdown
        @test !occursin("scenario_select", graph.appearance_html)
    end

    @testset "Graph with color columns" begin
        graph_data = DataFrame(
            node1 = ["A", "B", "C"],
            node2 = ["B", "C", "D"],
            strength = [0.9, 0.8, 0.7],
            sector = ["Tech", "Finance", "Healthcare"],
            region = ["North", "South", "East"],
            scenario = fill("Test", 3)
        )

        scenario = GraphScenario("Test", true, ["A", "B", "C", "D"])

        graph = Graph(:color_test, [scenario], :color_data;
                     color_cols = [:sector, :region],
                     default_color_col = :sector)

        # Check for color selector
        @test occursin("color_select_color_test", graph.appearance_html)
        @test occursin("sector", graph.appearance_html)
        @test occursin("region", graph.appearance_html)
        @test occursin("updateColors_color_test", graph.functional_html)
    end

    @testset "Graph without color columns" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:no_color, [scenario], :no_color_data;
                     color_cols = nothing)

        # Should not have color selector
        @test !occursin("Color nodes by", graph.appearance_html)
    end

    @testset "Graph with different layouts" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        for layout in [:cose, :circle, :grid, :concentric, :breadthfirst, :random]
            graph = Graph(:layout_test, [scenario], :layout_data;
                         layout = layout)

            @test occursin(string(layout), lowercase(graph.appearance_html))
            @test occursin("layout_select_layout_test", graph.appearance_html)
        end
    end

    @testset "Graph layout validation" begin
        scenario = GraphScenario("Test", true, ["A", "B"])

        # Invalid layout should error
        @test_throws ErrorException Graph(:bad_layout, [scenario], :bad_data;
                                         layout = :invalid_layout)
    end

    @testset "Graph with edge labels" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        # With edge labels enabled
        graph_with = Graph(:with_labels, [scenario], :with_labels_data;
                          show_edge_labels = true)
        @test occursin("checked", graph_with.appearance_html)
        @test occursin("updateEdgeLabels", graph_with.functional_html)

        # With edge labels disabled
        graph_without = Graph(:without_labels, [scenario], :without_labels_data;
                             show_edge_labels = false)
        @test !occursin("checked", graph_without.appearance_html)
    end

    @testset "Graph with custom cutoff" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:cutoff_test, [scenario], :cutoff_data;
                     cutoff = 0.75)

        @test occursin("0.75", graph.appearance_html)
        @test occursin("cutoff_slider_cutoff_test", graph.appearance_html)
    end

    @testset "Graph error - empty scenarios" begin
        @test_throws ErrorException Graph(:empty, GraphScenario[], :empty_data)
    end

    @testset "Graph error - invalid default scenario" begin
        scenario = GraphScenario("Test", true, ["A", "B"])

        @test_throws ErrorException Graph(:bad_default, [scenario], :bad_data;
                                         default_scenario = "Nonexistent")
    end

    @testset "Graph error - invalid default variables" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        @test_throws ErrorException Graph(:bad_vars, [scenario], :bad_vars_data;
                                         default_variables = ["X", "Y", "Z"])
    end

    @testset "Graph with default variables" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C", "D"])

        graph = Graph(:default_vars, [scenario], :default_vars_data;
                     default_variables = ["A", "B"])

        # Should initialize with only A and B selected
        @test occursin("selectedVars", graph.functional_html)
        @test occursin("[\"A\",\"B\"]", graph.functional_html)
    end

    @testset "Graph variable selector" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C", "D"])

        graph = Graph(:var_select, [scenario], :var_select_data)

        # Check for variable selector
        @test occursin("var_select_var_select", graph.appearance_html)
        @test occursin("Select Variables", graph.appearance_html)
        @test occursin("populateVarSelector", graph.functional_html)
        @test occursin("updateNodeOpacity", graph.functional_html)
    end

    @testset "Graph recalculate button" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:recalc, [scenario], :recalc_data)

        # Check for recalculate button
        @test occursin("recalc_btn_recalc", graph.appearance_html)
        @test occursin("Recalculate Graph", graph.appearance_html)
        @test occursin("recalculateGraph_recalc", graph.functional_html)
        @test occursin("Apply variable selection & reorganize layout", graph.appearance_html)
    end

    @testset "Graph JavaScript functions" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:js_test, [scenario], :js_data)

        # Check for all key JavaScript functions
        @test occursin("populateVarSelector_js_test", graph.functional_html)
        @test occursin("initializeGraph_js_test", graph.functional_html)
        @test occursin("recalculateGraph_js_test", graph.functional_html)
        @test occursin("updateEdges_js_test", graph.functional_html)
        @test occursin("updateNodeOpacity_js_test", graph.functional_html)
        @test occursin("updateColors_js_test", graph.functional_html)
        @test occursin("updateEdgeLabels_js_test", graph.functional_html)
    end

    @testset "Graph Cytoscape configuration" begin
        scenario = GraphScenario("Test", true, ["A", "B"])

        graph = Graph(:cyto_test, [scenario], :cyto_data)

        # Check for Cytoscape elements
        @test occursin("cytoscape({", graph.functional_html)
        @test occursin("container:", graph.functional_html)
        @test occursin("style:", graph.functional_html)
        @test occursin("layout:", graph.functional_html)

        # Check for node styles
        @test occursin("node", graph.functional_html)
        @test occursin("background-color", graph.functional_html)
        @test occursin("label", graph.functional_html)

        # Check for edge styles
        @test occursin("edge", graph.functional_html)
        @test occursin("line-color", graph.functional_html)

        # Check for deselected node style
        @test occursin("node.deselected", graph.functional_html)
        @test occursin("opacity", graph.functional_html)
    end

    @testset "Graph node position persistence" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:pos_test, [scenario], :pos_data)

        # Check for nodePositions object
        @test occursin("nodePositions", graph.functional_html)
        @test occursin("nodePositions = {}", graph.functional_html)

        # Check that positions are stored
        @test occursin("nodePositions[node.id()]", graph.functional_html)
    end

    @testset "Graph initialization order" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:init_order, [scenario], :init_data)

        # populateVarSelector should be called BEFORE initializeGraph
        html = graph.functional_html
        populate_idx = findfirst("populateVarSelector_init_order()", html)
        initialize_idx = findfirst("initializeGraph_init_order()", html)

        @test !isnothing(populate_idx)
        @test !isnothing(initialize_idx)
        @test populate_idx.start < initialize_idx.start
    end

    @testset "Graph with custom title and notes" begin
        scenario = GraphScenario("Test", true, ["A", "B"])

        title = "Custom Graph Title"
        notes = "These are custom notes for the graph"

        graph = Graph(:custom_text, [scenario], :custom_data;
                     title = title,
                     notes = notes)

        @test occursin(title, graph.appearance_html)
        @test occursin(notes, graph.appearance_html)
    end

    @testset "Graph dependencies function" begin
        scenario = GraphScenario("Test", true, ["A", "B"])

        graph = Graph(:deps_test, [scenario], :deps_data)

        deps = dependencies(graph)
        @test deps == [:deps_data]
    end

    @testset "Graph page integration" begin
        # Create graph data
        graph_data = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.8, 0.7],
            sector = ["Tech", "Tech", "Finance"],
            scenario = fill("Test", 3)
        )

        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:page_test, [scenario], :page_data;
                     title = "Page Integration Test",
                     color_cols = [:sector])

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, DataFrame}(:page_data => graph_data),
                [graph];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "graph_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Page Integration Test", html_content)
            @test occursin("cytoscape", html_content)
            @test occursin("graph_page_test", html_content)
        end
    end

    @testset "Graph with multiple scenarios - page integration" begin
        # Create graph data with multiple scenarios
        graph_data = DataFrame(
            node1 = ["A", "A", "B", "A", "A", "B"],
            node2 = ["B", "C", "C", "B", "C", "C"],
            strength = [0.9, 0.7, 0.6, 0.85, 0.75, 0.55],
            category = repeat(["X", "Y", "Z"], 2),
            scenario = [fill("Scenario1", 3); fill("Scenario2", 3)]
        )

        scenario1 = GraphScenario("Scenario1", true, ["A", "B", "C"])
        scenario2 = GraphScenario("Scenario2", true, ["A", "B", "C"])

        # Calculate smart cutoff
        cutoff = calculate_smart_cutoff(graph_data, "Scenario1", true, 0.15)

        graph = Graph(:multi_page, [scenario1, scenario2], :multi_page_data;
                     title = "Multi-Scenario Integration",
                     cutoff = cutoff,
                     color_cols = [:category],
                     default_scenario = "Scenario1",
                     default_variables = ["A", "B"])

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, DataFrame}(:multi_page_data => graph_data),
                [graph];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "multi_graph_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Multi-Scenario Integration", html_content)
            @test occursin("scenario_select_multi_page", html_content)
            @test occursin("Scenario1", html_content)
            @test occursin("Scenario2", html_content)
            @test occursin("var_select_multi_page", html_content)
            @test occursin("recalc_btn_multi_page", html_content)
        end
    end

    @testset "Graph with distance data (is_correlation=false)" begin
        graph_data = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.1, 0.2, 0.3],  # Lower = stronger for distance
            scenario = fill("Distance", 3)
        )

        scenario = GraphScenario("Distance", false, ["A", "B", "C"])

        graph = Graph(:distance_test, [scenario], :distance_data;
                     cutoff = 0.25)

        @test graph.chart_title == :distance_test
        @test !isempty(graph.functional_html)
        @test !isempty(graph.appearance_html)
    end

    @testset "Graph smart cutoff with distance vs correlation" begin
        # Create identical data but treat as distance vs correlation
        data = DataFrame(
            node1 = repeat(["A"], 10),
            node2 = string.('B':'K'),
            strength = range(0.1, 0.9, length=10),
            scenario = fill("test", 10)
        )

        # For correlation (higher = stronger), cutoff should be high
        cutoff_corr = calculate_smart_cutoff(data, "test", true, 0.2)
        @test cutoff_corr > 0.7  # Top 20% of high values

        # For distance (lower = stronger), cutoff should be low
        cutoff_dist = calculate_smart_cutoff(data, "test", false, 0.2)
        @test cutoff_dist < 0.3  # Top 20% of low values

        # They should be different
        @test cutoff_corr != cutoff_dist
    end

    @testset "Graph with all layout options" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:all_layouts, [scenario], :layouts_data)

        # Check that all layout options are present
        @test occursin("Cose", graph.appearance_html)
        @test occursin("Circle", graph.appearance_html)
        @test occursin("Grid", graph.appearance_html)
        @test occursin("Concentric", graph.appearance_html)
        @test occursin("Breadthfirst", graph.appearance_html)
        @test occursin("Random", graph.appearance_html)
    end

    @testset "Graph scenario switching updates edges only" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:edge_update, [scenario], :edge_data)

        # Check that updateEdges removes and rebuilds edges
        @test occursin("cy.edges().remove()", graph.functional_html)
        @test occursin("getEdgesForScenario", graph.functional_html)
        @test occursin("cy.add(edges)", graph.functional_html)
    end

    @testset "Graph recalculate clears positions" begin
        scenario = GraphScenario("Test", true, ["A", "B", "C"])

        graph = Graph(:clear_pos, [scenario], :clear_data)

        # Check that recalculate clears nodePositions
        html = graph.functional_html
        @test occursin("nodePositions = {}", html)

        # Should happen in recalculateGraph
        recalc_start = findfirst("recalculateGraph_clear_pos", html)
        @test !isnothing(recalc_start)
    end

    @testset "Graph CSS classes for deselected nodes" begin
        scenario = GraphScenario("Test", true, ["A", "B"])

        graph = Graph(:css_test, [scenario], :css_data)

        # Check for deselected class handling
        @test occursin("node.deselected", graph.functional_html)
        @test occursin("removeClass('deselected')", graph.functional_html)
        @test occursin("addClass('deselected')", graph.functional_html)
        @test occursin("opacity", graph.functional_html)
    end

    # ========================================
    # Tests for DataFrame-based constructor (new API)
    # ========================================

    @testset "Graph DataFrame constructor - basic" begin
        # New API: Pass DataFrame directly instead of GraphScenario
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6]
        )

        graph = Graph(:df_basic, graph_df, :df_basic_data;
            title = "DataFrame API Test"
        )

        @test graph.chart_title == :df_basic
        @test graph.data_label == :df_basic_data
        @test !isempty(graph.functional_html)
        @test !isempty(graph.appearance_html)
        @test occursin("DataFrame API Test", graph.appearance_html)
    end

    @testset "Graph DataFrame constructor - with scenario column" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B", "A", "A", "B"],
            node2 = ["B", "C", "C", "B", "C", "C"],
            strength = [0.9, 0.7, 0.6, 0.85, 0.75, 0.55],
            scenario = [fill("Base", 3); fill("Stress", 3)]
        )

        graph = Graph(:df_scenario, graph_df, :df_scenario_data;
            scenario_col = :scenario,
            default_scenario = "Base",
            title = "Scenario Test"
        )

        @test occursin("scenario_select_df_scenario", graph.appearance_html)
        @test occursin("Base", graph.appearance_html)
        @test occursin("Stress", graph.appearance_html)
    end

    @testset "Graph DataFrame constructor - missing required columns" begin
        # Missing strength column
        bad_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"]
        )

        @test_throws ErrorException Graph(:bad_df, bad_df, :bad_data)
    end

    @testset "Graph DataFrame constructor - missing scenario column" begin
        graph_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8]
        )

        @test_throws ErrorException Graph(:bad_scenario_col, graph_df, :bad_data;
            scenario_col = :nonexistent
        )
    end

    @testset "Graph tooltip_cols parameter" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            sector = ["Tech", "Finance", "Tech"],
            description = ["Node A", "Node B", "Node C"]
        )

        graph = Graph(:tooltip_test, graph_df, :tooltip_data;
            tooltip_cols = [:sector, :description],
            title = "Tooltip Test"
        )

        @test occursin("tooltipCols", graph.functional_html)
        @test occursin("sector", graph.functional_html)
        @test occursin("description", graph.functional_html)
        @test occursin("setupTooltips_tooltip_test", graph.functional_html)
    end

    @testset "Graph tooltip_cols with missing columns warning" begin
        graph_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8]
        )

        # Should warn about missing column but not error
        @test_logs (:warn, r"Tooltip column nonexistent not found") begin
            graph = Graph(:tooltip_warn, graph_df, :tooltip_warn_data;
                tooltip_cols = [:nonexistent]
            )
            @test !isnothing(graph)
        end
    end

    @testset "Graph colour_map - global gradient" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            score = [1.5, -0.5, 2.0]
        )

        colour_gradient = Dict{Float64,String}(
            -2.0 => "#FF0000",
            0.0 => "#FFFFFF",
            2.0 => "#0000FF"
        )

        graph = Graph(:colour_map_test, graph_df, :colour_map_data;
            color_cols = [:score],
            colour_map = colour_gradient,
            title = "Colour Map Test"
        )

        @test occursin("colourMap", graph.functional_html)
        @test occursin("FF0000", graph.functional_html)
        @test occursin("FFFFFF", graph.functional_html)
        @test occursin("0000FF", graph.functional_html)
        @test occursin("applyContinuousColoring", graph.functional_html)
    end

    @testset "Graph colour_map - per-variable gradients" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            score1 = [1.5, -0.5, 2.0],
            score2 = [0.3, 0.8, 0.5]
        )

        per_var_gradients = Dict{String,Dict{Float64,String}}(
            "score1" => Dict(-2.0 => "#FF0000", 0.0 => "#FFFFFF", 2.0 => "#0000FF"),
            "score2" => Dict(0.0 => "#00FF00", 1.0 => "#FF00FF")
        )

        graph = Graph(:per_var_colour, graph_df, :per_var_data;
            color_cols = [:score1, :score2],
            colour_map = per_var_gradients,
            title = "Per-Variable Gradients"
        )

        @test occursin("colourMap", graph.functional_html)
        @test occursin("score1", graph.functional_html)
        @test occursin("score2", graph.functional_html)
    end

    @testset "Graph colour_map validation - too few stops" begin
        graph_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8],
            score = [1.0, 2.0]
        )

        # Global gradient with only 1 stop
        bad_gradient = Dict{Float64,String}(0.0 => "#FF0000")

        @test_throws ErrorException Graph(:bad_gradient, graph_df, :bad_data;
            color_cols = [:score],
            colour_map = bad_gradient
        )
    end

    @testset "Graph colour_map validation - per-variable too few stops" begin
        graph_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8],
            score = [1.0, 2.0]
        )

        # Per-variable gradient with only 1 stop
        bad_per_var = Dict{String,Dict{Float64,String}}(
            "score" => Dict(0.0 => "#FF0000")
        )

        @test_throws ErrorException Graph(:bad_per_var, graph_df, :bad_data;
            color_cols = [:score],
            colour_map = bad_per_var
        )
    end

    @testset "Graph extrapolate_colors parameter" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            score = [1.5, -0.5, 5.0]  # 5.0 is outside gradient range
        )

        colour_gradient = Dict{Float64,String}(
            -2.0 => "#FF0000",
            0.0 => "#FFFFFF",
            2.0 => "#0000FF"
        )

        # With extrapolation enabled
        graph = Graph(:extrapolate_test, graph_df, :extrapolate_data;
            color_cols = [:score],
            colour_map = colour_gradient,
            extrapolate_colors = true
        )

        @test occursin("extrapolateColors = true", graph.functional_html)

        # Without extrapolation (default)
        graph_clamp = Graph(:clamp_test, graph_df, :clamp_data;
            color_cols = [:score],
            colour_map = colour_gradient,
            extrapolate_colors = false
        )

        @test occursin("extrapolateColors = false", graph_clamp.functional_html)
    end

    @testset "Graph continuous vs discrete color column detection" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            numeric_col = [1.5, 2.0, 3.5],
            string_col = ["X", "Y", "Z"]
        )

        graph = Graph(:col_type_test, graph_df, :col_type_data;
            color_cols = [:numeric_col, :string_col],
            title = "Column Type Detection"
        )

        @test occursin("continuousCols", graph.functional_html)
        @test occursin("discreteCols", graph.functional_html)
        @test occursin("numeric_col", graph.functional_html)
        @test occursin("string_col", graph.functional_html)

        # Check appearance HTML shows type indicators
        @test occursin("(continuous)", graph.appearance_html)
        @test occursin("(discrete)", graph.appearance_html)
    end

    @testset "Graph js_dependencies function" begin
        graph_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8]
        )

        graph = Graph(:js_deps_test, graph_df, :js_deps_data)

        js_deps = js_dependencies(graph)
        @test length(js_deps) >= 2
        @test any(dep -> occursin("jquery", lowercase(dep)), js_deps)
        @test any(dep -> occursin("cytoscape", lowercase(dep)), js_deps)
    end

    @testset "Graph correlation_method column detection" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B", "A", "A", "B"],
            node2 = ["B", "C", "C", "B", "C", "C"],
            strength = [0.9, 0.7, 0.6, 0.85, 0.75, 0.55],
            correlation_method = [fill("pearson", 3); fill("spearman", 3)]
        )

        graph = Graph(:corr_method_test, graph_df, :corr_method_data;
            title = "Correlation Method Test"
        )

        # Check for correlation method selector container
        @test occursin("corr_method_container_corr_method_test", graph.appearance_html)
        @test occursin("corr_method_select_corr_method_test", graph.appearance_html)
        @test occursin("Correlation method", graph.appearance_html)
    end

    @testset "Graph aspect ratio slider" begin
        graph_df = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"],
            strength = [0.9, 0.8]
        )

        graph = Graph(:aspect_test, graph_df, :aspect_data)

        # Check for aspect ratio control
        @test occursin("aspect_ratio_slider_aspect_test", graph.appearance_html)
        @test occursin("Aspect Ratio", graph.appearance_html)
        @test occursin("setupGraphAspectRatio_aspect_test", graph.functional_html)
    end

    @testset "Graph DataFrame with combined color and tooltip cols" begin
        graph_df = DataFrame(
            node1 = ["A", "A", "B"],
            node2 = ["B", "C", "C"],
            strength = [0.9, 0.7, 0.6],
            sector = ["Tech", "Finance", "Tech"],
            region = ["North", "South", "East"],
            extra_info = ["Info1", "Info2", "Info3"]
        )

        # color_cols and tooltip_cols with overlap - should deduplicate
        graph = Graph(:combined_cols, graph_df, :combined_data;
            color_cols = [:sector, :region],
            tooltip_cols = [:sector, :extra_info],  # sector overlaps
            title = "Combined Columns Test"
        )

        # All should appear in tooltipCols
        @test occursin("tooltipCols", graph.functional_html)
        @test occursin("sector", graph.functional_html)
        @test occursin("region", graph.functional_html)
        @test occursin("extra_info", graph.functional_html)
    end
end

println("Graph tests completed successfully!")
