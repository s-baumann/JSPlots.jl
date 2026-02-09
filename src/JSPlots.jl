module JSPlots

    using CSV, DataFrames, JSON, Dates, DuckDB, DBInterface, Base64, LinearAlgebra, TimeZones, Infiltrator, VegaLite, Statistics, OrderedCollections, Clustering, Distances, StatsBase, CategoricalArrays

    abstract type JSPlotsType end

    # =============================================================================
    # JavaScript Dependency Constants
    # =============================================================================
    # These constants define the external JavaScript libraries used by different chart types.
    # Each chart type declares its dependencies via js_dependencies(), and make_html.jl
    # collects the union of all dependencies for a page.

    # Core dependencies - jQuery for DOM manipulation and filters
    const JS_DEP_JQUERY = [
        """<link rel="stylesheet" href="https://code.jquery.com/ui/1.13.2/themes/base/jquery-ui.css">""",
        """<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>""",
        """<script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>""",
    ]

    # CSV parsing for data loading (PapaParse)
    const JS_DEP_CSV = [
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/PapaParse/5.3.0/papaparse.min.js"></script>""",
    ]

    # Plotly.js for most 2D and 3D charts
    const JS_DEP_PLOTLY = [
        """<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>""",
    ]

    # D3.js v3 for TSNEPlot, RadarChart
    const JS_DEP_D3 = [
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.5/d3.min.js"></script>""",
    ]

    # C3.js (requires D3) - used by PivotTable
    const JS_DEP_C3 = [
        """<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/c3/0.4.11/c3.min.css">""",
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/c3/0.4.11/c3.min.js"></script>""",
    ]

    # PivotTable.js (requires D3 and C3)
    const JS_DEP_PIVOTTABLE = [
        """<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/pivot.min.css">""",
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/pivot.min.js"></script>""",
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/d3_renderers.min.js"></script>""",
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/c3_renderers.min.js"></script>""",
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/pivottable/2.19.0/export_renderers.min.js"></script>""",
    ]

    # Cytoscape.js for Graph visualization
    const JS_DEP_CYTOSCAPE = [
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.28.1/cytoscape.min.js"></script>""",
    ]

    # Prism.js for code syntax highlighting (base - languages added separately)
    const JS_DEP_PRISM = [
        """<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css">""",
        """<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>""",
    ]

    # Leaflet.js for geographic maps
    const JS_DEP_LEAFLET = [
        """<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="">""",
        """<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>""",
        """<script src="https://unpkg.com/topojson-client@3"></script>""",
    ]

    # Parquet-wasm for Parquet data format (requires Arrow, loaded as ES module in body)
    const JS_DEP_PARQUET = [
        """<script src="https://cdn.jsdelivr.net/npm/apache-arrow@14.0.1/Arrow.es2015.min.js"></script>""",
        """<script type="module">
import * as parquet from 'https://unpkg.com/parquet-wasm@0.6.1/esm/parquet_wasm.js';
await parquet.default();
window.parquetWasm = parquet;
window.parquetReady = true;
console.log('Parquet-wasm library loaded successfully');
</script>""",
    ]

    # Export dependency constants for use by chart types
    export JS_DEP_JQUERY, JS_DEP_CSV, JS_DEP_PLOTLY, JS_DEP_D3, JS_DEP_C3
    export JS_DEP_PIVOTTABLE, JS_DEP_CYTOSCAPE, JS_DEP_PRISM, JS_DEP_LEAFLET, JS_DEP_PARQUET

    """
        js_dependencies(plot::JSPlotsType)

    Returns a vector of HTML script/link tags for JavaScript dependencies required by this plot type.
    Default implementation returns an empty vector. Plot types with special dependencies should override this.

    Charts should use the JS_DEP_* constants to declare their chart-specific dependencies, e.g.:
    ```julia
    js_dependencies(::LineChart) = vcat(JS_DEP_JQUERY, JS_DEP_PLOTLY)
    js_dependencies(::GeoPlot) = vcat(JS_DEP_JQUERY, JS_DEP_LEAFLET)
    ```

    Note: Data format dependencies (PapaParse for CSV, Arrow for Parquet) are added automatically
    based on the page's dataformat setting, not from chart dependencies.

    The make_html.jl module collects dependencies from all charts on a page and includes
    only the unique union, so duplication in declarations is handled automatically.
    """
    js_dependencies(::JSPlotsType) = String[]

    export js_dependencies

    # Helper function to sanitize chart titles for use in JavaScript function names
    # Replaces spaces and other problematic characters with underscores
    function sanitize_chart_title(title::Symbol)
        str = string(title)
        # Replace spaces, hyphens, and other special chars with underscores
        sanitized = replace(str, r"[\s\-\.:]" => "_")
        return Symbol(sanitized)
    end

    export sanitize_chart_title

    """
        sanitize_html_id(label::Union{Symbol, String}; prefix::String="")

    Sanitize a label for use as an HTML element ID.

    HTML IDs cannot contain spaces and should avoid special characters.
    This function replaces problematic characters with underscores and
    optionally adds a prefix.

    # Arguments
    - `label`: The label to sanitize (Symbol or String)
    - `prefix`: Optional prefix to add (e.g., "data_" for data elements)

    # Returns
    - `String`: A valid HTML ID string

    # Examples
    ```julia
    sanitize_html_id(:my_chart)           # => "my_chart"
    sanitize_html_id(Symbol("My Chart"))  # => "My_Chart"
    sanitize_html_id(:sales, prefix="data_")  # => "data_sales"
    ```
    """
    function sanitize_html_id(label::Union{Symbol, String}; prefix::String="")
        str = string(label)
        # Replace spaces, hyphens, dots, colons, and other special chars with underscores
        sanitized = replace(str, r"[\s\-\.:/\\]" => "_")
        return prefix * sanitized
    end

    export sanitize_html_id

    # Valid data format options for JSPlotPage and Pages
    const VALID_DATAFORMATS = (:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet)

    function validate_dataformat(dataformat::Symbol)
        if !(dataformat in VALID_DATAFORMATS)
            error("dataformat must be one of $VALID_DATAFORMATS, got :$dataformat")
        end
    end

    """
        html_escape(s::AbstractString)

    Escape HTML special characters in a string.
    """
    function html_escape(s::AbstractString)
        s = replace(s, "&" => "&amp;")
        s = replace(s, "<" => "&lt;")
        s = replace(s, ">" => "&gt;")
        s = replace(s, "\"" => "&quot;")
        s = replace(s, "'" => "&#39;")
        return s
    end

    export html_escape

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

    # Type alias for color column specification with optional custom color maps
    # Can be either:
    # - Vector{Symbol}: [:col1, :col2] - uses default palette for all (categorical)
    # - Vector of tuples: [(:col1, :default), (:col2, Dict(:val1 => "#hex1"))] - categorical with custom
    # - Vector of tuples with numeric keys: [(:col1, Dict(0 => "#000", 1 => "#fff"))] - continuous interpolation
    const ColorColSpec = Union{
        Vector{Symbol},
        Vector{<:Tuple{Symbol, Any}}
    }

    """
        normalize_color_cols(color_cols::ColorColSpec)

    Normalize color column specification to a standard Vector of (column, colormap_spec) tuples.

    # Input formats
    - `Vector{Symbol}`: [:col1, :col2] → [(:col1, :default), (:col2, :default)]
    - `Vector{Tuple}`: [(:col1, :default), (:col2, Dict(...))] → unchanged

    # Examples
    ```julia
    normalize_color_cols([:species, :region])
    # Returns: [(:species, :default), (:region, :default)]

    normalize_color_cols([(:species, :default), (:region, Dict("US" => "#ff0000"))])
    # Returns: [(:species, :default), (:region, Dict("US" => "#ff0000"))]
    ```
    """
    function normalize_color_cols(color_cols::Vector{Symbol})
        return [(col, :default) for col in color_cols]
    end

    function normalize_color_cols(color_cols::Vector{<:Tuple{Symbol, Any}})
        return color_cols
    end

    """
        extract_color_col_names(color_cols::ColorColSpec)

    Extract just the column names from a ColorColSpec, returning a Vector{Symbol}.
    Useful for validating columns exist in a DataFrame.
    """
    function extract_color_col_names(color_cols::Vector{Symbol})
        return color_cols
    end

    function extract_color_col_names(color_cols::Vector{<:Tuple{Symbol, Any}})
        return [col for (col, _) in color_cols]
    end

    """
        is_continuous_color_spec(color_spec::Dict)

    Check if a color specification Dict represents a continuous color scale (numeric keys).
    Returns true if all keys are numeric (Int, Float64, etc.).
    """
    function is_continuous_color_spec(color_spec::Dict)
        isempty(color_spec) && return false
        all(k -> k isa Number, keys(color_spec))
    end

    is_continuous_color_spec(::Any) = false

    """
        build_color_maps(cols::Vector{Symbol}, df::DataFrame, palette=DEFAULT_COLOR_PALETTE)

    Thin wrapper around `build_color_maps_extended` for backward compatibility.
    Returns (color_maps, valid_cols) — ignores continuous color scales.
    """
    function build_color_maps(cols::Vector{Symbol}, df::DataFrame, palette=DEFAULT_COLOR_PALETTE)
        color_maps, _, valid_cols = build_color_maps_extended(cols, df, palette)
        return color_maps, valid_cols
    end

    """
        build_color_maps_extended(color_cols::ColorColSpec, df::DataFrame, palette=DEFAULT_COLOR_PALETTE)

    Build color maps for columns with support for custom color mappings and continuous color scales.

    # Arguments
    - `color_cols`: Color column specification - either Vector{Symbol} or Vector of (col, spec) tuples
      where spec is either:
      - `:default` - use default palette (categorical)
      - `Dict{String/Symbol => color}` - categorical with custom colors
      - `Dict{Number => color}` - continuous with interpolation between color stops
    - `df::DataFrame`: DataFrame containing the columns
    - `palette`: Vector of color hex codes for :default columns (default: DEFAULT_COLOR_PALETTE)

    # Returns
    - `color_maps`: Dict for categorical columns (column name => value => color)
    - `color_scales`: Dict for continuous columns (column name => sorted list of {value, color} stops)
    - `valid_cols`: Vector of column names that existed in df

    # Examples
    ```julia
    # Using default palette (categorical)
    color_maps, color_scales, valid_cols = build_color_maps_extended([:species, :region], df)

    # With custom categorical colors
    color_maps, color_scales, valid_cols = build_color_maps_extended([
        (:species, :default),
        (:region, Dict(:US => "#ff0000", :EU => "#00ff00"))
    ], df)

    # With continuous color scale (interpolates between stops)
    color_maps, color_scales, valid_cols = build_color_maps_extended([
        (:temperature, Dict(0 => "#0000ff", 50 => "#ffffff", 100 => "#ff0000"))
    ], df)
    ```
    """
    function build_color_maps_extended(color_cols::ColorColSpec, df::DataFrame, palette=DEFAULT_COLOR_PALETTE)
        normalized = normalize_color_cols(color_cols)
        available_cols = Set(names(df))
        color_maps = Dict{String, Dict{String, String}}()
        color_scales = Dict{String, Vector{Dict{String, Any}}}()
        valid_cols = Symbol[]

        for (col, color_spec) in normalized
            if string(col) in available_cols
                push!(valid_cols, col)
                unique_vals = unique(df[!, col])

                if color_spec === :default
                    # Use default palette (categorical)
                    color_maps[string(col)] = Dict{String, String}(
                        string(key) => palette[(i - 1) % length(palette) + 1]
                        for (i, key) in enumerate(unique_vals)
                    )
                elseif is_continuous_color_spec(color_spec)
                    # Continuous color scale - store sorted stops for interpolation
                    stops = sort(collect(color_spec), by=x->x[1])
                    color_scales[string(col)] = [
                        Dict{String, Any}("value" => Float64(k), "color" => string(v))
                        for (k, v) in stops
                    ]
                else
                    # Categorical with custom color mapping, with fallback to palette for unmapped values
                    custom_map = Dict{String, String}()
                    palette_idx = 1
                    for val in unique_vals
                        val_str = string(val)
                        # Check for matching key in custom mapping (try both symbol and original type)
                        if haskey(color_spec, val)
                            custom_map[val_str] = string(color_spec[val])
                        elseif haskey(color_spec, Symbol(val_str))
                            custom_map[val_str] = string(color_spec[Symbol(val_str)])
                        elseif haskey(color_spec, val_str)
                            custom_map[val_str] = string(color_spec[val_str])
                        else
                            # Fallback to palette for unmapped values
                            custom_map[val_str] = palette[(palette_idx - 1) % length(palette) + 1]
                            palette_idx += 1
                        end
                    end
                    color_maps[string(col)] = custom_map
                end
            end
        end

        return color_maps, color_scales, valid_cols
    end

    """
        build_color_scales_js(color_scales::Dict{String, Vector{Dict{String, Any}}})

    Build JavaScript object string for continuous color scales.
    """
    function build_color_scales_js(color_scales::Dict{String, Vector{Dict{String, Any}}})
        if isempty(color_scales)
            return "{}"
        end
        entries = String[]
        for (col, stops) in color_scales
            stops_js = "[" * join([
                "{value: $(s["value"]), color: '$(s["color"])'}"
                for s in stops
            ], ", ") * "]"
            push!(entries, "'$col': $stops_js")
        end
        return "{" * join(entries, ", ") * "}"
    end

    # JavaScript helper function for color interpolation (to be included in charts that need it)
    const JS_COLOR_INTERPOLATION = """
    // Interpolate color for continuous color scales
    function interpolateColor(stops, value) {
        if (!stops || stops.length === 0) return '#000000';
        if (stops.length === 1) return stops[0].color;

        // Clamp to range
        if (value <= stops[0].value) return stops[0].color;
        if (value >= stops[stops.length - 1].value) return stops[stops.length - 1].color;

        // Find surrounding stops
        for (let i = 0; i < stops.length - 1; i++) {
            if (value >= stops[i].value && value <= stops[i + 1].value) {
                const t = (value - stops[i].value) / (stops[i + 1].value - stops[i].value);
                return lerpColor(stops[i].color, stops[i + 1].color, t);
            }
        }
        return stops[stops.length - 1].color;
    }

    // Linear interpolation between two hex colors
    function lerpColor(color1, color2, t) {
        const c1 = hexToRgb(color1);
        const c2 = hexToRgb(color2);
        if (!c1 || !c2) return color1;

        const r = Math.round(c1.r + (c2.r - c1.r) * t);
        const g = Math.round(c1.g + (c2.g - c1.g) * t);
        const b = Math.round(c1.b + (c2.b - c1.b) * t);

        return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
    }

    // Convert hex color to RGB object
    function hexToRgb(hex) {
        const result = /^#?([a-f\\d]{2})([a-f\\d]{2})([a-f\\d]{2})\$/i.exec(hex);
        return result ? {
            r: parseInt(result[1], 16),
            g: parseInt(result[2], 16),
            b: parseInt(result[3], 16)
        } : null;
    }

    // Get color for a value, handling both categorical and continuous
    function getColor(colorMaps, colorScales, colorCol, value) {
        // Check categorical first
        if (colorMaps[colorCol] && colorMaps[colorCol][String(value)] !== undefined) {
            return colorMaps[colorCol][String(value)];
        }
        // Check continuous
        if (colorScales[colorCol]) {
            const numVal = parseFloat(value);
            if (!isNaN(numVal)) {
                return interpolateColor(colorScales[colorCol], numVal);
            }
        }
        // Fallback
        return '#000000';
    }
    """

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
        normalize_choices(choices, df::DataFrame)

    Normalize choice specification to a standard Dict{Symbol, Any} format where values are single defaults.

    Choices are like filters but only allow selecting ONE value at a time. This is useful for
    parameters where the user must choose exactly one option (e.g., selecting a single strategy).

    # Arguments
    - `choices`: Can be:
      - `Vector{Symbol}`: Column names - uses first unique value from each column as default
      - `Dict`: Column => default value mapping
    - `df::DataFrame`: DataFrame to validate columns and get first value if needed

    # Behavior
    - Vector input: `[:strategy, :region]` becomes `Dict(:strategy => first_val, :region => first_val)`
    - Dict values can be: Symbol, String, Number, or any single value
    - If Dict value is `nothing`, uses the first unique value from the column

    # Examples
    ```julia
    # Shorthand - uses first unique value from each column
    normalize_choices([:strategy, :region], df)
    # Returns: Dict(:strategy => first(unique(df.strategy)), :region => first(unique(df.region)))

    # With explicit default
    normalize_choices(Dict(:strategy => :momentum), df)
    # Returns: Dict(:strategy => :momentum)

    # With nothing - uses first unique value
    normalize_choices(Dict(:strategy => nothing), df)
    # Returns: Dict(:strategy => <first unique value in df.strategy>)
    ```
    """
    function normalize_choices(choices::Vector{Symbol}, df::DataFrame)::Dict{Symbol, Any}
        # Convert Vector{Symbol} to Dict with nothing values, then normalize
        return normalize_choices(Dict{Symbol, Any}(col => nothing for col in choices), df)
    end

    function normalize_choices(choices::Dict, df::DataFrame)::Dict{Symbol, Any}
        result = Dict{Symbol, Any}()
        for (col, default_val) in choices
            col_sym = col isa Symbol ? col : Symbol(col)
            if !(string(col_sym) in names(df))
                @warn "Choice column $col_sym not found in dataframe, skipping"
                continue
            end

            # Get unique values for this column
            unique_vals = collect(unique(skipmissing(df[!, col_sym])))

            if isnothing(default_val)
                # Nothing means use first value
                if !isempty(unique_vals)
                    result[col_sym] = first(unique_vals)
                end
            else
                # Use the provided default value
                result[col_sym] = default_val
            end
        end
        return result
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
    export validate_and_filter_columns, build_color_maps, normalize_filters, normalize_choices, build_filter_options, build_js_array, select_default_column, is_continuous_column
    export ColorColSpec, normalize_color_cols, extract_color_col_names, build_color_maps_extended, build_color_scales_js, JS_COLOR_INTERPOLATION, is_continuous_color_spec

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

    include("notes.jl")
    export Notes

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
    export CorrPlot, compute_correlations, prepare_corrplot_data

    include("graph.jl")
    export Graph

    include("radarchart.jl")
    export RadarChart

    include("table.jl")
    export Table

    include("LinkList.jl")
    export LinkList

    include("candlestickchart.jl")
    export CandlestickChart

    include("cumplot.jl")
    export CumPlot

    include("drawdownplot.jl")
    export DrawdownPlot


    include("localgaussiancorrelationplot.jl")
    export LocalGaussianCorrelationPlot

    include("bumpchart.jl")
    export BumpChart

    include("tsneplot.jl")
    export TSNEPlot

    include("executionplot.jl")
    export ExecutionPlot, prepare_execution_data, get_execution_data_dict

    include("geoplot.jl")
    export GeoPlot, list_region_types

    include("Pages.jl")
    export JSPlotPage, Pages, sanitize_filename, extract_dataframes_from_struct, is_struct_with_dataframes

    include("reportindex.jl")
    export ReportIndex, ManifestEntry, add_to_manifest, get_manifest_columns, MANIFEST_REQUIRED_COLS

    include("make_html.jl")
    export create_html

end # module JSPlots
