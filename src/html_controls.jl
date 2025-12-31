"""
HTML Controls Module

This module provides a unified abstraction for generating HTML controls
(filters, attributes, facets) across all chart types, eliminating code duplication.
"""

"""
    DropdownControl

Specification for a single dropdown control.

# Fields
- `id::String`: HTML element ID
- `label::String`: Display label for the dropdown
- `options::Vector{String}`: Available options in the dropdown
- `default_value::Union{String, Vector{String}}`: Default selected value(s)
- `onchange::String`: JavaScript function to call on change
"""
struct DropdownControl
    id::String
    label::String
    options::Vector{String}
    default_value::Union{String, Vector{String}}  # String for single-select, Vector for multi-select
    onchange::String
end

"""
    RangeSliderControl

Specification for a range slider control (for continuous numeric filters).

# Fields
- `id::String`: HTML element ID (without _min/_max suffix)
- `label::String`: Display label for the slider
- `min_value::Float64`: Minimum value of the range (in milliseconds for dates)
- `max_value::Float64`: Maximum value of the range (in milliseconds for dates)
- `default_min::Float64`: Default minimum selection (in milliseconds for dates)
- `default_max::Float64`: Default maximum selection (in milliseconds for dates)
- `onchange::String`: JavaScript function to call on change
- `value_type::Symbol`: Type of values (:numeric, :date, :datetime, :zoneddatetime, :time)
"""
struct RangeSliderControl
    id::String
    label::String
    min_value::Float64
    max_value::Float64
    default_min::Float64
    default_max::Float64
    onchange::String
    value_type::Symbol
end

"""
    ChartHtmlControls

Complete specification for a chart's HTML controls (filters, attributes, facets).

# Fields
- `chart_title_safe::String`: Sanitized chart title for use in HTML IDs
- `chart_div_id::String`: ID of the main chart div element
- `update_function_name::String`: Name of the JavaScript update function
- `filter_dropdowns::Vector{DropdownControl}`: Categorical filter controls
- `filter_sliders::Vector{RangeSliderControl}`: Continuous filter controls
- `attribute_dropdowns::Vector{DropdownControl}`: Chart-specific attribute controls
- `facet_dropdowns::Vector{DropdownControl}`: Faceting controls (0-2 elements)
- `title::String`: Chart title to display
- `notes::String`: Chart description/notes to display
"""
struct ChartHtmlControls
    chart_title_safe::String
    chart_div_id::String
    update_function_name::String
    filter_dropdowns::Vector{DropdownControl}
    filter_sliders::Vector{RangeSliderControl}
    attribute_dropdowns::Vector{DropdownControl}
    facet_dropdowns::Vector{DropdownControl}
    title::String
    notes::String
end

"""
    generate_dropdown_html(dropdown::DropdownControl; multiselect::Bool=false)

Generate HTML for a single dropdown control.

# Arguments
- `dropdown::DropdownControl`: The dropdown specification
- `multiselect::Bool`: Whether to allow multiple selections (default: false)

# Returns
- `String`: HTML string for the dropdown
"""
function generate_dropdown_html(dropdown::DropdownControl; multiselect::Bool=false)::String
    options_html = ""

    # Handle both single value (String) and multiple values (Vector{String})
    default_values = dropdown.default_value isa Vector{String} ? dropdown.default_value : [dropdown.default_value]
    default_values_str = string.(default_values)

    for option in dropdown.options
        selected = (string(option) in default_values_str) ? " selected" : ""
        options_html *= "                <option value=\"$option\"$selected>$option</option>\n"
    end

    multiple_attr = multiselect ? " multiple" : ""

    return """
            <div style="margin: 10px; display: flex; align-items: center;">
                <div style="flex: 0 0 70%;">
                    <label for="$(dropdown.id)">$(dropdown.label): </label>
                    <select id="$(dropdown.id)"$multiple_attr onchange="$(dropdown.onchange)">
    $options_html            </select>
                </div>
                <div style="flex: 0 0 30%; text-align: right; padding-right: 10px;">
                    <span id="$(dropdown.id)_obs_count" style="font-size: 0.9em; color: #666;"></span>
                </div>
            </div>
            """
