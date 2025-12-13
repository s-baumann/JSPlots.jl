"""
    Slides(chart_title::Symbol, directory::String, prefix::String, filetype::String; kwargs...)

Create an interactive slideshow from image files in a directory with optional filtering.

# Constructor 1: From Directory Pattern

Scans a directory for files matching `prefix!group1!group2!...!slidenum.extension` pattern.

# Arguments
- `chart_title::Symbol`: Unique identifier for this slideshow
- `directory::String`: Directory containing slide images
- `prefix::String`: Filename prefix to match
- `filetype::String`: File extension ("png", "jpg", "jpeg", "pdf")

# Keyword Arguments
- `default_filters::Dict{Symbol,Any}`: Default values for filters (default: `Dict{Symbol,Any}()`)
- `title::String`: Slideshow title (default: `"Slides"`)
- `notes::String`: Descriptive text (default: `""`)
- `autoplay::Bool`: Start in autoplay mode (default: `false`)
- `delay::Float64`: Seconds between slides in autoplay (default: `0.5`, range: `0.05` to `5.0`)

# Data Format Behavior
- Embedded formats (`:csv_embedded`, `:json_embedded`): Images are embedded in HTML
  - SVG files are embedded as XML
  - PNG/JPEG files are base64-encoded
  - PDF files show placeholder text (limited browser support)
- External formats (`:csv_external`, `:json_external`, `:parquet`): Images are copied to `slides/` subdirectory

# File Naming Pattern
Files should follow the pattern: `prefix!group1!group2!...!slidenum.extension`

- Groups are optional filtering dimensions
- All files must have the same number of group segments
- `slidenum` is the slide number (integer)
- Supported extensions: png, jpg, jpeg, pdf

# Example
```julia
# Files in directory:
# sales!North!Q1!1.png
# sales!North!Q1!2.png
# sales!South!Q1!1.png
# sales!South!Q2!1.png

slides = Slides(:sales_slides, "charts", "sales", "png";
    default_filters = Dict{Symbol,Any}(:group_1 => "North", :group_2 => "Q1"),
    title = "Sales Analysis Slideshow"
)
```

# Constructor 2: From Function

Generates slides by calling a function for each combination of groups and slide numbers.

```julia
Slides(chart_title::Symbol, df::DataFrame, data_label::Symbol,
       group_cols::Vector{Symbol}, slide_col::Symbol,
       chart_function::Function; kwargs...)
```

# Arguments
- `chart_title::Symbol`: Unique identifier
- `df::DataFrame`: Data for generating charts
- `data_label::Symbol`: Data reference (not used, but required for consistency)
- `group_cols::Vector{Symbol}`: Columns to use as filter groups
- `slide_col::Symbol`: Column containing slide numbers
- `chart_function::Function`: Function with signature `(df, group_values..., slide_num) -> chart_object`

# Keyword Arguments
- `default_filters::Dict{Symbol,Any}`: Default filter values
- `output_format::Symbol`: Chart output format - `:png`, `:svg`, `:jpeg` (default: `:png`)
- `title::String`: Slideshow title
- `notes::String`: Descriptive text
- `autoplay::Bool`: Start in autoplay mode
- `delay::Float64`: Seconds between slides

# Data Format Behavior
- Embedded formats (`:csv_embedded`, `:json_embedded`): Images are embedded in HTML
- External formats (`:csv_external`, `:json_external`, `:parquet`): Images are copied to `slides/` subdirectory
- Function-generated slides create temporary files that are cleaned up after HTML generation

# Example (VegaLite.jl)
```julia
using VegaLite

function make_chart_vegalite(df, region, quarter, slide_num)
    # Filter data and create VegaLite chart
    filtered = df[(df.Region .== region) .& (df.Quarter .== quarter), :]

    chart = filtered |> @vlplot(
        :bar,
        title = "\$(region) - \$(quarter) - Slide \$(slide_num)",
        x = :Month,
        y = :Sales
    )

    return chart  # VegaLite chart object is auto-saved by Slides
end

slides = Slides(:generated_slides, df, :sales_data,
    [:Region, :Quarter], :SlideNum, make_chart_vegalite;
    output_format = :svg,  # VegaLite charts work best as SVG
    title = "Generated Sales Slides"
)
```

# Example (Plots.jl)
```julia
using Plots

function make_chart_plots(df, region, quarter, slide_num)
    filtered = df[(df.Region .== region) .& (df.Quarter .== quarter), :]
    return plot(filtered.Month, filtered.Sales, title="Slide \$slide_num")
end

slides = Slides(:generated_slides, df, :sales_data,
    [:Region, :Quarter], :SlideNum, make_chart_plots;
    output_format = :png,
    title = "Generated Sales Slides"
)
```
"""
struct Slides <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    image_files::Vector{String}  # Paths to image files
    group_names::Vector{Symbol}  # Names of grouping dimensions
    filter_options::Dict{String,Vector{String}}  # Available values for each group
    slide_numbers::Vector{Int}  # Available slide numbers
    file_mapping::Dict{Tuple,String}  # (group_vals..., slide_num) => filepath
    is_temp::Bool  # Whether files are temporary (from function generation)
    functional_html::String
    appearance_html::String
