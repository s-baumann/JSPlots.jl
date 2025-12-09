
struct LinkList <: JSPlotsType
    lnks::Vector{Tuple{String,String,String}}
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String

    function LinkList(lnks::Vector{Tuple{String,String,String}}; chart_title::Symbol=:link_list)
        # Generate HTML for the link list
        links_html = "<ul>\n"
        for (title, link, blurb) in lnks
            links_html *= "    <li><strong><a href=\"$(link)\">$(title)</a></strong>: $(blurb)</li>\n"
        end
        links_html *= "</ul>"

        appearance_html = """
        <div style="margin: 20px 0; padding: 15px; border: 1px solid #ddd; background-color: #f9f9f9;">
            <h3>Pages</h3>
            $links_html
        </div>
        """

        # LinkList has no functional JS and no data
        new(lnks, chart_title, :no_data, "", appearance_html)
    end
end

# Dependencies method for LinkList (no data dependencies)
dependencies(a::LinkList) = Symbol[]