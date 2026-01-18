
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
    Picture(chart_title::Symbol, image_path::String; title::String="", notes::String="")

Create a Picture plot from a single image file.

# Arguments
- `chart_title::Symbol`: Unique identifier for this picture
- `image_path::String`: Path to the image file (PNG, SVG, JPEG, GIF, etc.)
- `title::String`: Optional title (default: chart_title)
- `notes::String`: Optional descriptive text shown below the chart

# Example
```julia
pic = Picture(:my_image, "path/to/image.png"; title="My Plot", notes="A saved plot")
```
"""
struct Picture <: JSPlotsType
    chart_title::Symbol
    title::String
    notes::String
    is_temp::Bool
    # For single image mode
    image_path::Union{String,Nothing}
    # For filtered mode
    image_files::Vector{String}
    group_names::Vector{Symbol}
    filter_options::Dict{String,Vector{String}}
    file_mapping::Dict{Tuple,String}
    # HTML generation
    appearance_html::String
    functional_html::String
end

# Internal constructor for single image
function Picture(chart_title::Symbol, image_path::String, title::String, notes::String, is_temp::Bool)
    # Single image mode - no filtering
    Picture(chart_title, title, notes, is_temp,
            image_path, String[], Symbol[], Dict{String,Vector{String}}(),
            Dict{Tuple,String}(), "", "")
end

# External constructor from single file path (backward compatible)
function Picture(chart_title::Symbol, image_path::String;
                 title::String="", notes::String="")
    if !isfile(image_path)
        error("Image file not found: $image_path")
    end
    display_title = isempty(title) ? string(chart_title) : title
    return Picture(chart_title, image_path, display_title, notes, false)
end

"""
    Picture(chart_title::Symbol, directory::String, prefix::String;
            filters::Dict{Symbol,Any}=Dict{Symbol,Any}(), title::String="Picture Viewer", notes::String="")

Create an interactive Picture viewer with filtering from multiple image files.

Scans a directory for image files matching `prefix!group1!group2!...!groupN.ext` pattern.

# Arguments
- `chart_title::Symbol`: Unique identifier for this picture viewer
- `directory::String`: Directory containing image files
- `prefix::String`: Filename prefix to match

# Keyword Arguments
- `filters::Dict{Symbol,Any}`: Default values for filters (default: `Dict{Symbol,Any}()`)
- `title::String`: Picture viewer title (default: `"Picture Viewer"`)
- `notes::String`: Descriptive text (default: `""`)

# File Naming Pattern
Files should follow the pattern: `prefix!group1!group2!...!groupN.ext`

- Groups are filtering dimensions (e.g., Region, Quarter, Scenario)
- All files must have the same number of group segments
- Supported extensions: .png, .jpg, .jpeg, .gif, .svg

