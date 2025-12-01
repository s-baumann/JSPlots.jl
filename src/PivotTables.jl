module PivotTables


    using CSV, DataFrames, JSON, Dates
    
    abstract type PivotTablesType end

    include("tables.jl")
    export PivotTable
    
    include("linechart.jl")
    export PChart

    include("threedchart.jl")
    export PThreeDChart

    include("PScatterPlot.jl")
    export PScatterPlot

    include("make_html.jl")
    export PivotTablePage, create_html

end # module PivotTables
