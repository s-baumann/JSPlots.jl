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
- `value_type::Symbol`: Type of values (:integer, :numeric, :date, :datetime, :zoneddatetime, :time)
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

Complete specification for a chart's HTML controls (filters, attributes, axes, facets).

# Fields
- `chart_title_safe::String`: Sanitized chart title for use in HTML IDs
- `chart_div_id::String`: ID of the main chart div element
- `update_function_name::String`: Name of the JavaScript update function
- `choice_dropdowns::Vector{DropdownControl}`: Single-select choice controls (displayed at top of filters)
- `filter_dropdowns::Vector{DropdownControl}`: Categorical filter controls (multi-select)
- `filter_sliders::Vector{RangeSliderControl}`: Continuous filter controls
- `attribute_dropdowns::Vector{DropdownControl}`: Chart-specific attribute controls
- `axes_html::String`: Pre-built HTML for axes controls (integrated into Plot Attributes)
- `facet_dropdowns::Vector{DropdownControl}`: Faceting controls (0-2 elements)
- `title::String`: Chart title to display
- `notes::String`: Chart description/notes to display
"""
struct ChartHtmlControls
    chart_title_safe::String
    chart_div_id::String
    update_function_name::String
    choice_dropdowns::Vector{DropdownControl}
    filter_dropdowns::Vector{DropdownControl}
    filter_sliders::Vector{RangeSliderControl}
    attribute_dropdowns::Vector{DropdownControl}
    axes_html::String
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
        elseif slider.value_type == :integer
            # Integer: always format as whole number
            return string(Int(round(x)))
        else
            # Floating point numeric: format with appropriate precision
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
    elseif slider.value_type == :integer
        js_formatter = """
                        function formatValue_$(slider.id)(x) {
                            return Math.round(x).toString();
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
                            step: $(slider.value_type == :integer ? "1.0" : string((slider.max_value - slider.min_value) / 1000)),  // Integer steps for integers, smooth for others
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
The generated HTML includes two optional sections:
1. Filters - for data filtering (with pink background)
2. Plot Attributes - for chart-specific controls, axes, and facets (with light green background)

Each section is only included if it has controls to display.
"""
function generate_appearance_html(controls::ChartHtmlControls;
                                  multiselect_filters::Bool=true,
                                  aspect_ratio_default::Float64=0.6)::String

    # Build filters section (includes choices at top, then filters)
    filters_html = ""
    has_choices = !isempty(controls.choice_dropdowns)
    has_filters = !isempty(controls.filter_dropdowns) || !isempty(controls.filter_sliders)

    if has_choices || has_filters
        filter_controls_html = ""

        # Add choice dropdowns first (single-select, at top)
        for dropdown in controls.choice_dropdowns
            filter_controls_html *= generate_choice_dropdown_html(dropdown)
        end

        # Add dropdown filters (multi-select)
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
                <span id="$(controls.chart_div_id)_total_obs" style="font-weight: normal; font-size: 0.9em; color: #666;"></span>
            </h4>
            $filter_controls_html
        </div>
        """
    end

    # Build Plot Attributes section (includes attributes, axes, and facets)
    attributes_html = ""
    if !isempty(controls.attribute_dropdowns) || controls.axes_html != "" || !isempty(controls.facet_dropdowns)
        attribute_controls_html = ""

        # Add attribute dropdowns
        for dropdown in controls.attribute_dropdowns
            attribute_controls_html *= generate_dropdown_html(dropdown; multiselect=false)
        end

        # Append axes HTML (which includes its own subheading)
        attribute_controls_html *= controls.axes_html

        # Add facets section with subheading if facets exist
        if !isempty(controls.facet_dropdowns)
            # Render facet dropdowns side-by-side on one line
            facet_controls_html = if length(controls.facet_dropdowns) == 1
                # Single facet - simple layout
                dropdown = controls.facet_dropdowns[1]
                options_html = join(["""<option value="$opt"$(opt == dropdown.default_value ? " selected" : "")>$opt</option>"""
                                    for opt in dropdown.options], "\n")
                """
                <div style="margin: 10px 0;">
                    <label for="$(dropdown.id)">$(dropdown.label): </label>
                    <select id="$(dropdown.id)" onchange="$(dropdown.onchange)">
                        $options_html
                    </select>
                </div>
                """
            else
                # Two facets - side-by-side layout
                dropdown1 = controls.facet_dropdowns[1]
                dropdown2 = controls.facet_dropdowns[2]

                options1_html = join(["""<option value="$opt"$(opt == dropdown1.default_value ? " selected" : "")>$opt</option>"""
                                     for opt in dropdown1.options], "\n")
                options2_html = join(["""<option value="$opt"$(opt == dropdown2.default_value ? " selected" : "")>$opt</option>"""
                                     for opt in dropdown2.options], "\n")

                """
                <div style="margin: 10px 0; display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                    <div>
                        <label for="$(dropdown1.id)">$(dropdown1.label): </label>
                        <select id="$(dropdown1.id)" style="padding: 5px 10px;" onchange="$(dropdown1.onchange)">
                            $options1_html
                        </select>
                    </div>
                    <div>
                        <label for="$(dropdown2.id)">$(dropdown2.label): </label>
                        <select id="$(dropdown2.id)" style="padding: 5px 10px;" onchange="$(dropdown2.onchange)">
                            $options2_html
                        </select>
                    </div>
                </div>
                """
            end

            attribute_controls_html *= """
            <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Facets</h4>
            $facet_controls_html
            """
        end

        # Add aspect ratio slider at the bottom of Plot Attributes
        # Use logarithmic scale for better precision at smaller values
        log_min = log(0.25)
        log_max = log(2.5)
        log_default = log(aspect_ratio_default)
        aspect_ratio_html = """
        <div style="margin: 15px 0; padding-top: 10px; border-top: 1px solid #ddd;">
            <label for="$(controls.chart_div_id)_aspect_ratio_slider">Aspect Ratio: </label>
            <span id="$(controls.chart_div_id)_aspect_ratio_label">$aspect_ratio_default</span>
            <input type="range" id="$(controls.chart_div_id)_aspect_ratio_slider"
                   min="$log_min" max="$log_max" step="0.01" value="$log_default"
                   style="width: 75%; margin-left: 10px;">
            <span style="margin-left: 10px; color: #666; font-size: 0.9em;">(0.25 - 2.5)</span>
        </div>
        """
        attribute_controls_html *= aspect_ratio_html

        attributes_html = """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0fff0;">
            <h4 style="margin-top: 0;">Plot Attributes</h4>
            $attribute_controls_html
        </div>
        """
    end

    # Combine all sections
    # Only add chart div if chart_div_id is provided (some charts add their own container)
    chart_div_html = isempty(controls.chart_div_id) ? "" : """
        <!-- Chart -->
        <div id="$(controls.chart_div_id)"></div>"""

    return """
        <h2>$(controls.title)</h2>
        <p>$(controls.notes)</p>

        $filters_html
        $attributes_html
        $chart_div_html
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
    build_choice_dropdowns(chart_title_safe::String,
                          choices::Dict{Symbol, Any},
                          df::DataFrame,
                          update_function::String)

Helper function to build choice (single-select) dropdown controls from choice dictionary.
Choices are like filters but only allow selecting ONE value at a time.

# Arguments
- `chart_title_safe::String`: Sanitized chart title for IDs
- `choices::Dict{Symbol, Any}`: Choice specifications (col => default_value)
- `df::DataFrame`: DataFrame to extract choice options from
- `update_function::String`: JavaScript function name for updates

# Returns
- `Vector{DropdownControl}`: Vector of single-select dropdown controls
"""
function build_choice_dropdowns(chart_title_safe::String,
                                choices::Dict{Symbol, Any},
                                df::DataFrame,
                                update_function::String)::Vector{DropdownControl}

    choice_dropdowns = DropdownControl[]

    for (col, default_val) in choices
        col_str = string(col)
        if col_str in names(df)
            # Get all unique values for the dropdown
            unique_vals = sort(unique(skipmissing(df[!, col])))
            options = [string(v) for v in unique_vals]

            # Convert default value to string
            default_str = string(default_val)

            # Verify default is in options, otherwise use first option
            if !(default_str in options) && !isempty(options)
                default_str = options[1]
            end

            push!(choice_dropdowns, DropdownControl(
                "$(col)_choice_$chart_title_safe",
                col_str,
                options,
                default_str,  # Single value (not vector) for single-select
                update_function
            ))
        end
    end

    return choice_dropdowns
end

"""
    generate_choice_dropdown_html(dropdown::DropdownControl)

Generate HTML for a single-select choice dropdown control.
Similar to filter dropdowns but without multiselect and with different styling.

# Arguments
- `dropdown::DropdownControl`: The dropdown specification

# Returns
- `String`: HTML string for the single-select dropdown
"""
function generate_choice_dropdown_html(dropdown::DropdownControl)::String
    options_html = ""

    # Default value is a single string for choices
    default_value_str = dropdown.default_value isa String ? dropdown.default_value : string(dropdown.default_value)

    for option in dropdown.options
        selected = (string(option) == default_value_str) ? " selected" : ""
        options_html *= "                <option value=\"$option\"$selected>$option</option>\n"
    end

    return """
            <div style="margin: 10px; display: flex; align-items: center;">
                <div style="flex: 0 0 100%;">
                    <label for="$(dropdown.id)"><strong>$(dropdown.label)</strong>: </label>
                    <select id="$(dropdown.id)" onchange="$(dropdown.onchange)" style="padding: 5px 10px; font-weight: bold;">
    $options_html            </select>
                </div>
            </div>
            """
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
                    # Distinguish between integer and floating point types
                    if min_data isa Integer
                        value_type = :integer
                    else
                        value_type = :numeric
                    end
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
            <div style="margin: 10px 0; display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                <div>
                    <label for="facet1_select_$chart_title">Facet 1: </label>
                    <select id="facet1_select_$chart_title" style="padding: 5px 10px;" onchange="$update_function">
$options1                </select>
                </div>
                <div>
                    <label for="facet2_select_$chart_title">Facet 2: </label>
                    <select id="facet2_select_$chart_title" style="padding: 5px 10px;" onchange="$update_function">
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
                                           chart_div_id::String;
                                           choices_html::String="",
                                           aspect_ratio_default::Float64=0.6)

