module JSPlots

    using CSV, DataFrames, JSON, Dates, DuckDB, DBInterface, Base64, LinearAlgebra, TimeZones, Infiltrator, VegaLite, Statistics, OrderedCollections, Clustering, Distances, StatsBase, CategoricalArrays

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

    """
        validate_and_filter_columns(cols::Vector{Symbol}, df::DataFrame, col_name::String)

    Validate that at least one column from cols exists in the DataFrame.
    Returns filtered list of valid columns that exist in df.
    Throws error if none of the specified columns exist.

    # Arguments
    - `cols::Vector{Symbol}`: Columns to validate
    - `df::DataFrame`: DataFrame to check against
    - `col_name::String`: Name of column type for error messages (e.g., "x_cols", "y_cols")

    # Examples
    ```julia
    valid_x = validate_and_filter_columns([:a, :b, :c], df, "x_cols")
    # Returns only columns that exist in df, errors if none exist
    ```
    """
    function validate_and_filter_columns(cols::Vector{Symbol}, df::DataFrame, col_name::String)
        available_cols = Set(names(df))
        valid_cols = [col for col in cols if string(col) in available_cols]
        if isempty(valid_cols)
            error("None of the specified $col_name exist in the dataframe. Available columns: $(names(df))")
        end
        return valid_cols
    end

    """
        build_color_maps(cols::Vector{Symbol}, df::DataFrame, palette=DEFAULT_COLOR_PALETTE)

    Build color maps for categorical columns, mapping unique values to colors from a palette.
    Returns (color_maps, valid_cols) where color_maps is a Dict{String, Dict{String, String}}.

    # Arguments
    - `cols::Vector{Symbol}`: Columns to build color maps for
    - `df::DataFrame`: DataFrame containing the columns
    - `palette`: Vector of color hex codes (default: DEFAULT_COLOR_PALETTE)

    # Returns
    - `color_maps`: Dict mapping column name to Dict of value->color mappings
    - `valid_cols`: Vector of column names that existed in df

    # Examples
    ```julia
    color_maps, valid_cols = build_color_maps([:species, :region], df)
    # color_maps["species"]["setosa"] => "#636efa"
    ```
    """
    function build_color_maps(cols::Vector{Symbol}, df::DataFrame, palette=DEFAULT_COLOR_PALETTE)
        available_cols = Set(names(df))
        color_maps = Dict()
        valid_cols = Symbol[]

        for col in cols
            if string(col) in available_cols
                push!(valid_cols, col)
                unique_vals = unique(df[!, col])
                color_maps[string(col)] = Dict(
                    string(key) => palette[(i - 1) % length(palette) + 1]
                    for (i, key) in enumerate(unique_vals)
                )
            end
        end

        return color_maps, valid_cols
    end

    """
        normalize_filters(filters::Union{Vector{Symbol}, Dict}, df::DataFrame)

    Normalize filter specification to a standard Dict{Symbol, Any} format where values are Vectors.

    # Arguments
    - `filters`: Either a Vector{Symbol} of column names or Dict with default values
    - `df::DataFrame`: DataFrame to extract unique values from

    # Behavior
    - `Vector{Symbol}`: Expands to Dict where each column maps to all its unique values
    - `Dict`: Normalizes values to vectors (wraps non-vector values)

    # Examples
    ```julia
    # Vector input - all unique values selected by default
    normalize_filters([:country, :region], df)
    # Returns: Dict(:country => unique(df.country), :region => unique(df.region))

    # Dict with array values - keeps as-is
    normalize_filters(Dict(:country => [:Australia, :Bangladesh]), df)
    # Returns: Dict(:country => [:Australia, :Bangladesh])

    # Dict with single value - wraps in array
    normalize_filters(Dict(:country => :Australia), df)
    # Returns: Dict(:country => [:Australia])
    ```
    """
    function normalize_filters(filters::Vector{Symbol}, df::DataFrame)::Dict{Symbol, Any}
        result = Dict{Symbol, Any}()
        for col in filters
            if string(col) in names(df)
                result[col] = collect(unique(skipmissing(df[!, col])))
            else
                @warn "Filter column $col not found in dataframe, skipping"
            end
        end
        return result
    end

    function normalize_filters(filters::Dict, df::DataFrame)::Dict{Symbol, Any}
        result = Dict{Symbol, Any}()
        for (col, default_val) in filters
            col_sym = col isa Symbol ? col : Symbol(col)
            if !(string(col_sym) in names(df))
                @warn "Filter column $col_sym not found in dataframe, skipping"
                continue
            end

            # Normalize default_val to a vector
            if default_val isa AbstractVector
                # Already a vector, use as-is
                result[col_sym] = collect(default_val)
            elseif isnothing(default_val)
                # Nothing means all values
                result[col_sym] = collect(unique(skipmissing(df[!, col_sym])))
            else
                # Single value, wrap in array
                result[col_sym] = [default_val]
            end
        end
        return result
    end

    """
        build_filter_options(filters::Dict{Symbol,Any}, df::DataFrame)

    Build a dictionary of unique values for each filter column.
    Returns Dict{String, Vector} mapping column names to their unique values.

    # Arguments
    - `filters::Dict{Symbol,Any}`: Dictionary of normalized filter configurations
    - `df::DataFrame`: DataFrame to extract unique values from

    # Examples
    ```julia
    normalized = normalize_filters([:region, :year], df)
    filter_options = build_filter_options(normalized, df)
    # Returns: Dict("region" => ["North", "South"], "year" => [2020, 2021, 2022])
    ```
    """
    function build_filter_options(filters::Dict{Symbol,Any}, df::DataFrame)
        return Dict(string(col) => unique(df[!, col]) for col in keys(filters))
    end

    """
        is_continuous_column(df::DataFrame, col::Symbol)

    Determine if a column should be treated as continuous (numeric or date/time type).

    All numeric types (Int, Float, etc.) and date/time types are treated as continuous
    and will use range sliders in the UI. This avoids type conversion issues between
    numeric values and string-based categorical filters.

    # Arguments
    - `df::DataFrame`: DataFrame containing the column
    - `col::Symbol`: Column to check

    # Returns
    - `Bool`: true if column is numeric or date/time type, false otherwise

    # Examples
    ```julia
    is_continuous_column(df, :age)        # true if numeric
    is_continuous_column(df, :year)       # true if numeric (even with few unique values)
    is_continuous_column(df, :date)       # true if date/time type
    is_continuous_column(df, :category)   # false if string
    ```
    """
    function is_continuous_column(df::DataFrame, col::Symbol)
        col_str = string(col)
        if !(col_str in names(df))
            return false
        end

        col_type = eltype(df[!, col])
        # Check if numeric or date type
        is_numeric = col_type <: Number || col_type <: Union{Missing, <:Number}
        is_date = col_type <: Dates.TimeType || col_type <: Union{Missing, <:Dates.TimeType}

        # All numeric and date/time types are treated as continuous
        # This avoids type conversion issues with categorical filters
        return is_numeric || is_date
    end

    """
        build_js_array(cols::Vector)

    Convert a Julia vector to a JavaScript array string representation.
    Returns a string like "['col1', 'col2', 'col3']".

    # Arguments
    - `cols::Vector`: Vector of items to convert (typically Symbols or Strings)

    # Examples
    ```julia
    build_js_array([:a, :b, :c])  # Returns: "['a', 'b', 'c']"
    build_js_array(["x", "y"])    # Returns: "['x', 'y']"
    ```
    """
    function build_js_array(cols::Vector)
        return "[" * join(["'$col'" for col in cols], ", ") * "]"
    end

    """
        select_default_column(cols::Vector{Symbol}, placeholder::String="__none__")

    Select the first column as default, or return placeholder if vector is empty.

    # Arguments
    - `cols::Vector{Symbol}`: Columns to select from
    - `placeholder::String`: Value to return if cols is empty (default: "__none__")

    # Examples
    ```julia
    select_default_column([:a, :b, :c])           # Returns: "a"
    select_default_column(Symbol[], "__no_color__")  # Returns: "__no_color__"
    ```
    """
    function select_default_column(cols::Vector{Symbol}, placeholder::String="__none__")
        return isempty(cols) ? placeholder : string(cols[1])
    end

    export DEFAULT_COLOR_PALETTE, normalize_to_symbol_vector, validate_column, validate_columns, normalize_and_validate_facets
    export validate_and_filter_columns, build_color_maps, normalize_filters, build_filter_options, build_js_array, select_default_column, is_continuous_column

    get_filter_vars(filters::Vector{Symbol}) = filters
    get_filter_vars(filters::Dict) = Symbol.(keys(filters))

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

    include("codeblock.jl")
    export CodeBlock, execute_codeblock

    include("picture.jl")
    export Picture

    include("slides.jl")
    export Slides

    include("waterfall.jl")
    export Waterfall

    include("boxandwhiskers.jl")
    export BoxAndWhiskers

    include("sankey.jl")
    export SanKey

    include("corrplot.jl")
    include("corrplot_advanced.jl")
    export CorrPlot, CorrelationScenario, compute_correlations, cluster_from_correlation

    include("table.jl")
    export Table

    include("LinkList.jl")
    export LinkList

    include("Pages.jl")
    export JSPlotPage, Pages, sanitize_filename

    include("make_html.jl")
    export create_html

end # module JSPlots
