using JSPlots
using DataFrames
using Dates

# Notes Example
# =============
# This example demonstrates the Notes chart type which allows you to add
# editable commentary to your visualizations.
#
# When using external data formats (csv_external, json_external, parquet),
# Notes creates text files that you can edit after the HTML is generated.
# Your notes will then appear in the HTML document with a distinctive
# pale yellow background.
#
# Workflow:
# 1. Run this script to generate the HTML and notes files
# 2. Open the HTML to view your charts
# 3. Edit the .txt files in the 'notes' folder with your observations
# 4. Refresh the HTML to see your notes displayed

# Create some sample data
dates = Date(2024, 1, 1):Day(1):Date(2024, 3, 31)
sales_df = DataFrame(
    date = dates,
    sales = cumsum(rand(length(dates)) .* 100),
    region = repeat(["North", "South"], outer=length(dates) ÷ 2 + 1)[1:length(dates)]
)

# Create a simple line chart
sales_chart = LineChart(:sales_trend, sales_df, :sales_data;
    x_cols = [:date],
    y_cols = [:sales],
    title = "Quarterly Sales Trend",
    notes = "Daily cumulative sales data"
)

# Create Notes sections for different purposes
# Each Notes block creates a text file that can be edited

# Main observations note
observations_note = Notes(
    template = """Key Observations:
-
-
-

Questions to investigate:
1.
2.
""",
    heading = "Analysis Notes",
    textfilename = "observations.txt"
)

# Methodology note
methodology_note = Notes(
    template = """Data Sources:
- Sales data from internal CRM

Processing Steps:
1. Aggregated daily totals
2. Calculated cumulative sum

Known Limitations:
-
""",
    heading = "Methodology",
    textfilename = "methodology.txt"
)

# Conclusions note
conclusions_note = Notes(
    template = """Summary:


Recommendations:
1.
2.

Next Steps:
-
""",
    heading = "Conclusions",
    textfilename = "conclusions.txt"
)

# Create the page with all elements
page = JSPlotPage(
    Dict{Symbol, Any}(:sales_data => sales_df),
    [
        TextBlock("<h1>Sales Analysis Report</h1><p>This report analyzes quarterly sales trends with space for analyst commentary.</p>"),
        methodology_note,
        sales_chart,
        observations_note,
        conclusions_note
    ];
    tab_title = "Sales Analysis with Notes",
    page_header = "Q1 2024 Sales Analysis",
    dataformat = :parquet  # External format enables editable notes files
)

# Generate the HTML
output_path = joinpath(dirname(@__DIR__), "generated_html_examples", "notes_example.html")
# Manifest entry for report index
manifest_entry = ManifestEntry(path="../notes_example", html_filename="notes_example.html",
                               description="Notes Examples", date=today(),
                               extra_columns=Dict(:chart_type => "Text & Code", :page_type => "Chart Tutorial"))
create_html(page, output_path;
            manifest="generated_html_examples/z_general_example/manifest.csv", manifest_entry=manifest_entry)

println("""

Notes Example Generated!
========================

Output: $(output_path)

To use the Notes feature:
1. Open the generated HTML in a browser
2. You'll see pale yellow notes sections with placeholder text
3. Navigate to the 'notes' folder in the output directory
4. Edit the .txt files (observations.txt, methodology.txt, conclusions.txt)
5. Refresh the HTML page to see your notes

Note: If you don't edit the notes files, they will show "No notes provided"
      Once you add content beyond the template, your notes will be displayed.
""")
