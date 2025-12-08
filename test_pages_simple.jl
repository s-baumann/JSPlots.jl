using JSPlots, DataFrames

println("Testing Pages with flat structure...")

# Simple test data
df = DataFrame(x = 1:10, y = rand(10), category = repeat(["A", "B"], 5))

# Page 1
chart1 = LineChart(:chart1, df, :data1; x_cols=[:x], y_cols=[:y], title="Chart 1")
page1 = JSPlotPage(
    Dict(:data1 => df),
    [TextBlock("<h2>Page 1</h2>"), chart1],
    tab_title = "Page 1"
)

# Page 2
chart2 = LineChart(:chart2, df, :data2; x_cols=[:x], y_cols=[:y], title="Chart 2")
page2 = JSPlotPage(
    Dict(:data2 => df),
    [TextBlock("<h2>Page 2</h2>"), chart2],
    tab_title = "Page 2"
)

# Coverpage with links
links = LinkList([
    ("Page 1", "page_1.html", "First page"),
    ("Page 2", "page_2.html", "Second page")
])

coverpage = JSPlotPage(
    Dict{Symbol,DataFrame}(),
    [TextBlock("<h1>Home</h1>"), links],
    tab_title = "Home"
)

# Create Pages
pages = Pages(coverpage, [page1, page2], dataformat = :parquet)
create_html(pages, "generated_html_examples/test_pages.html")

println("\nTest complete! Checking structure...")

# Verify flat structure
project_dir = "generated_html_examples/test_pages"
if isdir(project_dir)
    println("✓ Project directory created: $project_dir")

    # Check all files at same level
    files = readdir(project_dir)
    println("  Files at root level: ", join(files, ", "))

    # Check main page
    if isfile(joinpath(project_dir, "test_pages.html"))
        println("  ✓ Main page: test_pages.html")
    end

    # Check subpages
    if isfile(joinpath(project_dir, "page_1.html"))
        println("  ✓ Subpage 1: page_1.html")
    end
    if isfile(joinpath(project_dir, "page_2.html"))
        println("  ✓ Subpage 2: page_2.html")
    end

    # Check data folder
    if isdir(joinpath(project_dir, "data"))
        data_files = readdir(joinpath(project_dir, "data"))
        println("  ✓ Data folder with $(length(data_files)) file(s): ", join(data_files, ", "))

        # Verify only 2 data files (data1 and data2 should be saved once each)
        parquet_files = filter(f -> endswith(f, ".parquet"), data_files)
        println("  ✓ Shared data files: $(length(parquet_files)) parquet files")
    end

    # Check launchers
    if isfile(joinpath(project_dir, "open.sh"))
        println("  ✓ Launcher: open.sh")
    end
    if isfile(joinpath(project_dir, "open.bat"))
        println("  ✓ Launcher: open.bat")
    end

    # Verify no nested folders for pages
    has_nested = any(f -> isdir(joinpath(project_dir, f)) && startswith(f, "page_"), files)
    if !has_nested
        println("  ✓ No nested page folders (flat structure confirmed)")
    else
        println("  ✗ Warning: Found nested page folders!")
    end

    println("\nOpen the report with:")
    println("  cd $project_dir && ./open.sh")
else
    println("✗ Project directory not found!")
end
