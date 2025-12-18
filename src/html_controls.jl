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
- `default_value::String`: Default selected value
- `onchange::String`: JavaScript function to call on change
"""
struct DropdownControl
    id::String
    label::String
    options::Vector{String}
    default_value::String
    onchange::String
end

"""
    ChartHtmlControls

Complete specification for a chart's HTML controls (filters, attributes, facets).

# Fields
- `chart_title_safe::String`: Sanitized chart title for use in HTML IDs
- `chart_div_id::String`: ID of the main chart div element
- `update_function_name::String`: Name of the JavaScript update function
- `filter_dropdowns::Vector{DropdownControl}`: Categorical filter controls
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
    for option in dropdown.options
        selected = (option == dropdown.default_value) ? " selected" : ""
        options_html *= "                <option value=\"$option\"$selected>$option</option>\n"
    end

    multiple_attr = multiselect ? " multiple" : ""

    return """
            <div style="margin: 10px;">
                <label for="$(dropdown.id)">$(dropdown.label): </label>
                <select id="$(dropdown.id)"$multiple_attr onchange="$(dropdown.onchange)">
    $options_html            </select>
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
                                  multiselect_filters::Bool=true)::String

    # Build filters section
    filters_html = ""
    if !isempty(controls.filter_dropdowns)
        filter_controls_html = ""
        for dropdown in controls.filter_dropdowns
            filter_controls_html *= generate_dropdown_html(dropdown; multiselect=multiselect_filters)
        end

        filters_html = """
        <div style="margin-bottom: 15px; padding: 10px; border: 1px solid #ddd; background-color: #fff5f5;">
            <h4 style="margin-top: 0;">Filters</h4>
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

Helper function to build filter dropdown controls from filter dictionary.

# Arguments
- `chart_title_safe::String`: Sanitized chart title for IDs
- `filters::Dict{Symbol, Any}`: Filter specifications (col => default_value)
- `df::DataFrame`: DataFrame to extract filter options from
- `update_function::String`: JavaScript function name for updates

# Returns
- `Vector{DropdownControl}`: Vector of filter dropdown controls
"""
function build_filter_dropdowns(chart_title_safe::String,
                                filters::Dict{Symbol, Any},
                                df::DataFrame,
                                update_function::String)::Vector{DropdownControl}

    filter_dropdowns = DropdownControl[]

    for (col, default_val) in filters
        col_str = string(col)
        if col_str in names(df)
            # Get unique values for this column
            unique_vals = sort(unique(skipmissing(df[!, col])))
            options = [string(v) for v in unique_vals]

            # Determine default value
            default_str = string(default_val)
            if !(default_str in options)
                # If provided default not in options, use first option
                default_str = isempty(options) ? "" : options[1]
            end

            push!(filter_dropdowns, DropdownControl(
                "$(col)_select_$chart_title_safe",
                col_str,
                options,
                default_str,
                update_function
            ))
        end
    end

    return filter_dropdowns
end

"""
    detect_slider_type(df::DataFrame, col::Symbol)

Detect the appropriate slider type for a column based on its data type and values.

# Returns
- `:date` - for Date/DateTime columns
- `:continuous` - for numeric columns with >20 unique values
- `:categorical` - for all other cases (strings, or numeric with ≤20 unique values)
"""
function detect_slider_type(df::DataFrame, col::Symbol)
    col_data = df[!, col]
    eltype(col_data) <: Union{Date, DateTime, Missing} && return :date

    if eltype(col_data) <: Union{Number, Missing}
        unique_vals = unique(skipmissing(col_data))
        return length(unique_vals) <= 20 ? :categorical : :continuous
    end

    return :categorical
end

"""
    generate_slider_html_and_js(df::DataFrame,
                                slider_cols::Vector{Symbol},
                                chart_id::String,
                                update_function::String)

Generate HTML and JavaScript for filter sliders.

# Arguments
- `df::DataFrame`: The data to build sliders from
- `slider_cols::Vector{Symbol}`: Columns to create sliders for
- `chart_id::String`: Unique identifier for the chart (used in element IDs)
- `update_function::String`: JavaScript function name to call on change

# Returns
- `(sliders_html::String, slider_init_js::String)`: Tuple of HTML markup and JS initialization code

