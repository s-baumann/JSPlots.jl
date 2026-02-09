"""
    GeoPlot - Interactive geographic visualization with points and choropleth regions

Create interactive maps with markers (points) and/or choropleth shading (regions).
Uses Leaflet.js with OpenStreetMap tiles for rendering. The map automatically zooms
to fit the data on initial load.

# Two Modes

## Points Mode
Display markers at geographic coordinates:
```julia
geo = GeoPlot(:earthquakes, df, :data;
    lat = :latitude,
    lon = :longitude,
    color = :magnitude,      # optional: color markers by value
    size = :depth,           # optional: size markers by value
    title = "Earthquake Locations"
)
```

## Choropleth Mode
Shade regions by value (supports multiple overlay options):
```julia
# Single overlay
geo = GeoPlot(:population, df, :data;
    region = :state_name,    # column with region names like "Minnesota"
    value_cols = [:population],  # column with values to shade by
    region_type = :us_states,
    title = "US Population by State"
)

# Multiple overlays with dropdown to switch between them
geo = GeoPlot(:stats, df, :data;
    region = :state_name,
    value_cols = [:population, :area_sq_km, :gdp],  # user can switch between these
    region_type = :us_states,
    title = "US State Statistics"
)
```

# Supported Region Types
- `:world_countries` - World countries (Natural Earth)
- `:us_states` - US states
- `:us_counties` - US counties (FIPS codes)

# Custom GeoJSON
For regions not in the built-in list:
```julia
geo = GeoPlot(:custom, df, :data;
    region = :territory_id,
    value_cols = [:revenue],
    geojson_url = "https://example.com/territories.geojson",
    region_key = "id"  # property in GeoJSON to match against
)
```
"""
struct GeoPlot <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    mode::Symbol  # :points or :choropleth

    function GeoPlot(chart_title::Symbol, df::DataFrame, data_label::Symbol;
                     # Points mode parameters
                     lat::Union{Nothing, Symbol}=nothing,
                     lon::Union{Nothing, Symbol}=nothing,
                     color::Union{Nothing, Symbol}=nothing,
                     size::Union{Nothing, Symbol}=nothing,
                     popup_cols::Vector{Symbol}=Symbol[],
                     # Choropleth mode parameters
                     region::Union{Nothing, Symbol}=nothing,
                     value_cols::Vector{Symbol}=Symbol[],    # overlay columns (use dropdown to switch)
                     region_type::Union{Nothing, Symbol}=nothing,
                     geojson_url::Union{Nothing, String}=nothing,
                     region_key::String="name",
                     # Common parameters
                     color_scale::Symbol=:viridis,
                     filters::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                     choices::Union{Vector{Symbol}, Dict}=Dict{Symbol, Any}(),
                     title::String="Geographic Map",
                     notes::String="")

        # Determine mode based on parameters
        has_points = lat !== nothing && lon !== nothing
        has_choropleth = region !== nothing && !isempty(value_cols)

        if !has_points && !has_choropleth
            error("GeoPlot requires either (lat, lon) for points mode or (region, value_cols, region_type) for choropleth mode")
        end

        mode = has_points ? :points : :choropleth

        # Validate columns
        if has_points
            validate_column(df, lat, "lat")
            validate_column(df, lon, "lon")
            if color !== nothing
                validate_column(df, color, "color")
            end
            if size !== nothing
                validate_column(df, size, "size")
            end
            for col in popup_cols
                validate_column(df, col, "popup_cols")
            end
        end

        if has_choropleth
            validate_column(df, region, "region")
            for col in value_cols
                validate_column(df, col, "value_cols")
            end

            # Validate region_type or geojson_url
            if region_type === nothing && geojson_url === nothing
                error("Choropleth mode requires either region_type or geojson_url")
            end
        end

        default_value_col = isempty(value_cols) ? nothing : value_cols[1]

        # Normalize filters
        normalized_filters = normalize_filters(filters, df)
        normalized_choices = normalize_choices(choices, df)

        # Build filter controls
        update_function = "updateMap_$(chart_title)()"
        filter_dropdowns, filter_sliders = build_filter_dropdowns(string(chart_title), normalized_filters, df, update_function)
        choice_dropdowns = build_choice_dropdowns(string(chart_title), normalized_choices, df, update_function)
        filters_html = join([generate_dropdown_html(dd, multiselect=true) for dd in filter_dropdowns], "\n") *
                       join([generate_range_slider_html(sl) for sl in filter_sliders], "\n")

        categorical_filter_cols = [col for col in keys(normalized_filters) if !is_continuous_column(df, col)]
        continuous_filter_cols = [col for col in keys(normalized_filters) if is_continuous_column(df, col)]
        choice_cols = collect(keys(normalized_choices))

        categorical_filters_js = build_js_array(categorical_filter_cols)
        continuous_filters_js = build_js_array(continuous_filter_cols)
        choice_filters_js = build_js_array(choice_cols)

        # Get GeoJSON URL for region type
        geojson_source = get_geojson_url(region_type, geojson_url)

        # Color scales for choropleth
        color_scales = Dict(
            :viridis => ["#440154", "#482878", "#3e4989", "#31688e", "#26838f", "#1f9e89", "#35b779", "#6ece58", "#b5de2b", "#fde725"],
            :blues => ["#f7fbff", "#deebf7", "#c6dbef", "#9ecae1", "#6baed6", "#4292c6", "#2171b5", "#08519c", "#08306b"],
            :reds => ["#fff5f0", "#fee0d2", "#fcbba1", "#fc9272", "#fb6a4a", "#ef3b2c", "#cb181d", "#a50f15", "#67000d"],
            :greens => ["#f7fcf5", "#e5f5e0", "#c7e9c0", "#a1d99b", "#74c476", "#41ab5d", "#238b45", "#006d2c", "#00441b"],
            :plasma => ["#0d0887", "#46039f", "#7201a8", "#9c179e", "#bd3786", "#d8576b", "#ed7953", "#fb9f3a", "#fdca26", "#f0f921"],
            :turbo => ["#30123b", "#4662d7", "#36aaf9", "#1ae4b6", "#72fe5e", "#c8ef34", "#faba39", "#f66b19", "#ca2a04", "#7a0403"]
        )
        color_palette = get(color_scales, color_scale, color_scales[:viridis])
        color_palette_js = JSON.json(color_palette)

        # Build popup columns array for JavaScript
        popup_cols_js = build_js_array(popup_cols)

        # Build value columns array for JavaScript
        value_cols_js = build_js_array(String.(value_cols))
        default_value_col_str = default_value_col !== nothing ? string(default_value_col) : ""

        # Mode-specific JavaScript configuration
        mode_config = if mode == :points
            lat_col = string(lat)
            lon_col = string(lon)
            color_col = color !== nothing ? string(color) : "null"
            size_col = size !== nothing ? string(size) : "null"
            """
            const MODE = 'points';
            const LAT_COL = '$lat_col';
            const LON_COL = '$lon_col';
            const COLOR_COL = $( color !== nothing ? "'$color_col'" : "null" );
            const SIZE_COL = $( size !== nothing ? "'$size_col'" : "null" );
            const POPUP_COLS = $popup_cols_js;
            const GEOJSON_URL = null;
            const REGION_COL = null;
            const VALUE_COLS = [];
            let VALUE_COL = null;
            const REGION_KEY = null;
            """
        else
            region_col = string(region)
            """
            const MODE = 'choropleth';
            const LAT_COL = null;
            const LON_COL = null;
            const COLOR_COL = null;
            const SIZE_COL = null;
            const POPUP_COLS = [];
            const GEOJSON_URL = '$geojson_source';
            const REGION_COL = '$region_col';
            const VALUE_COLS = $value_cols_js;
            let VALUE_COL = '$default_value_col_str';
            const REGION_KEY = '$region_key';
            """
        end

        chart_title_str = string(chart_title)

        # Build overlay dropdown HTML if multiple value columns
        overlay_dropdown_html = if mode == :choropleth && length(value_cols) > 1
            options_html = join(["""<option value="$col" $(col == default_value_col ? "selected" : "")>$col</option>""" for col in value_cols], "\n")
            """
            <div style="margin-bottom: 10px;">
                <label for="overlay_select_$chart_title_str" style="font-weight: bold;">Overlay: </label>
                <select id="overlay_select_$chart_title_str" onchange="updateMap_$chart_title_str()" style="padding: 5px; border-radius: 4px;">
                    $options_html
                </select>
            </div>
            """
        else
            ""
        end

        functional_html = """
        (function() {
            // Configuration
            $mode_config
            const COLOR_PALETTE = $color_palette_js;
            const CATEGORICAL_FILTERS = $categorical_filters_js;
            const CONTINUOUS_FILTERS = $continuous_filters_js;
            const CHOICE_FILTERS = $choice_filters_js;

            let map_$chart_title_str = null;
            let markersLayer_$chart_title_str = null;
            let choroplethLayer_$chart_title_str = null;
            let legend_$chart_title_str = null;
            let geojsonData_$chart_title_str = null;

            // Country/region name aliases for matching
            // Maps common variations to canonical names used in data
            const NAME_ALIASES = {
                'russian federation': 'russia',
                'united states of america': 'united states',
                'usa': 'united states',
                'uk': 'united kingdom',
                'great britain': 'united kingdom',
                'republic of korea': 'south korea',
                'korea, republic of': 'south korea',
                'democratic people\\'s republic of korea': 'north korea',
                'korea, dem. people\\'s rep.': 'north korea',
                'china, people\\'s republic of': 'china',
                'iran, islamic republic of': 'iran',
                'czech republic': 'czechia',
                'syrian arab republic': 'syria',
                'venezuela, bolivarian republic of': 'venezuela',
                'viet nam': 'vietnam',
                'lao people\\'s democratic republic': 'laos',
                'myanmar (burma)': 'myanmar',
                'côte d\\'ivoire': 'ivory coast',
                'congo, democratic republic of the': 'democratic republic of the congo',
                'congo, republic of the': 'republic of the congo',
                'tanzania, united republic of': 'tanzania',
                'bolivia, plurinational state of': 'bolivia',
                'the bahamas': 'bahamas',
                'the gambia': 'gambia'
            };

            // Normalize a region name for matching
            function normalizeRegionName(name) {
                if (!name) return '';
                let normalized = String(name).toLowerCase().trim();
                // Check if this name has an alias
                if (NAME_ALIASES[normalized]) {
                    return NAME_ALIASES[normalized];
                }
                return normalized;
            }

            // Fix polygons that cross the antimeridian (180° longitude line)
            // This prevents Fiji, Russia, etc. from rendering as lines across the whole map
            // Excludes Antarctica which is a polar region requiring different handling
            function fixAntimeridian(geojson) {
                if (!geojson || !geojson.features) return geojson;

                const newFeatures = [];

                geojson.features.forEach(feature => {
                    if (!feature.geometry) {
                        newFeatures.push(feature);
                        return;
                    }

                    // Skip Antarctica - it's a polar region that wraps differently
                    const props = feature.properties || {};
                    const featureName = (props.name || props.NAME || props.Name || '').toLowerCase();
                    if (featureName.includes('antarctica')) {
                        newFeatures.push(feature);
                        return;
                    }

                    const geomType = feature.geometry.type;

                    if (geomType === 'Polygon') {
                        const fixed = fixPolygonAntimeridian(feature.geometry.coordinates);
                        if (fixed.length === 1) {
                            newFeatures.push(feature);
                        } else {
                            // Split into MultiPolygon
                            newFeatures.push({
                                ...feature,
                                geometry: {
                                    type: 'MultiPolygon',
                                    coordinates: fixed.map(ring => [ring])
                                }
                            });
                        }
                    } else if (geomType === 'MultiPolygon') {
                        const allFixed = [];
                        feature.geometry.coordinates.forEach(polygon => {
                            const fixed = fixPolygonAntimeridian(polygon);
                            fixed.forEach(ring => allFixed.push([ring]));
                        });
                        newFeatures.push({
                            ...feature,
                            geometry: {
                                type: 'MultiPolygon',
                                coordinates: allFixed
                            }
                        });
                    } else {
                        newFeatures.push(feature);
                    }
                });

                return { ...geojson, features: newFeatures };
            }

            function fixPolygonAntimeridian(rings) {
                // Check if polygon crosses antimeridian
                const outerRing = rings[0];
                let crossesAntimeridian = false;

                for (let i = 1; i < outerRing.length; i++) {
                    const lon1 = outerRing[i-1][0];
                    const lon2 = outerRing[i][0];
                    // If there's a jump of more than 180 degrees, it crosses
                    if (Math.abs(lon2 - lon1) > 180) {
                        crossesAntimeridian = true;
                        break;
                    }
                }

                if (!crossesAntimeridian) {
                    return [outerRing];
                }

                // Split the polygon at the antimeridian
                const westRing = [];
                const eastRing = [];

                for (let i = 0; i < outerRing.length; i++) {
                    let [lon, lat] = outerRing[i];

                    // Normalize longitude to be either all positive or handle split
                    if (lon < 0) {
                        westRing.push([lon, lat]);
                        eastRing.push([lon + 360, lat]);
                    } else {
                        westRing.push([lon - 360, lat]);
                        eastRing.push([lon, lat]);
                    }
                }

                // Return both rings - Leaflet will clip them appropriately
                // Filter to only keep the ring that makes sense for each hemisphere
                const westFiltered = westRing.filter(([lon, lat]) => lon >= -180 && lon <= 0);
                const eastFiltered = eastRing.filter(([lon, lat]) => lon >= 0 && lon <= 180);

                // If filtering didn't work well, just shift all coordinates
                if (westFiltered.length < 4 || eastFiltered.length < 4) {
                    // Alternative: shift all negative longitudes to positive
                    const shiftedRing = outerRing.map(([lon, lat]) => {
                        return lon < 0 ? [lon + 360, lat] : [lon, lat];
                    });
                    return [shiftedRing];
                }

                return [westFiltered, eastFiltered];
            }

            // Color interpolation for choropleth
            function getColor(value, min, max) {
                if (value === null || value === undefined || isNaN(value)) return '#cccccc';
                const ratio = max > min ? (value - min) / (max - min) : 0;
                const idx = Math.min(Math.floor(ratio * (COLOR_PALETTE.length - 1)), COLOR_PALETTE.length - 1);
                return COLOR_PALETTE[Math.max(0, idx)];
            }

            // Create legend
            function createLegend(min, max, units) {
                if (legend_$chart_title_str) {
                    map_$chart_title_str.removeControl(legend_$chart_title_str);
                }

                legend_$chart_title_str = L.control({position: 'bottomright'});
                legend_$chart_title_str.onAdd = function(map) {
                    const div = L.DomUtil.create('div', 'info legend');
                    div.style.cssText = 'background: white; padding: 10px; border-radius: 5px; box-shadow: 0 0 15px rgba(0,0,0,0.2);';

                    let html = '<strong>' + (units || 'Value') + '</strong><br>';
                    const steps = 5;
                    for (let i = 0; i <= steps; i++) {
                        const val = min + (max - min) * (i / steps);
                        html += '<i style="background:' + getColor(val, min, max) +
                                '; width: 18px; height: 18px; display: inline-block; margin-right: 5px;"></i> ' +
                                val.toFixed(1) + '<br>';
                    }
                    div.innerHTML = html;
                    return div;
                };
                legend_$chart_title_str.addTo(map_$chart_title_str);
            }

            // Render points mode
            function renderPoints(data, fitBoundsToData = false) {
                if (markersLayer_$chart_title_str) {
                    map_$chart_title_str.removeLayer(markersLayer_$chart_title_str);
                }

                markersLayer_$chart_title_str = L.layerGroup();

                // Calculate min/max for color and size scaling
                let colorMin = Infinity, colorMax = -Infinity;
                let sizeMin = Infinity, sizeMax = -Infinity;

                if (COLOR_COL) {
                    data.forEach(d => {
                        const v = parseFloat(d[COLOR_COL]);
                        if (!isNaN(v)) {
                            colorMin = Math.min(colorMin, v);
                            colorMax = Math.max(colorMax, v);
                        }
                    });
                }

                if (SIZE_COL) {
                    data.forEach(d => {
                        const v = parseFloat(d[SIZE_COL]);
                        if (!isNaN(v)) {
                            sizeMin = Math.min(sizeMin, v);
                            sizeMax = Math.max(sizeMax, v);
                        }
                    });
                }

                data.forEach(row => {
                    const lat = parseFloat(row[LAT_COL]);
                    const lon = parseFloat(row[LON_COL]);

                    if (isNaN(lat) || isNaN(lon)) return;

                    // Determine marker color
                    let markerColor = '#3388ff';
                    if (COLOR_COL && row[COLOR_COL] !== null && row[COLOR_COL] !== undefined) {
                        const colorVal = parseFloat(row[COLOR_COL]);
                        if (!isNaN(colorVal)) {
                            markerColor = getColor(colorVal, colorMin, colorMax);
                        }
                    }

                    // Determine marker size
                    let radius = 6;
                    if (SIZE_COL && row[SIZE_COL] !== null && row[SIZE_COL] !== undefined) {
                        const sizeVal = parseFloat(row[SIZE_COL]);
                        if (!isNaN(sizeVal) && sizeMax > sizeMin) {
                            radius = 4 + 12 * (sizeVal - sizeMin) / (sizeMax - sizeMin);
                        }
                    }

                    // Build popup content
                    let popupContent = '';
                    POPUP_COLS.forEach(col => {
                        if (row[col] !== undefined && row[col] !== null) {
                            popupContent += '<strong>' + col + ':</strong> ' + row[col] + '<br>';
                        }
                    });
                    if (COLOR_COL) popupContent += '<strong>' + COLOR_COL + ':</strong> ' + row[COLOR_COL] + '<br>';
                    if (SIZE_COL) popupContent += '<strong>' + SIZE_COL + ':</strong> ' + row[SIZE_COL] + '<br>';
                    popupContent += '<strong>Lat:</strong> ' + lat.toFixed(4) + '<br>';
                    popupContent += '<strong>Lon:</strong> ' + lon.toFixed(4);

                    const marker = L.circleMarker([lat, lon], {
                        radius: radius,
                        fillColor: markerColor,
                        color: '#000',
                        weight: 1,
                        opacity: 1,
                        fillOpacity: 0.7
                    }).bindPopup(popupContent);

                    markersLayer_$chart_title_str.addLayer(marker);
                });

                markersLayer_$chart_title_str.addTo(map_$chart_title_str);

                // Create legend if color column is used
                if (COLOR_COL && colorMin !== Infinity) {
                    createLegend(colorMin, colorMax, COLOR_COL);
                }

                // Fit bounds to markers only on initial render
                if (fitBoundsToData && data.length > 0) {
                    const bounds = [];
                    data.forEach(row => {
                        const lat = parseFloat(row[LAT_COL]);
                        const lon = parseFloat(row[LON_COL]);
                        if (!isNaN(lat) && !isNaN(lon)) {
                            bounds.push([lat, lon]);
                        }
                    });
                    if (bounds.length > 0) {
                        map_$chart_title_str.fitBounds(bounds, {padding: [20, 20]});
                    }
                }
            }

            // Render choropleth mode
            function renderChoropleth(data, fitBoundsToData = false) {
                if (choroplethLayer_$chart_title_str) {
                    map_$chart_title_str.removeLayer(choroplethLayer_$chart_title_str);
                }

                if (!geojsonData_$chart_title_str) {
                    console.error('GeoJSON data not loaded');
                    return;
                }

                // Build lookup from data with normalized names
                const dataLookup = {};
                data.forEach(row => {
                    const key = normalizeRegionName(row[REGION_COL]);
                    dataLookup[key] = parseFloat(row[VALUE_COL]);
                });

                // Calculate min/max values
                let min = Infinity, max = -Infinity;
                data.forEach(row => {
                    const v = parseFloat(row[VALUE_COL]);
                    if (!isNaN(v)) {
                        min = Math.min(min, v);
                        max = Math.max(max, v);
                    }
                });

                // Track layers that have matching data for bounds calculation
                const layersWithData = [];

                // Style function
                function style(feature) {
                    // Try multiple property names for matching
                    const props = feature.properties || {};
                    const possibleKeys = [REGION_KEY, 'name', 'NAME', 'Name', 'postal', 'abbrev', 'iso_a2', 'iso_a3', 'STUSPS', 'STATEFP'];

                    let value = null;
                    for (const key of possibleKeys) {
                        if (props[key]) {
                            const lookupKey = normalizeRegionName(props[key]);
                            if (dataLookup[lookupKey] !== undefined) {
                                value = dataLookup[lookupKey];
                                break;
                            }
                        }
                    }

                    return {
                        fillColor: getColor(value, min, max),
                        weight: 1,
                        opacity: 1,
                        color: '#666',
                        fillOpacity: 0.7
                    };
                }

                // Check if a feature has matching data
                function featureHasData(feature) {
                    const props = feature.properties || {};
                    const possibleKeys = [REGION_KEY, 'name', 'NAME', 'Name', 'postal', 'abbrev', 'iso_a2', 'iso_a3', 'STUSPS', 'STATEFP'];
                    for (const key of possibleKeys) {
                        if (props[key]) {
                            const lookupKey = normalizeRegionName(props[key]);
                            if (dataLookup[lookupKey] !== undefined) {
                                return true;
                            }
                        }
                    }
                    return false;
                }

                // Popup function
                function onEachFeature(feature, layer) {
                    const props = feature.properties || {};
                    const possibleKeys = [REGION_KEY, 'name', 'NAME', 'Name', 'postal', 'abbrev'];

                    let regionName = 'Unknown';
                    let value = null;
                    let hasData = false;
                    for (const key of possibleKeys) {
                        if (props[key]) {
                            const lookupKey = normalizeRegionName(props[key]);
                            if (dataLookup[lookupKey] !== undefined) {
                                regionName = props[key];
                                value = dataLookup[lookupKey];
                                hasData = true;
                                break;
                            } else if (regionName === 'Unknown') {
                                regionName = props[key];
                            }
                        }
                    }

                    // Track layers with data for bounds fitting
                    if (hasData) {
                        layersWithData.push(layer);
                    }

                    let popupContent = '<strong>' + regionName + '</strong>';
                    if (value !== null) {
                        popupContent += '<br>' + VALUE_COL + ': ' + value.toFixed(2);
                    } else {
                        popupContent += '<br><em>No data</em>';
                    }
                    layer.bindPopup(popupContent);

                    layer.on({
                        mouseover: function(e) {
                            const layer = e.target;
                            layer.setStyle({weight: 3, color: '#333'});
                            layer.bringToFront();
                        },
                        mouseout: function(e) {
                            choroplethLayer_$chart_title_str.resetStyle(e.target);
                        }
                    });
                }

                choroplethLayer_$chart_title_str = L.geoJSON(geojsonData_$chart_title_str, {
                    style: style,
                    onEachFeature: onEachFeature
                }).addTo(map_$chart_title_str);

                // Create legend
                if (min !== Infinity) {
                    createLegend(min, max, VALUE_COL);
                }

                // Fit bounds only to regions that have data (not the entire GeoJSON)
                if (fitBoundsToData && layersWithData.length > 0) {
                    const group = L.featureGroup(layersWithData);
                    map_$chart_title_str.fitBounds(group.getBounds(), {padding: [20, 20]});
                } else if (fitBoundsToData) {
                    // Fallback: if no specific layers matched, fit to entire choropleth layer
                    map_$chart_title_str.fitBounds(choroplethLayer_$chart_title_str.getBounds(), {padding: [20, 20]});
                }
            }

            // Main update function
            window.updateMap_$chart_title_str = function() {
                // Get overlay column from dropdown if it exists
                const overlaySelect = document.getElementById('overlay_select_$chart_title_str');
                if (overlaySelect) {
                    VALUE_COL = overlaySelect.value;
                }

                // Get current filter values
                const { filters, rangeFilters, choices } = readFilterValues('$chart_title_str', CATEGORICAL_FILTERS, CONTINUOUS_FILTERS, CHOICE_FILTERS);

                // Apply filters
                const filteredData = applyFiltersWithCounting(
                    window.allData_$chart_title_str,
                    '$chart_title_str',
                    CATEGORICAL_FILTERS,
                    CONTINUOUS_FILTERS,
                    filters,
                    rangeFilters,
                    CHOICE_FILTERS,
                    choices
                );

                // Always fit bounds to show the current filtered data
                // This ensures the view refocuses when filters change
                if (MODE === 'points') {
                    renderPoints(filteredData, true);
                } else {
                    renderChoropleth(filteredData, true);
                }

                // Update zoom slider to reflect current zoom level
                updateZoomSlider_$chart_title_str();
            };

            // Initialize map
            function initMap() {
                // Set initial height based on width and aspect ratio (default 0.6)
                const mapDiv = document.getElementById('map_$chart_title_str');
                const width = mapDiv.offsetWidth;
                const aspectSlider = document.getElementById('map_$chart_title_str' + '_aspect_ratio_slider');
                let aspectRatio = 0.6;
                if (aspectSlider) {
                    aspectRatio = Math.exp(parseFloat(aspectSlider.value));
                }
                mapDiv.style.height = (width * aspectRatio) + 'px';

                map_$chart_title_str = L.map('map_$chart_title_str', {
                    worldCopyJump: true,  // Helps with features crossing the antimeridian (like Russia)
                    maxBoundsViscosity: 1.0,
                    zoomSnap: 0.1,        // Enable fractional/continuous zoom (default is 1)
                    zoomDelta: 0.5        // Smaller zoom steps for mouse wheel
                }).setView([0, 0], 2);  // Default world view, will be overwritten by fitBounds

                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
                    noWrap: false  // Allow world wrapping for better antimeridian handling
                }).addTo(map_$chart_title_str);
            }

            // Setup aspect ratio slider for map
            function setupMapAspectRatio() {
                const slider = document.getElementById('map_$chart_title_str' + '_aspect_ratio_slider');
                const label = document.getElementById('map_$chart_title_str' + '_aspect_ratio_label');
                if (!slider || !label) return;

                slider.addEventListener('input', function() {
                    const logValue = parseFloat(this.value);
                    const aspectRatio = Math.exp(logValue);
                    label.textContent = aspectRatio.toFixed(2);

                    const mapDiv = document.getElementById('map_$chart_title_str');
                    if (!mapDiv || !map_$chart_title_str) return;

                    const width = mapDiv.offsetWidth;
                    const height = width * aspectRatio;
                    mapDiv.style.height = height + 'px';

                    // Invalidate map size without panning - keeps center and zoom fixed
                    map_$chart_title_str.invalidateSize({pan: false});
                });
            }

            // Update zoom slider to reflect current map zoom level
            function updateZoomSlider_$chart_title_str() {
                const slider = document.getElementById('map_$chart_title_str' + '_zoom_slider');
                const label = document.getElementById('map_$chart_title_str' + '_zoom_label');
                if (!slider || !label || !map_$chart_title_str) return;

                const zoom = map_$chart_title_str.getZoom();
                slider.value = zoom;
                label.textContent = zoom.toFixed(1);
            }

            // Setup zoom slider for map
            function setupMapZoom() {
                const slider = document.getElementById('map_$chart_title_str' + '_zoom_slider');
                const label = document.getElementById('map_$chart_title_str' + '_zoom_label');
                if (!slider || !label) return;

                // Update zoom when slider changes
                slider.addEventListener('input', function() {
                    const zoom = parseFloat(this.value);
                    label.textContent = zoom.toFixed(1);

                    if (map_$chart_title_str) {
                        map_$chart_title_str.setZoom(zoom);
                    }
                });

                // Sync slider when map zoom changes (via mouse wheel, buttons, etc.)
                if (map_$chart_title_str) {
                    map_$chart_title_str.on('zoomend', function() {
                        updateZoomSlider_$chart_title_str();
                    });
                }
            }

            // Load data and initialize
            loadDataset('$data_label').then(data => {
                window.allData_$chart_title_str = data;

                \$(function() {
                    initMap();
                    setupMapAspectRatio();
                    setupMapZoom();

                    if (MODE === 'choropleth' && GEOJSON_URL) {
                        // Load GeoJSON for choropleth
                        fetch(GEOJSON_URL)
                            .then(response => response.json())
                            .then(geojson => {
                                // Handle TopoJSON format
                                let parsedGeojson;
                                if (geojson.type === 'Topology') {
                                    // Convert TopoJSON to GeoJSON
                                    const objectName = Object.keys(geojson.objects)[0];
                                    parsedGeojson = topojson.feature(geojson, geojson.objects[objectName]);
                                } else {
                                    parsedGeojson = geojson;
                                }
                                // Fix polygons that cross the antimeridian (Fiji, Russia, etc.)
                                geojsonData_$chart_title_str = fixAntimeridian(parsedGeojson);
                                updateMap_$chart_title_str();
                            })
                            .catch(error => {
                                console.error('Error loading GeoJSON:', error);
                                document.getElementById('map_$chart_title_str').innerHTML =
                                    '<div style="padding: 20px; color: red;">Error loading map boundaries: ' + error.message + '</div>';
                            });
                    } else {
                        updateMap_$chart_title_str();
                    }
                });
            }).catch(error => console.error('Error loading data for chart $chart_title_str:', error));
        })();
        """

        # Build aspect ratio slider HTML (logarithmic scale, default 0.6)
        aspect_ratio_default = 0.6
        log_min = log(0.25)
        log_max = log(2.5)
        log_default = log(aspect_ratio_default)

        # Build sliders HTML (aspect ratio and zoom side by side)
        sliders_html = """
        <div style="margin-bottom: 10px; display: flex; flex-wrap: wrap; gap: 20px;">
            <div style="flex: 1; min-width: 250px;">
                <label for="map_$(chart_title_str)_aspect_ratio_slider">Aspect Ratio: </label>
                <span id="map_$(chart_title_str)_aspect_ratio_label">$(round(aspect_ratio_default, digits=2))</span>
                <input type="range" id="map_$(chart_title_str)_aspect_ratio_slider"
                       min="$(log_min)" max="$(log_max)" step="0.01" value="$(log_default)"
                       style="width: 60%; margin-left: 10px;">
            </div>
            <div style="flex: 1; min-width: 250px;">
                <label for="map_$(chart_title_str)_zoom_slider">Zoom: </label>
                <span id="map_$(chart_title_str)_zoom_label">2.0</span>
                <input type="range" id="map_$(chart_title_str)_zoom_slider"
                       min="1" max="18" step="0.1" value="2"
                       style="width: 60%; margin-left: 10px;">
            </div>
        </div>
        """

        # Build appearance HTML
        map_container = """
        <div id="map_$chart_title_str" style="width: 100%; height: 500px; border: 1px solid #ccc; border-radius: 4px;"></div>
        """

        # Generate choices HTML
        choices_html = join([generate_choice_dropdown_html(dd) for dd in choice_dropdowns], "\n")

        appearance_html = """
        <div class="chart-container" style="margin-bottom: 20px;">
            <h3>$title</h3>
            $(isempty(notes) ? "" : "<p style=\"color: #666; font-size: 0.9em;\">$notes</p>")
            $sliders_html
            <div style="margin-bottom: 10px;">
                $overlay_dropdown_html
                $choices_html
                $filters_html
            </div>
            $map_container
            <div id="obs_count_$chart_title_str" style="color: #666; font-size: 0.85em; margin-top: 5px;"></div>
        </div>
        """

        new(chart_title, data_label, functional_html, appearance_html, mode)
    end
