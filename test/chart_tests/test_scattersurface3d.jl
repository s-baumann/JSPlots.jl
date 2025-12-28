using Test
using JSPlots
using DataFrames
using Statistics
using Random

@testset "ScatterSurface3D" begin
    # Generate test data
    function generate_test_data(n=50)
        df = DataFrame()

        # Group A: Saddle surface
        x_a = randn(n) .* 2
        y_a = randn(n) .* 2
        z_a = x_a.^2 .- y_a.^2 .+ randn(n) .* 0.3
        df_a = DataFrame(x=x_a, y=y_a, z=z_a, group="A", region="North")

        # Group B: Paraboloid
        x_b = randn(n) .* 2
        y_b = randn(n) .* 2
        z_b = x_b.^2 .+ y_b.^2 .+ randn(n) .* 0.3
        df_b = DataFrame(x=x_b, y=y_b, z=z_b, group="B", region="South")

        return vcat(df_a, df_b)
    end

    @testset "Basic constructor" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:test_chart, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        @test chart.chart_title == :test_chart
        @test chart.data_label == :test_data
        @test !isempty(chart.functional_html)
        @test !isempty(chart.appearance_html)
    end

    @testset "Constructor with all parameters" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:full_chart, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            smoothing_params=[0.5, 1.0, 2.0],
            default_smoothing=Dict("A" => 1.0, "B" => 0.5),
            marker_size=6,
            marker_opacity=0.8,
            height=700,
            title="Test Chart",
            notes="Test notes")

        @test chart.chart_title == :full_chart
        @test occursin("Test Chart", chart.appearance_html)
        @test occursin("Test notes", chart.appearance_html)
        @test occursin("700px", chart.appearance_html)
    end

    @testset "Default surface smoother" begin
        # Test the surface_smoother function directly
        x = [1.0, 2.0, 3.0, 1.5, 2.5]
        y = [1.0, 2.0, 3.0, 1.5, 2.5]
        z = [2.0, 8.0, 18.0, 4.5, 12.5]  # z ≈ 2*x*y

        smoothing = 1.0
        x_grid, y_grid, z_grid = JSPlots.surface_smoother(x, y, z, smoothing)

        @test length(x_grid) == 20  # Default grid size
        @test length(y_grid) == 20
        @test size(z_grid) == (20, 20)

        # Check that grid covers the data range (with extension)
        @test minimum(x_grid) < minimum(x)
        @test maximum(x_grid) > maximum(x)
        @test minimum(y_grid) < minimum(y)
        @test maximum(y_grid) > maximum(y)

        # Check that z values are reasonable (no NaN or Inf)
        @test all(isfinite, z_grid)
        @test all(z_grid .> -1000) && all(z_grid .< 1000)
    end

    @testset "Custom surface fitter" begin
        df = generate_test_data(30)

        # Simple custom fitter that just creates a plane
        function plane_fitter(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, param::Float64)
            grid_size = 10
            x_min, x_max = extrema(x)
            y_min, y_max = extrema(y)

            x_grid = range(x_min, x_max, length=grid_size)
            y_grid = range(y_min, y_max, length=grid_size)
            z_grid = fill(mean(z), grid_size, grid_size)

            return (collect(x_grid), collect(y_grid), z_grid)
        end

        chart = ScatterSurface3D(:custom_chart, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            surface_fitter=plane_fitter,
            smoothing_params=[1.0])

        @test chart.chart_title == :custom_chart
        @test !isempty(chart.functional_html)
        @test !isempty(chart.appearance_html)
    end

    @testset "Multiple grouping columns" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:multi_group, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group, :region])

        @test chart.chart_title == :multi_group
        # Should have group buttons for each combination
        @test occursin("A", chart.appearance_html)
        @test occursin("B", chart.appearance_html)
        @test occursin("North", chart.appearance_html) || occursin("South", chart.appearance_html)
    end

    @testset "Single group" begin
        df = DataFrame(
            x = randn(20),
            y = randn(20),
            z = randn(20)
        )

        chart = ScatterSurface3D(:single_group, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=Symbol[])

        @test chart.chart_title == :single_group
        @test !isempty(chart.functional_html)
        @test occursin("all", chart.appearance_html)
    end

    @testset "Smoothing parameters" begin
        df = generate_test_data(30)

        smoothing_vals = [0.2, 0.5, 1.0, 2.0, 4.0]
        chart = ScatterSurface3D(:smooth_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            smoothing_params=smoothing_vals)

        # Check that smoothing options appear in HTML
        for val in smoothing_vals
            @test occursin(string(val), chart.appearance_html)
        end

        # Check for "Defaults" option
        @test occursin("Defaults", chart.appearance_html)
    end

    @testset "Default smoothing per group" begin
        df = generate_test_data(30)

        default_smooth = Dict("A" => 1.0, "B" => 2.0)
        chart = ScatterSurface3D(:default_smooth, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            smoothing_params=[0.5, 1.0, 2.0],
            default_smoothing=default_smooth)

        # Check that default smoothing is encoded in JavaScript
        @test occursin("defaultSmoothing", chart.functional_html)
        @test occursin("\"A\"", chart.functional_html)
        @test occursin("\"B\"", chart.functional_html)
    end

    @testset "HTML controls generation" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:controls_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        # Check for global controls
        @test occursin("Toggle All Surfaces", chart.appearance_html)
        @test occursin("Toggle All Points", chart.appearance_html)

        # Check for smoothing control
        @test occursin("Smoothing Parameter", chart.appearance_html)

        # Check for plot div
        @test occursin("plot_controls_test", chart.appearance_html)
    end

    @testset "JavaScript function generation" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:js_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        # Check for essential JavaScript functions
        @test occursin("updatePlot_js_test", chart.functional_html)
        @test occursin("updatePlotWithFilters_js_test", chart.functional_html)
        @test occursin("toggleGroup_js_test", chart.functional_html)
        @test occursin("toggleAllSurfaces_js_test", chart.functional_html)
        @test occursin("toggleAllPoints_js_test", chart.functional_html)
        @test occursin("setSmoothing_js_test", chart.functional_html)

        # Check for data structures
        @test occursin("allSurfaces_js_test", chart.functional_html)
        @test occursin("allSchemes_js_test", chart.functional_html)
        @test occursin("smoothingParams_js_test", chart.functional_html)
    end

    @testset "Color generation" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:color_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        # Check that colors are in the HTML
        @test occursin("rgb(", chart.appearance_html) || occursin("#", chart.appearance_html)
    end

    @testset "Data filtering" begin
        df = generate_test_data(30)

        # Test with filters parameter
        chart = ScatterSurface3D(:filter_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            filters=Dict{Symbol, Any}(:region => ["North"]))

        # Check that filter controls are present
        @test occursin("region", chart.appearance_html)
        @test occursin("_select", chart.appearance_html)
        @test occursin("updatePlotWithFilters", chart.functional_html)
    end

    @testset "Marker customization" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:marker_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            marker_size=8,
            marker_opacity=0.9)

        # Check that marker settings are in JavaScript
        @test occursin("8", chart.functional_html)  # marker size
        @test occursin("0.9", chart.functional_html)  # opacity
    end

    @testset "Chart title sanitization" begin
        # Test that special characters in chart titles are handled
        df = generate_test_data(20)

        chart = ScatterSurface3D(Symbol("my-chart.test"), df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        # Sanitized title should be in JavaScript (no special chars)
        @test occursin("my_chart_test", chart.functional_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df = generate_test_data(30)

            chart = ScatterSurface3D(:page_test, df, :test_data,
                x_col=:x,
                y_col=:y,
                z_col=:z,
                group_cols=[:group])

            page = JSPlotPage(Dict(:test_data => df), [chart])
            outfile = joinpath(tmpdir, "scattersurface3d_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Check for Plotly.js library
            @test occursin("plotly", content) || occursin("Plotly", content)

            # Check for chart elements
            @test occursin("page_test", content)
            @test occursin("updatePlot_page_test", content)
            @test occursin("plot_page_test", content)
        end
    end

    @testset "Multiple ScatterSurface3D on same page" begin
        mktempdir() do tmpdir
            df1 = generate_test_data(20)
            df2 = generate_test_data(20)

            chart1 = ScatterSurface3D(:chart1, df1, :data1,
                x_col=:x, y_col=:y, z_col=:z, group_cols=[:group],
                title="First Chart")

            chart2 = ScatterSurface3D(:chart2, df2, :data2,
                x_col=:x, y_col=:y, z_col=:z, group_cols=[:group],
                title="Second Chart")

            page = JSPlotPage(
                Dict(:data1 => df1, :data2 => df2),
                [chart1, chart2])
            outfile = joinpath(tmpdir, "multiple_charts.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Check that both charts are present
            @test occursin("chart1", content)
            @test occursin("chart2", content)
            @test occursin("First Chart", content)
            @test occursin("Second Chart", content)

            # Each should have its own controls
            @test occursin("updatePlot_chart1", content)
            @test occursin("updatePlot_chart2", content)
            @test occursin("plot_chart1", content)
            @test occursin("plot_chart2", content)
        end
    end

    @testset "Empty group handling" begin
        df = generate_test_data(30)

        # This should work - no groups means "all" group
        chart = ScatterSurface3D(:no_groups, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=Symbol[])

        @test chart.chart_title == :no_groups
        @test occursin("all", chart.appearance_html)
    end

    @testset "Minimal data test" begin
        # Test with very small dataset
        df = DataFrame(
            x = [1.0, 2.0, 3.0],
            y = [1.0, 2.0, 3.0],
            z = [1.0, 4.0, 9.0]
        )

        chart = ScatterSurface3D(:minimal, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=Symbol[])

        @test chart.chart_title == :minimal
        @test !isempty(chart.functional_html)
        @test !isempty(chart.appearance_html)
    end

    @testset "Grid size parameter" begin
        df = generate_test_data(30)

        chart = ScatterSurface3D(:grid_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            grid_size=15)

        @test chart.chart_title == :grid_test
        # Surface data should use the specified grid size
        @test occursin("surfacesData", chart.functional_html)
    end

    @testset "Surface computation with different smoothing levels" begin
        df = generate_test_data(30)

        # Test with multiple smoothing parameters
        chart = ScatterSurface3D(:multi_smooth, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            smoothing_params=[0.5, 1.0, 2.0, 4.0])

        # Should have surfaces pre-computed for all combinations
        @test occursin("0.5", chart.functional_html)
        @test occursin("1.0", chart.functional_html)
        @test occursin("2.0", chart.functional_html)
        @test occursin("4.0", chart.functional_html)
    end

    @testset "Notes and title display" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:display_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            title="My 3D Surface Plot",
            notes="These are important notes about the data.")

        @test occursin("My 3D Surface Plot", chart.appearance_html)
        @test occursin("These are important notes about the data.", chart.appearance_html)
    end

    @testset "Height customization" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:size_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            height=800)

        @test occursin("800px", chart.appearance_html)
    end

    @testset "Multiple grouping schemes" begin
        df = DataFrame(
            x = randn(50),
            y = randn(50),
            z = randn(50),
            industry = repeat(["Tech", "Finance"], 25),
            country = repeat(["USA", "UK", "Germany"], 17)[1:50]
        )

        chart = ScatterSurface3D(:multi_grouping, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            grouping_schemes=Dict(
                "Industry" => [:industry],
                "Country" => [:country]
            ),
            smoothing_params=[0.5, 1.0, 2.0])

        @test chart.chart_title == :multi_grouping
        @test occursin("Grouping Scheme", chart.appearance_html)
        @test occursin("Industry", chart.appearance_html)
        @test occursin("Country", chart.appearance_html)
        @test occursin("changeScheme_multi_grouping", chart.functional_html)
        @test occursin("allSchemes_multi_grouping", chart.functional_html)
    end

    @testset "Multiple grouping schemes with default smoothing" begin
        df = generate_test_data(30)
        df.region = repeat(["North", "South", "East"], 20)

        chart = ScatterSurface3D(:multi_scheme_smooth, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            grouping_schemes=Dict(
                "Group" => [:group],
                "Region" => [:region]
            ),
            smoothing_params=[0.5, 1.0, 2.0],
            default_smoothing=Dict(
                "A" => 1.0,
                "B" => 0.5,
                "North" => 2.0,
                "South" => 1.0,
                "East" => 1.5
            ))

        @test occursin("defaultSmoothing", chart.functional_html)
        @test occursin("\"A\"", chart.functional_html)
        @test occursin("\"North\"", chart.functional_html)
    end

    @testset "Grouping scheme selector HTML" begin
        df = generate_test_data(20)  # Returns 40 rows (20*2 groups)
        df.category = repeat(["X", "Y"], 20)

        chart = ScatterSurface3D(:scheme_selector, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            grouping_schemes=Dict(
                "By Group" => [:group],
                "By Category" => [:category]
            ))

        @test occursin("scheme_selector_scheme_selector", chart.appearance_html)
        @test occursin("option value=\"By Group\"", chart.appearance_html)
        @test occursin("option value=\"By Category\"", chart.appearance_html)
        @test occursin("selected", chart.appearance_html)
    end

    @testset "Group buttons dynamically update" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:dynamic_buttons, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            grouping_schemes=Dict(
                "GroupA" => [:group],
                "GroupB" => [:region]
            ))

        @test occursin("group_buttons_dynamic_buttons", chart.appearance_html)
        @test occursin("updateGroupButtons_dynamic_buttons", chart.functional_html)
    end

    @testset "L1/L2 toggle button present" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:l1l2_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        @test occursin("l1l2_toggle_l1l2_test", chart.appearance_html)
        @test occursin("toggleL1L2_l1l2_test", chart.functional_html)
        @test occursin("Using L2 (Mean)", chart.appearance_html)
    end

    @testset "Method explanation appears" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:explanation_test, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        @test occursin("method_explanation_explanation_test", chart.appearance_html)
        @test occursin("updateMethodExplanation_explanation_test", chart.functional_html)
    end

    @testset "Surface controls section order" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:section_order, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group])

        # Find positions of sections in HTML
        groups_pos = findfirst("<!-- Group Selection -->", chart.appearance_html)
        surface_pos = findfirst("<!-- Surface Controls -->", chart.appearance_html)

        # Groups should come before Surface Controls
        @test groups_pos !== nothing
        @test surface_pos !== nothing
        @test groups_pos.start < surface_pos.start
    end

    @testset "Shaded control sections" begin
        df = generate_test_data(20)

        chart = ScatterSurface3D(:shaded_sections, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            filters=Dict{Symbol, Any}(:region => ["North"]))

        # Check for different background colors
        @test occursin("background-color: #f9f9f9", chart.appearance_html)  # Data Filters
        @test occursin("background-color: #fff8f0", chart.appearance_html)  # Groups
        @test occursin("background-color: #f0f8ff", chart.appearance_html)  # Surface Controls
    end

    @testset "Multiple grouping schemes surfaces JSON structure" begin
        df = generate_test_data(20)  # Returns 40 rows (20*2 groups)
        df.type = repeat(["P", "Q"], 20)

        chart = ScatterSurface3D(:json_struct, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            grouping_schemes=Dict(
                "Scheme1" => [:group],
                "Scheme2" => [:type]
            ),
            smoothing_params=[1.0])

        # Check that surfaces data structure is present
        @test occursin("allSurfaces_json_struct", chart.functional_html)
        @test occursin("\"Scheme1\"", chart.functional_html)
        @test occursin("\"Scheme2\"", chart.functional_html)
    end

    @testset "Backwards compatibility with group_cols" begin
        df = generate_test_data(20)

        # Old style with group_cols (no grouping_schemes)
        chart = ScatterSurface3D(:backwards_compat, df, :test_data,
            x_col=:x,
            y_col=:y,
            z_col=:z,
            group_cols=[:group],
            smoothing_params=[0.5, 1.0])

        @test chart.chart_title == :backwards_compat
        # With single grouping scheme, no dropdown selector should be visible
        @test !occursin("Grouping Scheme", chart.appearance_html)
        # But the changeScheme function is present internally
        @test occursin("allSchemes_backwards_compat", chart.functional_html)
        @test occursin("\"default\"", chart.functional_html)
    end

    @testset "weighted_median helper function" begin
        # Test basic weighted median calculation
        values = [1.0, 2.0, 3.0, 4.0, 5.0]
        weights = [1.0, 1.0, 1.0, 1.0, 1.0]
        result = JSPlots.weighted_median(values, weights)
        @test result == 3.0  # Middle value with equal weights

        # Test with unequal weights
        values2 = [1.0, 2.0, 3.0, 4.0, 5.0]
        weights2 = [0.1, 0.1, 10.0, 0.1, 0.1]  # Weight heavily toward 3.0
        result2 = JSPlots.weighted_median(values2, weights2)
        @test result2 == 3.0

        # Test with weights biased toward higher values
        values3 = [1.0, 2.0, 3.0, 4.0, 5.0]
        weights3 = [0.1, 0.1, 0.1, 5.0, 5.0]
        result3 = JSPlots.weighted_median(values3, weights3)
        @test result3 >= 4.0  # Should be in the heavier-weighted region

        # Test with unsorted values
        values4 = [5.0, 1.0, 3.0, 2.0, 4.0]
        weights4 = [1.0, 1.0, 1.0, 1.0, 1.0]
        result4 = JSPlots.weighted_median(values4, weights4)
        @test result4 == 3.0

        # Test empty array handling
        empty_vals = Float64[]
        empty_weights = Float64[]
        result_empty = JSPlots.weighted_median(empty_vals, empty_weights)
        @test result_empty == 0.0

        # Test single value
        single_val = [42.0]
        single_weight = [1.0]
        result_single = JSPlots.weighted_median(single_val, single_weight)
        @test result_single == 42.0

        # Test two values
        two_vals = [10.0, 20.0]
        two_weights = [1.0, 3.0]  # More weight on 20.0
        result_two = JSPlots.weighted_median(two_vals, two_weights)
        @test result_two == 20.0

        # Test with very small weights
        values5 = [1.0, 2.0, 3.0]
        weights5 = [1e-10, 1e-10, 1.0]
        result5 = JSPlots.weighted_median(values5, weights5)
        @test result5 == 3.0
    end

    @testset "generate_colors helper function" begin
        # Test color generation for different numbers of groups
        colors_1 = JSPlots.generate_colors(1)
        @test length(colors_1) == 1
        @test startswith(colors_1[1], "hsl(")
        @test endswith(colors_1[1], ")")

        colors_3 = JSPlots.generate_colors(3)
        @test length(colors_3) == 3
        @test all(startswith(c, "hsl(") for c in colors_3)
        @test all(occursin("70%", c) for c in colors_3)  # Saturation
        @test all(occursin("50%", c) for c in colors_3)  # Lightness

        # Colors should be different from each other
        @test colors_3[1] != colors_3[2]
        @test colors_3[2] != colors_3[3]
        @test colors_3[1] != colors_3[3]

        # Test with larger number
        colors_10 = JSPlots.generate_colors(10)
        @test length(colors_10) == 10
        # All should be unique
        @test length(unique(colors_10)) == 10

        # Test hue distribution
        colors_4 = JSPlots.generate_colors(4)
        @test length(colors_4) == 4
        # First color should have hue 0, second 90, third 180, fourth 270
        @test occursin("hsl(0", colors_4[1]) || occursin("hsl(0.0", colors_4[1])
    end

    @testset "surface_smoother with L1 minimization" begin
        # Test surface_smoother with L2_metric=false (uses weighted_median)
        x = [1.0, 2.0, 3.0, 1.5, 2.5]
        y = [1.0, 2.0, 3.0, 1.5, 2.5]
        z = [2.0, 8.0, 18.0, 4.5, 12.5]

        smoothing = 1.0
        x_grid_l1, y_grid_l1, z_grid_l1 = JSPlots.surface_smoother(x, y, z, smoothing; L2_metric=false)

        @test length(x_grid_l1) == 20
        @test length(y_grid_l1) == 20
        @test size(z_grid_l1) == (20, 20)

        # All values should be finite
        @test all(isfinite, z_grid_l1)

        # Compare L1 and L2 results - they should be different
        x_grid_l2, y_grid_l2, z_grid_l2 = JSPlots.surface_smoother(x, y, z, smoothing; L2_metric=true)

        # Grids should be the same
        @test x_grid_l1 == x_grid_l2
        @test y_grid_l1 == y_grid_l2

        # But z values should differ (L1 uses median, L2 uses mean)
        @test z_grid_l1 != z_grid_l2

        # Test with outlier data to show L1 robustness
        x_outlier = [1.0, 2.0, 3.0, 4.0, 5.0]
        y_outlier = [1.0, 1.0, 1.0, 1.0, 1.0]
        z_outlier = [1.0, 2.0, 3.0, 4.0, 100.0]  # Outlier at end

        x_grid_out_l1, y_grid_out_l1, z_grid_out_l1 = JSPlots.surface_smoother(
            x_outlier, y_outlier, z_outlier, 0.5; L2_metric=false)
        x_grid_out_l2, y_grid_out_l2, z_grid_out_l2 = JSPlots.surface_smoother(
            x_outlier, y_outlier, z_outlier, 0.5; L2_metric=true)

        # L1 should be more robust to outliers
        @test all(isfinite, z_grid_out_l1)
        @test all(isfinite, z_grid_out_l2)
    end

    @testset "surface_smoother with different smoothing parameters" begin
        x = rand(20) .* 10
        y = rand(20) .* 10
        z = @. sin(x) * cos(y) + randn() * 0.1

        # Test with very small smoothing (should be more local)
        x_grid_small, y_grid_small, z_grid_small = JSPlots.surface_smoother(x, y, z, 0.1)
        @test all(isfinite, z_grid_small)

        # Test with large smoothing (should be smoother)
        x_grid_large, y_grid_large, z_grid_large = JSPlots.surface_smoother(x, y, z, 10.0)
        @test all(isfinite, z_grid_large)

        # Larger smoothing should produce less variation
        var_small = var(z_grid_small)
        var_large = var(z_grid_large)
        @test var_large <= var_small  # May be equal in some cases due to randomness
    end

    @testset "compute_surfaces with edge cases" begin
        # Test with groups that have too few points
        df_small = DataFrame(
            x = [1.0, 2.0],
            y = [1.0, 2.0],
            z = [1.0, 2.0],
            group = ["A", "A"]  # Only 2 points in group A
        )

        # Should skip groups with < 3 points
        surfaces = JSPlots.compute_surfaces(
            df_small, :x, :y, :z, [:group], ["A"], true, [1.0], 20)

        # Group A should be skipped or have empty surface data
        @test haskey(surfaces, "A")
        @test isempty(surfaces["A"])  # Should have no surfaces computed

        # Test with exactly 3 points (minimum)
        df_min = DataFrame(
            x = [1.0, 2.0, 3.0],
            y = [1.0, 2.0, 3.0],
            z = [1.0, 4.0, 9.0],
            group = ["B", "B", "B"]
        )

        surfaces_min = JSPlots.compute_surfaces(
            df_min, :x, :y, :z, [:group], ["B"], true, [1.0], 20)

        @test haskey(surfaces_min, "B")
        @test haskey(surfaces_min["B"], 1.0)  # Should have computed surface

        # Test with "all" group
        df_all = DataFrame(
            x = randn(20),
            y = randn(20),
            z = randn(20)
        )

        surfaces_all = JSPlots.compute_surfaces(
            df_all, :x, :y, :z, Symbol[], ["all"], true, [0.5, 1.0], 20)

        @test haskey(surfaces_all, "all")
        @test haskey(surfaces_all["all"], 0.5)
        @test haskey(surfaces_all["all"], 1.0)

        # Verify surface structure
        x_grid, y_grid, z_grid = surfaces_all["all"][0.5]
        @test length(x_grid) == 20
        @test length(y_grid) == 20
        @test size(z_grid) == (20, 20)
        @test all(isfinite, z_grid)
    end

    @testset "compute_surfaces with L1 vs L2" begin
        # Use deterministic data with outliers to ensure L1 and L2 differ
        rng = Random.MersenneTwister(12345)

        x_data = randn(rng, 30)
        y_data = randn(rng, 30)
        z_data = randn(rng, 30)

        # Add outliers to ensure L1 and L2 differ
        z_data[1] += 10.0  # Large outlier
        z_data[16] += 10.0  # Another outlier for group Y

        df = DataFrame(
            x = x_data,
            y = y_data,
            z = z_data,
            group = repeat(["X", "Y"], 15)
        )

        # Compute with L2
        surfaces_l2 = JSPlots.compute_surfaces(
            df, :x, :y, :z, [:group], ["X", "Y"], true, [1.0], 20)

        # Compute with L1
        surfaces_l1 = JSPlots.compute_surfaces(
            df, :x, :y, :z, [:group], ["X", "Y"], false, [1.0], 20)

        # Both should have same structure
        @test haskey(surfaces_l2, "X")
        @test haskey(surfaces_l2, "Y")
        @test haskey(surfaces_l1, "X")
        @test haskey(surfaces_l1, "Y")

        # Verify surfaces were computed
        @test haskey(surfaces_l2["X"], 1.0)
        @test haskey(surfaces_l1["X"], 1.0)

        # Verify both produce finite results
        _, _, z_grid_l2_x = surfaces_l2["X"][1.0]
        _, _, z_grid_l1_x = surfaces_l1["X"][1.0]
        @test all(isfinite, z_grid_l2_x)
        @test all(isfinite, z_grid_l1_x)
    end

    @testset "compute_surfaces with multi-part group names" begin
        df = DataFrame(
            x = randn(40),
            y = randn(40),
            z = randn(40),
            category = repeat(["Alpha", "Beta"], 20),
            region = repeat(["North", "South"], 20)
        )

        # Multi-column grouping creates names like "Alpha_North"
        group_levels = ["Alpha_North", "Alpha_South", "Beta_North", "Beta_South"]

        surfaces = JSPlots.compute_surfaces(
            df, :x, :y, :z, [:category, :region], group_levels, true, [1.0], 20)

        # Check all groups were computed
        @test haskey(surfaces, "Alpha_North")
        @test haskey(surfaces, "Alpha_South")
        @test haskey(surfaces, "Beta_North")
        @test haskey(surfaces, "Beta_South")

        # Each should have a surface for smoothing=1.0
        @test haskey(surfaces["Alpha_North"], 1.0)
        @test haskey(surfaces["Beta_South"], 1.0)
    end

    @testset "dependencies function" begin
        df = generate_test_data(20)
        chart = ScatterSurface3D(:dep_test, df, :my_data,
            x_col=:x, y_col=:y, z_col=:z)

        deps = JSPlots.dependencies(chart)
        @test deps == [:my_data]
        @test length(deps) == 1
    end
end
