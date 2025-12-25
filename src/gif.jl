"""
    Gif(chart_title::Symbol, directory::String, prefix::String; kwargs...)

Create an interactive GIF viewer with frame-by-frame control and optional filtering.

# Constructor: From Directory Pattern

Scans a directory for GIF files matching `prefix!group1!group2!...!groupN.gif` pattern.

# Arguments
- `chart_title::Symbol`: Unique identifier for this GIF viewer
- `directory::String`: Directory containing GIF files
- `prefix::String`: Filename prefix to match

# Keyword Arguments
- `filters::Dict{Symbol,Any}`: Default values for filters (default: `Dict{Symbol,Any}()`)
- `title::String`: GIF viewer title (default: `"GIF Viewer"`)
- `notes::String`: Descriptive text (default: `""`)
- `autoplay::Bool`: Start in autoplay mode (default: `false`)
- `delay::Float64`: Seconds between frames in autoplay (default: `0.1`, range: `0.05` to `5.0`)
- `loop::Bool`: Enable looping animation (default: `true`)

# Data Format Behavior
- Embedded formats (`:csv_embedded`, `:json_embedded`): GIFs are base64-encoded in HTML
- External formats (`:csv_external`, `:json_external`, `:parquet`): GIFs are copied to `gifs/` subdirectory

# File Naming Pattern
Files should follow the pattern: `prefix!group1!group2!...!groupN.gif`

- Groups are optional filtering dimensions
- All files must have the same number of group segments
- No slide number (each GIF contains its own frames)

# Example
```julia
# Files in directory:
# animation!North!Q1.gif
# animation!North!Q2.gif
# animation!South!Q1.gif
# animation!South!Q2.gif

gif_chart = Gif(:sales_gifs, "animations", "animation";
    filters = Dict{Symbol,Any}(:group_1 => "North", :group_2 => "Q1"),
    title = "Sales Animations by Region and Quarter",
    autoplay = false,
    loop = true
)
```

# Frame-by-Frame Control
The GIF viewer uses libgif.js to parse GIFs client-side, enabling:
- Play/Pause control
- Previous/Next frame buttons
- Frame counter display
- Speed control slider
- Loop toggle

# Frame Preservation
When filters change (switching between GIFs), the viewer attempts to maintain the
same frame number. If the new GIF has fewer frames, it jumps to the last available frame.
"""
struct Gif <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol  # :no_data for file-based
    gif_files::Vector{String}  # Paths to GIF files
    group_names::Vector{Symbol}  # Names of grouping dimensions
    filter_options::Dict{String,Vector{String}}  # Available values for each group
    file_mapping::Dict{Tuple,String}  # (group_vals...) => filepath
    is_temp::Bool  # Whether files are temporary (from function generation)
    functional_html::String
    appearance_html::String
end

# Constructor: From directory pattern
function Gif(chart_title::Symbol, directory::String, prefix::String;
             filters::Dict{Symbol,Any} = Dict{Symbol,Any}(),
             title::String = "GIF Viewer",
             notes::String = "",
             autoplay::Bool = false,
             delay::Float64 = 0.1,
             loop::Bool = true)

    if !isdir(directory)
        error("Directory not found: $directory")
    end

    # Find all matching GIF files
    all_files = readdir(directory, join=true)
    pattern_files = filter(all_files) do f
        basename(f) |> name ->
            startswith(name, prefix * "!") && endswith(lowercase(name), ".gif")
    end

    if isempty(pattern_files)
        error("No GIF files found matching pattern: $(prefix)!*.gif in $directory")
    end

    # Parse filenames to extract structure
    parsed_files = []
    for filepath in pattern_files
        filename = basename(filepath)
        # Remove prefix and .gif extension
        stem = replace(filename, Regex("^$(prefix)!") => "")
        stem = replace(stem, r"\.gif$"i => "")

        # Split by ! to get group values
        groups = split(stem, "!")
        if length(groups) < 1
            continue  # Skip malformed files
        end

        push!(parsed_files, (filepath=filepath, groups=String.(groups)))
    end

    if isempty(parsed_files)
        error("No valid GIF files found. Files should match: $(prefix)!group1!...!groupN.gif")
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

    # Build file mapping
    file_mapping = Dict{Tuple,String}()
    for pf in parsed_files
        key = tuple(pf.groups...)
        file_mapping[key] = pf.filepath
    end

    # Get all GIF file paths
    gif_files = [pf.filepath for pf in parsed_files]

    # Generate HTML
    functional_html, appearance_html = _generate_gif_html(
        chart_title, title, notes, group_names, filter_options,
        file_mapping, gif_files, filters,
        autoplay, delay, loop
    )

    return Gif(chart_title, :no_data, gif_files, group_names,
               filter_options, file_mapping, false,
               functional_html, appearance_html)