end

"""
    generate_range_slider_html(slider::RangeSliderControl)

Generate HTML for a range slider control (dual-handle jQuery UI slider for numeric ranges).

Uses jQuery UI's range slider with two handles for intuitive min/max selection.

# Arguments
- `slider::RangeSliderControl`: The range slider specification

# Returns
- `String`: HTML string for the jQuery UI range slider
"""
function generate_range_slider_html(slider::RangeSliderControl)::String
    # Format numbers or dates for display based on value_type
    function format_value(x::Float64)::String
        if slider.value_type == :date
            # Convert milliseconds to Date and format as YYYY-MM-DD
            dt = Dates.unix2datetime(x / 1000)
            return Dates.format(Date(dt), "yyyy-mm-dd")
        elseif slider.value_type == :datetime || slider.value_type == :zoneddatetime
            # Convert milliseconds to DateTime and format as YYYY-MM-DDTHH:MM:SS
            dt = Dates.unix2datetime(x / 1000)
            return Dates.format(dt, "yyyy-mm-ddTHH:MM:SS")
        elseif slider.value_type == :time
            # Convert milliseconds to Time and format as HH:MM:SS
            ns = Int64(x * 1_000_000)  # Convert back to nanoseconds
            t = Time(Dates.Nanosecond(ns))
            return Dates.format(t, "HH:MM:SS")
        else
            # Numeric: format with appropriate precision
            return x == floor(x) ? string(Int(floor(x))) : string(round(x, digits=2))
        end
    end

    # Create JavaScript formatter function based on value_type
    local js_formatter::String
    if slider.value_type == :date
        js_formatter = """
                        function formatValue_$(slider.id)(x) {
                            const d = new Date(x);
                            return d.getFullYear() + '-' +
                                   String(d.getMonth() + 1).padStart(2, '0') + '-' +
                                   String(d.getDate()).padStart(2, '0');
                        }"""
    elseif slider.value_type == :datetime || slider.value_type == :zoneddatetime
        js_formatter = """
                        function formatValue_$(slider.id)(x) {
                            const d = new Date(x);
                            return d.getFullYear() + '-' +
                                   String(d.getMonth() + 1).padStart(2, '0') + '-' +
                                   String(d.getDate()).padStart(2, '0') + 'T' +
                                   String(d.getHours()).padStart(2, '0') + ':' +
                                   String(d.getMinutes()).padStart(2, '0') + ':' +
                                   String(d.getSeconds()).padStart(2, '0');
                        }"""
    elseif slider.value_type == :time
        js_formatter = """
                        function formatValue_$(slider.id)(x) {
                            // x is milliseconds since midnight
                            const totalSeconds = Math.floor(x / 1000);
                            const hours = Math.floor(totalSeconds / 3600);
                            const minutes = Math.floor((totalSeconds % 3600) / 60);
                            const seconds = totalSeconds % 60;
                            return String(hours).padStart(2, '0') + ':' +
                                   String(minutes).padStart(2, '0') + ':' +
                                   String(seconds).padStart(2, '0');
                        }"""
    else
        js_formatter = """
                        function formatValue_$(slider.id)(x) {
                            return x === Math.floor(x) ? Math.floor(x).toString() : x.toFixed(2);
                        }"""
    end

    return """
            <div style="margin: 15px 10px; display: flex; align-items: flex-start;">
                <div style="flex: 0 0 70%;">
                    <label style="display: block; margin-bottom: 5px; font-weight: bold;">$(slider.label): </label>
                    <span id="$(slider.id)_display" style="display: inline-block; min-width: 200px; font-size: 0.9em; color: #666;">$(format_value(slider.default_min)) - $(format_value(slider.default_max))</span>
                    <div id="$(slider.id)_slider" style="margin: 10px 5px; width: 90%;"></div>
                </div>
                <div style="flex: 0 0 30%; text-align: right; padding-right: 10px; padding-top: 25px;">
                    <span id="$(slider.id)_obs_count" style="font-size: 0.9em; color: #666;"></span>
                </div>
                <script>
                    \$(function() {
                        // Value formatter function
                        $js_formatter

                        // Initialize jQuery UI range slider
                        \$("#$(slider.id)_slider").slider({
                            range: true,
                            min: $(slider.min_value),
                            max: $(slider.max_value),
                            step: $(slider.max_value - slider.min_value) / 1000,  // Smooth sliding
                            values: [$(slider.default_min), $(slider.default_max)],
                            slide: function(event, ui) {
                                // Update display during sliding
                                const minVal = ui.values[0];
                                const maxVal = ui.values[1];
                                \$("#$(slider.id)_display").text(formatValue_$(slider.id)(minVal) + " - " + formatValue_$(slider.id)(maxVal));
                            },
                            change: function(event, ui) {
                                // Update display and trigger chart update
                                const minVal = ui.values[0];
                                const maxVal = ui.values[1];
                                \$("#$(slider.id)_display").text(formatValue_$(slider.id)(minVal) + " - " + formatValue_$(slider.id)(maxVal));

                                // Store values for easy access
                                \$("#$(slider.id)_slider").data('minValue', minVal);
                                \$("#$(slider.id)_slider").data('maxValue', maxVal);

                                // Call the update function
                                $(slider.onchange)
                            }
                        });

                        // Store initial values
                        \$("#$(slider.id)_slider").data('minValue', $(slider.default_min));
                        \$("#$(slider.id)_slider").data('maxValue', $(slider.default_max));
                    });

                    // Helper functions to get slider values
                    function get$(slider.id)Min() {
                        return \$("#$(slider.id)_slider").slider("values", 0);
                    }

                    function get$(slider.id)Max() {
                        return \$("#$(slider.id)_slider").slider("values", 1);
                    }
                </script>
            </div>
            """
