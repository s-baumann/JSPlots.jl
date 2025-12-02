module JSPlots


    using CSV, DataFrames, JSON, Dates, DuckDB, DBInterface

    abstract type JSPlotsType end

    include("tables.jl")
    export PivotTable

    include("linechart.jl")
    export LineChart

    include("threedchart.jl")
    export Chart3d

    include("scatterplot.jl")
    export ScatterPlot

    include("distplot.jl")
    export DistPlot

    include("textblock.jl")
    export TextBlock

    include("make_html.jl")
    export JSPlotPage, create_html

end # module JSPlots