end

# Helper function to generate HTML for Gif
function _generate_gif_html(chart_title::Symbol, title::String, notes::String,
                             group_names::Vector{Symbol},
                             filter_options::Dict{String,Vector{String}},
                             file_mapping::Dict{Tuple,String},
                             gif_files::Vector{String},
                             filters::Dict{Symbol,Any},
                             autoplay::Bool, delay::Float64, loop::Bool)

    chart_title_str = string(chart_title)

    # Build filter dropdowns
    filter_dropdowns_html = ""
    for (i, group_name) in enumerate(group_names)
        group_str = string(group_name)
        options = filter_options[group_str]
        default_val = get(filters, group_name, options[1])

        options_html = ""
        for opt in options
            selected = (string(opt) == string(default_val)) ? " selected" : ""
            options_html *= "                <option value=\"$(opt)\"$selected>$(opt)</option>\n"
        end

        filter_dropdowns_html *= """
        <div style="margin: 10px;">
            <label for="$(group_str)_select_$chart_title">$(group_name): </label>
            <select id="$(group_str)_select_$chart_title" onchange="switchGif_$chart_title()">
$options_html            </select>
        </div>
        """
    end

    # JavaScript arrays
    group_names_js = "[" * join(["'$gn'" for gn in group_names], ", ") * "]"

    # Calculate slider value from delay using inverse of log scale formula
    slider_value = round(Int, 50 * log10(delay / 0.05))
    slider_value = clamp(slider_value, 0, 100)

    # Build file mapping as JavaScript object
    mapping_entries = String[]
    for (key, filepath) in file_mapping
        key_str = join(key, ",")
        gif_id = "gif_" * replace(basename(filepath), r"[^\w]" => "_")
        push!(mapping_entries, "    '$key_str': '$gif_id'")
    end
    file_mapping_js = "{\n" * join(mapping_entries, ",\n") * "\n    }"

    functional_html = """
    (function() {
        const GROUP_NAMES = $group_names_js;
        const FILE_MAPPING = $file_mapping_js;

        let currentGif_$chart_title = null;
        let currentFrame_$chart_title = 0;
        let isPlaying_$chart_title = false;
        let shouldLoop_$chart_title = $(loop ? "true" : "false");
        let frameDelay_$chart_title = $(delay * 1000);  // milliseconds

        function initGif_$chart_title(gifId) {
            const canvas = document.getElementById('gif_canvas_$chart_title');
            const gifImg = document.getElementById(gifId);

            if (!gifImg || !canvas) {
                console.error('GIF or canvas not found');
                return;
            }

            // Create SuperGif instance
            const rub = new SuperGif({
                gif: gifImg,
                auto_play: false,
                loop_mode: shouldLoop_$chart_title,
                draw_while_loading: true,
                show_progress_bar: false
            });

            rub.load(function() {
                currentGif_$chart_title = rub;

                // Move to saved frame position (clamped to available frames)
                const totalFrames = rub.get_length();
                const targetFrame = Math.min(currentFrame_$chart_title, totalFrames - 1);
                rub.move_to(targetFrame);

                // Update frame counter
                updateFrameCounter_$chart_title();

                // Start playing if autoplay is enabled and we're on first load
                if ($(autoplay ? "!isPlaying_$chart_title" : "false")) {
                    togglePlay_$chart_title();
                }
            });
        }

        function switchGif_$chart_title() {
            // Store current frame number before switching
            if (currentGif_$chart_title) {
                currentFrame_$chart_title = currentGif_$chart_title.get_current_frame();
            }

            const wasPlaying = isPlaying_$chart_title;

            // Pause current GIF
            if (isPlaying_$chart_title) {
                togglePlay_$chart_title();
            }

            // Get current filter values
            const filterValues = [];
            for (let groupName of GROUP_NAMES) {
                const select = document.getElementById(groupName + '_select_$chart_title');
                if (select) {
                    filterValues.push(select.value);
                }
            }

            // Build lookup key
            const key = filterValues.join(',');
            const gifId = FILE_MAPPING[key];

            // Hide all GIF images
            const allGifs = document.querySelectorAll('.gif-image-$chart_title');
            allGifs.forEach(gif => gif.style.display = 'none');

            // Show and initialize selected GIF
            if (gifId) {
                const selectedGif = document.getElementById(gifId);
                if (selectedGif) {
                    selectedGif.style.display = 'block';
                    initGif_$chart_title(gifId);

                    // Resume playback if it was playing
                    if (wasPlaying) {
                        // Small delay to allow GIF to initialize
                        setTimeout(() => togglePlay_$chart_title(), 100);
                    }
                }
            }
        }

        function togglePlay_$chart_title() {
            if (!currentGif_$chart_title) return;

            isPlaying_$chart_title = !isPlaying_$chart_title;
            const btn = document.getElementById('play-btn-$chart_title');

            if (isPlaying_$chart_title) {
                btn.textContent = '⏸ Pause';
                currentGif_$chart_title.play();
            } else {
                btn.textContent = '▶ Play';
                currentGif_$chart_title.pause();
            }
        }

        function previousFrame_$chart_title() {
            if (!currentGif_$chart_title) return;

            const currentFrame = currentGif_$chart_title.get_current_frame();
            if (currentFrame > 0) {
                currentGif_$chart_title.move_to(currentFrame - 1);
                updateFrameCounter_$chart_title();
            }
        }

        function nextFrame_$chart_title() {
            if (!currentGif_$chart_title) return;

            const totalFrames = currentGif_$chart_title.get_length();
            const currentFrame = currentGif_$chart_title.get_current_frame();
            if (currentFrame < totalFrames - 1) {
                currentGif_$chart_title.move_to(currentFrame + 1);
                updateFrameCounter_$chart_title();
            }
        }

        function updateFrameCounter_$chart_title() {
            if (!currentGif_$chart_title) return;

            const counter = document.getElementById('frame-counter-$chart_title');
            if (counter) {
                const current = currentGif_$chart_title.get_current_frame() + 1;
                const total = currentGif_$chart_title.get_length();
                counter.textContent = `Frame \${current} / \${total}`;
            }
        }

        function toggleLoop_$chart_title() {
            const checkbox = document.getElementById('loop-checkbox-$chart_title');
            shouldLoop_$chart_title = checkbox.checked;

            if (currentGif_$chart_title) {
                // Update loop mode on current GIF
                currentGif_$chart_title.options.loop_mode = shouldLoop_$chart_title;
            }
        }

        function updateSpeed_$chart_title() {
            const slider = document.getElementById('speed-slider-$chart_title');
            const label = document.getElementById('speed-label-$chart_title');

            // Convert slider value (0-100) to delay using log scale (0.05s to 5s)
            const sliderVal = parseFloat(slider.value);
            const delaySeconds = 0.05 * Math.pow(10, sliderVal / 50);
            frameDelay_$chart_title = delaySeconds * 1000;
            label.textContent = delaySeconds.toFixed(2) + 's';

            if (currentGif_$chart_title) {
                // Update frame delay (override value in milliseconds per frame)
                currentGif_$chart_title.options.loop_delay = frameDelay_$chart_title;
            }
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            // Only trigger if not focused on input/select
            if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'SELECT') {
                if (e.key === 'ArrowLeft') {
                    e.preventDefault();
                    previousFrame_$chart_title();
                } else if (e.key === 'ArrowRight') {
                    e.preventDefault();
                    nextFrame_$chart_title();
                } else if (e.key === ' ') {
                    e.preventDefault();
                    togglePlay_$chart_title();
                } else if (e.key.toLowerCase() === 'l') {
                    e.preventDefault();
                    const checkbox = document.getElementById('loop-checkbox-$chart_title');
                    checkbox.checked = !checkbox.checked;
                    toggleLoop_$chart_title();
                }
            }
        });

        // Initialize on page load
        window.addEventListener('load', function() {
            switchGif_$chart_title();
        });

        // Expose functions globally
        window.switchGif_$chart_title = switchGif_$chart_title;
        window.togglePlay_$chart_title = togglePlay_$chart_title;
        window.previousFrame_$chart_title = previousFrame_$chart_title;
        window.nextFrame_$chart_title = nextFrame_$chart_title;
        window.toggleLoop_$chart_title = toggleLoop_$chart_title;
        window.updateSpeed_$chart_title = updateSpeed_$chart_title;
    })();
    """

    appearance_html = """
    <style>
        .gif-container-$chart_title {
            padding: 20px;
            margin: 10px 0;
        }

        .gif-display-area-$chart_title {
            text-align: center;
            background-color: #f5f5f5;
            padding: 20px;
            min-height: 400px;
            margin: 20px 0;
            border: 1px solid #ddd;
            border-radius: 5px;
            position: relative;
        }

        .gif-image-$chart_title {
            display: none;
            position: absolute;
            opacity: 0;
            pointer-events: none;
        }

        #gif_canvas_$chart_title {
            max-width: 100%;
            max-height: 600px;
            height: auto;
            margin: 0 auto;
            display: block;
        }

        .gif-controls-$chart_title {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 15px;
            padding: 15px;
            background-color: #f0f0f0;
            border-radius: 5px;
            flex-wrap: wrap;
        }

        .gif-controls-$chart_title button {
            padding: 8px 16px;
            font-size: 14px;
            border: 1px solid #ccc;
            background-color: white;
            cursor: pointer;
            border-radius: 4px;
        }

        .gif-controls-$chart_title button:hover {
            background-color: #e8e8e8;
        }

        .gif-controls-$chart_title button:active {
            background-color: #d0d0d0;
        }

        .speed-control-$chart_title {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .speed-control-$chart_title input[type="range"] {
            width: 150px;
        }

        .loop-control-$chart_title {
            display: flex;
            align-items: center;
            gap: 5px;
        }
    </style>

    <div class="gif-container-$chart_title">
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters -->
        $(filter_dropdowns_html != "" ? "<div style=\"margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;\">\n            <h4 style=\"margin-top: 0;\">Filters</h4>\n            $filter_dropdowns_html\n        </div>" : "")

        <!-- GIF Display Area -->
        <div class="gif-display-area-$chart_title">
            <!-- Hidden GIF images for libgif.js -->
            ___GIF_IMAGES___
            <!-- Canvas for rendering -->
            <canvas id="gif_canvas_$chart_title"></canvas>
        </div>

        <!-- Controls -->
        <div class="gif-controls-$chart_title">
            <button onclick="previousFrame_$chart_title()">◀ Prev Frame</button>
            <button id="play-btn-$chart_title" onclick="togglePlay_$chart_title()">▶ Play</button>
            <button onclick="nextFrame_$chart_title()">Next Frame ▶</button>
            <span id="frame-counter-$chart_title" style="font-weight: bold; min-width: 120px;">Frame 1 / 1</span>
            <div class="speed-control-$chart_title">
                <label for="speed-slider-$chart_title">Speed:</label>
                <input type="range" id="speed-slider-$chart_title"
                       min="0" max="100" step="1" value="$slider_value"
                       oninput="updateSpeed_$chart_title()">
                <span id="speed-label-$chart_title">$(round(delay, digits=2))s</span>
            </div>
            <div class="loop-control-$chart_title">
                <input type="checkbox" id="loop-checkbox-$chart_title"
                       $(loop ? "checked" : "")
                       onchange="toggleLoop_$chart_title()">
                <label for="loop-checkbox-$chart_title">Loop</label>
            </div>
        </div>

        <p style="margin-top: 10px; font-size: 0.9em; color: #666;">
            <strong>Keyboard shortcuts:</strong> ← Prev Frame, → Next Frame, Space Play/Pause, L Toggle Loop
        </p>
    </div>
    """

    return functional_html, appearance_html