end

"""
    generate_appearance_html(controls::ChartHtmlControls; multiselect_filters::Bool=true)

Generate complete appearance HTML for a chart including filters, attributes, facets, and chart container.

# Arguments
- `controls::ChartHtmlControls`: Complete control specification
- `multiselect_filters::Bool`: Whether filter dropdowns should allow multiple selections (default: true)

# Returns
- `String`: Complete appearance HTML string

# HTML Structure
The generated HTML includes three optional sections:
1. Filters - for data filtering (with gray background)
2. Plot Attributes - for chart-specific controls (with light blue background)
3. Faceting - for facet selection (with light orange background)

Each section is only included if it has controls to display.
"""
function generate_appearance_html(controls::ChartHtmlControls;
                                  multiselect_filters::Bool=true,
                                  chart_title::Symbol=:chart)::String

    # Build filters section
    filters_html = ""
    if !isempty(controls.filter_dropdowns) || !isempty(controls.filter_sliders)
        filter_controls_html = ""

        # Add dropdown filters
        for dropdown in controls.filter_dropdowns
            filter_controls_html *= generate_dropdown_html(dropdown; multiselect=multiselect_filters)
        end

        # Add range slider filters
        for slider in controls.filter_sliders
            filter_controls_html *= generate_range_slider_html(slider)
        end

        filters_html = """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff5f5;">
            <h4 style="margin-top: 0; display: flex; justify-content: space-between; align-items: center;">
                <span>Filters</span>
                <span id="$(chart_title)_total_obs" style="font-weight: normal; font-size: 0.9em; color: #666;"></span>
            </h4>
            $filter_controls_html
        </div>
        """
    end

    # Build attributes section
    attributes_html = ""
    if !isempty(controls.attribute_dropdowns)
        attribute_controls_html = ""
        for dropdown in controls.attribute_dropdowns
            attribute_controls_html *= generate_dropdown_html(dropdown; multiselect=false)
        end

        attributes_html = """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0fff0;">
            <h4 style="margin-top: 0;">Plot Attributes</h4>
            $attribute_controls_html
        </div>
        """
    end

    # Build faceting section
    facets_html = ""
    if !isempty(controls.facet_dropdowns)
        facet_controls_html = ""
        for dropdown in controls.facet_dropdowns
            facet_controls_html *= generate_dropdown_html(dropdown; multiselect=false)
        end

        facets_html = """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0f8ff;">
            <h4 style="margin-top: 0;">Faceting</h4>
            $facet_controls_html
        </div>
        """
    end

    # Combine all sections
    return """
        <h2>$(controls.title)</h2>
        <p>$(controls.notes)</p>

        $filters_html
        $attributes_html
        $facets_html
        <!-- Chart -->
        <div id="$(controls.chart_div_id)"></div>
        """
