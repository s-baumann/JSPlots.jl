using Test
using JSPlots
using DataFrames
using Dates
using Random

@testset "JSPlots.jl" begin
    # Run each test file in order
    @testset "Miscellaneous Tests" begin
        include("chart_tests/test_misc.jl")
    end

    @testset "LineChart Tests" begin
        include("chart_tests/test_linechart.jl")
    end

    @testset "AreaChart Tests" begin
        include("chart_tests/test_areachart.jl")
    end

    @testset "Surface3D Tests" begin
        include("chart_tests/test_surface3d.jl")
    end

    @testset "Scatter3D Tests" begin
        include("chart_tests/test_scatter3d.jl")
    end

    @testset "ScatterSurface3D Tests" begin
        include("chart_tests/test_scattersurface3d.jl")
    end

    @testset "ScatterPlot Tests" begin
        include("chart_tests/test_scatterplot.jl")
    end

    @testset "DistPlot Tests" begin
        include("chart_tests/test_distplot.jl")
    end

    @testset "Path Tests" begin
        include("chart_tests/test_path.jl")
    end

    @testset "PieChart Tests" begin
        include("chart_tests/test_piechart.jl")
    end

    @testset "KernelDensity Tests" begin
        include("chart_tests/test_kerneldensity.jl")
    end

    @testset "PivotTable Tests" begin
        include("chart_tests/test_pivottable.jl")
    end

    @testset "TextBlock Tests" begin
        include("chart_tests/test_textblock.jl")
    end

    @testset "CodeBlock Tests" begin
        include("chart_tests/test_codeblock.jl")
    end

    @testset "Picture Tests" begin
        include("chart_tests/test_picture.jl")
    end

    @testset "Picture Integration Tests" begin
        include("chart_tests/test_picture_integrations.jl")
    end

    @testset "Slides Tests" begin
        include("chart_tests/test_slides.jl")
    end

    @testset "Waterfall Tests" begin
        include("chart_tests/test_waterfall.jl")
    end

    @testset "BoxAndWhiskers Tests" begin
        include("chart_tests/test_boxandwhiskers.jl")
    end

    @testset "SanKey Tests" begin
        include("chart_tests/test_sankey.jl")
    end

    @testset "CorrPlot Tests" begin
        include("chart_tests/test_corrplot.jl")
    end

    @testset "Graph Tests" begin
        include("chart_tests/test_graph.jl")
    end

    @testset "Table Tests" begin
        include("chart_tests/test_table.jl")
    end

    @testset "LinkList Tests" begin
        include("chart_tests/test_linklist.jl")
    end

    @testset "CandlestickChart Tests" begin
        include("chart_tests/test_candlestickchart.jl")
    end

    @testset "BumpChart Tests" begin
        include("chart_tests/test_bumpchart.jl")
    end

    @testset "TSNEPlot Tests" begin
        include("chart_tests/test_tsneplot.jl")
    end

    @testset "Pages Tests" begin
        include("chart_tests/test_pages.jl")
    end

    @testset "Data Formats and HTML Generation Tests" begin
        include("chart_tests/test_dataformats.jl")
    end
end