end

# Constructor 1: From directory pattern
function Slides(chart_title::Symbol, directory::String, prefix::String, filetype::String;
                default_filters::Dict{Symbol,Any} = Dict{Symbol,Any}(),
                title::String = "Slides",
                notes::String = "",
                autoplay::Bool = false,
                delay::Float64 = 0.5)

    if !isdir(directory)
        error("Directory not found: $directory")
    end

    # Normalize filetype
    filetype = lowercase(replace(filetype, "." => ""))
    if !(filetype in ["png", "jpg", "jpeg", "pdf", "svg"])
        error("Unsupported filetype: $filetype. Use png, jpg, jpeg, pdf, or svg")
    end

    # Find all matching files
    all_files = readdir(directory, join=true)
    pattern_files = filter(all_files) do f
        basename(f) |> name ->
            startswith(name, prefix * "!") && endswith(lowercase(name), "." * filetype)
    end

    if isempty(pattern_files)
        error("No files found matching pattern: $(prefix)!*!*.$(filetype) in $directory")
    end

    # Parse filenames to extract structure
    parsed_files = []
    for filepath in pattern_files
        filename = basename(filepath)
        # Remove prefix and extension
        stem = replace(filename, Regex("^$(prefix)!") => "")
        stem = replace(stem, Regex("\\.$(filetype)\$", "i") => "")

        # Split by !
        parts = split(stem, "!")
        if length(parts) < 1
            continue  # Skip malformed files
        end

        # Last part is slide number
        slide_str = parts[end]
        slide_num = tryparse(Int, slide_str)
        if slide_num === nothing
            continue  # Skip if slide number isn't an integer
        end

        # Everything else is group values
        groups = String.(parts[1:end-1])

        push!(parsed_files, (filepath=filepath, groups=groups, slide_num=slide_num))
    end

    if isempty(parsed_files)
        error("No valid files found. Files should match: $(prefix)!group1!...!slidenum.$(filetype)")
    end

    # Validate that all files have same number of groups
    num_groups = length(parsed_files[1].groups)
    if !all(length(pf.groups) == num_groups for pf in parsed_files)
        error("All files must have the same number of group segments. Found varying lengths.")
    end

    # Build group names
    group_names = Symbol[Symbol("group_$i") for i in 1:num_groups]

    # Build filter options (unique values for each group position)
    filter_options = Dict{String,Vector{String}}()
    for i in 1:num_groups
        group_name = string(group_names[i])
        unique_vals = unique([pf.groups[i] for pf in parsed_files])
        filter_options[group_name] = sort(unique_vals)
    end

    # Get unique slide numbers
    slide_numbers = sort(unique([pf.slide_num for pf in parsed_files]))

    # Build mapping
    file_mapping = Dict{Tuple,String}()
    for pf in parsed_files
        key = tuple(pf.groups..., pf.slide_num)
        file_mapping[key] = pf.filepath
    end

    # Get all image file paths
    image_files = [pf.filepath for pf in parsed_files]

    # Generate HTML
    functional_html, appearance_html = _generate_slides_html(
        chart_title, title, notes, group_names, filter_options,
        slide_numbers, file_mapping, image_files, default_filters,
        autoplay, delay
    )

    return Slides(chart_title, :no_data, image_files, group_names,
                  filter_options, slide_numbers, file_mapping, false,
                  functional_html, appearance_html)
