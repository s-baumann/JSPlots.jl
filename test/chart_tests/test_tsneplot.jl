using Test
using JSPlots
using DataFrames
using StableRNGs

# Explicitly import to avoid conflicts
import JSPlots: TSNEPlot, dependencies

@testset "TSNEPlot" begin
    # Create test data
    rng = StableRNG(42)

    @testset "Basic TSNEPlot creation with feature columns" begin
        # Create simple test data
        test_data = DataFrame(
            entity = ["A", "B", "C", "D", "E"],
            feature1 = randn(rng, 5),
            feature2 = randn(rng, 5),
            feature3 = randn(rng, 5),
            category = ["X", "X", "Y", "Y", "Z"]
        )

        tsne = TSNEPlot(:basic_tsne, test_data, :test_data;
            entity_col = :entity,
            feature_cols = [:feature1, :feature2, :feature3],
            title = "Basic t-SNE Test"
        )

        @test tsne.chart_title == :basic_tsne
        @test tsne.data_label == :test_data
        @test !isempty(tsne.functional_html)
        @test !isempty(tsne.appearance_html)

        # Check for key HTML elements
        @test occursin("Basic t-SNE Test", tsne.appearance_html)
        @test occursin("tsne_canvas_basic_tsne", tsne.appearance_html)
        @test occursin("loadDataset", tsne.functional_html)
    end

    @testset "TSNEPlot with color columns" begin
        test_data = DataFrame(
            stock = ["AAPL", "MSFT", "GOOGL", "JPM", "BAC"],
            returns = randn(rng, 5),
            volatility = abs.(randn(rng, 5)),
            sector = ["Tech", "Tech", "Tech", "Finance", "Finance"],
            region = ["US", "US", "US", "US", "US"]
        )

        tsne = TSNEPlot(:color_tsne, test_data, :stock_data;
            entity_col = :stock,
            feature_cols = [:returns, :volatility],
            color_cols = [:sector, :region],
            title = "Colored t-SNE"
        )

        # Check for color selector
        @test occursin("color_select_color_tsne", tsne.appearance_html)
        @test occursin("sector", tsne.appearance_html)
        @test occursin("region", tsne.appearance_html)
        @test occursin("updateColors_color_tsne", tsne.functional_html)
    end

    @testset "TSNEPlot with tooltip columns" begin
        test_data = DataFrame(
            name = ["Alice", "Bob", "Carol", "Dave"],
            x1 = randn(rng, 4),
            x2 = randn(rng, 4),
            age = [25, 30, 35, 40],
            score = [85.5, 90.2, 78.3, 92.1]
        )

        tsne = TSNEPlot(:tooltip_tsne, test_data, :people_data;
            entity_col = :name,
            feature_cols = [:x1, :x2],
            tooltip_cols = [:age, :score],
            title = "Tooltip Test"
        )

        # Check for tooltip configuration
        @test occursin("TOOLTIP_COLS", tsne.functional_html)
        @test occursin("age", tsne.functional_html)
        @test occursin("score", tsne.functional_html)
        @test occursin("tooltip_tooltip_tsne", tsne.appearance_html)
    end

    @testset "TSNEPlot with distance matrix" begin
        # Create distance matrix format data with node1, node2, distance columns
        entities = ["A", "B", "C", "D"]
        distance_data = DataFrame(
            node1 = String[],
            node2 = String[],
            distance = Float64[]
        )
        for i in 1:length(entities)
            for j in (i+1):length(entities)
                push!(distance_data, (entities[i], entities[j], rand(rng) * 2))
            end
        end

        tsne = TSNEPlot(:distance_tsne, distance_data, :dist_data;
            distance_matrix = true,
            title = "Distance Matrix t-SNE"
        )

        @test tsne.chart_title == :distance_tsne
        @test occursin("IS_DISTANCE_MATRIX = true", tsne.functional_html)
        # Should not have feature selection UI for distance matrix
        @test !occursin("Feature Selection for Distance Calculation", tsne.appearance_html)
        # Check for node1/node2 column references in JavaScript
        @test occursin("row.node1", tsne.functional_html)
        @test occursin("row.node2", tsne.functional_html)
    end

    @testset "TSNEPlot with custom hyperparameters" begin
        test_data = DataFrame(
            id = ["P1", "P2", "P3"],
            f1 = [1.0, 2.0, 3.0],
            f2 = [4.0, 5.0, 6.0]
        )

        tsne = TSNEPlot(:hyperparam_tsne, test_data, :hp_data;
            entity_col = :id,
            feature_cols = [:f1, :f2],
            perplexity = 15.0,
            learning_rate = 500.0,
            title = "Custom Hyperparameters"
        )

        # Check for custom perplexity
        @test occursin("INITIAL_PERPLEXITY = 15.0", tsne.functional_html)
        @test occursin("value=\"15.0\"", tsne.appearance_html)

        # Check for custom learning rate
        @test occursin("INITIAL_LEARNING_RATE = 500.0", tsne.functional_html)
        @test occursin("value=\"500.0\"", tsne.appearance_html)
    end

    @testset "TSNEPlot with label column different from entity" begin
        test_data = DataFrame(
            code = ["A001", "B002", "C003"],
            display_name = ["Alpha", "Beta", "Gamma"],
            x = [1.0, 2.0, 3.0],
            y = [4.0, 5.0, 6.0]
        )

        tsne = TSNEPlot(:label_tsne, test_data, :label_data;
            entity_col = :code,
            label_col = :display_name,
            feature_cols = [:x, :y],
            title = "Custom Labels"
        )

        @test occursin("ENTITY_COL = 'code'", tsne.functional_html)
        @test occursin("LABEL_COL = 'display_name'", tsne.functional_html)
    end

    @testset "TSNEPlot feature selection UI" begin
        test_data = DataFrame(
            name = ["A", "B", "C"],
            f1 = [1.0, 2.0, 3.0],
            f2 = [4.0, 5.0, 6.0],
            f3 = [7.0, 8.0, 9.0]
        )

        tsne = TSNEPlot(:feature_select_tsne, test_data, :fs_data;
            entity_col = :name,
            feature_cols = [:f1, :f2],  # Only f1 and f2 initially selected
            title = "Feature Selection"
        )

        # Check for feature selection UI elements
        @test occursin("Available Features", tsne.appearance_html)
        @test occursin("Selected Features", tsne.appearance_html)
        @test occursin("available_features_feature_select_tsne", tsne.appearance_html)
        @test occursin("selected_features_feature_select_tsne", tsne.appearance_html)
        @test occursin("addFeature_feature_select_tsne", tsne.functional_html)
        @test occursin("removeFeature_feature_select_tsne", tsne.functional_html)
        @test occursin("recalculateDistances_feature_select_tsne", tsne.functional_html)
    end

    @testset "TSNEPlot rescaling options" begin
        test_data = DataFrame(
            id = ["X", "Y", "Z"],
            a = [1.0, 2.0, 3.0],
            b = [10.0, 20.0, 30.0]
        )

        tsne = TSNEPlot(:rescale_tsne, test_data, :rescale_data;
            entity_col = :id,
            feature_cols = [:a, :b],
            title = "Rescaling Test"
        )

        # Check for rescaling dropdown
        @test occursin("rescaling_rescale_tsne", tsne.appearance_html)
        @test occursin("No rescaling", tsne.appearance_html)
        @test occursin("Z-score", tsne.appearance_html)
        @test occursin("zscore_capped", tsne.appearance_html)
        @test occursin("Quantile", tsne.appearance_html)
    end

    @testset "TSNEPlot control buttons" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:controls_tsne, test_data, :ctrl_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Controls Test"
        )

        # Check for all control buttons
        @test occursin("Randomize Positions", tsne.appearance_html)
        @test occursin("Step (small)", tsne.appearance_html)
        @test occursin("Exaggerated Step", tsne.appearance_html)
        @test occursin("Run to Convergence", tsne.appearance_html)

        # Check for button functions
        @test occursin("randomizePositions_controls_tsne", tsne.functional_html)
        @test occursin("stepIteration_controls_tsne", tsne.functional_html)
        @test occursin("toggleRun_controls_tsne", tsne.functional_html)
    end

    @testset "TSNEPlot early exaggeration settings" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:exag_tsne, test_data, :exag_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Exaggeration Test"
        )

        # Check for exaggeration settings
        @test occursin("exag_iters_exag_tsne", tsne.appearance_html)
        @test occursin("exag_factor_exag_tsne", tsne.appearance_html)
        @test occursin("Early exaggeration iters", tsne.appearance_html)
        @test occursin("Exaggeration factor", tsne.appearance_html)

        # Check for exaggeration functions
        @test occursin("getExaggerationFactor", tsne.functional_html)
        @test occursin("getExaggerationIters", tsne.functional_html)
    end

    @testset "TSNEPlot convergence settings" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:conv_tsne, test_data, :conv_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Convergence Test"
        )

        # Check for convergence settings
        @test occursin("convergence_conv_tsne", tsne.appearance_html)
        @test occursin("max_iter_conv_tsne", tsne.appearance_html)
        @test occursin("Convergence threshold", tsne.appearance_html)
        @test occursin("Max iterations", tsne.appearance_html)
        @test occursin("value=\"5000\"", tsne.appearance_html)  # Default max iterations
    end

    @testset "TSNEPlot status display" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:status_tsne, test_data, :status_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Status Display Test"
        )

        # Check for status display elements
        @test occursin("iteration_status_tsne", tsne.appearance_html)
        @test occursin("distance_status_tsne", tsne.appearance_html)
        @test occursin("status_status_tsne", tsne.appearance_html)
        @test occursin("exaggeration_status_status_tsne", tsne.appearance_html)
        @test occursin("updateIterationDisplay", tsne.functional_html)
        @test occursin("updateStatus", tsne.functional_html)
    end

    @testset "TSNEPlot t-SNE algorithm components" begin
        test_data = DataFrame(
            id = ["A", "B", "C"],
            x = [1.0, 2.0, 3.0],
            y = [4.0, 5.0, 6.0]
        )

        tsne = TSNEPlot(:algo_tsne, test_data, :algo_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Algorithm Test"
        )

        # Check for t-SNE algorithm functions
        @test occursin("computeGaussianPerplexity", tsne.functional_html)
        @test occursin("tsneStep", tsne.functional_html)
        @test occursin("buildDistanceMatrix", tsne.functional_html)

        # Check for gradient descent components
        @test occursin("velocities", tsne.functional_html)
        @test occursin("gains", tsne.functional_html)
        @test occursin("momentum", tsne.functional_html)
    end

    @testset "TSNEPlot drag behavior" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:drag_tsne, test_data, :drag_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Drag Test"
        )

        # Check for D3 v3 drag behavior
        @test occursin("d3.behavior.drag()", tsne.functional_html)
        @test occursin("dragstart", tsne.functional_html)
        @test occursin("dragend", tsne.functional_html)

        # Check for coordinate transform
        @test occursin("currentTransform", tsne.functional_html)
    end

    @testset "TSNEPlot aspect ratio control" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:aspect_tsne, test_data, :aspect_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Aspect Ratio Test"
        )

        # Check for aspect ratio slider
        @test occursin("aspect_ratio_slider_aspect_tsne", tsne.appearance_html)
        @test occursin("Aspect Ratio", tsne.appearance_html)
        @test occursin("setupAspectRatio", tsne.functional_html)
    end

    @testset "TSNEPlot error - missing entity column" begin
        test_data = DataFrame(
            wrong_col = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        @test_throws ErrorException TSNEPlot(:error_tsne, test_data, :error_data;
            entity_col = :entity,  # Does not exist
            feature_cols = [:x, :y]
        )
    end

    @testset "TSNEPlot error - missing feature column" begin
        test_data = DataFrame(
            entity = ["A", "B"],
            x = [1.0, 2.0]
        )

        @test_throws ErrorException TSNEPlot(:error_tsne2, test_data, :error_data2;
            entity_col = :entity,
            feature_cols = [:x, :y, :z]  # z does not exist
        )
    end

    @testset "TSNEPlot error - distance matrix missing columns" begin
        # Missing required columns for distance matrix
        test_data = DataFrame(
            node1 = ["A", "B"],
            node2 = ["B", "C"]
            # Missing :distance column
        )

        @test_throws ErrorException TSNEPlot(:error_dist, test_data, :error_dist_data;
            distance_matrix = true
        )
    end

    @testset "TSNEPlot dependencies function" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        tsne = TSNEPlot(:deps_tsne, test_data, :deps_data;
            entity_col = :id,
            feature_cols = [:x, :y]
        )

        deps = dependencies(tsne)
        @test deps == [:deps_data]
    end

    @testset "TSNEPlot page integration" begin
        test_data = DataFrame(
            stock = ["AAPL", "MSFT", "GOOGL"],
            returns = [0.05, 0.03, 0.04],
            volatility = [0.2, 0.18, 0.22],
            sector = ["Tech", "Tech", "Tech"]
        )

        tsne = TSNEPlot(:page_tsne, test_data, :page_data;
            entity_col = :stock,
            feature_cols = [:returns, :volatility],
            color_cols = [:sector],
            title = "Page Integration Test"
        )

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, Any}(:page_data => test_data),
                [tsne];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "tsne_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Page Integration Test", html_content)
            @test occursin("tsne_canvas_page_tsne", html_content)
            @test occursin("computeGaussianPerplexity", html_content)
        end
    end

    @testset "TSNEPlot with all numeric columns auto-detected" begin
        test_data = DataFrame(
            name = ["A", "B", "C"],
            val1 = [1.0, 2.0, 3.0],
            val2 = [4.0, 5.0, 6.0],
            val3 = [7.0, 8.0, 9.0],
            category = ["X", "Y", "Z"]  # Non-numeric, should be excluded
        )

        # Don't specify feature_cols - should auto-detect all numeric
        tsne = TSNEPlot(:auto_tsne, test_data, :auto_data;
            entity_col = :name,
            title = "Auto-detect Columns"
        )

        # Check that all numeric columns are in ALL_NUMERIC_COLS
        @test occursin("val1", tsne.functional_html)
        @test occursin("val2", tsne.functional_html)
        @test occursin("val3", tsne.functional_html)
    end

    @testset "TSNEPlot with notes" begin
        test_data = DataFrame(
            id = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        notes = "These are custom notes for the t-SNE visualization"

        tsne = TSNEPlot(:notes_tsne, test_data, :notes_data;
            entity_col = :id,
            feature_cols = [:x, :y],
            title = "Notes Test",
            notes = notes
        )

        @test occursin(notes, tsne.appearance_html)
    end

    @testset "TSNEPlot with continuous color columns" begin
        test_data = DataFrame(
            entity = ["A", "B", "C", "D", "E"],
            x = [1.0, 2.0, 3.0, 4.0, 5.0],
            y = [2.0, 4.0, 6.0, 8.0, 10.0],
            score = [0.1, 0.5, 0.8, 1.2, 2.0],  # Continuous variable
            category = ["X", "X", "Y", "Y", "Z"]  # Discrete variable
        )

        tsne = TSNEPlot(:cont_color_tsne, test_data, :cont_data;
            entity_col = :entity,
            feature_cols = [:x, :y],
            color_cols = [:score, :category],
            title = "Continuous Color Test"
        )

        # Check for continuous coloring support
        @test occursin("continuousCols", tsne.functional_html)
        @test occursin("discreteCols", tsne.functional_html)
        @test occursin("interpolateColor_cont_color_tsne", tsne.functional_html)
        @test occursin("parseHexColor_cont_color_tsne", tsne.functional_html)

        # Check that score is listed as continuous and category as discrete
        @test occursin("score (continuous)", tsne.appearance_html)
        @test occursin("category (discrete)", tsne.appearance_html)
    end

    @testset "TSNEPlot with colour_map" begin
        test_data = DataFrame(
            entity = ["A", "B", "C"],
            x = [1.0, 2.0, 3.0],
            y = [4.0, 5.0, 6.0],
            value = [-1.0, 0.0, 1.0]
        )

        # Global gradient
        colour_map = Dict(
            -1.0 => "#FF0000",
            0.0 => "#FFFFFF",
            1.0 => "#0000FF"
        )

        tsne = TSNEPlot(:cmap_tsne, test_data, :cmap_data;
            entity_col = :entity,
            feature_cols = [:x, :y],
            color_cols = [:value],
            colour_map = colour_map,
            title = "Colour Map Test"
        )

        @test occursin("colourMap", tsne.functional_html)
        @test occursin("#FF0000", tsne.functional_html)
        @test occursin("#0000FF", tsne.functional_html)
    end

    @testset "TSNEPlot with extrapolate_colors" begin
        test_data = DataFrame(
            entity = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0],
            val = [0.5, 1.5]
        )

        tsne = TSNEPlot(:extrap_tsne, test_data, :extrap_data;
            entity_col = :entity,
            feature_cols = [:x, :y],
            color_cols = [:val],
            extrapolate_colors = true,
            title = "Extrapolate Colors Test"
        )

        @test occursin("extrapolateColors = true", tsne.functional_html)
    end

    @testset "TSNEPlot colour_map validation" begin
        test_data = DataFrame(
            entity = ["A", "B"],
            x = [1.0, 2.0],
            y = [3.0, 4.0]
        )

        # Invalid colour_map with only 1 stop
        invalid_map = Dict(0.0 => "#FF0000")

        @test_throws ErrorException TSNEPlot(:invalid_cmap, test_data, :inv_data;
            entity_col = :entity,
            feature_cols = [:x, :y],
            colour_map = invalid_map
        )
    end
end

println("TSNEPlot tests completed successfully!")
