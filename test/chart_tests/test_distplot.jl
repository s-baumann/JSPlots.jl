using Test
using JSPlots
using DataFrames
using Dates

@testset "DistPlot" begin
    df_dist = DataFrame(value = randn(100))

    @testset "Basic creation" begin
        chart = DistPlot(:test_dist, df_dist, :df_dist;
            value_cols = [:value],
            title = "Dist Test"
        )
        @test chart.chart_title == :test_dist
        @test occursin("value", chart.functional_html)
    end

    @testset "With groups" begin
        df_grouped = DataFrame(
            value = randn(100),
            group = repeat(["A", "B"], 50)
        )
        chart = DistPlot(:grouped_dist, df_grouped, :df_grouped;
            value_cols = [:value],
            color_cols = [:group]
        )
        @test occursin("group", chart.functional_html)
    end

    @testset "Custom appearance" begin
        chart = DistPlot(:custom_dist, df_dist, :df_dist;
            value_cols = [:value],
            show_box = false,
            show_rug = false,
            histogram_bins = 50,
            box_opacity = 0.7
        )
        @test occursin("50", chart.functional_html)
        @test occursin("false", lowercase(chart.functional_html))
    end

    @testset "Multiple value columns" begin
        df_multi = DataFrame(
            value1 = randn(50),
            value2 = randn(50) .+ 2,
            value3 = randn(50) .* 2
        )
        chart = DistPlot(:multi_values, df_multi, :df_multi;
            value_cols = [:value1, :value2, :value3],
            show_controls = true
        )
        @test occursin("value1", chart.appearance_html)
        @test occursin("value2", chart.appearance_html)
        @test occursin("value3", chart.appearance_html)
    end

    @testset "Multiple group columns" begin
        df_groups = DataFrame(
            value = randn(100),
            category = repeat(["A", "B"], 50),
            region = repeat(["North", "South", "East", "West"], 25)
        )
        chart = DistPlot(:multi_groups, df_groups, :df_groups;
            value_cols = [:value],
            color_cols = [:category, :region],
            show_controls = true
        )
        @test occursin("category", chart.appearance_html)
        @test occursin("region", chart.appearance_html)
    end

    @testset "Filter dropdowns - continuous" begin
        df_filter = DataFrame(
            value = randn(100),
            temperature = rand(100) .* 30 .+ 10,
            pressure = rand(100) .* 100 .+ 900
        )
        chart = DistPlot(:filter_continuous, df_filter, :df_filter;
            value_cols = [:value],
            filters = [:temperature, :pressure]
        )
        @test occursin("temperature", chart.appearance_html)
        @test occursin("pressure", chart.appearance_html)
    end

    @testset "Filter dropdowns - dates" begin
        ndays = 365
        df_dates = DataFrame(
            value = randn(ndays),
            date = Date(2024, 1, 1):Day(1):Date(2024, 12, 30)  # 365 days
        )
        chart = DistPlot(:filter_dates, df_dates, :df_dates;
            value_cols = [:value],
            filters = [:date]
        )
        @test occursin("date", chart.appearance_html)
    end

    @testset "Filter dropdowns - integers" begin
        df_int = DataFrame(
            value = randn(100),
            year = rand(2020:2024, 100),
            count = rand(1:100, 100)
        )
        chart = DistPlot(:filter_int, df_int, :df_int;
            value_cols = [:value],
            filters = [:year, :count]
        )
        @test occursin("year", chart.appearance_html)
        @test occursin("count", chart.appearance_html)
    end

    @testset "Only histogram" begin
        chart = DistPlot(:hist_only, df_dist, :df_dist;
            value_cols = [:value],
            show_histogram = true,
            show_box = false,
            show_rug = false
        )
        @test occursin("histogram", lowercase(chart.functional_html))
    end

    @testset "Only box plot" begin
        chart = DistPlot(:box_only, df_dist, :df_dist;
            value_cols = [:value],
            show_histogram = false,
            show_box = true,
            show_rug = false
        )
        @test occursin("box", lowercase(chart.functional_html))
    end

    @testset "Only rug plot" begin
        chart = DistPlot(:rug_only, df_dist, :df_dist;
            value_cols = [:value],
            show_histogram = false,
            show_box = false,
            show_rug = true
        )
        @test chart.functional_html != ""
    end

    @testset "Custom histogram bins" begin
        for bins in [10, 20, 50, 100]
            chart = DistPlot(Symbol("bins_$bins"), df_dist, :df_dist;
                value_cols = [:value],
                histogram_bins = bins
            )
            @test occursin(string(bins), chart.functional_html)
        end
    end

    @testset "Custom box opacity" begin
        for opacity in [0.3, 0.5, 0.8, 1.0]
            chart = DistPlot(Symbol("opacity_$(Int(opacity*10))"), df_dist, :df_dist;
                value_cols = [:value],
                box_opacity = opacity
            )
            @test occursin(string(opacity), chart.functional_html)
        end
    end

    @testset "With notes" begin
        notes = "This is a test distribution plot with detailed notes."
        chart = DistPlot(:with_notes, df_dist, :df_dist;
            value_cols = [:value],
            notes = notes
        )
        @test occursin(notes, chart.appearance_html)
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            df_test = DataFrame(
                value = randn(50),
                category = repeat(["X", "Y"], 25)
            )

            chart = DistPlot(:page_dist, df_test, :test_data;
                value_cols = [:value],
                color_cols = [:category],
                title = "Distribution Test"
            )

            page = JSPlotPage(Dict(:test_data => df_test), [chart])
            outfile = joinpath(tmpdir, "distplot_test.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Distribution Test", content)
            @test occursin("page_dist", content)
        end
    end

    @testset "Dependencies method" begin
        chart = DistPlot(:dep_test, df_dist, :my_data;
            value_cols = [:value]
        )
        deps = JSPlots.dependencies(chart)
        @test deps == [:my_data]
        @test length(deps) == 1
    end

    @testset "Empty data handling" begin
        df_empty = DataFrame(value = Float64[])
        chart = DistPlot(:empty_dist, df_empty, :df_empty;
            value_cols = [:value]
        )
        @test chart.chart_title == :empty_dist
    end

    @testset "Show controls parameter" begin
        df_test = DataFrame(
            value = randn(50),
            group = repeat(["A", "B"], 25)
        )

        # With controls
        chart_with = DistPlot(:with_controls, df_test, :df_test;
            value_cols = [:value],
            color_cols = [:group],
            show_controls = true
        )
        @test occursin("control", lowercase(chart_with.appearance_html)) ||
              occursin("select", lowercase(chart_with.appearance_html))

        # Without controls
        chart_without = DistPlot(:without_controls, df_test, :df_test;
            value_cols = [:value],
            color_cols = [:group],
            show_controls = false
        )
        @test chart_without.appearance_html != chart_with.appearance_html
    end

    @testset "Filter dropdowns - categorical" begin
        df_cat = DataFrame(
            value = randn(100),
            category = repeat(["Alpha", "Beta", "Gamma"], 34)[1:100]
        )
        chart = DistPlot(:filter_categorical, df_cat, :df_cat;
            value_cols = [:value],
            filters = [:category]
        )
        @test occursin("category", chart.appearance_html)
        @test occursin("Alpha", chart.appearance_html)
        @test occursin("Beta", chart.appearance_html)
        @test occursin("Gamma", chart.appearance_html)
    end

    @testset "All plots disabled" begin
        chart = DistPlot(:all_disabled, df_dist, :df_dist;
            value_cols = [:value],
            show_histogram = false,
            show_box = false,
            show_rug = false
        )
        @test chart.chart_title == :all_disabled
        @test chart.functional_html != ""
    end

    @testset "Single value and group column" begin
        df_single = DataFrame(
            value = randn(50),
            group = repeat(["X", "Y"], 25)
        )
        chart = DistPlot(:single_cols, df_single, :df_single;
            value_cols = [:value],
            color_cols = [:group]
        )
        @test occursin("value", chart.functional_html)
        @test occursin("group", chart.functional_html)
    end

    @testset "Large number of bins" begin
        chart = DistPlot(:large_bins, df_dist, :df_dist;
            value_cols = [:value],
            histogram_bins = 100
        )
        @test occursin("100", chart.functional_html)
    end

    @testset "Small number of bins" begin
        chart = DistPlot(:small_bins, df_dist, :df_dist;
            value_cols = [:value],
            histogram_bins = 5
        )
        @test occursin("5", chart.functional_html)
    end

    @testset "Zero opacity box plot" begin
        chart = DistPlot(:zero_opacity, df_dist, :df_dist;
            value_cols = [:value],
            box_opacity = 0.0
        )
        @test occursin("0.0", chart.functional_html)
    end

    @testset "Full opacity box plot" begin
        chart = DistPlot(:full_opacity, df_dist, :df_dist;
            value_cols = [:value],
            box_opacity = 1.0
        )
        @test occursin("1.0", chart.functional_html)
    end

    @testset "Multiple filters combined" begin
        df_multi_filter = DataFrame(
            value = randn(200),
            temperature = rand(200) .* 30 .+ 10,
            category = repeat(["A", "B", "C", "D"], 50),
            date = Date(2024, 1, 1):Day(1):Date(2024, 7, 18)
        )
        chart = DistPlot(:multi_filters, df_multi_filter, :df_multi_filter;
            value_cols = [:value],
            filters = [:temperature, :category, :date]
        )
        @test occursin("temperature", chart.appearance_html)
        @test occursin("category", chart.appearance_html)
        @test occursin("date", chart.appearance_html)
    end

    @testset "No filters, no groups" begin
        chart = DistPlot(:minimal, df_dist, :df_dist;
            value_cols = [:value]
        )
        @test chart.chart_title == :minimal
        @test occursin("value", chart.functional_html)
    end

    @testset "Empty title and notes" begin
        chart = DistPlot(:no_title, df_dist, :df_dist;
            value_cols = [:value],
            title = "",
            notes = ""
        )
        @test chart.appearance_html != ""
    end
end