end

# Constructor 2: From function
function Slides(chart_title::Symbol, df::DataFrame, data_label::Symbol,
                group_cols::Vector{Symbol}, slide_col::Symbol,
                chart_function::Function;
                default_filters::Dict{Symbol,Any} = Dict{Symbol,Any}(),
                output_format::Symbol = :png,
                title::String = "Slides",
                notes::String = "",
                autoplay::Bool = false,
                delay::Float64 = 0.5)

    if !(output_format in [:png, :svg, :jpeg, :jpg, :pdf])
        error("Unsupported output_format: $output_format. Use :png, :svg, :jpeg, or :pdf")
    end

    # Get unique combinations of groups and slide numbers
    group_combos = unique(df[:, group_cols])
    slide_numbers = sort(unique(df[:, slide_col]))

    if isempty(slide_numbers)
        error("No slide numbers found in column: $slide_col")
    end

    # Create temporary directory for generated slides
    temp_dir = mktempdir()

    # Build filter options
    filter_options = Dict{String,Vector{String}}()
    for (i, col) in enumerate(group_cols)
        filter_options[string(col)] = sort(unique(string.(df[:, col])))
    end

    # Generate charts and save to files
    image_files = String[]
    file_mapping = Dict{Tuple,String}()

    ext = string(output_format)
    ext = ext == "jpg" ? "jpeg" : ext

    for row in eachrow(group_combos)
        group_vals = [string(row[col]) for col in group_cols]

        for slide_num in slide_numbers
            # Call user function
            try
                chart_obj = chart_function(df, [row[col] for col in group_cols]..., slide_num)

                # Generate filename
                filename = "slide_$(join(group_vals, "_"))_$(slide_num).$(ext)"
                filepath = joinpath(temp_dir, filename)

                # Save chart
                _save_chart(chart_obj, filepath, output_format)

                # Add to mapping
                key = tuple(group_vals..., slide_num)
                file_mapping[key] = filepath
                push!(image_files, filepath)
            catch e
                @warn "Failed to generate chart for groups=$(group_vals), slide=$slide_num: $e"
            end
        end
    end

    if isempty(image_files)
        error("No charts were successfully generated")
    end

    # Generate HTML
    functional_html, appearance_html = _generate_slides_html(
        chart_title, title, notes, group_cols, filter_options,
        slide_numbers, file_mapping, image_files, default_filters,
        autoplay, delay
    )

    return Slides(chart_title, data_label, image_files, group_cols,
                  filter_options, slide_numbers, file_mapping, true,
                  functional_html, appearance_html)
end

# Helper function to save charts
function _save_chart(chart_obj, filepath::String, format::Symbol)
    # Auto-detect chart library and save
    chart_type = typeof(chart_obj)
    type_name = string(chart_type)

    if occursin("VegaLite", type_name)
        # VegaLite.jl
        chart_obj |> VegaLite.save(filepath)
    elseif occursin("Plots.Plot", type_name) || occursin("Plots.jl", type_name)
        # Plots.jl
        Plots.savefig(chart_obj, filepath)
    elseif occursin("Makie", type_name) || occursin("Figure", type_name)
        # Makie
        CairoMakie.save(filepath, chart_obj)
    elseif hasproperty(chart_obj, :save) && isa(getproperty(chart_obj, :save), Function)
        # Object with save method
        chart_obj.save(filepath)
    else
        error("Cannot auto-detect save method for chart type: $chart_type. Provide a custom save function.")
    end