# Examples
```julia
# Files in directory:
# chart!North!Q1.png
# chart!North!Q2.png
# chart!South!Q1.png
# chart!South!Q2.png

pic = Picture(:regional_charts, "charts/", "chart";
    filters = Dict{Symbol,Any}(:region => "North", :quarter => "Q1"),
    title = "Regional Sales Charts"
)
```
"""
function Picture(chart_title::Symbol, directory::String, prefix::String;
                 filters::Dict{Symbol,Any} = Dict{Symbol,Any}(),
                 title::String = "Picture Viewer",
                 notes::String = "")

    if !isdir(directory)
        error("Directory not found: $directory")
    end

    # Find all matching image files
    all_files = readdir(directory, join=true)
    valid_extensions = [".png", ".jpg", ".jpeg", ".gif", ".svg"]

    pattern_files = filter(all_files) do f
        basename(f) |> name -> begin
            ext = lowercase(splitext(name)[2])
            startswith(name, prefix * "!") && ext in valid_extensions
        end
    end

    if isempty(pattern_files)
        error("No image files found matching pattern: $(prefix)!*.{png,jpg,jpeg,gif,svg} in $directory")
    end

    # Parse filenames to extract structure
    parsed_files = []
    for filepath in pattern_files
        filename = basename(filepath)
        # Remove extension
        name_without_ext = splitext(filename)[1]
        # Split by "!"
        parts = split(name_without_ext, "!")
        if length(parts) < 2
            continue  # Skip files that don't match pattern
        end

        # First part is prefix, rest are group values
        group_values = parts[2:end]
        push!(parsed_files, (groups=group_values, path=filepath))
    end

    if isempty(parsed_files)
        error("No valid image files found matching pattern")
    end

    # Verify all files have same number of groups
    num_groups = length(parsed_files[1].groups)
    if !all(length(pf.groups) == num_groups for pf in parsed_files)
        error("All image files must have the same number of group segments in filename")
    end

    # Build group names - check if user provided custom names
    group_names = Symbol[]
    for i in 1:num_groups
        if haskey(filters, Symbol("group_$i"))
            push!(group_names, Symbol("group_$i"))
        else
            # Try to find a custom filter name at this position
            found = false
            for (k, v) in filters
                if !(k in group_names) && !startswith(string(k), "group_")
                    # This might be a custom name - we'll validate it exists in data
                    push!(group_names, k)
                    found = true
                    break
                end
            end
            if !found
                push!(group_names, Symbol("group_$i"))
            end
        end
    end
    # Ensure we have the right number of names
    if length(group_names) != num_groups
        group_names = [Symbol("group_$i") for i in 1:num_groups]
    end

    # Build filter options (unique values for each group dimension)
    filter_options = Dict{String,Vector{String}}()
    for (i, group_name) in enumerate(group_names)
        unique_vals = unique([pf.groups[i] for pf in parsed_files])
        filter_options[string(group_name)] = sort(unique_vals)
    end

    # Build file mapping
    file_mapping = Dict{Tuple,String}()
    for pf in parsed_files
        key = Tuple(pf.groups)
        file_mapping[key] = pf.path
    end

    # Get all file paths
    image_files = [pf.path for pf in parsed_files]

    # Normalize filters to match group names
    normalized_filters = Dict{Symbol,Any}()
    for (i, group_name) in enumerate(group_names)
        if haskey(filters, group_name)
            val = filters[group_name]
            # Ensure value is valid
            if string(val) in filter_options[string(group_name)]
                normalized_filters[group_name] = [string(val)]
            else
                # Use first available value
                normalized_filters[group_name] = [filter_options[string(group_name)][1]]
            end
        else
            # Default to first available value
            normalized_filters[group_name] = [filter_options[string(group_name)][1]]
        end
    end

    # Build appearance HTML with filter controls
    chart_title_str = string(chart_title)
    update_function = "updatePicture_$chart_title()"

    # Build filter dropdowns HTML
    filter_dropdowns_html = ""
    for group_name in group_names
        group_str = string(group_name)
        available_values = filter_options[group_str]
        default_value = normalized_filters[group_name][1]

        # Create friendly label (capitalize and remove underscores)
        label = uppercasefirst(replace(group_str, "_" => " "))

        options_html = ""
        for opt in available_values
            selected = (string(opt) == string(default_value)) ? " selected" : ""
            options_html *= "                <option value=\"$(opt)\"$selected>$(opt)</option>\n"
        end

        filter_dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="$(group_str)_select_$chart_title">$(label): </label>
            <select id="$(group_str)_select_$chart_title" onchange="$update_function">
$options_html            </select>
        </div>
        """
    end

    # Generate full appearance HTML
    appearance_html = """
    <h2>$title</h2>
    <p>$notes</p>

    $(filter_dropdowns_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;\">\n        <h4 style=\"margin-top: 0;\">Filters</h4>\n        $filter_dropdowns_html\n    </div>" : "")

    <div style="text-align: center; margin: 20px 0;">
        <img id="picture_img_$chart_title" style="max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 4px;" />
    </div>
    """

    # Build JS arrays for file mapping
    group_names_js = "[" * join(["'" * string(gn) * "'" for gn in group_names], ", ") * "]"

    mapping_entries = []
    for (key, filepath) in file_mapping
        key_str = join(key, ",")
        img_id = "picture_" * replace(basename(filepath), r"[^\w]" => "_")
        push!(mapping_entries, "    '$key_str': '$img_id'")
    end
    file_mapping_js = "{\n" * join(mapping_entries, ",\n") * "\n    }"

    # Build functional HTML (JavaScript)
    functional_html = """
    (function() {
        const GROUP_NAMES = $group_names_js;
        const FILE_MAPPING = $file_mapping_js;

        window.updatePicture_$chart_title = function() {
            // Get current filter values
            const filterValues = [];
            for (let groupName of GROUP_NAMES) {
                const select = document.getElementById(groupName + '_select_$chart_title');
                if (select) {
                    filterValues.push(select.value);
                } else {
                    console.error('Select not found:', groupName + '_select_$chart_title');
                }
            }

            // Build lookup key
            const key = filterValues.join(',');
            const imgId = FILE_MAPPING[key];

            if (!imgId) {
                console.error('No image found for filter combination:', filterValues, 'Available keys:', Object.keys(FILE_MAPPING));
                return;
            }

            // Get the hidden image element and the display image
            const imgElement = document.getElementById(imgId);
            const displayImg = document.getElementById('picture_img_$chart_title');

            if (!imgElement || !displayImg) {
                console.error('Image elements not found. imgId:', imgId, 'imgElement:', imgElement, 'displayImg:', displayImg);
                return;
            }

            // Update the display image source
            displayImg.src = imgElement.src;
        };

        // Initialize after DOM is fully loaded
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
                setTimeout(function() { updatePicture_$chart_title(); }, 100);
            });
        } else {
            setTimeout(function() { updatePicture_$chart_title(); }, 100);
        }
    })();
    """

    Picture(chart_title, title, notes, false,
            nothing, image_files, group_names, filter_options,
            file_mapping, appearance_html, functional_html)