Generate appearance HTML from pre-built sections (for charts using custom controls).

This function provides the standard two-section layout without requiring DropdownControl objects.
Useful for charts that build their HTML sections directly.

# Arguments
- `filters_html::String`: Pre-built HTML for filter controls (multiselect)
- `plot_attributes_html::String`: Pre-built HTML for attribute controls
- `faceting_html::String`: Pre-built HTML for faceting controls (merged into Plot Attributes)
- `title::String`: Chart title
- `notes::String`: Chart notes/description
- `chart_div_id::String`: ID for the chart container div
- `choices_html::String`: Pre-built HTML for choice controls (single-select, displayed at top of filters)
- `aspect_ratio_default::Float64`: Default aspect ratio (default: 0.6)

# Returns
- `String`: Complete appearance HTML with two-section layout (Filters + Plot Attributes with facets)
"""
function generate_appearance_html_from_sections(filters_html::String,
                                                plot_attributes_html::String,
                                                faceting_html::String,
                                                title::String,
                                                notes::String,
                                                chart_div_id::String;
                                                choices_html::String="",
                                                aspect_ratio_default::Float64=0.6)::String
    # Combine choices and filters - choices go at the top
    combined_filters_html = choices_html * filters_html

    # Build filters section (includes both choices and filters)
    filters_section = combined_filters_html != "" ? """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff5f5;">
            <h4 style="margin-top: 0; display: flex; justify-content: space-between; align-items: center;">
                <span>Filters</span>
                <span id="$(chart_div_id)_total_obs" style="font-weight: normal; font-size: 0.9em; color: #666;"></span>
            </h4>
            $combined_filters_html
        </div>
        """ : ""

    # Build Plot Attributes section (includes facets if present)
    attributes_section = if plot_attributes_html != "" || faceting_html != ""
        # Combine plot attributes and facets
        combined_content = plot_attributes_html

        # Add facets section with subheading if facets exist
        if faceting_html != ""
            combined_content *= """
            <h4 style="margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;">Facets</h4>
            $faceting_html
            """
        end

        # Add aspect ratio slider at the bottom
        # Use logarithmic scale for better precision at smaller values
        log_min = log(0.25)
        log_max = log(2.5)
        log_default = log(aspect_ratio_default)
        combined_content *= """
        <div style="margin: 15px 0; padding-top: 10px; border-top: 1px solid #ddd;">
            <label for="$(chart_div_id)_aspect_ratio_slider">Aspect Ratio: </label>
            <span id="$(chart_div_id)_aspect_ratio_label">$aspect_ratio_default</span>
            <input type="range" id="$(chart_div_id)_aspect_ratio_slider"
                   min="$log_min" max="$log_max" step="0.01" value="$log_default"
                   style="width: 75%; margin-left: 10px;">
            <span style="margin-left: 10px; color: #666; font-size: 0.9em;">(0.25 - 2.5)</span>
        </div>
        """

        """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #f0fff0;">
            <h4 style="margin-top: 0;">Plot Attributes</h4>
            $combined_content
        </div>
        """
    else
        ""
    end

    return """
        <h2>$title</h2>
        <p>$notes</p>

        <!-- Filters (for data filtering) -->
        $filters_section
        <!-- Plot Attributes -->
        $attributes_section
        <!-- Chart -->
        <div id="$chart_div_id"></div>
        """
end

"""
    build_axis_controls_html(chart_title_safe::String,
                             update_function::String;
                             x_cols::Vector{Symbol}=Symbol[],
                             y_cols::Vector{Symbol}=Symbol[],
                             z_cols::Vector{Symbol}=Symbol[],
                             default_x::Union{Symbol,Nothing}=nothing,
                             default_y::Union{Symbol,Nothing}=nothing,
                             default_z::Union{Symbol,Nothing}=nothing)

