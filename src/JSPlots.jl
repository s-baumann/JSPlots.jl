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

    # Default color palette used across multiple chart types
    const DEFAULT_COLOR_PALETTE = ["#636efa", "#EF553B", "#00cc96", "#ab63fa", "#FFA15A",
                                    "#19d3f3", "#FF6692", "#B6E880", "#FF97FF", "#FECB52"]

    """
        normalize_to_symbol_vector(input::Union{Nothing, Symbol, Vector{Symbol}})

    Normalize input to a vector of Symbols. Handles Nothing, single Symbol, or Vector{Symbol}.

    # Examples
    ```julia
    normalize_to_symbol_vector(nothing) # Returns Symbol[]
    normalize_to_symbol_vector(:col)    # Returns [:col]
    normalize_to_symbol_vector([:a, :b]) # Returns [:a, :b]
    ```
    """
    function normalize_to_symbol_vector(input::Union{Nothing, Symbol, Vector{Symbol}})
        if input === nothing
            return Symbol[]
        elseif input isa Symbol
            return [input]
        else
            return input
        end
    end

    """
        validate_column(df::DataFrame, col::Symbol, col_type::String="Column")

    Validate that a column exists in a DataFrame. Throws descriptive error if not found.
    """
    function validate_column(df::DataFrame, col::Symbol, col_type::String="Column")
        all_cols = names(df)
        if !(String(col) in all_cols)
            error("$col_type $col not found in dataframe. Available: $all_cols")
        end
        return true
    end

    """
        validate_columns(df::DataFrame, cols::Vector{Symbol}, col_type::String="Column")

    Validate that multiple columns exist in a DataFrame. Throws descriptive error if any not found.
    """
    function validate_columns(df::DataFrame, cols::Vector{Symbol}, col_type::String="Column")
        all_cols = names(df)
        for col in cols
            if !(String(col) in all_cols)
                error("$col_type $col not found in dataframe. Available: $all_cols")
            end
        end
        return true
    end

    """
        normalize_and_validate_facets(facet_cols::Union{Nothing, Symbol, Vector{Symbol}},
                                      default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}})

    Normalize and validate facet configuration. Returns (facet_choices, default_facet_array).

    # Validation Rules
    - At most 2 default facets allowed
    - Default facets must be subset of available facet choices
    """
    function normalize_and_validate_facets(facet_cols::Union{Nothing, Symbol, Vector{Symbol}},
                                           default_facet_cols::Union{Nothing, Symbol, Vector{Symbol}})
        # Normalize to vectors
        facet_choices = normalize_to_symbol_vector(facet_cols)
        default_facet_array = normalize_to_symbol_vector(default_facet_cols)

        # Validate default facets
        if length(default_facet_array) > 2
            error("default_facet_cols can have at most 2 columns")
        end

        for col in default_facet_array
            if !(col in facet_choices)
                error("default_facet_cols must be a subset of facet_cols")
            end
        end

        return (facet_choices, default_facet_array)
    end

    export DEFAULT_COLOR_PALETTE, normalize_to_symbol_vector, validate_column, validate_columns, normalize_and_validate_facets

    include("html_controls.jl")

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

    include("path.jl")
    export Path

    include("piechart.jl")
    export PieChart

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
