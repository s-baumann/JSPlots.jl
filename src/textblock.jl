 
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


struct TextBlock <: JSPlotsType
    html_content::String
    appearance_html::String
    functional_html::String  # Empty for TextBlock, but needed for consistency

    function TextBlock(html_content::String)
        appearance_html = replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => html_content)
        functional_html = ""  # TextBlock doesn't need any JavaScript
        new(html_content, appearance_html, functional_html)
    end
end
