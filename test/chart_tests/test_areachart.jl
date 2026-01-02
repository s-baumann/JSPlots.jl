using Test
using JSPlots
include("test_data.jl")

@testset "AreaChart" begin
    @testset "Basic creation" begin
        chart = AreaChart(:test_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            title = "Test Area Chart"
        )
        @test chart.chart_title == :test_area
        @test chart.data_label == :test_df
        @test occursin("test_area", chart.functional_html)
        @test occursin("x", chart.functional_html)
    end

    @testset "With grouping and filters" begin
        chart = AreaChart(:grouped_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = [:category],
            filters = Dict{Symbol,Any}(:category => "A"),
            title = "Grouped Area Chart"
        )
        @test occursin("category", chart.functional_html)
        @test occursin("A", chart.functional_html)
    end

    @testset "Without group column" begin
        df_no_group = DataFrame(x = 1:10, y = rand(10))
        chart = AreaChart(:no_group_area, df_no_group, :df_no_group;
            x_cols = [:x],
            y_cols = [:y],
            title = "No Group Area Chart"
        )
        @test occursin("__no_group__", chart.functional_html)
    end

    @testset "Stack mode options" begin
        for mode in ["unstack", "stack", "normalised_stack"]
            chart = AreaChart(:stack_test, test_df, :test_df;
                x_cols = [:x],
                y_cols = [:y],
                color_cols = [:category],
                stack_mode = mode,
                title = "Stack Mode: $mode"
            )
            @test occursin(mode, chart.functional_html)
        end
    end

    @testset "With faceting" begin
        chart = AreaChart(:facet_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = [:category],
            facet_cols = [:color],
            default_facet_cols = [:color],
            title = "Faceted Area Chart"
        )
        @test occursin("color", chart.functional_html)
        @test occursin("FACET_COLS", chart.functional_html)
    end

    @testset "Custom fill opacity" begin
        chart = AreaChart(:opacity_area, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            fill_opacity = 0.8,
            title = "Custom Opacity"
        )
        @test occursin("0.8", chart.functional_html)
    end


    @testset "Multiple dimension options" begin
        df_multi = DataFrame(
            x1 = 1:10,
            x2 = 11:20,
            y1 = rand(10),
            y2 = rand(10),
            group1 = repeat(["A", "B"], 5),
            group2 = repeat(["X", "Y"], 5)
        )
        chart = AreaChart(:multi_area, df_multi, :df_multi;
            x_cols = [:x1, :x2],
            y_cols = [:y1, :y2],
            color_cols = [:group1, :group2],
            title = "Multiple Dimensions"
        )
        @test occursin("x1", chart.functional_html)
        @test occursin("x2", chart.functional_html)
        @test occursin("y1", chart.functional_html)
        @test occursin("y2", chart.functional_html)
        @test occursin("group1", chart.functional_html)
        @test occursin("group2", chart.functional_html)
    end

    @testset "With Date type for continuous detection" begin
        using Dates
        df_dates = DataFrame(
            date = Date(2024, 1, 1):Day(1):Date(2024, 1, 31),
            sales = rand(31) .* 1000,
            region = repeat(["North", "South"], 16)[1:31]
        )
        chart = AreaChart(:date_area, df_dates, :df_dates;
            x_cols = [:date],
            y_cols = [:sales],
            color_cols = [:region],
            stack_mode = "stack",
            title = "Sales Over Time"
        )
        @test occursin("date", chart.functional_html)
        @test occursin("sales", chart.functional_html)
        @test occursin("region", chart.functional_html)
    end

    @testset "Discrete detection with integers" begin
        df_discrete = DataFrame(
            category = repeat(1:5, 4),
            count = rand(1:100, 20),
            type = repeat(["A", "B", "C", "D"], 5)
        )
        chart = AreaChart(:discrete_area, df_discrete, :df_discrete;
            x_cols = [:category],
            y_cols = [:count],
            color_cols = [:type],
            stack_mode = "normalised_stack",
            title = "Normalized Stacks"
        )
        @test occursin("category", chart.functional_html)
        @test occursin("normalised_stack", chart.functional_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df_test = DataFrame(
                x = 1:20,
                y = rand(20) .* 100,
                group = repeat(["Alpha", "Beta"], 10)
            )

            chart = AreaChart(:page_test, df_test, :test_data;
                x_cols = [:x],
                y_cols = [:y],
                color_cols = [:group],
                stack_mode = "stack",
                title = "Integration Test"
            )

            page = JSPlotPage(Dict(:test_data => df_test), [chart])
            outfile = joinpath(tmpdir, "areachart_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Check for chart presence
            @test occursin("page_test", content)
            @test occursin("Integration Test", content)
            @test occursin("updatePlot_page_test", content)

            # Check for Plotly.js presence
            @test occursin("plotly", lowercase(content))
        end
    end

    @testset "Multiple AreaCharts on same page" begin
        mktempdir() do tmpdir
            df1 = DataFrame(x = 1:10, y = rand(10), g = repeat(["A"], 10))
            df2 = DataFrame(x = 1:10, y = rand(10), g = repeat(["B"], 10))

            chart1 = AreaChart(:chart1, df1, :data1;
                x_cols = [:x],
                y_cols = [:y],
                color_cols = [:g],
                title = "First Chart"
            )

            chart2 = AreaChart(:chart2, df2, :data2;
                x_cols = [:x],
                y_cols = [:y],
                color_cols = [:g],
                title = "Second Chart",
                stack_mode = "normalised_stack"
            )

            page = JSPlotPage(
                Dict(:data1 => df1, :data2 => df2),
                [chart1, chart2]
            )
            outfile = joinpath(tmpdir, "multiple_areas.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Both charts should be present
            @test occursin("chart1", content)
            @test occursin("chart2", content)
            @test occursin("First Chart", content)
            @test occursin("Second Chart", content)

            # Each should have own update function
            @test occursin("updatePlot_chart1", content)
            @test occursin("updatePlot_chart2", content)
        end
    end

    @testset "HTML controls and interactive elements" begin
        # Need multiple columns for each dimension to trigger dropdown generation
        df_multi = DataFrame(
            x = 1:10,
            x2 = 11:20,
            y = rand(10),
            y2 = rand(10),
            category = repeat(["A", "B"], 5),
            category2 = repeat(["X", "Y"], 5)
        )

        chart = AreaChart(:controls_test, df_multi, :test_df;
            x_cols = [:x, :x2],
            y_cols = [:y, :y2],
            color_cols = [:category, :category2],
            stack_mode = "stack",
            title = "Controls Test"
        )

        # Check for control elements in appearance HTML
        @test occursin("Axes", chart.appearance_html)
        @test occursin("X: ", chart.appearance_html)
        @test occursin("Y: ", chart.appearance_html)
        @test occursin("Color by", chart.appearance_html)
        @test occursin("Stack mode", chart.appearance_html)
        @test occursin("controls_test", chart.appearance_html)

        # Check for JavaScript functions
        @test occursin("updatePlot_controls_test", chart.functional_html)
    end

    @testset "Sanitization of chart titles" begin
        # Test special characters in chart title
        chart = AreaChart(Symbol("my-chart.test"), test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            title = "Special Chars Test"
        )

        # Sanitized title should appear in JavaScript (no special chars)
        @test occursin("my_chart_test", chart.functional_html)
        @test !occursin("my-chart.test", chart.functional_html)
    end

    @testset "Notes parameter" begin
        notes_text = "This is a detailed explanation of the chart with <b>HTML</b> markup."
        chart = AreaChart(:notes_test, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            notes = notes_text
        )

        @test occursin(notes_text, chart.appearance_html)
        @test occursin("<b>HTML</b>", chart.appearance_html)
    end

    @testset "Empty color_cols creates default group" begin
        df_no_groups = DataFrame(x = 1:10, y = rand(10))
        chart = AreaChart(:default_group, df_no_groups, :df_no_groups;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = Symbol[],
            title = "No Groups"
        )

        @test occursin("__no_group__", chart.functional_html)
    end

    @testset "Data structure passed to JavaScript" begin
        chart = AreaChart(:data_struct, test_df, :test_df;
            x_cols = [:x],
            y_cols = [:y],
            color_cols = [:category]
        )

        # Check that data is loaded via loadDataset
        @test occursin("loadDataset", chart.functional_html)
        @test occursin("test_df", chart.functional_html)
    end
end
