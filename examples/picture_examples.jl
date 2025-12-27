# Picture Examples - Single Images, Animated GIFs, and Filtered Image Viewing
# This file demonstrates various ways to use the Picture type in JSPlots.jl

using JSPlots
using DataFrames
using VegaLite
using StableRNGs

println("Creating Picture examples...")

# Set up consistent RNG for reproducible examples
rng = StableRNG(123)

# ========================================
# Example 1: Simple Picture from file path
# ========================================
# Note: This would work with any existing image file

example_image_path = joinpath(@__DIR__, "pictures", "images.jpeg")
pic1 = Picture(:example_image, example_image_path;
               notes="This is an example image loaded from a file path")

# ========================================
# Example 2: Animated GIF as a Picture
# ========================================
println("Creating animated GIF example...")


# Create a simple animated GIF using Plots.jl
using Plots
gr()  # Use GR backend




# Generate animation data
anim_data = @animate for i in 1:20
    x = range(0, 2π, length=100)
    y = sin.(x .+ i/3)
    plot(x, y, ylim=(-1.2, 1.2),
         title="Sine Wave Animation",
         xlabel="x", ylabel="sin(x + t)",
         legend=false, linewidth=2)
end

# Save as GIF
temp_gif_path = tempname() * ".gif"
gif(anim_data, temp_gif_path, fps=10)

gif_pic = Picture(:animated_sine_wave, temp_gif_path;
                  title="Animated Sine Wave",
                  notes="This is an animated GIF created with Plots.jl.")

# Note: Don't delete the temp file - Picture will handle cleanup automatically

# ========================================
# Example 3: Filtered Picture Viewer with VegaLite Charts
# ========================================
println("Creating VegaLite charts for filtered viewing...")

# Create sample sales data
regions = ["North", "South", "East", "West"]
quarters = ["Q1", "Q2", "Q3", "Q4"]
products = ["Widget", "Gadget", "Doohickey"]

# Create a temporary directory for our charts
charts_dir = mktempdir()

# Generate VegaLite charts for each region/quarter/product combination
chart_count = 0
for region in regions
    for quarter in quarters
        for product in products
            global chart_count
            # Generate random sales data for this combination
            months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            # Determine which months are in this quarter
            q_num = parse(Int, quarter[2:2])
            quarter_months = months[(q_num-1)*3+1:q_num*3]

            # Create sales data with some variation
            sales_values = Float64[]
            for (i, month) in enumerate(quarter_months)
                base = if region == "North"
                    rand(rng, 80:120)
                elseif region == "South"
                    rand(rng, 60:100)
                elseif region == "East"
                    rand(rng, 90:130)
                else  # West
                    rand(rng, 70:110)
                end

                # Product multiplier
                multiplier = if product == "Widget"
                    1.2
                elseif product == "Gadget"
                    1.0
                else  # Doohickey
                    0.8
                end

                push!(sales_values, base * multiplier)
            end

            # Create VegaLite chart
            df_sales = DataFrame(
                Month = quarter_months,
                Sales = sales_values
            )

            chart = df_sales |> @vlplot(
                :bar,
                x={:Month, axis={title="Month"}},
                y={:Sales, axis={title="Sales (thousands)"}},
                title="$(product) Sales - $(region) Region - $(quarter)",
                width=400,
                height=300,
                color={value="#4682B4"}
            )

            # Save chart with pattern: chart!Region!Quarter!Product.png
            filename = "chart!$(region)!$(quarter)!$(product).png"
            filepath = joinpath(charts_dir, filename)
            VegaLite.save(filepath, chart)
            chart_count += 1
        end
    end
end

println("  Created $chart_count VegaLite charts")

# Create filtered Picture viewer
# Files follow pattern: chart!Region!Quarter!Product.png
filtered_pic = Picture(:regional_sales_charts, charts_dir, "chart";
                       filters = Dict{Symbol,Any}(
                           :group_1 => "North",  # Region
                           :group_2 => "Q1",      # Quarter
                           :group_3 => "Widget"   # Product
                       ),
                       title="Regional Sales Dashboard",
                       notes="Use the filters above to explore sales data across different regions, quarters, and products. " *
                             "The charts are generated with VegaLite and show monthly sales trends.")

# ========================================
# Example 4: Simpler Filtered Example - Region and Quarter only
# ========================================
println("Creating simpler filtered example...")

# Create charts dir for simpler example
simple_charts_dir = mktempdir()

for region in ["North", "South"]
    for quarter in ["Q1", "Q2"]
        # Generate summary data
        q_num = parse(Int, quarter[2:2])

        # Create quarterly summary
        metrics = ["Revenue", "Costs", "Profit"]
        values = if region == "North"
            [rand(rng, 400:600), rand(rng, 200:300), rand(rng, 150:300)]
        else  # South
            [rand(rng, 300:500), rand(rng, 150:250), rand(rng, 100:250)]
        end

        df_summary = DataFrame(
            Metric = metrics,
            Amount = values
        )

        chart = df_summary |> @vlplot(
            :bar,
            x={:Metric, axis={title=""}},
            y={:Amount, axis={title="Amount (thousands)"}},
            title="$(region) Region - $(quarter) Summary",
            width=350,
            height=250,
            color={:Metric, scale={scheme="category10"}}
        )

        # Save with pattern: summary!Region!Quarter.png
        filename = "summary!$(region)!$(quarter).png"
        filepath = joinpath(simple_charts_dir, filename)
        VegaLite.save(filepath, chart)
    end
end

simple_filtered_pic = Picture(:quarterly_summary, simple_charts_dir, "summary";
                               filters = Dict{Symbol,Any}(
                                   :group_1 => "North",  # Region
                                   :group_2 => "Q1"      # Quarter
                               ),
                               title="Quarterly Business Summary",
                               notes="Compare quarterly performance across regions. Use the filters to switch between regions and quarters.")

# ========================================
# Create HTML page with all examples
# ========================================
println("Creating HTML page...")

# Create page with all picture examples
page = JSPlotPage(
    Dict{Symbol,DataFrame}(),
    [pic1, gif_pic, filtered_pic, simple_filtered_pic],
    dataformat=:csv_embedded
)

output_path = "generated_html_examples/picture_examples.html"
create_html(page, output_path)

println("Created: $output_path")
println()
println("Picture examples complete!")
println("Open the HTML file in a browser to see:")
println("  1. Animated GIF (sine wave)")
println("  2. Filtered VegaLite charts with 3 dimensions (Region × Quarter × Product)")
println("  3. Simpler filtered example with 2 dimensions (Region × Quarter)")
println()
println("The filtering feature allows you to generate multiple charts for different")
println("scenarios and let users interactively switch between them!")
