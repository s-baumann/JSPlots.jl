using JSPlots, DataFrames, Dates, Plots, StableRNGs
rng = StableRNG(444)

println("Creating Gif examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/gif_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Gif Examples</h1>
<p>This page demonstrates the interactive Gif chart type in JSPlots.</p>
<ul>
    <li><strong>Frame-by-frame control:</strong> Navigate through GIF frames with precision</li>
    <li><strong>Interactive controls:</strong> Play/pause, previous/next frame, speed control</li>
    <li><strong>Loop control:</strong> Toggle looping on/off</li>
    <li><strong>Filtering:</strong> Switch between different GIFs while maintaining frame position</li>
    <li><strong>Keyboard shortcuts:</strong> ← → for frame navigation, Space for play/pause, L for loop toggle</li>
</ul>
""")

# =============================================================================
# Create sample GIF animations
# =============================================================================

gifs_dir = joinpath(@__DIR__, "gifs")
if !isdir(gifs_dir)
    mkpath(gifs_dir)
end

println("Creating sample GIF animations using Plots.jl...")

# Create sample GIFs with the pattern: prefix!group1!group2.gif
regions = ["North", "South"]
quarters = ["Q1", "Q2"]
colors_map = Dict("North" => :blue, "South" => :red,
                  "Q1" => :green, "Q2" => :purple)

for region in regions
    for quarter in quarters
        region_color = colors_map[region]
        quarter_color = colors_map[quarter]

        # Create a simple animated plot
        filename = "animation!$(region)!$(quarter).gif"
        filepath = joinpath(gifs_dir, filename)

        # Different animations for different combinations
        if region == "North" && quarter == "Q1"
            # Sine wave animation
            anim = @animate for t in 1:48
                plot(0:0.1:4π, x -> sin(x + t/8),
                     label="$region - $quarter",
                     color=region_color,
                     ylim=(-1.5, 1.5),
                     xlabel="x",
                     ylabel="sin(x + t/8)",
                     title="Sine Wave Animation\n$region - $quarter",
                     legend=:topright,
                     grid=true,
                     linewidth=2)
            end
        elseif region == "North" && quarter == "Q2"
            # Cosine wave animation
            anim = @animate for t in 1:48
                plot(0:0.1:4π, x -> cos(x + t/8),
                     label="$region - $quarter",
                     color=quarter_color,
                     ylim=(-1.5, 1.5),
                     xlabel="x",
                     ylabel="cos(x + t/8)",
                     title="Cosine Wave Animation\n$region - $quarter",
                     legend=:topright,
                     grid=true,
                     linewidth=2)
            end
        elseif region == "South" && quarter == "Q1"
            # Growing circle animation
            anim = @animate for t in 1:48
                θ = range(0, 2π, length=100)
                r = 0.5 + 0.5 * sin(t/8)
                x = r .* cos.(θ)
                y = r .* sin.(θ)
                plot(x, y,
                     label="$region - $quarter",
                     color=region_color,
                     xlim=(-1.2, 1.2),
                     ylim=(-1.2, 1.2),
                     aspect_ratio=:equal,
                     title="Pulsing Circle\n$region - $quarter",
                     legend=:topright,
                     grid=true,
                     linewidth=2,
                     fill=(0, 0.3, region_color))
            end
        else  # South && Q2
            # Spiral animation
            anim = @animate for t in 1:48
                θ = range(0, 4π, length=200)
                r = range(0, 1, length=200) .+ t/50
                x = r .* cos.(θ)
                y = r .* sin.(θ)
                plot(x, y,
                     label="$region - $quarter",
                     color=quarter_color,
                     xlim=(-2, 2),
                     ylim=(-2, 2),
                     aspect_ratio=:equal,
                     title="Spiral Animation\n$region - $quarter",
                     legend=:topright,
                     grid=true,
                     linewidth=2)
            end
        end

        # Save the animation as GIF
        gif(anim, filepath, fps=10)
        println("  Created: $filename")
    end
end

println("Created $(length(regions) * length(quarters)) GIF files")

# =============================================================================
# Example 1: Basic Gif from Directory Pattern
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Basic Gif from Directory Pattern</h2>
<p>This example loads GIF files from a directory following the pattern: <code>prefix!group1!group2!...!groupN.gif</code></p>
<p>The GIFs below were created with the pattern: <code>animation!Region!Quarter.gif</code></p>
<p>Features:</p>
<ul>
    <li>Automatic detection of filter groups from filename structure</li>
    <li>Play/Pause controls with frame-by-frame navigation</li>
    <li>Speed slider (0.05s to 5s per frame on log scale)</li>
    <li>Loop toggle checkbox</li>
    <li>Keyboard shortcuts: ← → for frames, Space for play/pause, L for loop</li>
    <li><strong>Frame preservation:</strong> When you change filters, the viewer jumps to the same frame number in the new GIF</li>
</ul>
""")