# Slider Types
- **Categorical**: Multi-select dropdown for columns with discrete values
- **Continuous**: Range slider for numeric columns with many values
- **Date**: Range slider for date/datetime columns
"""
function generate_slider_html_and_js(df::DataFrame,
                                     slider_cols::Vector{Symbol},
                                     chart_id::String,
                                     update_function::String)
    sliders_html = ""
    slider_init_js = ""

    for col in slider_cols
        slider_type = detect_slider_type(df, col)
        slider_id = "$(chart_id)_$(col)_slider"

        if slider_type == :categorical
            unique_vals = sort(unique(skipmissing(df[!, col])))
            options = join(["<option value=\"$(v)\" selected>$(v)</option>" for v in unique_vals], "\n")
            sliders_html *= """
            <div style="margin: 20px 0;">
                <label for="$slider_id">Filter by $(col): </label>
                <select id="$slider_id" multiple style="width: 300px; height: 100px;">
                    $options
                </select>
                <p style="margin: 5px 0;"><em>Hold Ctrl/Cmd to select multiple values</em></p>
            </div>
            """
            slider_init_js *= "                    document.getElementById('$slider_id').addEventListener('change', () => $update_function);\n"
        elseif slider_type == :continuous
            min_val, max_val = extrema(skipmissing(df[!, col]))
            sliders_html *= """
            <div style="margin: 20px 0;">
                <label>Filter by $(col): </label>
                <span id="$(slider_id)_label">$(round(min_val, digits=2)) to $(round(max_val, digits=2))</span>
                <div id="$slider_id" style="width: 300px; margin: 10px 0;"></div>
            </div>
            """
            slider_init_js *= """
                \$("#$slider_id").slider({
                    range: true, min: $min_val, max: $max_val, step: $(abs(max_val - min_val) / 1000),
                    values: [$min_val, $max_val],
                    slide: (e, ui) => \$("#$(slider_id)_label").text(ui.values[0].toFixed(2) + " to " + ui.values[1].toFixed(2)),
                    change: () => $update_function
                });
            """
        elseif slider_type == :date
            unique_dates = sort(unique(skipmissing(df[!, col])))
            date_strings = string.(unique_dates)
            sliders_html *= """
            <div style="margin: 20px 0;">
                <label>Filter by $(col): </label>
                <span id="$(slider_id)_label">$(first(date_strings)) to $(last(date_strings))</span>
                <div id="$slider_id" style="width: 300px; margin: 10px 0;"></div>
            </div>
            """
            slider_init_js *= """
                window.dateValues_$(slider_id) = $(JSON.json(date_strings));
                \$("#$slider_id").slider({
                    range: true, min: 0, max: $(length(unique_dates) - 1),
                    values: [0, $(length(unique_dates) - 1)],
                    slide: (e, ui) => {
                        const dates = window.dateValues_$(slider_id);
                        \$("#$(slider_id)_label").text(dates[ui.values[0]] + " to " + dates[ui.values[1]]);
                    },
                    change: () => $update_function
                });
            """
        end
    end

    return (sliders_html, slider_init_js)
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
                                         default_group_col::Union{Symbol, Nothing},
                                         update_function::String;
                                         label::String="Group by")

Generate group column selection dropdown HTML with "None" option.

# Arguments
- `chart_title::String`: Chart title for element IDs
- `group_cols::Vector{Symbol}`: Available group columns
- `default_group_col::Union{Symbol, Nothing}`: Default selected column (nothing for "None")
- `update_function::String`: JavaScript function to call on change
- `label::String`: Label text for the dropdown (default: "Group by")

# Returns
- `(html::String, js::String)`: Tuple of (HTML string, JavaScript init string)
  Returns empty strings if fewer than 2 group columns
"""
function generate_group_column_dropdown_html(chart_title::String,
                                               group_cols::Vector{Symbol},
                                               default_group_col::Union{Symbol, Nothing},
                                               update_function::String;
                                               label::String="Group by")::Tuple{String, String}

    if length(group_cols) < 2
        return ("", "")
    end

    group_options_html = """<option value="_none_"$(default_group_col === nothing ? " selected" : "")>None</option>\n""" *
                        join(["""<option value="$(col)"$(col == default_group_col ? " selected" : "")>$(col)</option>"""
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

Generate appearance HTML from pre-built sections (for charts using sliders or custom controls).

This function provides the standard three-section layout without requiring DropdownControl objects.
Useful for charts that build their HTML sections directly (e.g., using sliders instead of dropdowns).

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
            <h4 style="margin-top: 0;">Filters</h4>
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