end

"""
    generate_gif_html(gif::Gif, dataformat::Symbol, project_dir::String="")

Generate final HTML for Gif, handling GIF embedding or copying based on dataformat.
"""
function generate_gif_html(gif::Gif, dataformat::Symbol, project_dir::String="")
    # Generate all GIF image tags (hidden, used by libgif.js)
    gifs_html = ""

    for (key, filepath) in gif.file_mapping
        # Generate unique GIF ID
        gif_id = "gif_" * replace(basename(filepath), r"[^\w]" => "_")

        if dataformat in [:csv_embedded, :json_embedded]
            # Embed the GIF as base64
            gif_bytes = read(filepath)
            gif_base64 = base64encode(gif_bytes)

            gifs_html *= """<img class="gif-image-$(gif.chart_title)" id="$(gif_id)" src="data:image/gif;base64,$(gif_base64)" rel:animated_src="data:image/gif;base64,$(gif_base64)" rel:auto_play="0" />\n"""
        else
            # External format - copy to gifs/ subdirectory
            gifs_dir = joinpath(project_dir, "gifs")
            if !isdir(gifs_dir)
                mkpath(gifs_dir)
            end

            # Create destination path
            dest_filename = gif_id * ".gif"
            dest_path = joinpath(gifs_dir, dest_filename)

            # Copy the GIF file
            cp(filepath, dest_path, force=true)

            # Reference the external GIF
            gifs_html *= """<img class="gif-image-$(gif.chart_title)" id="$(gif_id)" src="gifs/$(dest_filename)" rel:animated_src="gifs/$(dest_filename)" rel:auto_play="0" />\n"""
        end
    end

    # Replace placeholder in appearance_html
    html = replace(gif.appearance_html, "___GIF_IMAGES___" => gifs_html)

    return html
end

dependencies(g::Gif) = [g.data_label]
