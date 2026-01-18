# GeoPlot Examples - Geographic Maps with Points and Choropleth Regions
# This file demonstrates various ways to use the GeoPlot type in JSPlots.jl

using JSPlots
using DataFrames
using StableRNGs

println("Creating GeoPlot examples...")

# Set up consistent RNG for reproducible examples
rng = StableRNG(456)

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/geoplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>GeoPlot Examples</h1>
<p>This page demonstrates the GeoPlot chart type in JSPlots for geographic data visualization.</p>
<p>GeoPlot supports two modes:</p>
<ul>
    <li><strong>Points Mode:</strong> Display markers at latitude/longitude coordinates</li>
    <li><strong>Choropleth Mode:</strong> Shade regions by value (countries, states, etc.)</li>
</ul>
<p><strong>Note:</strong> Maps require an internet connection to load tiles and boundary data from CDNs.</p>
""")

# ========================================
# Example 1: Points Mode - US Cities
# ========================================
println("Creating US Cities example (Points Mode)...")

# Major US cities with population data
cities_df = DataFrame(
    city = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix",
            "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose",
            "Austin", "Jacksonville", "Fort Worth", "Columbus", "Charlotte"],
    latitude = [40.7128, 34.0522, 41.8781, 29.7604, 33.4484,
                39.9526, 29.4241, 32.7157, 32.7767, 37.3382,
                30.2672, 30.3322, 32.7555, 39.9612, 35.2271],
    longitude = [-74.0060, -118.2437, -87.6298, -95.3698, -112.0740,
                 -75.1652, -98.4936, -117.1611, -96.7970, -121.8863,
                 -97.7431, -81.6557, -97.3308, -82.9988, -80.8431],
    population_millions = [8.34, 3.98, 2.69, 2.32, 1.68,
                          1.58, 1.55, 1.42, 1.34, 1.01,
                          0.98, 0.91, 0.91, 0.88, 0.87],
    region = ["Northeast", "West", "Midwest", "South", "West",
              "Northeast", "South", "West", "South", "West",
              "South", "South", "South", "Midwest", "South"]
)

cities_map = GeoPlot(:us_cities, cities_df, :cities_data;
    lat = :latitude,
    lon = :longitude,
    color = :population_millions,
    popup_cols = [:city, :region],
    filters = [:region],
    color_scale = :viridis,
    title = "Major US Cities by Population",
    notes = "Marker size and color indicate population in millions. Click on markers for details. Use the filter to show cities by region."
)

# ========================================
# Example 2: Choropleth - US States Population
# ========================================
println("Creating US States Population example (Choropleth Mode)...")

# US state population data (2020 census, in millions)
states_df = DataFrame(
    state = ["California", "Texas", "Florida", "New York", "Pennsylvania",
             "Illinois", "Ohio", "Georgia", "North Carolina", "Michigan",
             "New Jersey", "Virginia", "Washington", "Arizona", "Massachusetts",
             "Tennessee", "Indiana", "Missouri", "Maryland", "Wisconsin",
             "Colorado", "Minnesota", "South Carolina", "Alabama", "Louisiana",
             "Kentucky", "Oregon", "Oklahoma", "Connecticut", "Utah",
             "Iowa", "Nevada", "Arkansas", "Mississippi", "Kansas",
             "New Mexico", "Nebraska", "Idaho", "West Virginia", "Hawaii",
             "New Hampshire", "Maine", "Rhode Island", "Montana", "Delaware",
             "South Dakota", "North Dakota", "Alaska", "Vermont", "Wyoming"],
    population = [39.54, 29.15, 21.54, 20.20, 13.00,
                  12.81, 11.80, 10.71, 10.44, 10.08,
                  9.29, 8.63, 7.71, 7.15, 7.03,
                  6.91, 6.79, 6.15, 6.18, 5.89,
                  5.77, 5.71, 5.12, 5.02, 4.66,
                  4.51, 4.24, 3.96, 3.61, 3.27,
                  3.19, 3.10, 3.01, 2.96, 2.94,
                  2.12, 1.96, 1.90, 1.79, 1.46,
                  1.38, 1.36, 1.10, 1.08, 0.99,
                  0.89, 0.78, 0.73, 0.64, 0.58]
)

states_map = GeoPlot(:us_states_pop, states_df, :states_data;
    region = :state,
    value_cols = [:population],
    region_type = :us_states,
    region_key = "name",
    color_scale = :plasma,
    title = "US State Population (2020 Census)",
    notes = "Population in millions. Hover over states to see values. Data from 2020 US Census."
)

# ========================================
# Example 3: World Countries - GDP
# ========================================
println("Creating World GDP example (Choropleth Mode)...")

# Top 30 countries by GDP (nominal, 2023 estimates in trillion USD)
world_gdp_df = DataFrame(
    country = ["United States", "China", "Germany", "Japan", "India",
               "United Kingdom", "France", "Italy", "Brazil", "Canada",
               "Russia", "Mexico", "South Korea", "Australia", "Spain",
               "Indonesia", "Netherlands", "Saudi Arabia", "Turkey", "Switzerland",
               "Poland", "Argentina", "Sweden", "Belgium", "Ireland",
               "Norway", "Israel", "Austria", "United Arab Emirates", "Thailand"],
    gdp_trillion = [25.46, 17.96, 4.07, 4.23, 3.39,
                    3.07, 2.78, 2.01, 1.92, 2.14,
                    1.78, 1.32, 1.67, 1.68, 1.42,
                    1.32, 1.01, 1.07, 0.91, 0.81,
                    0.69, 0.63, 0.59, 0.58, 0.53,
                    0.48, 0.52, 0.47, 0.51, 0.50]
)

world_map = GeoPlot(:world_gdp, world_gdp_df, :gdp_data;
    region = :country,
    value_cols = [:gdp_trillion],
    region_type = :world_countries,
    region_key = "name",
    color_scale = :turbo,
    title = "World GDP by Country (2023)",
    notes = "GDP in trillion USD (nominal). Countries without data shown in gray. Data from IMF estimates."
)

# ========================================
# Example 4: Points with Size - Earthquake Data
# ========================================
println("Creating Earthquake example (Points with Size)...")

# Simulated earthquake data around the Pacific Ring of Fire
n_quakes = 50
earthquake_df = DataFrame(
    latitude = vcat(
        35.0 .+ randn(rng, 10) * 2,   # Japan
        -5.0 .+ randn(rng, 10) * 3,   # Indonesia
        -33.0 .+ randn(rng, 10) * 2,  # Chile
        37.0 .+ randn(rng, 10) * 2,   # California
        61.0 .+ randn(rng, 10) * 2    # Alaska
    ),
    longitude = vcat(
        140.0 .+ randn(rng, 10) * 2,  # Japan
        120.0 .+ randn(rng, 10) * 5,  # Indonesia
        -71.0 .+ randn(rng, 10) * 1,  # Chile
        -122.0 .+ randn(rng, 10) * 1, # California
        -150.0 .+ randn(rng, 10) * 3  # Alaska
    ),
    magnitude = 3.0 .+ rand(rng, n_quakes) * 4.5,
    depth_km = 5 .+ rand(rng, n_quakes) * 200,
    region = vcat(
        fill("Japan", 10),
        fill("Indonesia", 10),
        fill("Chile", 10),
        fill("California", 10),
        fill("Alaska", 10)
    )
)

earthquake_map = GeoPlot(:earthquakes, earthquake_df, :quake_data;
    lat = :latitude,
    lon = :longitude,
    color = :magnitude,
    size = :depth_km,
    popup_cols = [:region],
    filters = [:region],
    color_scale = :reds,
    title = "Simulated Earthquake Data - Pacific Ring of Fire",
    notes = "Color indicates magnitude (darker = stronger). Size indicates depth (larger = deeper). " *
            "Filter by region to focus on specific areas. This is simulated data for demonstration."
)

# ========================================
# Example 5: Simple Points - Global Offices
# ========================================
println("Creating Global Offices example...")

offices_df = DataFrame(
    office = ["New York HQ", "London", "Tokyo", "Sydney", "São Paulo", "Dubai"],
    latitude = [40.7580, 51.5074, 35.6762, -33.8688, -23.5505, 25.2048],
    longitude = [-73.9855, -0.1278, 139.6503, 151.2093, -46.6333, 55.2708],
    employees = [500, 250, 180, 120, 80, 60],
    type = ["Headquarters", "Regional", "Regional", "Regional", "Regional", "Regional"]
)

offices_map = GeoPlot(:offices, offices_df, :office_data;
    lat = :latitude,
    lon = :longitude,
    color = :employees,
    popup_cols = [:office, :type],
    filters = [:type],
    color_scale = :blues,
    title = "Global Office Locations",
    notes = "Click on markers to see office details. Color intensity indicates number of employees."
)

# ========================================
# Example 6: Multiple Overlays - Country Statistics
# ========================================
println("Creating Multiple Overlays example...")

# Country data with multiple metrics that can be switched between
country_stats_df = DataFrame(
    country = ["United States", "China", "India", "Brazil", "Russia",
               "Japan", "Germany", "United Kingdom", "France", "Italy",
               "Canada", "Australia", "Spain", "Mexico", "Indonesia"],
    population_millions = [331.0, 1412.0, 1408.0, 214.0, 144.0,
                          125.0, 83.0, 67.0, 65.0, 59.0,
                          38.0, 26.0, 47.0, 129.0, 274.0],
    area_million_km2 = [9.83, 9.60, 3.29, 8.52, 17.10,
                        0.38, 0.36, 0.24, 0.64, 0.30,
                        9.98, 7.69, 0.51, 1.96, 1.90],
    gdp_per_capita_usd = [76399, 12720, 2410, 8920, 12195,
                          33815, 48636, 45850, 43659, 34085,
                          52722, 64491, 30103, 10045, 4788]
)

# Multi-overlay map - user can switch between Population, Area, and GDP per Capita
multi_overlay_map = GeoPlot(:country_stats, country_stats_df, :country_stats_data;
    region = :country,
    value_cols = [:population_millions, :area_million_km2, :gdp_per_capita_usd],  # Multiple overlays!
    region_type = :world_countries,
    region_key = "name",
    color_scale = :viridis,
    title = "Country Statistics - Multiple Overlays",
    notes = "Use the Overlay dropdown to switch between Population, Area, and GDP per Capita. " *
            "This demonstrates how to provide multiple data columns that users can switch between."
)

# ========================================
# Create HTML page with all examples
# ========================================
println("Creating HTML page...")

# Combine all data
all_data = Dict{Symbol, Any}(
    :cities_data => cities_df,
    :states_data => states_df,
    :gdp_data => world_gdp_df,
    :quake_data => earthquake_df,
    :office_data => offices_df,
    :country_stats_data => country_stats_df
)

# Create page with all examples
page = JSPlotPage(
    all_data,
    [header, cities_map, states_map, world_map, earthquake_map, offices_map, multi_overlay_map],
    dataformat=:csv_embedded
)

output_path = "generated_html_examples/geoplot_examples.html"
create_html(page, output_path)

println("Created: $output_path")
println()
println("GeoPlot examples complete!")
println("Open the HTML file in a browser to see:")
println("  1. US Cities - Points with color by population")
println("  2. US States Population - Choropleth map")
println("  3. World GDP - Choropleth of countries")
println("  4. Earthquake Data - Points with color and size")
println("  5. Global Offices - Simple points example")
println()