end

"""
    get_geojson_url(region_type, geojson_url)

Get the URL for GeoJSON/TopoJSON data based on region type or custom URL.
"""
function get_geojson_url(region_type::Union{Nothing, Symbol}, geojson_url::Union{Nothing, String})
    if geojson_url !== nothing
        return geojson_url
    end

    if region_type === nothing
        return ""
    end

    # Map region types to CDN URLs
    # Note: US states uses a GeoJSON with full state names (not abbreviations)
    region_urls = Dict(
        :world_countries => "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json",
        :world_countries_50m => "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-50m.json",
        :world_countries_10m => "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-10m.json",
        :us_states => "https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json",
        :us_counties => "https://cdn.jsdelivr.net/npm/us-atlas@3/counties-10m.json",
        :us_nation => "https://cdn.jsdelivr.net/npm/us-atlas@3/nation-10m.json"
    )

    url = get(region_urls, region_type, nothing)
    if url === nothing
        available = join(string.(keys(region_urls)), ", ")
        error("Unknown region_type: $region_type. Available types: $available")
    end

    return url
end

"""
    list_region_types()

List all available built-in region types for choropleth maps.
"""
function list_region_types()
    println("Available region types for GeoPlot:")
    println("  :world_countries     - World countries (110m resolution, ~10KB)")
    println("  :world_countries_50m - World countries (50m resolution, ~50KB)")
    println("  :world_countries_10m - World countries (10m resolution, ~500KB)")
    println("  :us_states           - US states (10m resolution)")
    println("  :us_counties         - US counties (10m resolution)")
    println("  :us_nation           - US nation boundary (10m resolution)")
    println()
    println("For other regions, provide a custom geojson_url parameter.")
end

dependencies(g::GeoPlot) = [g.data_label]

# GeoPlot requires jQuery, CSV loading, and Leaflet.js with TopoJSON
js_dependencies(::GeoPlot) = vcat(JS_DEP_JQUERY, JS_DEP_LEAFLET)