end

# Helper function to generate HTML
function _generate_slides_html(chart_title::Symbol, title::String, notes::String,
                                group_names::Vector{Symbol},
                                filter_options::Dict{String,Vector{String}},
                                slide_numbers::Vector{Int},
                                file_mapping::Dict{Tuple,String},
                                image_files::Vector{String},
                                default_filters::Dict{Symbol,Any},
                                autoplay::Bool, delay::Float64)

    # Build filter dropdowns
    filter_dropdowns_html = ""
    for (i, group_name) in enumerate(group_names)
        group_str = string(group_name)
        options = filter_options[group_str]
        default_val = get(default_filters, group_name, options[1])

        options_html = ""
        for opt in options
            selected = (string(opt) == string(default_val)) ? " selected" : ""
            options_html *= "                <option value=\"$(opt)\"$selected>$(opt)</option>\n"
        end

        filter_dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="$(group_str)_select_$chart_title">$(group_name): </label>
            <select id="$(group_str)_select_$chart_title" onchange="updateSlide_$chart_title()">
$options_html            </select>
        </div>
        """
    end

    # JavaScript arrays
    group_names_js = "[" * join(["'$gn'" for gn in group_names], ", ") * "]"
    slide_numbers_js = "[" * join(string.(slide_numbers), ", ") * "]"

    # Calculate slider value from delay using inverse of log scale formula
    # delay = 0.05 * 10^(sliderVal/50), so sliderVal = 50 * log10(delay/0.05)
    slider_value = round(Int, 50 * log10(delay / 0.05))
    slider_value = clamp(slider_value, 0, 100)  # Ensure within range

    # Build file mapping as JavaScript object
    # mapping["group1,group2,...,slidenum"] = "image_id"
    mapping_entries = String[]
    for (key, filepath) in file_mapping
        # Join key values with commas to create a string key
        key_str = join(key, ",")
        # Use basename as image identifier
        img_id = "img_" * replace(basename(filepath), r"[^\w]" => "_")
        push!(mapping_entries, "    '$key_str': '$img_id'")
    end
    file_mapping_js = "{\n" * join(mapping_entries, ",\n") * "\n    }"

    functional_html = """
    (function() {
        const GROUP_NAMES = $group_names_js;
        const SLIDE_NUMBERS = $slide_numbers_js;
        const FILE_MAPPING = $file_mapping_js;

        let currentSlideIndex = 0;
        let isPlaying = $(autoplay ? "true" : "false");
        let playInterval = null;
        let slideDelay = $(delay * 1000);  // milliseconds

        function updateSlide_$chart_title() {
            // Get current filter values
            const filterValues = [];
            for (let groupName of GROUP_NAMES) {
                const select = document.getElementById(groupName + '_select_$chart_title');
                if (select) {
                    filterValues.push(select.value);
                }
            }

            // Get current slide number
            const slideNum = SLIDE_NUMBERS[currentSlideIndex];

            // Build lookup key
            const key = [...filterValues, slideNum].join(',');
            const imageId = FILE_MAPPING[key];

            // Hide all images
            const allImages = document.querySelectorAll('.slide-image-$chart_title');
            allImages.forEach(img => img.style.display = 'none');

            // Show selected image
            if (imageId) {
                const selectedImg = document.getElementById(imageId);
                if (selectedImg) {
                    selectedImg.style.display = 'block';
                }
            }

            // Update slide counter
            const counter = document.getElementById('slide-counter-$chart_title');
            if (counter) {
                counter.textContent = `Slide \${currentSlideIndex + 1} / \${SLIDE_NUMBERS.length}`;
            }
        }

        function previousSlide_$chart_title() {
            if (currentSlideIndex > 0) {
                currentSlideIndex--;
                updateSlide_$chart_title();
            }
        }

        function nextSlide_$chart_title() {
            if (currentSlideIndex < SLIDE_NUMBERS.length - 1) {
                currentSlideIndex++;
                updateSlide_$chart_title();
            }
        }

        function togglePlay_$chart_title() {
            isPlaying = !isPlaying;
            const btn = document.getElementById('play-btn-$chart_title');

            if (isPlaying) {
                btn.textContent = '⏸ Pause';
                playInterval = setInterval(() => {
                    if (currentSlideIndex < SLIDE_NUMBERS.length - 1) {
                        nextSlide_$chart_title();
                    } else {
                        // Loop back to start
                        currentSlideIndex = 0;
                        updateSlide_$chart_title();
                    }
                }, slideDelay);
            } else {
                btn.textContent = '▶ Play';
                if (playInterval) {
                    clearInterval(playInterval);
                    playInterval = null;
                }
            }
        }

        function updateDelay_$chart_title() {
            const slider = document.getElementById('delay-slider-$chart_title');
            const label = document.getElementById('delay-label-$chart_title');
            // Convert slider value (0-100) to delay using log scale (0.05s to 5s)
            const sliderVal = parseFloat(slider.value);
            const delaySeconds = 0.05 * Math.pow(10, sliderVal / 50);
            slideDelay = delaySeconds * 1000;
            label.textContent = delaySeconds.toFixed(2) + 's';

            // Restart interval if playing
            if (isPlaying && playInterval) {
                clearInterval(playInterval);
                playInterval = setInterval(() => {
                    if (currentSlideIndex < SLIDE_NUMBERS.length - 1) {
                        nextSlide_$chart_title();
                    } else {
                        currentSlideIndex = 0;
                        updateSlide_$chart_title();
                    }
                }, slideDelay);
            }
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'SELECT') {
                if (e.key === 'ArrowLeft') {
                    previousSlide_$chart_title();
                } else if (e.key === 'ArrowRight') {
                    nextSlide_$chart_title();
                } else if (e.key === ' ') {
                    e.preventDefault();
                    togglePlay_$chart_title();
                }
            }
        });

        // Initialize
        updateSlide_$chart_title();
        $(autoplay ? "togglePlay_$chart_title();" : "")

        // Expose functions globally
        window.previousSlide_$chart_title = previousSlide_$chart_title;
        window.nextSlide_$chart_title = nextSlide_$chart_title;
        window.togglePlay_$chart_title = togglePlay_$chart_title;
        window.updateSlide_$chart_title = updateSlide_$chart_title;
        window.updateDelay_$chart_title = updateDelay_$chart_title;
    })();
    """

    appearance_html = """
    <style>
        .slides-container-$chart_title {
            padding: 20px;
            margin: 10px 0;
        }

        .slides-image-area-$chart_title {
            text-align: center;
            background-color: #f5f5f5;
            padding: 20px;
            min-height: 400px;
            margin: 20px 0;
            border: 1px solid #ddd;
            border-radius: 5px;
        }

        .slide-image-$chart_title {
            max-width: 100%;
            max-height: 600px;
            height: auto;
            display: none;
        }

        .slides-controls-$chart_title {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 15px;
            padding: 15px;
            background-color: #f0f0f0;
            border-radius: 5px;
            flex-wrap: wrap;
        }

        .slides-controls-$chart_title button {
            padding: 8px 16px;
            font-size: 14px;
            border: 1px solid #ccc;
            background-color: white;
            cursor: pointer;
            border-radius: 4px;
        }

        .slides-controls-$chart_title button:hover {
            background-color: #e8e8e8;
        }

        .slides-controls-$chart_title button:active {
            background-color: #d0d0d0;
        }

        .delay-control-$chart_title {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .delay-control-$chart_title input[type="range"] {
            width: 150px;
        }
    </style>

    <div class="slides-container-$chart_title">
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters -->
        $(filter_dropdowns_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;\">\n            <h4 style=\"margin-top: 0;\">Filters</h4>\n            $filter_dropdowns_html\n        </div>" : "")

        <!-- Slide Display Area -->
        <div class="slides-image-area-$chart_title">
            <!-- Images will be inserted here by HTML generation -->
            ___SLIDE_IMAGES___
        </div>

        <!-- Controls -->
        <div class="slides-controls-$chart_title">
            <button onclick="previousSlide_$chart_title()">◀ Previous</button>
            <button id="play-btn-$chart_title" onclick="togglePlay_$chart_title()">▶ Play</button>
            <button onclick="nextSlide_$chart_title()">Next ▶</button>
            <span id="slide-counter-$chart_title" style="font-weight: bold; min-width: 100px;">Slide 1 / $(length(slide_numbers))</span>
            <div class="delay-control-$chart_title">
                <label for="delay-slider-$chart_title">Delay:</label>
                <input type="range" id="delay-slider-$chart_title"
                       min="0" max="100" step="1" value="$slider_value"
                       oninput="updateDelay_$chart_title()">
                <span id="delay-label-$chart_title">$(round(delay, digits=2))s</span>
            </div>
        </div>

        <p style="margin-top: 10px; font-size: 0.9em; color: #666;">
            <strong>Keyboard shortcuts:</strong> ← Previous, → Next, Space Play/Pause
        </p>
    </div>
    """

    return functional_html, appearance_html
end

"""
    generate_slides_html(slides::Slides, dataformat::Symbol, project_dir::String="")

Generate final HTML for Slides, handling image embedding or copying based on dataformat.
"""
function generate_slides_html(slides::Slides, dataformat::Symbol, project_dir::String="")
    # Generate all image tags
    images_html = ""

    for (key, filepath) in slides.file_mapping
        # Generate unique image ID
        img_id = "img_" * replace(basename(filepath), r"[^\w]" => "_")

        if dataformat in [:csv_embedded, :json_embedded]
            # Embed the image
            if endswith(lowercase(filepath), ".svg")
                # SVG: Embed directly as XML
                svg_content = read(filepath, String)
                images_html *= """<div class="slide-image-$(slides.chart_title)" id="$(img_id)">$(svg_content)</div>\n"""
            elseif endswith(lowercase(filepath), ".pdf")
                # PDF: Embed as object or warn
                @warn "PDF embedding not fully supported in browsers. File: $filepath"
                images_html *= """<div class="slide-image-$(slides.chart_title)" id="$(img_id)"><p>PDF: $(basename(filepath))</p></div>\n"""
            else
                # PNG/JPEG: Base64 encode
                img_bytes = read(filepath)
                img_base64 = base64encode(img_bytes)

                # Determine MIME type
                mime = if endswith(lowercase(filepath), ".png")
                    "image/png"
                elseif endswith(lowercase(filepath), r"\.(jpg|jpeg)$"i)
                    "image/jpeg"
                else
                    "image/png"
                end

                images_html *= """<img class="slide-image-$(slides.chart_title)" id="$(img_id)" src="data:$(mime);base64,$(img_base64)" alt="Slide" />\n"""
            end
        else
            # External format - copy to slides/ subdirectory
            slides_dir = joinpath(project_dir, "slides")
            if !isdir(slides_dir)
                mkpath(slides_dir)
            end

            # Get file extension and create destination path
            ext = splitext(filepath)[2]
            dest_filename = img_id * ext
            dest_path = joinpath(slides_dir, dest_filename)

            # Copy the image file
            cp(filepath, dest_path, force=true)

            # Reference the external image
            if endswith(lowercase(filepath), ".pdf")
                images_html *= """<div class="slide-image-$(slides.chart_title)" id="$(img_id)"><embed src="slides/$(dest_filename)" type="application/pdf" width="100%" height="600px" /></div>\n"""
            else
                images_html *= """<img class="slide-image-$(slides.chart_title)" id="$(img_id)" src="slides/$(dest_filename)" alt="Slide" />\n"""
            end
        end
    end

    # Replace placeholder in appearance_html
    html = replace(slides.appearance_html, "___SLIDE_IMAGES___" => images_html)

    return html
end

dependencies(s::Slides) = [s.data_label]

