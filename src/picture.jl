
const PICTURE_TEMPLATE = raw"""
    <div class="picture-container">
        <h2>___PICTURE_TITLE___</h2>
        <p>___NOTES___</p>
        ___IMAGE_CONTENT___
    </div>
"""

const PICTURE_STYLE = raw"""
    <style>
        .picture-container {
            padding: 20px;
            margin: 10px 0;
            text-align: center;
        }

        .picture-container h2 {
            font-size: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
        }

        .picture-container img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .picture-container svg {
            max-width: 100%;
            height: auto;
        }
    </style>
"""

"""
    Picture(chart_title::Symbol, image_path::String; notes::String="")

Create a Picture plot from an existing image file.

# Arguments
- `chart_title::Symbol`: Unique identifier for this picture
- `image_path::String`: Path to the image file (PNG, SVG, JPEG, etc.)
- `notes::String`: Optional descriptive text shown below the chart

# Example
```julia
pic = Picture(:my_image, "path/to/image.png"; notes="A saved plot")
```
"""
struct Picture <: JSPlotsType
    chart_title::Symbol
    image_path::String
    notes::String
    is_temp::Bool
    appearance_html::String
    functional_html::String

    # Internal constructor
    function Picture(chart_title::Symbol, image_path::String, notes::String, is_temp::Bool)
        new(chart_title, image_path, notes, is_temp, "", "")
    end
end

# External constructor from file path
function Picture(chart_title::Symbol, image_path::String; notes::String="")
    if !isfile(image_path)
        error("Image file not found: $image_path")
    end
    return Picture(chart_title, image_path, notes, false)
end

"""
    Picture(chart_title::Symbol, chart_object, save_function::Function;
            format::Symbol=:png, notes::String="", rng=nothing)

Create a Picture plot from a chart object with a custom save function.

# Arguments
- `chart_title::Symbol`: Unique identifier for this picture
- `chart_object`: The chart/plot object to save
- `save_function::Function`: Function with signature `(chart, path) -> nothing` to save the chart
- `format::Symbol`: Output format (`:png`, `:svg`, `:jpeg`) (default: `:png`)
- `notes::String`: Optional descriptive text shown below the chart
- `rng`: Optional RNG object (e.g., StableRNG) for deterministic filenames. When provided, uses chart_title for filename instead of random temp name.

# Example
```julia
using Plots
p = plot(1:10, rand(10))
pic = Picture(:my_plot, p, (obj, path) -> savefig(obj, path); format=:png)

# For deterministic filenames (useful for git):
using StableRNGs
pic = Picture(:my_plot, p, (obj, path) -> savefig(obj, path); format=:png, rng=StableRNG(123))
```
"""
function Picture(chart_title::Symbol, chart_object, save_function::Function;
                 format::Symbol=:png, notes::String="", rng=nothing)
    if !(format in [:png, :svg, :jpeg, :jpg])
        error("Unsupported format: $format. Use :png, :svg, or :jpeg")
    end

    # Create temporary file - use deterministic name if rng provided
    if rng !== nothing
        # Use chart_title for deterministic filename
        temp_dir = mktempdir()
        temp_path = joinpath(temp_dir, string(chart_title) * "." * string(format))
    else
        temp_path = tempname() * "." * string(format)
    end

    try
        # Call user's save function
        save_function(chart_object, temp_path)
    catch e
        error("Failed to save chart: $e\n" *
              "Make sure your save function has signature: (chart, path) -> nothing")
    end

    if !isfile(temp_path)
        error("Save function did not create file at: $temp_path")
    end

    return Picture(chart_title, temp_path, notes, true)
end

