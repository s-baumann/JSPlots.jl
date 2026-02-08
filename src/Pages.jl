"""
    extract_dataframes_from_struct(obj, label::Symbol) -> Dict{Symbol, DataFrame}

Extract all DataFrame fields from a struct, handling Union{Missing, DataFrame} types.
Returns a dictionary mapping `label.fieldname` to the DataFrame.

Uses `.` as separator since Julia doesn't allow dots in identifiers, ensuring unique splitting.

This enables generic support for structs containing multiple DataFrames
without hardcoding specific struct types.

# Arguments
- `obj`: Any struct that may contain DataFrame fields
- `label::Symbol`: The label prefix to use for the extracted DataFrames

# Returns
- `Dict{Symbol, DataFrame}`: Dictionary mapping `Symbol("label.fieldname")` to DataFrame

# Example
```julia
struct MyData
    prices::DataFrame
    volumes::Union{Missing, DataFrame}
    name::String  # Non-DataFrame fields are ignored
end

data = MyData(prices_df, volumes_df, "test")
result = extract_dataframes_from_struct(data, :my_data)
# Returns Dict(Symbol("my_data.prices") => prices_df, Symbol("my_data.volumes") => volumes_df)
```
"""
function extract_dataframes_from_struct(obj, label::Symbol)::Dict{Symbol, DataFrame}
    result = Dict{Symbol, DataFrame}()

    # Get all field names for this struct type
    T = typeof(obj)
    field_names = fieldnames(T)

    for field_name in field_names
        field_value = getfield(obj, field_name)
        field_type = fieldtype(T, field_name)

        # Check if this field is a DataFrame or Union{Missing, DataFrame}
        is_df_field = field_type <: DataFrame ||
                      (field_type isa Union && DataFrame in Base.uniontypes(field_type))

        if is_df_field && !ismissing(field_value) && field_value isa DataFrame
            # Only include if it has rows
            if nrow(field_value) > 0
                # Use . as separator - Julia doesn't allow dots in identifiers so this is unique
                result[Symbol(string(label, ".", field_name))] = field_value
            end
        end
    end

    return result
end

"""
    is_struct_with_dataframes(obj) -> Bool

Check if an object is a struct that contains DataFrame fields.
Returns true if the object has at least one field of type DataFrame or Union{Missing, DataFrame}.
"""
function is_struct_with_dataframes(obj)::Bool
    T = typeof(obj)

    # Skip basic types and DataFrames themselves
    if obj isa DataFrame || obj isa AbstractDict || obj isa AbstractArray ||
       obj isa Number || obj isa AbstractString || obj isa Symbol
        return false
    end

    # Check if it's a concrete type with fields
    if !isconcretetype(T)
        return false
    end

    # Check if any field is a DataFrame type
    for field_name in fieldnames(T)
        field_type = fieldtype(T, field_name)
        if field_type <: DataFrame ||
           (field_type isa Union && DataFrame in Base.uniontypes(field_type))
            return true
        end
    end

    return false
end

"""
    sanitize_filename(title::String)

Convert a page title to a safe filename suitable for HTML files.

This function is used internally by the Pages constructor to generate filenames from page titles.
If you're manually creating a LinkList for a Pages coverpage, you should use this function
to ensure the link URLs match the actual filenames that will be generated.

# Arguments
- `title::String`: The page title (typically from `JSPlotPage.tab_title`)

# Returns
- `String`: A sanitized filename (lowercase, alphanumeric + underscores, max 50 chars)

# Examples
```julia
# When manually creating LinkList for Pages
links = LinkList([
    ("Revenue Report", "\$(sanitize_filename("Revenue Report")).html", "Sales data"),
    ("Cost Analysis", "\$(sanitize_filename("Cost Analysis")).html", "Expense breakdown")
])
```
"""
function sanitize_filename(title::String)
    # Replace spaces and special chars with underscores, remove problematic characters
    sanitized = replace(title, r"[\s\-\.:/\\]" => "_")
    # Remove any other non-alphanumeric characters except underscores
    sanitized = replace(sanitized, r"[^\w]" => "")
    # Convert to lowercase for consistency
    sanitized = lowercase(sanitized)
    # Limit length to avoid filesystem issues
    if length(sanitized) > 50
        sanitized = sanitized[1:50]
    end
    # Ensure it's not empty
    if isempty(sanitized)
        sanitized = "page"
    end
    return sanitized
end

