# Tests for LocalGaussianCorrelationPlot
using Random

@testset "LocalGaussianCorrelationPlot Basic" begin
    # Create test data with varying local correlation
    Random.seed!(42)
    n = 200

    # Create data where correlation varies by region
    x = randn(n)
    y = similar(x)
    for i in 1:n
        if x[i] > 0
            # Positive region: positive correlation
            y[i] = 0.8 * x[i] + 0.2 * randn()
        else
            # Negative region: negative correlation
            y[i] = -0.8 * x[i] + 0.2 * randn()
        end
    end

    df = DataFrame(
        x = x,
        y = y,
        category = rand(["A", "B", "C"], n)
    )

    # Basic construction
    lgc = LocalGaussianCorrelationPlot(:lgc_basic, df, :data,
        dimensions=[:x, :y],
        title="Basic LGC Test"
    )

    @test lgc.chart_title == :lgc_basic
    @test lgc.data_label == :data
    @test !isempty(lgc.functional_html)
    @test !isempty(lgc.appearance_html)
    @test occursin("localCorrelation", lgc.functional_html)
    @test occursin("kernel2D", lgc.functional_html)
end

@testset "LocalGaussianCorrelationPlot with Filters" begin
    Random.seed!(123)
    n = 100

    df = DataFrame(
        feature1 = randn(n),
        feature2 = randn(n),
        feature3 = randn(n),
        group = rand(["X", "Y", "Z"], n),
        year = rand(2020:2023, n)
    )

    # With categorical filter
    lgc_filtered = LocalGaussianCorrelationPlot(:lgc_filtered, df, :data,
        dimensions=[:feature1, :feature2, :feature3],
        filters=[:group],
        title="Filtered LGC"
    )

    @test occursin("group", lgc_filtered.appearance_html)
    @test occursin("CATEGORICAL_FILTERS", lgc_filtered.functional_html)

    # With Dict filter
    lgc_dict_filter = LocalGaussianCorrelationPlot(:lgc_dict, df, :data,
        dimensions=[:feature1, :feature2],
        filters=Dict(:group => ["X", "Y"]),
        title="Dict Filter LGC"
    )

    @test occursin("group", lgc_dict_filter.appearance_html)
end

@testset "LocalGaussianCorrelationPlot Custom Settings" begin
    Random.seed!(456)
    n = 50

    df = DataFrame(
        a = randn(n),
        b = randn(n),
        c = randn(n)
    )

    # With custom bandwidth and grid size
    lgc_custom = LocalGaussianCorrelationPlot(:lgc_custom, df, :data,
        dimensions=[:a, :b, :c],
        bandwidth=0.5,
        grid_size=20,
        min_weight=0.05,
        colorscale="Viridis",
        title="Custom Settings LGC"
    )

    @test occursin("DEFAULT_BANDWIDTH = 0.5", lgc_custom.functional_html)
    @test occursin("GRID_SIZE = 20", lgc_custom.functional_html)
    @test occursin("MIN_WEIGHT = 0.05", lgc_custom.functional_html)
    @test occursin("Viridis", lgc_custom.functional_html)
end

@testset "LocalGaussianCorrelationPlot Dependencies" begin
    df = DataFrame(x = randn(20), y = randn(20))

    lgc = LocalGaussianCorrelationPlot(:lgc_deps, df, :data,
        dimensions=[:x, :y]
    )

    deps = JSPlots.dependencies(lgc)
    @test :data in deps

    js_deps = JSPlots.js_dependencies(lgc)
    @test length(js_deps) > 0
end

@testset "LocalGaussianCorrelationPlot Validation" begin
    df = DataFrame(x = randn(20), y = randn(20))

    # Should error with missing column
    @test_throws ErrorException LocalGaussianCorrelationPlot(:lgc_error, df, :data,
        dimensions=[:x, :missing_col]
    )

    # Should error with less than 2 dimensions
    @test_throws ErrorException LocalGaussianCorrelationPlot(:lgc_error2, df, :data,
        dimensions=[:x]
    )
end

@testset "LocalGaussianCorrelationPlot HTML Structure" begin
    df = DataFrame(
        var1 = randn(30),
        var2 = randn(30),
        var3 = randn(30)
    )

    lgc = LocalGaussianCorrelationPlot(:lgc_html, df, :data,
        dimensions=[:var1, :var2, :var3],
        title="HTML Test",
        notes="Test notes for the chart"
    )

    # Check appearance HTML structure
    @test occursin("HTML Test", lgc.appearance_html)
    @test occursin("Test notes for the chart", lgc.appearance_html)
    @test occursin("x_col_select_lgc_html", lgc.appearance_html)
    @test occursin("y_col_select_lgc_html", lgc.appearance_html)
    @test occursin("x_transform_select_lgc_html", lgc.appearance_html)
    @test occursin("y_transform_select_lgc_html", lgc.appearance_html)
    @test occursin("bandwidth_slider", lgc.appearance_html)

    # Check functional HTML structure
    @test occursin("updatePlotWithFilters_lgc_html", lgc.functional_html)
    @test occursin("computeLocalCorrelation", lgc.functional_html)
    @test occursin("silvermanBandwidth", lgc.functional_html)
    @test occursin("applyAxisTransform", lgc.functional_html)
end

@testset "LocalGaussianCorrelationPlot Bootstrap t-statistic" begin
    df = DataFrame(
        x = randn(50),
        y = randn(50)
    )

    lgc = LocalGaussianCorrelationPlot(:lgc_bootstrap, df, :data,
        dimensions=[:x, :y],
        title="Bootstrap Test"
    )

    # Check display mode selector is present
    @test occursin("lgc_bootstrap_display_mode", lgc.appearance_html)
    @test occursin("Local Correlation", lgc.appearance_html)
    @test occursin("Bootstrap t-statistic", lgc.appearance_html)

    # Check bootstrap status indicator
    @test occursin("lgc_bootstrap_bootstrap_status", lgc.appearance_html)
    @test occursin("lgc_bootstrap_bootstrap_progress", lgc.appearance_html)

    # Check bootstrap computation functions are present in JS
    @test occursin("computeBootstrapTStats", lgc.functional_html)
    @test occursin("bootstrapIndices", lgc.functional_html)
    @test occursin("BOOTSTRAP_ITERATIONS", lgc.functional_html)
    @test occursin("bootstrapCache", lgc.functional_html)

    # Check bootstrap is lazy (only computed on demand)
    @test occursin("displayMode === 'tstat'", lgc.functional_html)
end