# Constructor for auto-detected plotting packages
function Picture(chart_title::Symbol, chart_object; format::Symbol=:png, notes::String="", rng=nothing)
    # Try to detect the plotting package and use appropriate save function
    chart_type = typeof(chart_object)

    # Check for VegaLite
    if isdefined(Main, :VegaLite) && chart_type <: Main.VegaLite.VLSpec
        return Picture(chart_title, chart_object,
                      (obj, path) -> Main.VegaLite.save(path, obj);
                      format=format, notes=notes, rng=rng)
    end

    # Check for Plots.jl
    if isdefined(Main, :Plots) && chart_type <: Main.Plots.Plot
        return Picture(chart_title, chart_object,
                      (obj, path) -> Main.Plots.savefig(obj, path);
                      format=format, notes=notes, rng=rng)
    end

    # Check for Makie (GLMakie, WGLMakie, etc.)
    if isdefined(Main, :Makie)
        makie_types = [:Figure, :FigureAxisPlot, :Scene]
        for t in makie_types
            if isdefined(Main.Makie, t) && chart_type <: getfield(Main.Makie, t)
                return Picture(chart_title, chart_object,
                              (obj, path) -> Main.Makie.save(path, obj);
                              format=format, notes=notes, rng=rng)
            end
        end
    end

    # If we couldn't detect the type, provide helpful error
    error("Could not auto-detect plotting library for type $(chart_type).\n" *
          "Please use the explicit constructor with a save function:\n" *
          "  Picture(:title, chart, (obj, path) -> your_save_function(obj, path); format=:png)")
end

"""
    generate_picture_html(pic::Picture, dataformat::Symbol, project_dir::String="")

Generate HTML for a Picture, handling both embedded and external formats.

For embedded formats (:csv_embedded, :json_embedded): Encodes image as base64 data URI
For external formats (:csv_external, :json_external, :parquet): Copies image to pictures/ subdirectory
"""
function generate_picture_html(pic::Picture, dataformat::Symbol, project_dir::String="")
    check_image_size(pic.image_path, dataformat)

    image_html = ""

    if dataformat in [:csv_embedded, :json_embedded]
        # Embed the image
        if endswith(lowercase(pic.image_path), ".svg")
            # SVG: Embed directly as XML
            svg_content = read(pic.image_path, String)
            image_html = svg_content
        else
            # PNG/JPEG: Base64 encode
            img_bytes = read(pic.image_path)
            img_base64 = base64encode(img_bytes)

            # Determine MIME type
            mime = if endswith(lowercase(pic.image_path), ".png")
                "image/png"
            elseif endswith(lowercase(pic.image_path), r"\.(jpg|jpeg)$"i)
                "image/jpeg"
            else
                "image/png"  # Default to PNG
            end

            image_html = """<img src="data:$(mime);base64,$(img_base64)" alt="$(pic.chart_title)" />"""
        end
    else
        # External format - copy to pictures/ subdirectory
        pictures_dir = joinpath(project_dir, "pictures")
        if !isdir(pictures_dir)
            mkpath(pictures_dir)
        end

        # Get file extension
        ext = splitext(pic.image_path)[2]
        dest_filename = string(pic.chart_title) * ext
        dest_path = joinpath(pictures_dir, dest_filename)

        # Copy the image file
        cp(pic.image_path, dest_path, force=true)
        println("  Picture saved to $dest_path")

        # Reference the external image
        image_html = """<img src="pictures/$(dest_filename)" alt="$(pic.chart_title)" />"""
    end

    # Build the complete HTML
    html = replace(PICTURE_TEMPLATE, "___PICTURE_TITLE___" => string(pic.chart_title))
    html = replace(html, "___NOTES___" => pic.notes)
    html = replace(html, "___IMAGE_CONTENT___" => image_html)

    return html
end

"""
    check_image_size(path::String, dataformat::Symbol)

Warn if embedding a large image file.
"""
function check_image_size(path::String, dataformat::Symbol)
    if dataformat in [:csv_embedded, :json_embedded]
        size_mb = filesize(path) / 1_048_576
        if size_mb > 5
            @warn "Large image ($(round(size_mb, digits=1)) MB) being embedded. " *
                  "Consider using external dataformat (:csv_external, :json_external, or :parquet) " *
                  "or reducing image size/quality."
        end
    end
end

dependencies(a::Picture) = []