end

"""
    Picture(chart_title::Symbol, chart_object, save_function::Function;
            format::Symbol=:png, title::String="", notes::String="", rng=nothing)

Create a Picture plot from a chart object with a custom save function.

# Arguments
- `chart_title::Symbol`: Unique identifier for this picture
- `chart_object`: The chart/plot object to save
- `save_function::Function`: Function with signature `(chart, path) -> nothing` to save the chart
- `format::Symbol`: Output format (`:png`, `:svg`, `:jpeg`) (default: `:png`)
- `title::String`: Optional title (default: chart_title)
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
                 format::Symbol=:png, title::String="", notes::String="", rng=nothing)
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

    display_title = isempty(title) ? string(chart_title) : title
    return Picture(chart_title, temp_path, display_title, notes, true)
end

# Constructor for auto-detected plotting packages
function Picture(chart_title::Symbol, chart_object;
                 format::Symbol=:png, title::String="", notes::String="", rng=nothing)
    # Try to detect the plotting package and use appropriate save function
    chart_type = typeof(chart_object)

    # Check for VegaLite
    if isdefined(Main, :VegaLite) && chart_type <: Main.VegaLite.VLSpec
        return Picture(chart_title, chart_object,
                      (obj, path) -> Main.VegaLite.save(path, obj);
                      format=format, title=title, notes=notes, rng=rng)
    end

    # Check for Plots.jl
    if isdefined(Main, :Plots) && chart_type <: Main.Plots.Plot
        return Picture(chart_title, chart_object,
                      (obj, path) -> Main.Plots.savefig(obj, path);
                      format=format, title=title, notes=notes, rng=rng)
    end

    # Check for Makie (GLMakie, WGLMakie, etc.)
    if isdefined(Main, :Makie)
        makie_types = [:Figure, :FigureAxisPlot, :Scene]
        for t in makie_types
            if isdefined(Main.Makie, t) && chart_type <: getfield(Main.Makie, t)
                return Picture(chart_title, chart_object,
                              (obj, path) -> Main.Makie.save(path, obj);
                              format=format, title=title, notes=notes, rng=rng)
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

Generate HTML for a Picture, handling both single image and filtered modes.

For embedded formats (:csv_embedded, :json_embedded): Encodes images as base64 data URI
For external formats (:csv_external, :json_external, :parquet): Copies images to pictures/ subdirectory
"""
function generate_picture_html(pic::Picture, dataformat::Symbol, project_dir::String="")
    # Check if this is filtered mode or single image mode
    if isempty(pic.image_files)
        # Single image mode - use original logic
        check_image_size(pic.image_path, dataformat)

        image_html = ""

        if dataformat in [:csv_embedded, :json_embedded]
            # Embed the image
            if endswith(lowercase(pic.image_path), ".svg")
                # SVG: Embed directly as XML
                svg_content = read(pic.image_path, String)
                image_html = svg_content
            elseif endswith(lowercase(pic.image_path), ".gif")
                # GIF: Base64 encode
                img_bytes = read(pic.image_path)
                img_base64 = base64encode(img_bytes)
                image_html = """<img src="data:image/gif;base64,$(img_base64)" alt="$(pic.chart_title)" />"""
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

        # Build the complete HTML for single image
        html = replace(PICTURE_TEMPLATE, "___PICTURE_TITLE___" => pic.title)
        html = replace(html, "___NOTES___" => pic.notes)
        html = replace(html, "___IMAGE_CONTENT___" => image_html)

        return html
    else
        # Filtered mode - generate hidden images + controls
        html_parts = []

        if dataformat in [:csv_embedded, :json_embedded]
            # Embed all images as base64
            for (key, filepath) in pic.file_mapping
                check_image_size(filepath, dataformat)

                if endswith(lowercase(filepath), ".svg")
                    # SVG: embed as hidden div
                    svg_content = read(filepath, String)
                    img_id = "picture_" * replace(basename(filepath), r"[^\w]" => "_")
                    push!(html_parts, """<div id="$img_id" style="display:none;">$svg_content</div>""")
                elseif endswith(lowercase(filepath), ".gif")
                    # GIF: Base64 encode
                    img_bytes = read(filepath)
                    img_base64 = base64encode(img_bytes)
                    img_id = "picture_" * replace(basename(filepath), r"[^\w]" => "_")
                    push!(html_parts, """<img id="$img_id" src="data:image/gif;base64,$img_base64" style="display:none;" />""")
                else
                    # PNG/JPEG: Base64 encode
                    img_bytes = read(filepath)
                    img_base64 = base64encode(img_bytes)
                    img_id = "picture_" * replace(basename(filepath), r"[^\w]" => "_")

                    # Determine MIME type
                    mime = if endswith(lowercase(filepath), ".png")
                        "image/png"
                    elseif endswith(lowercase(filepath), r"\.(jpg|jpeg)$"i)
                        "image/jpeg"
                    else
                        "image/png"
                    end

                    push!(html_parts, """<img id="$img_id" src="data:$(mime);base64,$img_base64" style="display:none;" />""")
                end
            end
        else
            # External format - copy to pictures/ subdirectory
            pictures_dir = joinpath(project_dir, "pictures")
            if !isdir(pictures_dir)
                mkpath(pictures_dir)
            end

            for (key, filepath) in pic.file_mapping
                filename = basename(filepath)
                dest_path = joinpath(pictures_dir, filename)

                # Copy the image file
                cp(filepath, dest_path, force=true)

                # Create hidden img element referencing external file
                img_id = "picture_" * replace(filename, r"[^\w]" => "_")
                push!(html_parts, """<img id="$img_id" src="pictures/$filename" style="display:none;" />""")
            end
        end

        # Combine appearance HTML with hidden images
        full_html = pic.appearance_html * "\n\n" * join(html_parts, "\n")
        return full_html
    end
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
js_dependencies(::Picture) = vcat(JS_DEP_JQUERY)
