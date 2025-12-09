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
        for (i, page) in enumerate(pages)
            link_url = "page_$(i).html"
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
end