end

"""
    build_facet_dropdowns(chart_title_safe::String,
                         facet_choices::Vector{Symbol},
                         default_facet_array::Vector{Symbol},
                         update_function::String)

Helper function to build facet dropdown controls.

# Arguments
- `chart_title_safe::String`: Sanitized chart title for IDs
- `facet_choices::Vector{Symbol}`: Available facet columns
- `default_facet_array::Vector{Symbol}`: Default facet selections (0-2 elements)
- `update_function::String`: JavaScript function name for updates

# Returns
- `Vector{DropdownControl}`: Vector of facet dropdown controls (0-2 elements)
"""
function build_facet_dropdowns(chart_title_safe::String,
                               facet_choices::Vector{Symbol},
                               default_facet_array::Vector{Symbol},
                               update_function::String)::Vector{DropdownControl}

    facet_dropdowns = DropdownControl[]

    if length(facet_choices) == 0
        return facet_dropdowns
    elseif length(facet_choices) == 1
        # Single facet option - on/off toggle
        default_facet1 = length(default_facet_array) >= 1 ? string(default_facet_array[1]) : "None"
        facet_col = string(facet_choices[1])

        push!(facet_dropdowns, DropdownControl(
            "facet1_select_$chart_title_safe",
            "Facet by",
            ["None", facet_col],
            default_facet1,
            update_function
        ))
    else
        # Multiple facet options - show both facet 1 and facet 2 dropdowns
        default_facet1 = length(default_facet_array) >= 1 ? string(default_facet_array[1]) : "None"
        default_facet2 = length(default_facet_array) >= 2 ? string(default_facet_array[2]) : "None"

        options = ["None"; [string(col) for col in facet_choices]]

        push!(facet_dropdowns, DropdownControl(
            "facet1_select_$chart_title_safe",
            "Facet 1",
            options,
            default_facet1,
            update_function
        ))

        push!(facet_dropdowns, DropdownControl(
            "facet2_select_$chart_title_safe",
            "Facet 2",
            options,
            default_facet2,
            update_function
        ))
    end

    return facet_dropdowns
end