Build axis controls HTML in a 2-column layout (dimensions on left, transforms on right).
Returns HTML string to be included in Plot Attributes section.

# Arguments
- `chart_title_safe::String`: Sanitized chart title for IDs
- `update_function::String`: JavaScript update function name
- `x_cols::Vector{Symbol}`: Available X dimension columns
- `y_cols::Vector{Symbol}`: Available Y dimension columns
- `z_cols::Vector{Symbol}`: Available Z dimension columns (for 3D charts)
- `default_x::Union{Symbol,Nothing}`: Default X column
- `default_y::Union{Symbol,Nothing}`: Default Y column
- `default_z::Union{Symbol,Nothing}`: Default Z column

# Returns
- `String`: HTML for axes section with 2-column layout
"""
function build_axis_controls_html(chart_title_safe::String,
                                  update_function::String;
                                  x_cols::Vector{Symbol}=Symbol[],
                                  y_cols::Vector{Symbol}=Symbol[],
                                  z_cols::Vector{Symbol}=Symbol[],
                                  default_x::Union{Symbol,Nothing}=nothing,
                                  default_y::Union{Symbol,Nothing}=nothing,
                                  default_z::Union{Symbol,Nothing}=nothing,
                                  include_x_transform::Bool=false,
                                  include_y_transform::Bool=true,
                                  include_cumulative::Bool=true,
                                  include_smoothing::Bool=false,
                                  default_ewma_weight::Float64=0.1,
                                  default_ewmstd_weight::Float64=0.1,
                                  default_sma_window::Int=10,
                                  default_y_transform::String="identity")::String

    if isempty(x_cols) && isempty(y_cols) && isempty(z_cols)
        return ""
    end

    # Base transform options
    base_transform_options = ["identity", "log", "z_score", "quantile", "inverse_cdf"]
    # Cumulative options only for certain chart types (like LineChart)
    cumulative_options = include_cumulative ? ["cumulative", "cumprod"] : String[]
    # Smoothing options only for certain chart types (like LineChart)
    smoothing_options = include_smoothing ? ["ewma", "ewmstd", "sma"] : String[]
    y_transform_options = vcat(base_transform_options, cumulative_options, smoothing_options)
    x_transform_options = base_transform_options  # X never has cumulative or smoothing
    transform_default = default_y_transform

    axes_html = "<h4 style=\"margin-top: 15px; margin-bottom: 10px; border-top: 1px solid #ddd; padding-top: 10px;\">Axes</h4>\n"

    # Put X, Y, transforms on the same line
    axes_html *= "<div style=\"display: flex; gap: 15px; flex-wrap: wrap; align-items: center;\">\n"

    # X variable
    if !isempty(x_cols)
        default_x_str = string(isnothing(default_x) ? x_cols[1] : default_x)

        if length(x_cols) > 1
            x_options = join(["""<option value="$(col)"$(string(col) == default_x_str ? " selected" : "")>$(col)</option>"""
                            for col in x_cols], "\n")
            axes_html *= """
                <div>
                    <label for="x_col_select_$chart_title_safe">X: </label>
                    <select id="x_col_select_$chart_title_safe" style="padding: 5px 10px;" onchange="$update_function">
                        $x_options
                    </select>
                </div>
            """
        else
            axes_html *= """
                <div>
                    <label>X: </label>
                    <span style="font-weight: bold;">$default_x_str</span>
                </div>
            """
        end

        # X transform (if enabled)
        if include_x_transform
            x_transform_opts = join(["""<option value="$(opt)"$(opt == transform_default ? " selected" : "")>$(opt)</option>"""
                                  for opt in x_transform_options], "\n")
            axes_html *= """
                <div>
                    <label for="x_transform_select_$chart_title_safe">X Transform: </label>
                    <select id="x_transform_select_$chart_title_safe" style="padding: 5px 10px;" onchange="$update_function">
                        $x_transform_opts
                    </select>
                </div>
            """
        end
    end

    # Y variable
    if !isempty(y_cols)
        default_y_str = string(isnothing(default_y) ? y_cols[1] : default_y)

        if length(y_cols) > 1
            y_options = join(["""<option value="$(col)"$(string(col) == default_y_str ? " selected" : "")>$(col)</option>"""
                            for col in y_cols], "\n")
            axes_html *= """
                <div>
                    <label for="y_col_select_$chart_title_safe">Y: </label>
                    <select id="y_col_select_$chart_title_safe" style="padding: 5px 10px;" onchange="$update_function">
                        $y_options
                    </select>
                </div>
            """
        else
            axes_html *= """
                <div>
                    <label>Y: </label>
                    <span style="font-weight: bold;">$default_y_str</span>
                </div>
            """
        end

        # Y transform (if enabled)
        if include_y_transform
            y_transform_opts = join(["""<option value="$(opt)"$(opt == transform_default ? " selected" : "")>$(opt)</option>"""
                                  for opt in y_transform_options], "\n")

            # Build onchange handler: show/hide smoothing param boxes + call update function
            y_transform_onchange = if include_smoothing
                """(function(){
                    var sel = document.getElementById('y_transform_select_$chart_title_safe').value;
                    document.getElementById('ewma_param_$chart_title_safe').style.display = (sel === 'ewma') ? '' : 'none';
                    document.getElementById('ewmstd_param_$chart_title_safe').style.display = (sel === 'ewmstd') ? '' : 'none';
                    document.getElementById('sma_param_$chart_title_safe').style.display = (sel === 'sma') ? '' : 'none';
                    $update_function;
                })()"""
            else
                update_function
            end

            axes_html *= """
                <div>
                    <label for="y_transform_select_$chart_title_safe">Y Transform: </label>
                    <select id="y_transform_select_$chart_title_safe" style="padding: 5px 10px;" onchange="$y_transform_onchange">
                        $y_transform_opts
                    </select>
                </div>
            """

        end
    end

    # Z variable (for 3D charts) - no transform, just variable selection
    if !isempty(z_cols)
        default_z_str = string(isnothing(default_z) ? z_cols[1] : default_z)

        if length(z_cols) > 1
            z_options = join(["""<option value="$(col)"$(string(col) == default_z_str ? " selected" : "")>$(col)</option>"""
                            for col in z_cols], "\n")
            axes_html *= """
                <div>
                    <label for="z_col_select_$chart_title_safe">Z: </label>
                    <select id="z_col_select_$chart_title_safe" style="padding: 5px 10px;" onchange="$update_function">
                        $z_options
                    </select>
                </div>
            """
        else
            axes_html *= """
                <div>
                    <label>Z: </label>
                    <span style="font-weight: bold;">$default_z_str</span>
                </div>
            """
        end
    end

    axes_html *= "</div>\n"

    # Add smoothing parameter input boxes below the axes flex row (hidden by default)
    if include_smoothing
        axes_html *= """
            <div id="ewma_param_$chart_title_safe" style="display:$(transform_default == "ewma" ? "" : "none"); margin-top: 5px;">
                <label for="ewma_weight_$chart_title_safe">EWMA weight: </label>
                <input type="number" id="ewma_weight_$chart_title_safe" value="$default_ewma_weight" min="0.001" max="1" step="0.01" style="width: 80px; padding: 3px;" onchange="$update_function">
            </div>
            <div id="ewmstd_param_$chart_title_safe" style="display:$(transform_default == "ewmstd" ? "" : "none"); margin-top: 5px;">
                <label for="ewmstd_weight_$chart_title_safe">EWMSTD weight: </label>
                <input type="number" id="ewmstd_weight_$chart_title_safe" value="$default_ewmstd_weight" min="0.001" max="1" step="0.01" style="width: 80px; padding: 3px;" onchange="$update_function">
            </div>
            <div id="sma_param_$chart_title_safe" style="display:$(transform_default == "sma" ? "" : "none"); margin-top: 5px;">
                <label for="sma_window_$chart_title_safe">SMA window: </label>
                <input type="number" id="sma_window_$chart_title_safe" value="$default_sma_window" min="1" step="1" style="width: 80px; padding: 3px;" onchange="$update_function">
            </div>
        """
    end

    return axes_html
end

"""
    generate_axes_section_html(axis_controls::Vector{DropdownControl})

Generate the "Axes" section HTML containing dimension and transformation selectors.

# Arguments
- `axis_controls::Vector{DropdownControl}`: Axis control dropdowns

# Returns
- `String`: HTML for the axes section
"""
function generate_axes_section_html(axis_controls::Vector{DropdownControl})::String
    if isempty(axis_controls)
        return ""
    end

    controls_html = ""
    for dropdown in axis_controls
        controls_html *= generate_dropdown_html(dropdown; multiselect=false)
    end

    return """
    <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fffaf0;">
        <h4 style="margin-top: 0;">Axes</h4>
        $controls_html
    </div>
    """
end
