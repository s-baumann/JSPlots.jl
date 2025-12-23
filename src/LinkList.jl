"""
    LinkList(lnks::Vector{Tuple{String,String,String}}; chart_title=:link_list, notes="")

A styled list of hyperlinks for navigating between pages in a multi-page report.

# Arguments
- `lnks::Vector{Tuple{String,String,String}}`: Vector of link tuples, each containing:
  - `page_title::String`: Display name for the link
  - `link_url::String`: URL or path to the target page (e.g., "page_1.html")
  - `blurb::String`: Description text explaining what the page contains

# Keyword Arguments
- `chart_title::Symbol`: Unique identifier (default: `:link_list`)
- `notes::String`: Descriptive text displayed below the links (default: `""`)

# Examples
```julia
links = LinkList([
    ("Sales Dashboard", "page_1.html", "Quarterly sales analysis and trends"),
    ("Customer Metrics", "page_2.html", "Customer satisfaction and retention")
], notes="Navigate to different sections of the report")
```
"""
struct LinkList <: JSPlotsType
    lnks::Vector{Tuple{String,String,String}}
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function LinkList(lnks::Vector{Tuple{String,String,String}}; chart_title::Symbol=:link_list, notes::String="")
        # Generate HTML for the link list
        links_html = "<ul>\n"
        for (title, link, blurb) in lnks
            links_html *= "    <li><strong><a href=\"$(link)\">$(title)</a></strong>: $(blurb)</li>\n"
        end
        links_html *= "</ul>"

        # Generate notes section if provided
        notes_html = if isempty(notes)
            ""
        else
            "<div style=\"padding: 12px; background-color: #fffbdd; border-top: 1px solid #ddd; margin-top: 10px; font-size: 14px;\">$(notes)</div>"
        end

        appearance_html = """
        <div style="margin: 20px 0; padding: 15px; border: 1px solid #ddd; background-color: #f9f9f9;">
            <h3>Pages</h3>
            $links_html
            $notes_html
        </div>
        """

        # LinkList has no functional JS and no data
        new(lnks, chart_title, :no_data, "", appearance_html)
    end

    """
        LinkList(grouped_lnks::OrderedCollections.OrderedDict{String,Vector{Tuple{String,String,String}}}; chart_title=:link_list, notes="")

    A styled list of hyperlinks with subheadings for navigating between pages in a multi-page report.

    # Arguments
    - `grouped_lnks::OrderedDict{String,Vector{Tuple{String,String,String}}}`: Dictionary mapping section headings to vectors of link tuples

    # Keyword Arguments
    - `chart_title::Symbol`: Unique identifier (default: `:link_list`)
    - `notes::String`: Descriptive text displayed below the links (default: `""`)

    # Examples
    ```julia
    using OrderedCollections
    links = LinkList(OrderedDict(
        "Plot Types" => [
            ("Scatter Plot", "scatter.html", "Scatter plot examples"),
            ("Line Chart", "line.html", "Line chart examples")
        ],
        "Package API" => [
            ("Data Format", "dataformat.html", "Information about data formats"),
            ("Coding Practices", "practices.html", "Best practices guide")
        ]
    ), notes="Explore different sections of the documentation")
    ```
    """
    function LinkList(grouped_lnks::OrderedCollections.OrderedDict{String,Vector{Tuple{String,String,String}}}; chart_title::Symbol=:link_list, notes::String="")
        # Generate HTML for the grouped link list with subheadings
        links_html = ""
        for (heading, links) in grouped_lnks
            links_html *= "    <h4 style=\"margin-top: 15px; margin-bottom: 5px;\">$(heading)</h4>\n"
            links_html *= "    <ul>\n"
            for (title, link, blurb) in links
                links_html *= "        <li><strong><a href=\"$(link)\">$(title)</a></strong>: $(blurb)</li>\n"
            end
            links_html *= "    </ul>\n"
        end

        # Generate notes section if provided
        notes_html = if isempty(notes)
            ""
        else
            "<div style=\"padding: 12px; background-color: #fffbdd; border-top: 1px solid #ddd; margin-top: 10px; font-size: 14px;\">$(notes)</div>"
        end

        appearance_html = """
        <div style="margin: 20px 0; padding: 15px; border: 1px solid #ddd; background-color: #f9f9f9;">
            <h3>Pages</h3>
            $links_html
            $notes_html
        </div>
        """

        # Convert grouped links to flat list for storage
        flat_lnks = Tuple{String,String,String}[]
        for (heading, links) in grouped_lnks
            append!(flat_lnks, links)
        end

        # LinkList has no functional JS and no data
        new(flat_lnks, chart_title, :no_data, "", appearance_html)
    end
end

# Dependencies method for LinkList (no data dependencies)
dependencies(a::LinkList) = Symbol[]