"""
    build_filter_dropdowns(chart_title_safe::String,
                          filters::Dict{Symbol, Any},
                          df::DataFrame,
                          update_function::String)

Helper function to build filter controls from filter dictionary.
Returns both dropdown controls (for categorical filters) and range slider controls (for continuous filters).

# Arguments
- `chart_title_safe::String`: Sanitized chart title for IDs
- `filters::Dict{Symbol, Any}`: Filter specifications (col => default_value)
- `df::DataFrame`: DataFrame to extract filter options from
- `update_function::String`: JavaScript function name for updates

# Returns
- `Tuple{Vector{DropdownControl}, Vector{RangeSliderControl}}`: (categorical filters, continuous filters)
"""
function build_filter_dropdowns(chart_title_safe::String,
                                filters::Dict{Symbol, Any},
                                df::DataFrame,
                                update_function::String)::Tuple{Vector{DropdownControl}, Vector{RangeSliderControl}}

    filter_dropdowns = DropdownControl[]
    filter_sliders = RangeSliderControl[]

    for (col, default_vals) in filters
        col_str = string(col)
        if col_str in names(df)
            # Check if this is a continuous variable
            if is_continuous_column(df, col)
                # Create range slider for continuous variables
                col_data = collect(skipmissing(df[!, col]))

                # Convert date/time types to numeric values for slider
                # The JavaScript will compare the original Date objects, but the slider needs numbers
                min_data = minimum(col_data)
                max_data = maximum(col_data)

                # Determine value type and convert to numeric
                local value_type::Symbol
                if min_data isa Date
                    # Convert to milliseconds since Unix epoch
                    min_val = Float64(Dates.datetime2unix(DateTime(min_data)) * 1000)
                    max_val = Float64(Dates.datetime2unix(DateTime(max_data)) * 1000)
                    value_type = :date
                elseif min_data isa DateTime
                    # Convert to milliseconds since Unix epoch
                    min_val = Float64(Dates.datetime2unix(min_data) * 1000)
                    max_val = Float64(Dates.datetime2unix(max_data) * 1000)
                    value_type = :datetime
                elseif min_data isa ZonedDateTime
                    # Convert to milliseconds since Unix epoch
                    min_val = Float64(Dates.datetime2unix(DateTime(min_data)) * 1000)
                    max_val = Float64(Dates.datetime2unix(DateTime(max_data)) * 1000)
                    value_type = :zoneddatetime
                elseif min_data isa Time
                    # Convert to nanoseconds since midnight, then to milliseconds
                    min_val = Float64(Dates.value(min_data)) / 1_000_000
                    max_val = Float64(Dates.value(max_data)) / 1_000_000
                    value_type = :time
                else
                    # Numeric type - convert directly
                    min_val = Float64(min_data)
                    max_val = Float64(max_data)
                    value_type = :numeric
                end

                # Default to full range if default_vals is empty or contains all values
                default_min = min_val
                default_max = max_val

                push!(filter_sliders, RangeSliderControl(
                    "$(col)_range_$chart_title_safe",
                    col_str,
                    min_val,
                    max_val,
                    default_min,
                    default_max,
                    update_function,
                    value_type
                ))
            else
                # Create dropdown for categorical variables
                unique_vals = sort(unique(skipmissing(df[!, col])))
                options = [string(v) for v in unique_vals]

                # Convert default values to strings
                default_strs = [string(v) for v in default_vals]

                # Filter to only include defaults that are valid options
                valid_defaults = filter(d -> d in options, default_strs)

                # If no valid defaults, use all options
                if isempty(valid_defaults)
                    valid_defaults = options
                end

                push!(filter_dropdowns, DropdownControl(
                    "$(col)_select_$chart_title_safe",
                    col_str,
                    options,
                    valid_defaults,  # Now a Vector{String}
                    update_function
                ))
            end
        end
    end

    return (filter_dropdowns, filter_sliders)
end