# Create Gif from directory pattern
gif1 = Gif(:animation_gifs, gifs_dir, "animation";
    filters = Dict{Symbol,Any}(:group_1 => "North", :group_2 => "Q1"),
    title = "Animated Plots by Region and Quarter",
    notes = "Use filters to switch between regions and quarters. Notice how the frame position is preserved when switching!",
    autoplay = false,
    delay = 0.1,
    loop = true
)

# =============================================================================
# Example 2: Multiple Gifs with Different Filters
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Gif with Autoplay Enabled</h2>
<p>This example demonstrates the autoplay feature. The GIF starts playing automatically when the page loads.</p>
<p>Try the following:</p>
<ol>
    <li>Let it play automatically for a few frames</li>
    <li>Click "Pause" to stop it</li>
    <li>Use "Prev Frame" and "Next Frame" to navigate manually</li>
    <li>Change the filter to see a different animation (frame position will be preserved!)</li>
    <li>Adjust the speed slider to control playback speed</li>
    <li>Uncheck "Loop" to make it play only once</li>
</ol>
""")

# Create Gif with autoplay
gif2 = Gif(:autoplay_gifs, gifs_dir, "animation";
    filters = Dict{Symbol,Any}(:group_1 => "South", :group_2 => "Q2"),
    title = "Autoplay Example - Spiral Animation",
    notes = "This GIF starts playing automatically. Try changing filters while it's playing!",
    autoplay = true,
    delay = 0.08,
    loop = true
)

# =============================================================================
# Example 3: Fast Animation
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Fast Animation with Short Delay</h2>
<p>This example uses a very short delay (0.05s) for rapid playback.</p>
<p>The speed slider allows you to adjust from 0.05s to 5s per frame using a logarithmic scale.</p>
""")

gif3 = Gif(:fast_gifs, gifs_dir, "animation";
    filters = Dict{Symbol,Any}(:group_1 => "North", :group_2 => "Q2"),
    title = "Fast Animation - Cosine Wave",
    notes = "This animation plays quickly. Use the speed slider to slow it down if needed.",
    autoplay = false,
    delay = 0.05,
    loop = true
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The Gif chart type provides:</p>
<ul>
    <li><strong>Frame-by-frame control:</strong> Navigate through GIF frames precisely with Previous/Next buttons</li>
    <li><strong>libgif.js integration:</strong> Client-side GIF parsing for true frame control</li>
    <li><strong>Play controls:</strong> Play/Pause with adjustable speed (logarithmic scale from 0.05s to 5s)</li>
    <li><strong>Loop control:</strong> Toggle looping on/off with checkbox or 'L' key</li>
    <li><strong>Filter groups:</strong> Organize multiple GIFs by categories</li>
    <li><strong>Frame preservation:</strong> Maintains frame position when switching between GIFs</li>
    <li><strong>Keyboard shortcuts:</strong>
        <ul>
            <li>Left Arrow: Previous frame</li>
            <li>Right Arrow: Next frame</li>
            <li>Space: Play/Pause toggle</li>
            <li>L: Loop toggle</li>
        </ul>
    </li>
    <li><strong>Data format support:</strong> Works with both embedded (base64) and external storage</li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li>Animated data visualizations (time series, simulations)</li>
    <li>Step-by-step tutorials or walkthroughs</li>
    <li>Before/after comparisons with transitions</li>
    <li>Scientific animations (physics simulations, molecular dynamics)</li>
    <li>Algorithm visualizations</li>
</ul>
""")

# =============================================================================
# Create the page
# =============================================================================

# Output to the main generated_html_examples directory (not in examples/)
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end

# Create embedded format (single HTML file with all GIFs included)
page = JSPlotPage(
    Dict{Symbol, DataFrame}(),
    [header, example1_text, gif1, example2_text, gif2, example3_text, gif3, summary];
    dataformat=:csv_embedded
)

output_file = joinpath(output_dir, "gif_examples.html")
create_html(page, output_file)
println("Created: $output_file")

println("\nGif examples complete!")
println("Open the HTML file in a browser to see the interactive GIF viewers.")
println("All GIFs are embedded as base64-encoded data in the HTML file.")
