module JSPlots

    using CSV, DataFrames, JSON, Dates, DuckDB, DBInterface, Base64, LinearAlgebra, TimeZones, Infiltrator, VegaLite, Statistics

    abstract type JSPlotsType end

    # Helper function to sanitize chart titles for use in JavaScript function names
    # Replaces spaces and other problematic characters with underscores
    function sanitize_chart_title(title::Symbol)
        str = string(title)
        # Replace spaces, hyphens, and other special chars with underscores
        sanitized = replace(str, r"[\s\-\.:]" => "_")
        return Symbol(sanitized)
    end

    export sanitize_chart_title

    include("pivottables.jl")
    export PivotTable

    include("linechart.jl")
    export LineChart

    include("areachart.jl")
    export AreaChart

    include("surface3d.jl")
    export Surface3D

    include("scatter3d.jl")
    export Scatter3D

    include("scattersurface3d.jl")
    export ScatterSurface3D

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

    include("slides.jl")
    export Slides

    include("table.jl")
    export Table

    include("LinkList.jl")
    export LinkList

    include("Pages.jl")
    export JSPlotPage, Pages, sanitize_filename

    include("make_html.jl")
    export create_html

end # module JSPlots
