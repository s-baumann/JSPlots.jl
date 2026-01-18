using Test
using JSPlots
using DataFrames

@testset "GeoPlot" begin
    @testset "Points mode - basic creation" begin
        # Create sample data with coordinates
        df = DataFrame(
            latitude = [40.7128, 34.0522, 41.8781, 29.7604, 33.4484],
            longitude = [-74.0060, -118.2437, -87.6298, -95.3698, -112.0740],
            city = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix"],
            population = [8336817, 3979576, 2693976, 2320268, 1680992]
        )

        geo = GeoPlot(:test_points, df, :cities;
            lat = :latitude,
            lon = :longitude,
            title = "US Cities"
        )

        @test geo.chart_title == :test_points
        @test geo.data_label == :cities
        @test geo.mode == :points
        @test !isempty(geo.functional_html)
        @test !isempty(geo.appearance_html)

        # Check for Leaflet-related content
        @test occursin("L.map", geo.functional_html)
        @test occursin("L.tileLayer", geo.functional_html)
        @test occursin("L.circleMarker", geo.functional_html)
    end

    @testset "Points mode - with color and size" begin
        df = DataFrame(
            lat = [40.7, 34.0, 41.8],
            lon = [-74.0, -118.2, -87.6],
            magnitude = [5.5, 3.2, 4.1],
            depth = [10, 25, 15]
        )

        geo = GeoPlot(:colored_points, df, :earthquakes;
            lat = :lat,
            lon = :lon,
            color = :magnitude,
            size = :depth,
            title = "Earthquake Data"
        )

        @test geo.mode == :points
        @test occursin("COLOR_COL", geo.functional_html)
        @test occursin("SIZE_COL", geo.functional_html)
        @test occursin("magnitude", geo.functional_html)
        @test occursin("depth", geo.functional_html)
    end

    @testset "Points mode - with popup columns" begin
        df = DataFrame(
            lat = [40.7, 34.0],
            lon = [-74.0, -118.2],
            name = ["NYC", "LA"],
            info = ["Big Apple", "City of Angels"]
        )

        geo = GeoPlot(:popup_test, df, :cities;
            lat = :lat,
            lon = :lon,
            popup_cols = [:name, :info],
            title = "Cities with Info"
        )

        @test occursin("POPUP_COLS", geo.functional_html)
        @test occursin("name", geo.functional_html)
        @test occursin("info", geo.functional_html)
    end

    @testset "Choropleth mode - US states" begin
        df = DataFrame(
            state = ["California", "Texas", "Florida", "New York"],
            population = [39538223, 29145505, 21538187, 20201249]
        )

        geo = GeoPlot(:us_pop, df, :state_data;
            region = :state,
            value_cols = [:population],
            region_type = :us_states,
            title = "US Population by State"
        )

        @test geo.mode == :choropleth
        @test occursin("GEOJSON_URL", geo.functional_html)
        @test occursin("us-states.json", geo.functional_html)
        @test occursin("REGION_COL", geo.functional_html)
        @test occursin("VALUE_COL", geo.functional_html)
        @test occursin("L.geoJSON", geo.functional_html)
    end

    @testset "Choropleth mode - world countries" begin
        df = DataFrame(
            country = ["United States", "China", "India", "Brazil"],
            gdp = [21433.23, 14722.84, 2875.14, 1839.76]
        )

        geo = GeoPlot(:world_gdp, df, :country_data;
            region = :country,
            value_cols = [:gdp],
            region_type = :world_countries,
            title = "World GDP"
        )

        @test geo.mode == :choropleth
        @test occursin("world-atlas", geo.functional_html)
    end

    @testset "Choropleth mode - custom GeoJSON URL" begin
        df = DataFrame(
            region_id = ["A", "B", "C"],
            value = [100, 200, 150]
        )

        geo = GeoPlot(:custom_geo, df, :custom_data;
            region = :region_id,
            value_cols = [:value],
            geojson_url = "https://example.com/custom.geojson",
            region_key = "id",
            title = "Custom Regions"
        )

        @test geo.mode == :choropleth
        @test occursin("example.com/custom.geojson", geo.functional_html)
        @test occursin("REGION_KEY", geo.functional_html)
    end

    @testset "Color scales" begin
        df = DataFrame(
            state = ["California", "Texas"],
            value = [100, 200]
        )

        # Test viridis (default)
        geo_viridis = GeoPlot(:viridis_test, df, :data;
            region = :state,
            value_cols = [:value],
            region_type = :us_states,
            color_scale = :viridis
        )
        @test occursin("#440154", geo_viridis.functional_html)  # Viridis starts with this color

        # Test blues
        geo_blues = GeoPlot(:blues_test, df, :data;
            region = :state,
            value_cols = [:value],
            region_type = :us_states,
            color_scale = :blues
        )
        @test occursin("#f7fbff", geo_blues.functional_html)  # Blues starts with this color
    end

    @testset "Map controls" begin
        df = DataFrame(
            lat = [51.5074],
            lon = [-0.1278]
        )

        geo = GeoPlot(:london, df, :data;
            lat = :lat,
            lon = :lon,
            title = "London"
        )

        # Map auto-zooms to data bounds and has controls
        @test occursin("fitBounds", geo.functional_html)
        @test occursin("aspect_ratio_slider", geo.appearance_html)
        @test occursin("zoom_slider", geo.appearance_html)
        @test occursin("updateZoomSlider", geo.functional_html)
    end

    @testset "Filters support" begin
        df = DataFrame(
            lat = [40.7, 34.0, 41.8, 29.7],
            lon = [-74.0, -118.2, -87.6, -95.3],
            region = ["East", "West", "Midwest", "South"],
            year = [2020, 2020, 2021, 2021]
        )

        geo = GeoPlot(:filtered_map, df, :data;
            lat = :lat,
            lon = :lon,
            filters = [:region, :year],
            title = "Filtered Cities"
        )

        @test occursin("CATEGORICAL_FILTERS", geo.functional_html)
        @test occursin("region", geo.appearance_html)
        @test occursin("year", geo.appearance_html)
    end

    @testset "dependencies function" begin
        df = DataFrame(lat = [40.7], lon = [-74.0])

        geo = GeoPlot(:deps_test, df, :my_data;
            lat = :lat,
            lon = :lon
        )

        deps = dependencies(geo)
        @test :my_data in deps
    end

    @testset "Error handling - missing required columns" begin
        df = DataFrame(x = [1, 2, 3], y = [4, 5, 6])

        # Missing lat/lon for points mode
        @test_throws ErrorException GeoPlot(:error_test, df, :data;
            lat = :latitude,  # doesn't exist
            lon = :longitude
        )
    end

    @testset "Error handling - no mode specified" begin
        df = DataFrame(x = [1, 2, 3])

        # Neither points nor choropleth mode
        @test_throws ErrorException GeoPlot(:error_test, df, :data;
            title = "No mode"
        )
    end

    @testset "Error handling - choropleth without region_type" begin
        df = DataFrame(region = ["A", "B"], value = [1, 2])

        # Choropleth without region_type or geojson_url
        @test_throws ErrorException GeoPlot(:error_test, df, :data;
            region = :region,
            value_cols = [:value]
        )
    end

    @testset "Error handling - invalid region_type" begin
        df = DataFrame(region = ["A", "B"], value = [1, 2])

        @test_throws ErrorException GeoPlot(:error_test, df, :data;
            region = :region,
            value_cols = [:value],
            region_type = :invalid_type
        )
    end

    @testset "get_geojson_url function" begin
        # Test known region types
        @test JSPlots.get_geojson_url(:us_states, nothing) == "https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json"
        @test JSPlots.get_geojson_url(:world_countries, nothing) == "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json"
        @test JSPlots.get_geojson_url(:us_counties, nothing) == "https://cdn.jsdelivr.net/npm/us-atlas@3/counties-10m.json"

        # Custom URL takes precedence
        @test JSPlots.get_geojson_url(:us_states, "https://custom.url") == "https://custom.url"

        # Unknown region type throws error
        @test_throws ErrorException JSPlots.get_geojson_url(:unknown_type, nothing)
    end

    @testset "HTML generation for page integration" begin
        df = DataFrame(
            lat = [40.7, 34.0],
            lon = [-74.0, -118.2],
            value = [100, 200]
        )

        geo = GeoPlot(:page_test, df, :page_data;
            lat = :lat,
            lon = :lon,
            color = :value,
            title = "Page Integration Test"
        )

        mktempdir() do tmpdir
            page = JSPlotPage(
                Dict{Symbol, Any}(:page_data => df),
                [geo];
                dataformat = :csv_embedded
            )

            output_file = joinpath(tmpdir, "geo_test.html")
            create_html(page, output_file)

            @test isfile(output_file)

            html_content = read(output_file, String)
            @test occursin("Page Integration Test", html_content)
            @test occursin("leaflet", html_content)
            @test occursin("map_page_test", html_content)
        end
    end

    @testset "TopoJSON conversion support" begin
        df = DataFrame(
            state = ["California", "Texas"],
            value = [100, 200]
        )

        geo = GeoPlot(:topojson_test, df, :data;
            region = :state,
            value_cols = [:value],
            region_type = :us_states
        )

        # Check for TopoJSON handling code
        @test occursin("topojson.feature", geo.functional_html)
        @test occursin("Topology", geo.functional_html)
    end
end

println("GeoPlot tests completed successfully!")