"""
    generate_facet_dropdowns_html(chart_title::String,
                                   facet_choices::Vector{Symbol},
                                   default_facet_array::Vector{Symbol},
                                   update_function::String)

Generate facet dropdown HTML directly for charts using manual HTML sections.

# Arguments
- `chart_title::String`: Chart title for element IDs
- `facet_choices::Vector{Symbol}`: Available facet columns
- `default_facet_array::Vector{Symbol}`: Default facet selections (0-2 elements)
- `update_function::String`: JavaScript function to call on change

# Returns
- `String`: HTML string for facet dropdowns (empty if no facet choices)

# Behavior
- 0 facet choices: Returns empty string
- 1 facet choice: Single dropdown with "None" and the facet column
- 2+ facet choices: Two dropdowns (Facet 1 and Facet 2) with all choices
"""
function generate_facet_dropdowns_html(chart_title::String,
                                        facet_choices::Vector{Symbol},
                                        default_facet_array::Vector{Symbol},
                                        update_function::String)::String

    if length(facet_choices) == 0
        return ""
    elseif length(facet_choices) == 1
        # Single facet option - on/off toggle
        facet1_default = (length(default_facet_array) >= 1 && first(facet_choices) in default_facet_array) ? string(first(facet_choices)) : "None"
        facet_col = string(first(facet_choices))

        options = "                <option value=\"None\"$((facet1_default == "None") ? " selected" : "")>None</option>\n" *
                 "                <option value=\"$facet_col\"$((facet1_default == facet_col) ? " selected" : "")>$facet_col</option>"

        return """
            <div style="margin: 10px 0;">
                <label for="facet1_select_$chart_title">Facet by: </label>
                <select id="facet1_select_$chart_title" onchange="$update_function">
$options                </select>
            </div>
            """
    else
        # Multiple facet options - show both facet 1 and facet 2 dropdowns
        facet1_default = length(default_facet_array) >= 1 ? string(default_facet_array[1]) : "None"
        facet2_default = length(default_facet_array) >= 2 ? string(default_facet_array[2]) : "None"

        options1 = "                <option value=\"None\"$((facet1_default == "None") ? " selected" : "")>None</option>\n" *
                  join(["                <option value=\"$col\"$((string(col) == facet1_default) ? " selected" : "")>$col</option>"
                       for col in facet_choices], "\n")
        options2 = "                <option value=\"None\"$((facet2_default == "None") ? " selected" : "")>None</option>\n" *
                  join(["                <option value=\"$col\"$((string(col) == facet2_default) ? " selected" : "")>$col</option>"
                       for col in facet_choices], "\n")

        return """
            <div style="margin: 10px 0; display: flex; gap: 20px; align-items: center;">
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="facet1_select_$chart_title">Facet 1:</label>
                    <select id="facet1_select_$chart_title" onchange="$update_function">
$options1                </select>
                </div>
                <div style="display: flex; gap: 5px; align-items: center;">
                    <label for="facet2_select_$chart_title">Facet 2:</label>
                    <select id="facet2_select_$chart_title" onchange="$update_function">
$options2                </select>
                </div>
            </div>
            """
    end
end

"""
    generate_value_column_dropdown_html(chart_title::String,
                                         value_cols::Vector{Symbol},
                                         default_value_col::Symbol,
                                         update_function::String;
                                         label::String="Select variable")

Generate value column selection dropdown HTML.

# Arguments
- `chart_title::String`: Chart title for element IDs
- `value_cols::Vector{Symbol}`: Available value columns
- `default_value_col::Symbol`: Default selected column
- `update_function::String`: JavaScript function to call on change
- `label::String`: Label text for the dropdown (default: "Select variable")

# Returns
- `(html::String, js::String)`: Tuple of (HTML string, JavaScript init string)
  Returns empty strings if fewer than 2 value columns
"""
function generate_value_column_dropdown_html(chart_title::String,
                                               value_cols::Vector{Symbol},
                                               default_value_col::Symbol,
                                               update_function::String;
                                               label::String="Select variable")::Tuple{String, String}

    if length(value_cols) < 2
        return ("", "")
    end

    value_options_html = join(["""<option value="$(col)"$(col == default_value_col ? " selected" : "")>$(col)</option>"""
                               for col in value_cols], "\n")

    html = """
        <label for="$(chart_title)_value_selector">$label: </label>
        <select id="$(chart_title)_value_selector" style="padding: 5px 10px;">
            $value_options_html
        </select>
    """

    js = """
        document.getElementById('$(chart_title)_value_selector').addEventListener('change', function() {
            $update_function
        });
    """

    return (html, js)
