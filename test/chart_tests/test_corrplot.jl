using Test
using JSPlots
using DataFrames
using LinearAlgebra
using Clustering

# Explicitly import to avoid conflicts
import JSPlots: CorrPlot, dependencies, compute_correlations, cluster_from_correlation, CorrelationScenario

@testset "CorrPlot" begin
    # Create test data with numeric columns
    df = DataFrame(
        id = 1:50,
        x1 = randn(50),
        x2 = randn(50),
        x3 = randn(50),
        x4 = randn(50),
        x5 = randn(50),
        category = repeat(["A", "B"], 25),
        region = repeat(["North", "South", "East", "West"], outer=13)[1:50]
    )

    # Add some correlated columns
    df[!, :x1_corr] = df.x1 .+ randn(50) .* 0.3
    df[!, :x2_corr] = df.x2 .+ randn(50) .* 0.4

    @testset "compute_correlations basic functionality" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)

        @test haskey(cors, :pearson)
        @test haskey(cors, :spearman)
        @test size(cors.pearson) == (3, 3)
        @test size(cors.spearman) == (3, 3)

        # Diagonal should be 1.0
        @test all(diag(cors.pearson) .≈ 1.0)
        @test all(diag(cors.spearman) .≈ 1.0)

        # Should be symmetric
        @test cors.pearson ≈ cors.pearson'
        @test cors.spearman ≈ cors.spearman'
    end

    @testset "compute_correlations with correlated data" begin
        # x1 and x1_corr should be highly correlated
        vars = [:x1, :x1_corr]
        cors = compute_correlations(df, vars)

        @test cors.pearson[1, 2] > 0.9  # High positive correlation
        @test cors.spearman[1, 2] > 0.9
    end

    @testset "cluster_from_correlation basic functionality" begin
        vars = [:x1, :x2, :x3, :x4]
        cors = compute_correlations(df, vars)

        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        @test length(hc.order) == 4
        @test length(hc.heights) == 3  # n-1 merges
        @test size(hc.merges) == (3, 2)

        # All variables should appear in order exactly once
        @test sort(hc.order) == 1:4
    end

    @testset "cluster_from_correlation different linkage methods" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)

        for method in [:ward, :average, :single, :complete]
            hc = cluster_from_correlation(cors.pearson, linkage=method)
            @test length(hc.order) == 3
            @test length(hc.heights) == 2
        end
    end

    @testset "Basic CorrPlot creation" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:test_corr, cors.pearson, cors.spearman, hc,
                           string.(vars), :test_corr_data;
                           title = "Test Correlation Plot")

        @test corrplot.chart_title == :test_corr
        @test corrplot.data_label == :test_corr_data
        @test !isempty(corrplot.functional_html)
        @test !isempty(corrplot.appearance_html)

        # Check that HTML contains key elements
        @test occursin("test_corr", corrplot.functional_html)
        @test occursin("loadDataset", corrplot.functional_html)
        @test occursin("dendrogram", corrplot.appearance_html)
        @test occursin("corrmatrix", corrplot.appearance_html)
    end

    @testset "CorrPlot with multiple variables" begin
        vars = [:x1, :x2, :x3, :x4, :x5]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:average)

        corrplot = CorrPlot(:multi_corr, cors.pearson, cors.spearman, hc,
                           string.(vars), :multi_corr_data;
                           title = "Multi-Variable Correlation")

        @test occursin("Multi-Variable Correlation", corrplot.appearance_html)
        @test occursin("Plotly.newPlot", corrplot.functional_html)
    end

    @testset "CorrPlot matrix size validation" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        # Wrong size pearson matrix
        bad_pearson = cors.pearson[1:2, 1:2]
        @test_throws ErrorException CorrPlot(:bad_size, bad_pearson, cors.spearman, hc,
                                             string.(vars), :bad_size_data)

        # Wrong size spearman matrix
        bad_spearman = cors.spearman[1:2, 1:2]
        @test_throws ErrorException CorrPlot(:bad_size, cors.pearson, bad_spearman, hc,
                                             string.(vars), :bad_size_data)
    end

    @testset "CorrPlot dendrogram validation" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)

        # Create clustering with wrong number of variables
        vars_wrong = [:x1, :x2]
        cors_wrong = compute_correlations(df, vars_wrong)
        hc_wrong = cluster_from_correlation(cors_wrong.pearson, linkage=:ward)

        @test_throws ErrorException CorrPlot(:bad_dendro, cors.pearson, cors.spearman,
                                             hc_wrong, string.(vars), :bad_dendro_data)
    end

    @testset "CorrPlot visualization elements" begin
        vars = [:x1, :x2, :x3, :x4]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:viz_elements, cors.pearson, cors.spearman, hc,
                           string.(vars), :viz_data)

        # Check for Plotly plot creation
        @test occursin("Plotly.newPlot", corrplot.functional_html)
        @test occursin("heatmap", corrplot.functional_html)
        @test occursin("colorscale", corrplot.functional_html)
        @test occursin("dendrogram", corrplot.functional_html)
        @test occursin("corrmatrix", corrplot.functional_html)

        # Check for proper annotation of Pearson (P:) and Spearman (S:)
        @test occursin("'P: '", corrplot.functional_html)
        @test occursin("'S: '", corrplot.functional_html)
    end

    @testset "CorrPlot with custom title and notes" begin
        title = "Custom Correlation Analysis"
        notes = "This is a test correlation plot with custom notes"

        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:custom_text, cors.pearson, cors.spearman, hc,
                           string.(vars), :custom_data;
                           title = title,
                           notes = notes)

        @test occursin(title, corrplot.appearance_html)
        @test occursin(notes, corrplot.appearance_html)
    end

    @testset "CorrPlot dependencies function" begin
        vars = [:x1, :x2]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:deps, cors.pearson, cors.spearman, hc,
                           string.(vars), :deps_data)

        deps = dependencies(corrplot)
        @test deps == [:deps_data]  # Should return data_label
    end

    @testset "CorrPlot page integration" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:page_test, cors.pearson, cors.spearman, hc,
                           string.(vars), :page_test_data;
                           title = "Page Integration Test")

        # Prepare correlation data for external storage
        corr_data = JSPlots.prepare_corrplot_data(cors.pearson, cors.spearman, hc, string.(vars))

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, DataFrame}(:page_test_data => corr_data),
                [corrplot];
                dataformat=:csv_embedded
            )

            output_file = joinpath(tmpdir, "corrplot_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Page Integration Test", html_content)
            @test occursin("dendrogram", html_content)
            @test occursin("corrmatrix", html_content)
        end
    end

    @testset "CorrPlot with many variables" begin
        # Test with more variables to ensure clustering works
        vars = [:x1, :x2, :x3, :x4, :x5, :x1_corr, :x2_corr]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:many_vars, cors.pearson, cors.spearman, hc,
                           string.(vars), :many_vars_data)

        @test !isempty(corrplot.functional_html)
        @test !isempty(corrplot.appearance_html)
    end

    @testset "CorrPlot with minimum viable data" begin
        # Test with just 2 variables (minimum for correlation)
        small_df = DataFrame(a = 1.0:10.0, b = (1.0:10.0) .+ randn(10) .* 0.5)

        vars = [:a, :b]
        cors = compute_correlations(small_df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:minimal, cors.pearson, cors.spearman, hc,
                           string.(vars), :minimal_data)

        @test !isempty(corrplot.functional_html)
        @test !isempty(corrplot.appearance_html)
    end

    @testset "compute_correlations data validation" begin
        # Test with insufficient data
        tiny_df = DataFrame(a = [1.0], b = [2.0])
        @test_throws ErrorException compute_correlations(tiny_df, [:a, :b])

        # Test with NaN values
        nan_df = DataFrame(a = [1.0, 2.0, NaN, 4.0], b = [2.0, 3.0, 4.0, 5.0])
        cors = compute_correlations(nan_df, [:a, :b])
        @test !any(isnan, cors.pearson)
        @test !any(isnan, cors.spearman)
    end

    @testset "CorrPlot variable ordering by dendrogram" begin
        # Create data with clear correlation structure
        ordered_df = DataFrame(
            a = randn(100),
            b = randn(100),
            c = randn(100),
            d = randn(100)
        )
        # Make a and b highly correlated
        ordered_df[!, :a] = randn(100)
        ordered_df[!, :b] = ordered_df.a .+ randn(100) .* 0.1
        # Make c and d highly correlated
        ordered_df[!, :c] = randn(100)
        ordered_df[!, :d] = ordered_df.c .+ randn(100) .* 0.1

        vars = [:a, :b, :c, :d]
        cors = compute_correlations(ordered_df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        corrplot = CorrPlot(:ordered, cors.pearson, cors.spearman, hc,
                           string.(vars), :ordered_data)

        # Variables should be reordered in the plot
        @test occursin("loadDataset", corrplot.functional_html)
        @test occursin("labels", corrplot.functional_html)
    end

    @testset "CorrelationScenario creation and validation" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        scenario = CorrelationScenario("Test Scenario",
                                      cors.pearson, cors.spearman, hc,
                                      string.(vars))

        @test scenario.name == "Test Scenario"
        @test size(scenario.pearson) == (3, 3)
        @test size(scenario.spearman) == (3, 3)
        @test length(scenario.var_labels) == 3
        @test scenario.hc isa Clustering.Hclust
    end

    @testset "CorrelationScenario validation errors" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)

        # Wrong pearson matrix size
        @test_throws ErrorException CorrelationScenario("Bad",
            cors.pearson[1:2, 1:2], cors.spearman, hc, string.(vars))

        # Wrong spearman matrix size
        @test_throws ErrorException CorrelationScenario("Bad",
            cors.pearson, cors.spearman[1:2, 1:2], hc, string.(vars))
    end

    @testset "Advanced CorrPlot with multiple scenarios" begin
        # Create three scenarios
        vars1 = [:x1, :x2]
        cors1 = compute_correlations(df, vars1)
        hc1 = cluster_from_correlation(cors1.pearson, linkage=:ward)
        scenario1 = CorrelationScenario("Scenario 1", cors1.pearson, cors1.spearman, hc1, string.(vars1))

        vars2 = [:x3, :x4]
        cors2 = compute_correlations(df, vars2)
        hc2 = cluster_from_correlation(cors2.pearson, linkage=:ward)
        scenario2 = CorrelationScenario("Scenario 2", cors2.pearson, cors2.spearman, hc2, string.(vars2))

        vars3 = [:x1, :x2, :x3, :x4]
        cors3 = compute_correlations(df, vars3)
        hc3 = cluster_from_correlation(cors3.pearson, linkage=:ward)
        scenario3 = CorrelationScenario("All Variables", cors3.pearson, cors3.spearman, hc3, string.(vars3))

        # Create advanced CorrPlot
        corrplot = CorrPlot(:advanced_test, [scenario1, scenario2, scenario3], :adv_test_data;
                           title="Advanced Test",
                           default_scenario="All Variables",
                           default_variables=["x1", "x2"],
                           allow_manual_order=true)

        @test corrplot.chart_title == :advanced_test
        @test corrplot.data_label == :adv_test_data
        @test !isempty(corrplot.functional_html)
        @test !isempty(corrplot.appearance_html)

        # Check for scenario dropdown
        @test occursin("scenario_select_advanced_test", corrplot.appearance_html)
        @test occursin("Scenario 1", corrplot.appearance_html)
        @test occursin("Scenario 2", corrplot.appearance_html)
        @test occursin("All Variables", corrplot.appearance_html)

        # Check for variable selector
        @test occursin("var_select_advanced_test", corrplot.appearance_html)
        @test occursin("Select Variables", corrplot.appearance_html)

        # Check for order mode dropdown
        @test occursin("order_mode_advanced_test", corrplot.appearance_html)
        @test occursin("Order by dendrogram", corrplot.appearance_html)

        # Check for sortable functionality
        @test occursin("sortable_vars_advanced_test", corrplot.appearance_html)
        @test occursin("Sortable", corrplot.functional_html)

        # Check for update functions
        @test occursin("updateChart_advanced_test", corrplot.functional_html)
        @test occursin("populateVarSelector", corrplot.functional_html)
        @test occursin("initializeSortable", corrplot.functional_html)

        # Check for external data loading
        @test occursin("loadDataset", corrplot.functional_html)
    end

    @testset "Advanced CorrPlot without manual ordering" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)
        scenario = CorrelationScenario("Test", cors.pearson, cors.spearman, hc, string.(vars))

        corrplot = CorrPlot(:no_manual, [scenario], :no_manual_data;
                           allow_manual_order=false)

        # Should not have sortable elements when manual ordering is disabled
        @test !occursin("Drag to Reorder", corrplot.appearance_html)
    end

    @testset "Advanced CorrPlot with single scenario" begin
        vars = [:x1, :x2, :x3]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)
        scenario = CorrelationScenario("Single", cors.pearson, cors.spearman, hc, string.(vars))

        corrplot = CorrPlot(:single_scenario, [scenario], :single_data)

        # Should not have scenario dropdown with single scenario
        @test !occursin("scenario_select", corrplot.appearance_html)
    end

    @testset "Advanced CorrPlot error - empty scenarios" begin
        @test_throws ErrorException CorrPlot(:empty, CorrelationScenario[], :empty_data)
    end

    @testset "Advanced CorrPlot error - invalid default scenario" begin
        vars = [:x1, :x2]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)
        scenario = CorrelationScenario("Test", cors.pearson, cors.spearman, hc, string.(vars))

        @test_throws ErrorException CorrPlot(:bad_default, [scenario], :bad_default_data;
                                            default_scenario="Nonexistent")
    end

    @testset "Advanced CorrPlot error - invalid default variables" begin
        vars = [:x1, :x2]
        cors = compute_correlations(df, vars)
        hc = cluster_from_correlation(cors.pearson, linkage=:ward)
        scenario = CorrelationScenario("Test", cors.pearson, cors.spearman, hc, string.(vars))

        @test_throws ErrorException CorrPlot(:bad_vars, [scenario], :bad_vars_data;
                                            default_variables=["nonexistent"])
    end

    @testset "Advanced CorrPlot page integration" begin
        vars1 = [:x1, :x2]
        cors1 = compute_correlations(df, vars1)
        hc1 = cluster_from_correlation(cors1.pearson, linkage=:ward)
        scenario1 = CorrelationScenario("First", cors1.pearson, cors1.spearman, hc1, string.(vars1))

        vars2 = [:x3, :x4]
        cors2 = compute_correlations(df, vars2)
        hc2 = cluster_from_correlation(cors2.pearson, linkage=:ward)
        scenario2 = CorrelationScenario("Second", cors2.pearson, cors2.spearman, hc2, string.(vars2))

        corrplot = CorrPlot(:adv_integration, [scenario1, scenario2], :adv_int_data;
                           title="Advanced Integration Test",
                           default_scenario="First")

        # Prepare correlation data for external storage
        corr_data = JSPlots.prepare_corrplot_advanced_data([scenario1, scenario2])

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, DataFrame}(:adv_int_data => corr_data),
                [corrplot];
                dataformat=:csv_embedded
            )

            output_file = joinpath(tmpdir, "test_advanced_corrplot.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Advanced Integration Test", html_content)
            @test occursin("scenario_select", html_content)
            @test occursin("var_select", html_content)
            @test occursin("Order by dendrogram", html_content)
            @test occursin("Sortable", html_content)
        end
    end
end

println("CorrPlot tests completed successfully!")
