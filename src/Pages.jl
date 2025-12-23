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
    JSPlotPage(dataframes::Dict{Symbol,DataFrame}, pivot_tables::Vector; kwargs...)

A container for a single HTML page with plots and data.

# Arguments
- `dataframes::Dict{Symbol,DataFrame}`: Dictionary mapping data labels to DataFrames
- `pivot_tables::Vector`: Vector of plot objects (charts, tables, text blocks, etc.)

# Keyword Arguments
- `tab_title::String`: Browser tab title (default: `"JSPlots.jl"`)
- `page_header::String`: Main page heading (default: `""`)
- `notes::String`: Page description or notes (default: `""`)
- `dataformat::Symbol`: Data storage format - `:csv_embedded`, `:json_embedded`, `:csv_external`, `:json_external`, or `:parquet` (default: `:csv_embedded`)
"""
struct JSPlotPage
    dataframes::Dict{Symbol,DataFrame}
    pivot_tables::Vector
    tab_title::String
    page_header::String
    notes::String
    dataformat::Symbol
    function JSPlotPage(dataframes::Dict{Symbol,DataFrame}, pivot_tables::Vector; tab_title::String="JSPlots.jl", page_header::String="", notes::String="", dataformat::Symbol=:csv_embedded)
        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end
        new(dataframes, pivot_tables, tab_title, page_header, notes, dataformat)
    end
end

"""
    Pages(coverpage::JSPlotPage, pages::Vector{JSPlotPage}; dataformat=nothing)

A container for multiple linked HTML pages with a coverpage.

Creates a multi-page report with a main landing page (coverpage) and additional subpages.
All HTML files are created at the same level in a flat project folder structure.

# Arguments
- `coverpage::JSPlotPage`: The main landing page (index page) for the report
- `pages::Vector{JSPlotPage}`: Vector of additional pages to include

# Keyword Arguments
- `dataformat::Union{Nothing,Symbol}`: Optional data format override that applies to all pages (default: `nothing`, uses coverpage format)

# Alternate Constructor
    Pages(coverpage_content::Vector, pages::Vector{JSPlotPage}; tab_title="Home", page_header="", dataformat=:parquet)

Easy constructor that automatically builds a LinkList from pages and creates the coverpage.

# Examples
```julia
# Create individual pages
page1 = JSPlotPage(dfs, [chart1], tab_title="Revenue Analysis")
page2 = JSPlotPage(dfs, [chart2], tab_title="Cost Analysis")

# Create multi-page report using easy constructor
report = Pages([TextBlock("<h1>Welcome</h1>")], [page1, page2], dataformat=:parquet)
create_html(report, "report.html")
```
"""
struct Pages
    coverpage::JSPlotPage
    pages::Vector{JSPlotPage}
    dataformat::Symbol

    function Pages(coverpage::JSPlotPage, pages::Vector{JSPlotPage}; dataformat::Union{Nothing,Symbol}=nothing)
        # If dataformat is specified, it overrides all page dataformats
        if dataformat !== nothing
            if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
                error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
            end
            new(coverpage, pages, dataformat)
        else
            # Use the coverpage's dataformat as default
            new(coverpage, pages, coverpage.dataformat)
        end
    end

    # Easy constructor that automatically builds LinkList from pages
    function Pages(coverpage_content::Vector, pages::Vector{JSPlotPage};
                   tab_title::String="Home",
                   page_header::String="",
                   dataformat::Symbol=:parquet)

        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end

        # Build the LinkList automatically from the pages
        links = Tuple{String, String, String}[]
        for page in pages
            # Use sanitized tab_title for the filename
            sanitized_name = sanitize_filename(page.tab_title)
            link_url = "$(sanitized_name).html"
            link_title = page.tab_title
            link_blurb = page.notes
            push!(links, (link_title, link_url, link_blurb))
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

        new(coverpage, pages, dataformat)
    end

    # Easy constructor with grouped pages that creates LinkList with subheadings
    function Pages(coverpage_content::Vector, grouped_pages::OrderedCollections.OrderedDict{String, Vector{JSPlotPage}};
                   tab_title::String="Home",
                   page_header::String="",
                   dataformat::Symbol=:parquet)

        if !(dataformat in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet])
            error("dataformat must be :csv_embedded, :json_embedded, :csv_external, :json_external, or :parquet")
        end

        # Build the grouped LinkList automatically from the grouped pages
        grouped_links = OrderedCollections.OrderedDict{String, Vector{Tuple{String, String, String}}}()
        all_pages = JSPlotPage[]

        for (heading, pages_in_group) in grouped_pages
            links = Tuple{String, String, String}[]
            for page in pages_in_group
                # Use sanitized tab_title for the filename
                sanitized_name = sanitize_filename(page.tab_title)
                link_url = "$(sanitized_name).html"
                link_title = page.tab_title
                link_blurb = page.notes
                push!(links, (link_title, link_url, link_blurb))
                push!(all_pages, page)
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