"""
    JSPlotPage(dataframes::Dict{Symbol,Any}, pivot_tables::Vector; kwargs...)

A container for a single HTML page with plots and data.

# Arguments
- `dataframes::Dict{Symbol,Any}`: Dictionary mapping data labels to DataFrames or structs containing DataFrames.
  When a struct is provided, all DataFrame fields are automatically extracted and stored with dot-prefixed names
  (e.g., `:my_data` with fields `fills` and `metadata` becomes `Symbol("my_data.fills")` and `Symbol("my_data.metadata")`).
  For external formats (parquet/csv_external), struct DataFrames are stored in subfolders (e.g., `data/my_data/fills.parquet`).
  Supports `Union{Missing, DataFrame}` fields - missing DataFrames are skipped.
- `pivot_tables::Vector`: Vector of plot objects (charts, tables, text blocks, etc.)

# Keyword Arguments
- `tab_title::String`: Browser tab title (default: `"JSPlots.jl"`)
- `page_header::String`: Main page heading (default: `""`)
- `notes::String`: Page description or notes (default: `""`)
- `dataformat::Symbol`: Data storage format - `:csv_embedded`, `:json_embedded`, `:csv_external`, `:json_external`, or `:parquet` (default: `:csv_embedded`)

# Examples
```julia
# With DataFrames
page = JSPlotPage(Dict(:data1 => df1, :data2 => df2), [chart1, chart2])

# With a struct containing DataFrames
struct MyData
    prices::DataFrame
    volumes::DataFrame
end
my_data = MyData(prices_df, volumes_df)
page = JSPlotPage(Dict(:my_data => my_data), [chart1])
# The my_data.prices becomes Symbol("my_data.prices"), stored as data/my_data/prices.parquet
# Charts can reference Symbol("my_data.prices") as their data_label

# Mixing DataFrames and structs
page = JSPlotPage(
    Dict(:struct_data => my_struct, :other => some_df),
    [pivot_table]
)
```
"""
struct JSPlotPage
    dataframes::Dict{Symbol,DataFrame}
    pivot_tables::Vector
    tab_title::String
    page_header::String
    notes::String
    dataformat::Symbol
    function JSPlotPage(dataframes::AbstractDict{Symbol}, pivot_tables::Vector; tab_title::String="JSPlots.jl", page_header::String="", notes::String="", dataformat::Symbol=:csv_embedded)
        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end

        # Process input dictionary - expand structs containing DataFrames
        enhanced_dataframes = Dict{Symbol,DataFrame}()

        for (label, data) in dataframes
            if data isa DataFrame
                # Direct DataFrame - add as-is
                enhanced_dataframes[label] = data
            elseif is_struct_with_dataframes(data)
                # Struct with DataFrame fields - extract all DataFrames
                # Charts can then reference individual DataFrames via Symbol("label.fieldname")
                extracted = extract_dataframes_from_struct(data, label)
                merge!(enhanced_dataframes, extracted)
            else
                error("Data dictionary must contain DataFrame or struct with DataFrame fields, got $(typeof(data)) for key :$label")
            end
        end

        new(enhanced_dataframes, pivot_tables, tab_title, page_header, notes, dataformat)
    end
end