end

"""
    generate_group_column_dropdown_html(chart_title::String,
                                         group_cols::Vector{Symbol},
                                         default_color_col::Union{Symbol, Nothing},
                                         update_function::String;
                                         label::String="Group by")

Generate group column selection dropdown HTML with "None" option.

# Arguments
- `chart_title::String`: Chart title for element IDs
- `group_cols::Vector{Symbol}`: Available group columns
- `default_color_col::Union{Symbol, Nothing}`: Default selected column (nothing for "None")
- `update_function::String`: JavaScript function to call on change
- `label::String`: Label text for the dropdown (default: "Group by")

# Returns
- `(html::String, js::String)`: Tuple of (HTML string, JavaScript init string)
  Returns empty strings if fewer than 2 group columns
"""
function generate_group_column_dropdown_html(chart_title::String,
                                               group_cols::Vector{Symbol},
                                               default_color_col::Union{Symbol, Nothing},
                                               update_function::String;
                                               label::String="Group by")::Tuple{String, String}

    if length(group_cols) < 2
        return ("", "")
    end

    group_options_html = """<option value="_none_"$(default_color_col === nothing ? " selected" : "")>None</option>\n""" *
                        join(["""<option value="$(col)"$(col == default_color_col ? " selected" : "")>$(col)</option>"""
                             for col in group_cols], "\n")

    html = """
        <label for="$(chart_title)_group_selector" style="margin-left: 20px;">$label: </label>
        <select id="$(chart_title)_group_selector" style="padding: 5px 10px;">
            $group_options_html
        </select>
    """

    js = """
        document.getElementById('$(chart_title)_group_selector').addEventListener('change', function() {
            $update_function
        });
    """

    return (html, js)
end


"""
    generate_appearance_html_from_sections(filters_html::String,
                                           plot_attributes_html::String,
                                           faceting_html::String,
                                           title::String,
                                           notes::String,
                                           chart_div_id::String)

Generate appearance HTML from pre-built sections (for charts using custom controls).

This function provides the standard three-section layout without requiring DropdownControl objects.
Useful for charts that build their HTML sections directly.

# Arguments
- `filters_html::String`: Pre-built HTML for filter controls
- `plot_attributes_html::String`: Pre-built HTML for attribute controls
- `faceting_html::String`: Pre-built HTML for faceting controls
- `title::String`: Chart title
- `notes::String`: Chart notes/description
- `chart_div_id::String`: ID for the chart container div

# Returns
- `String`: Complete appearance HTML with standard three-section layout
"""
function generate_appearance_html_from_sections(filters_html::String,
                                                plot_attributes_html::String,
                                                faceting_html::String,
                                                title::String,
                                                notes::String,
                                                chart_div_id::String)::String
    # Build filters section
    filters_section = filters_html != "" ? """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff5f5;">
            <h4 style="margin-top: 0; display: flex; justify-content: space-between; align-items: center;">
                <span>Filters</span>
                <span id="$(chart_div_id)_total_obs" style="font-weight: normal; font-size: 0.9em; color: #666;"></span>
            </h4>
            $filters_html
        </div>
        """ : ""

    # Build plot attributes section
    attributes_section = plot_attributes_html != "" ? """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0fff0;">
            <h4 style="margin-top: 0;">Plot Attributes</h4>
            $plot_attributes_html
        </div>
        """ : ""

    # Build faceting section
    faceting_section = faceting_html != "" ? """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0f8ff;">
            <h4 style="margin-top: 0;">Faceting</h4>
            $faceting_html
        </div>
        """ : ""

    return """
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters (for data filtering) -->
        $filters_section
        <!-- Plot Attributes -->
        $attributes_section
        <!-- Faceting -->
        $faceting_section
        <!-- Chart -->
        <div id="$chart_div_id"></div>
        """
end
