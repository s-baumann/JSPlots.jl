 
const TEXTBLOCK_TEMPLATE = raw"""
    <div class="textblock-content">
        ___HTML_CONTENT___
    </div>
"""

const TEXTBLOCK_STYLE = raw"""
    <style>
        .textblock-content {
            padding: 20px;
            margin: 10px 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }

        .textblock-content h1 {
            font-size: 2em;
            margin-top: 0.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
        }

        .textblock-content h2 {
            font-size: 1.5em;
            margin-top: 0.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
        }

        .textblock-content h3 {
            font-size: 1.25em;
            margin-top: 0.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
        }

        .textblock-content p {
            margin: 0.5em 0;
        }

        .textblock-content ul, .textblock-content ol {
            margin: 0.5em 0;
            padding-left: 2em;
        }

        .textblock-content code {
            background-color: #f5f5f5;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }

        .textblock-content pre {
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }

        .textblock-content pre code {
            background-color: transparent;
            padding: 0;
        }

        .textblock-content blockquote {
            border-left: 4px solid #ddd;
            padding-left: 1em;
            margin-left: 0;
            color: #666;
        }

        .textblock-content a {
            color: #0066cc;
            text-decoration: none;
        }

        .textblock-content a:hover {
            text-decoration: underline;
        }

        .textblock-content table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
        }

        .textblock-content th, .textblock-content td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }

        .textblock-content th {
            background-color: #f5f5f5;
            font-weight: 600;
        }
    </style>
"""


"""
    TextBlock(html_content::String, images::Dict{String, String}=Dict{String, String}())

HTML text block for adding formatted text and tables to plot pages.

# Arguments
- `html_content::String`: HTML content to display
- `images::Dict{String, String}`: Optional dictionary mapping image IDs to file paths (default: empty)

# Supported HTML Elements
- Headings: `<h1>` through `<h6>`
- Paragraphs: `<p>`
- Lists: `<ul>`, `<ol>`, `<li>`
- Tables: `<table>`, `<tr>`, `<td>`, `<th>`
- Text formatting: `<strong>`, `<em>`, `<code>`, `<pre>`
- Links: `<a>`
- Blockquotes: `<blockquote>`
- Divisions: `<div>`, `<span>`

# Image Embedding
Images can be embedded using the syntax `{{IMAGE:image_id}}` in the HTML content,
where `image_id` corresponds to a key in the images dictionary.

# Examples
```julia
# Simple text block
tb = TextBlock("<h2>Analysis Results</h2><p>The data shows...</p>")

# Text block with embedded image
tb = TextBlock(
    "<h2>Plot</h2><p>{{IMAGE:plot1}}</p>",
    Dict("plot1" => "path/to/image.png")
)
```
"""
struct TextBlock <: JSPlotsType
    html_content::String
    images::Dict{String, String}  # Map image IDs to file paths
    appearance_html::String
    functional_html::String  # Empty for TextBlock, but needed for consistency
end

# Constructor with optional images parameter (default empty dict for backward compatibility)
function TextBlock(html_content::String, images::Dict{String, String}=Dict{String, String}())
    # Validate that all image files exist
    for (id, path) in images
        if !isfile(path)
            error("Image file not found for ID '$id': $path")
        end
    end

    # For TextBlocks without images, populate appearance_html for backward compatibility
    # For TextBlocks with images, appearance_html will be generated during create_html
    appearance_html = if isempty(images)
        replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => html_content)
    else
        ""  # Will be filled in generate_textblock_html
    end
    functional_html = ""  # TextBlock doesn't need any JavaScript
    TextBlock(html_content, images, appearance_html, functional_html)
end

"""
    generate_textblock_html(tb::TextBlock, dataformat::Symbol, project_dir::String="")

Generate HTML for a TextBlock, handling embedded images.

Images are referenced in the HTML content using the syntax: {{IMAGE:image_id}}
where image_id corresponds to a key in the images dictionary.

For embedded formats (:csv_embedded, :json_embedded): Encodes images as base64 data URIs
For external formats (:csv_external, :json_external, :parquet): Copies images to pictures/ subdirectory
"""
function generate_textblock_html(tb::TextBlock, dataformat::Symbol, project_dir::String="")
    html_content = tb.html_content

    # Process each image
    for (image_id, image_path) in tb.images
        # Check image size for embedded formats
        if dataformat in [:csv_embedded, :json_embedded]
            size_mb = filesize(image_path) / 1_048_576
            if size_mb > 5
                @warn "Large image '$image_id' ($(round(size_mb, digits=1)) MB) being embedded in TextBlock. " *
                      "Consider using external dataformat or reducing image size."
            end
        end

        image_html = ""

        if dataformat in [:csv_embedded, :json_embedded]
            # Embed the image
            if endswith(lowercase(image_path), ".svg")
                # SVG: Embed directly as XML
                svg_content = read(image_path, String)
                image_html = svg_content
            else
                # PNG/JPEG: Base64 encode
                img_bytes = read(image_path)
                img_base64 = base64encode(img_bytes)

                # Determine MIME type
                mime = if endswith(lowercase(image_path), ".png")
                    "image/png"
                elseif endswith(lowercase(image_path), r"\.(jpg|jpeg)$"i)
                    "image/jpeg"
                else
                    "image/png"  # Default to PNG
                end

                image_html = """<img src="data:$(mime);base64,$(img_base64)" alt="$(image_id)" />"""
            end
        else
            # External format - copy to pictures/ subdirectory
            pictures_dir = joinpath(project_dir, "pictures")
            if !isdir(pictures_dir)
                mkpath(pictures_dir)
            end

            # Get file extension
            ext = splitext(image_path)[2]
            dest_filename = image_id * ext
            dest_path = joinpath(pictures_dir, dest_filename)

            # Copy the image file
            cp(image_path, dest_path, force=true)
            println("  TextBlock image '$image_id' saved to $dest_path")

            # Reference the external image
            image_html = """<img src="pictures/$(dest_filename)" alt="$(image_id)" />"""
        end

        # Replace placeholder in HTML content
        html_content = replace(html_content, "{{IMAGE:$(image_id)}}" => image_html)
    end

    # Build the complete HTML using the template
    html = replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => html_content)

    return html
end

dependencies(a::TextBlock) = Symbol[]
js_dependencies(::TextBlock) = vcat(JS_DEP_JQUERY)