"""
    Pages(coverpage::JSPlotPage, pages::Vector{<:Union{JSPlotPage, Pages}}; dataformat=nothing)

A container for multiple linked HTML pages with a coverpage.

Creates a multi-page report with a main landing page (coverpage) and additional subpages.
Supports nesting: children can be `JSPlotPage` (flat HTML files) or `Pages` (subdirectories
with their own coverpage and children). Nested `Pages` get their own subdirectory and data
directory, so data labels are isolated between siblings.

# Arguments
- `coverpage::JSPlotPage`: The main landing page (index page) for the report
- `pages::Vector{<:Union{JSPlotPage, Pages}}`: Vector of additional pages or nested sub-reports

# Keyword Arguments
- `dataformat::Union{Nothing,Symbol}`: Optional data format override that applies to all pages (default: `nothing`, uses coverpage format)

# Alternate Constructor
    Pages(coverpage_content::Vector, pages::Vector{<:Union{JSPlotPage, Pages}}; tab_title="Home", page_header="", dataformat=:parquet)

Easy constructor that automatically builds a LinkList from pages and creates the coverpage.
For `JSPlotPage` children, links point to flat HTML files. For nested `Pages` children, links
point into the subdirectory.

# Examples
```julia
# Create individual pages
page1 = JSPlotPage(dfs, [chart1], tab_title="Revenue Analysis")
page2 = JSPlotPage(dfs, [chart2], tab_title="Cost Analysis")

# Create multi-page report using easy constructor
report = Pages([TextBlock("<h1>Welcome</h1>")], [page1, page2], dataformat=:parquet)
create_html(report, "report.html")

# Nested Pages (sub-reports get their own subdirectory)
sub_report = Pages([TextBlock("<h1>Sub</h1>")], [page1], tab_title="Sub Report", dataformat=:parquet)
report = Pages([TextBlock("<h1>Main</h1>")], [page2, sub_report], dataformat=:parquet)
create_html(report, "report.html")
```
"""
struct Pages
    coverpage::JSPlotPage
    pages::Vector{Union{JSPlotPage, Pages}}
    dataformat::Symbol

    function Pages(coverpage::JSPlotPage, pages::Vector{<:Union{JSPlotPage, Pages}}; dataformat::Union{Nothing,Symbol}=nothing)
        # If dataformat is specified, it overrides all page dataformats
        if dataformat !== nothing
            if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
                error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
            end
            new(coverpage, Vector{Union{JSPlotPage, Pages}}(pages), dataformat)
        else
            # Use the coverpage's dataformat as default
            new(coverpage, Vector{Union{JSPlotPage, Pages}}(pages), coverpage.dataformat)
        end
    end

    # Easy constructor that automatically builds LinkList from pages
    function Pages(coverpage_content::Vector, pages::Vector{<:Union{JSPlotPage, Pages}};
                   tab_title::String="Home",
                   page_header::String="",
                   dataformat::Symbol=:parquet)

        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end

        # Build the LinkList automatically from the pages
        links = Tuple{String, String, String}[]
        for item in pages
            if item isa JSPlotPage
                # Flat page: link to HTML file at same level
                sanitized_name = sanitize_filename(item.tab_title)
                link_url = "$(sanitized_name).html"
                link_title = item.tab_title
                link_blurb = item.notes
                push!(links, (link_title, link_url, link_blurb))
            elseif item isa Pages
                # Nested Pages: link into subdirectory
                sanitized_name = sanitize_filename(item.coverpage.tab_title)
                link_url = "$(sanitized_name)/$(sanitized_name).html"
                link_title = item.coverpage.tab_title
                link_blurb = item.coverpage.notes
                push!(links, (link_title, link_url, link_blurb))
            end
        end

        # Create the LinkList
        link_list = LinkList(links)

        # Build coverpage with provided content plus the LinkList
        coverpage_items = vcat(coverpage_content, [link_list])
        coverpage = JSPlotPage(
            Dict{Symbol,DataFrame}(),
            coverpage_items,
            tab_title = tab_title,
            page_header = page_header,
            dataformat = dataformat
        )

        new(coverpage, Vector{Union{JSPlotPage, Pages}}(pages), dataformat)
    end

    # Easy constructor with grouped pages that creates LinkList with subheadings
    function Pages(coverpage_content::Vector, grouped_pages::OrderedCollections.OrderedDict{String, <:Vector{<:Union{JSPlotPage, Pages}}};
                   tab_title::String="Home",
                   page_header::String="",
                   dataformat::Symbol=:parquet)

        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end

        # Build the grouped LinkList automatically from the grouped pages
        grouped_links = OrderedCollections.OrderedDict{String, Vector{Tuple{String, String, String}}}()
        all_pages = Vector{Union{JSPlotPage, Pages}}()

        for (heading, pages_in_group) in grouped_pages
            links = Tuple{String, String, String}[]
            for item in pages_in_group
                if item isa JSPlotPage
                    sanitized_name = sanitize_filename(item.tab_title)
                    link_url = "$(sanitized_name).html"
                    link_title = item.tab_title
                    link_blurb = item.notes
                    push!(links, (link_title, link_url, link_blurb))
                elseif item isa Pages
                    sanitized_name = sanitize_filename(item.coverpage.tab_title)
                    link_url = "$(sanitized_name)/$(sanitized_name).html"
                    link_title = item.coverpage.tab_title
                    link_blurb = item.coverpage.notes
                    push!(links, (link_title, link_url, link_blurb))
                end
                push!(all_pages, item)
            end
            grouped_links[heading] = links
        end

        # Create the LinkList with subheadings
        link_list = LinkList(grouped_links)

        # Build coverpage with provided content plus the LinkList
        coverpage_items = vcat(coverpage_content, [link_list])
        coverpage = JSPlotPage(
            Dict{Symbol,DataFrame}(),
            coverpage_items,
            tab_title = tab_title,
            page_header = page_header,
            dataformat = dataformat
        )

        new(coverpage, all_pages, dataformat)
    end
end