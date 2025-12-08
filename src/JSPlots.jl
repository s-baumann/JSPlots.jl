module JSPlots

    using CSV, DataFrames, JSON, Dates, DuckDB, DBInterface, Base64, LinearAlgebra, TimeZones, Infiltrator

    abstract type JSPlotsType end

    include("pivottables.jl")
    export PivotTable

    include("linechart.jl")
    export LineChart

    include("surface3d.jl")
    export Surface3D

    include("scatter3d.jl")
    export Scatter3D

    include("scatterplot.jl")
    export ScatterPlot

    include("distplot.jl")
    export DistPlot

    include("kerneldensity.jl")
    export KernelDensity

    include("textblock.jl")
    export TextBlock

    include("picture.jl")
    export Picture

    include("table.jl")
    export Table

    include("make_html.jl")
    export JSPlotPage, Pages, LinkList, create_html

end # module JSPlots
