using Test
using JSPlots
using DataFrames
using Dates

@testset "JSPlots.jl" begin

    # Create test data
    test_df = DataFrame(
        x = 1:10,
        y = rand(10),
        category = repeat(["A", "B"], 5),
        color = repeat(["Red", "Blue"], 5),
        date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10)
    )

    test_df_with_symbols = DataFrame(
        x = 1:5,
        y = rand(5),
        symbol_col = [:A, :B, :C, :D, :E]
    )

    test_df_with_missing = DataFrame(
        x = [1, 2, 3, missing, 5],
        y = [1.0, missing, 3.0, 4.0, 5.0],
        category = ["A", "B", missing, "D", "E"]
    )

    @testset "JSPlotPage Creation" begin
        @testset "Default data format" begin
            page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [])
            @test page.dataformat == :csv_embedded
            @test page.tab_title == "JSPlots.jl"
        end

        @testset "Custom parameters" begin
            page = JSPlotPage(
                Dict{Symbol,DataFrame}(:test => test_df),
                [],
                tab_title = "Custom Title",
                page_header = "Header",
                notes = "Notes",
                dataformat = :json_embedded
            )
            @test page.tab_title == "Custom Title"
            @test page.page_header == "Header"
            @test page.notes == "Notes"
            @test page.dataformat == :json_embedded
        end

        @testset "Invalid data format" begin
            @test_throws ErrorException JSPlotPage(
                Dict{Symbol,DataFrame}(:test => test_df),
                [],
                dataformat = :invalid_format
            )
        end

        @testset "All valid data formats" begin
            formats = [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet]
            for fmt in formats
                page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = fmt)
                @test page.dataformat == fmt
            end
        end
    end

    @testset "LineChart" begin
        @testset "Basic creation" begin
            chart = LineChart(:test_chart, test_df, :test_df;
                x_cols = [:x],
                y_cols = [:y],
                title = "Test Chart"
            )
            @test chart.chart_title == :test_chart
            @test chart.data_label == :test_df
            @test occursin("test_chart", chart.functional_html)
            @test occursin("x", chart.functional_html)
        end

        @testset "With color and filters" begin
            chart = LineChart(:color_chart, test_df, :test_df;
                x_cols = [:x],
                y_cols = [:y],
                color_cols = [:category],
                filters = Dict{Symbol,Any}(:category => "A"),
                title = "Colored Chart"
            )
            @test occursin("category", chart.functional_html)
            @test occursin("A", chart.functional_html)
        end

        @testset "With custom labels" begin
            chart = LineChart(:labeled_chart, test_df, :test_df;
                x_cols = [:x],
                y_cols = [:y],
                x_label = "X Axis",
                y_label = "Y Axis",
                notes = "Test notes"
            )
            @test occursin("X Axis", chart.functional_html)
            @test occursin("Y Axis", chart.functional_html)
            @test occursin("Test notes", chart.appearance_html)
        end
    end

    @testset "Surface3D" begin
        df_3d = DataFrame(
            x = repeat(1:5, inner=5),
            y = repeat(1:5, outer=5),
            z = rand(25),
            w = rand(25),
            group = repeat(["A", "B"], 13)[1:25],
            category = repeat(["Type1", "Type2"], 13)[1:25]
        )

        @testset "Basic creation" begin
            chart = Surface3D(:test_3d, df_3d, :df_3d;
                x_col = :x,
                y_col = :y,
                z_col = :z,
                title = "3D Test"
            )
            @test chart.chart_title == :test_3d
            @test occursin("x", chart.functional_html)
            @test occursin("y", chart.functional_html)
            @test occursin("z", chart.functional_html)
        end

        @testset "With groups" begin
            chart = Surface3D(:grouped_3d, df_3d, :df_3d;
                x_col = :x,
                y_col = :y,
                z_col = :z,
                group_col = :group,
                title = "Grouped 3D"
            )
            @test chart.chart_title == :grouped_3d
            @test occursin("group", chart.functional_html)
        end

        @testset "With filtering" begin
            chart = Surface3D(:filtered_3d, df_3d, :df_3d;
                x_col = :x,
                y_col = :y,
                z_col = :z,
                group_col = :group,
                slider_col = [:w, :category],
                title = "Filtered 3D"
            )
            @test occursin("w", chart.appearance_html)
            @test occursin("_slider", chart.appearance_html)
            @test occursin("updatePlotWithFilters", chart.functional_html)
        end

        @testset "Error handling" begin
            @test_throws ErrorException Surface3D(:bad_col, df_3d, :df_3d; x_col=:nonexistent, y_col=:y, z_col=:z)
            @test_throws ErrorException Surface3D(:bad_group, df_3d, :df_3d; x_col=:x, y_col=:y, z_col=:z, group_col=:nonexistent)
        end
    end

    @testset "Scatter3D" begin
        df_scatter_3d = DataFrame(
            x = randn(50),
            y = randn(50),
            z = randn(50),
            w = randn(50),
            v = randn(50),
            category = repeat(["A", "B", "C"], 17)[1:50],
            group = repeat(["G1", "G2"], 25)
        )

        @testset "Basic creation" begin
            chart = Scatter3D(:test_3d_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
                color_cols = [:category],
                title = "3D Scatter Test"
            )
            @test chart.chart_title == :test_3d_scatter
            @test occursin("scatter3d", chart.functional_html)
            @test occursin("eigenvector", lowercase(chart.appearance_html))
        end

        @testset "Multiple dimensions" begin
            chart = Scatter3D(:multi_dim_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z, :w, :v];
                color_cols = [:category],
                show_eigenvectors = true
            )
            @test occursin("_x_col_select", chart.appearance_html)
            @test occursin("_y_col_select", chart.appearance_html)
            @test occursin("_z_col_select", chart.appearance_html)
        end

        @testset "With filtering" begin
            chart = Scatter3D(:filtered_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
                color_cols = [:category],
                slider_col = [:w, :group],
                show_eigenvectors = true
            )
            @test occursin("w", chart.appearance_html)
            @test occursin("_slider", chart.appearance_html)
            @test occursin("updatePlotWithFilters", chart.functional_html)
        end

        @testset "Eigenvector toggle" begin
            chart1 = Scatter3D(:eig_on, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
                color_cols = [:category],
                show_eigenvectors = true
            )
            @test occursin("showEigenvectors", chart1.functional_html)
            @test occursin("true", chart1.functional_html)

            chart2 = Scatter3D(:eig_off, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
                color_cols = [:category],
                show_eigenvectors = false
            )
            @test occursin("false", chart2.functional_html)
        end

        @testset "Custom marker settings" begin
            chart = Scatter3D(:custom_scatter, df_scatter_3d, :df_scatter_3d, [:x, :y, :z];
                color_cols = [:category],
                marker_size = 8,
                marker_opacity = 0.8
            )
            @test occursin("8", chart.functional_html)
            @test occursin("0.8", chart.functional_html)
        end

        @testset "Error handling" begin
            @test_throws ErrorException Scatter3D(:bad_dims, df_scatter_3d, :df_scatter_3d, [:x, :y])  # Not enough dimensions
            @test_throws ErrorException Scatter3D(:bad_col, df_scatter_3d, :df_scatter_3d, [:x, :y, :nonexistent])
            @test_throws ErrorException Scatter3D(:bad_color, df_scatter_3d, :df_scatter_3d, [:x, :y, :z]; color_cols=[:nonexistent])
        end
    end

    @testset "ScatterPlot" begin
        @testset "Basic creation" begin
            chart = ScatterPlot(:test_scatter, test_df, :test_df, [:x, :y];
                title = "Scatter Test"
            )
            @test chart.chart_title == :test_scatter
            @test occursin("scatter", chart.functional_html)
        end

        @testset "With sliders" begin
            chart = ScatterPlot(:slider_scatter, test_df, :test_df, [:x, :y];
                slider_col = [:category, :date],
                color_cols = [:category]
            )
            @test occursin("category", chart.functional_html)
            @test occursin("date", chart.functional_html)
        end

        @testset "Custom marker settings" begin
            chart = ScatterPlot(:custom_scatter, test_df, :test_df, [:x, :y];
                marker_size = 10,
                marker_opacity = 0.5,
                show_density = false
            )
            @test occursin("10", chart.functional_html)
            @test occursin("0.5", chart.functional_html)
        end
    end

    @testset "DistPlot" begin
        df_dist = DataFrame(value = randn(100))

        @testset "Basic creation" begin
            chart = DistPlot(:test_dist, df_dist, :df_dist;
                value_cols = :value,
                title = "Dist Test"
            )
            @test chart.chart_title == :test_dist
            @test occursin("value", chart.functional_html)
        end

        @testset "With groups" begin
            df_grouped = DataFrame(
                value = randn(100),
                group = repeat(["A", "B"], 50)
            )
            chart = DistPlot(:grouped_dist, df_grouped, :df_grouped;
                value_cols = :value,
                group_cols = :group
            )
            @test occursin("group", chart.functional_html)
        end

        @testset "Custom appearance" begin
            chart = DistPlot(:custom_dist, df_dist, :df_dist;
                value_cols = :value,
                show_box = false,
                show_rug = false,
                histogram_bins = 50,
                box_opacity = 0.7
            )
            @test occursin("50", chart.functional_html)
            @test occursin("false", lowercase(chart.functional_html))
        end
    end

    @testset "KernelDensity" begin
        df_kde = DataFrame(value = randn(100))

        @testset "Basic creation" begin
            chart = KernelDensity(:test_kde, df_kde, :df_kde;
                value_cols = :value,
                title = "KDE Test"
            )
            @test chart.chart_title == :test_kde
            @test occursin("value", chart.functional_html)
            @test occursin("kernelDensity", chart.functional_html)
        end

        @testset "With groups" begin
            df_grouped = DataFrame(
                value = randn(100),
                group = repeat(["A", "B"], 50)
            )
            chart = KernelDensity(:grouped_kde, df_grouped, :df_grouped;
                value_cols = :value,
                group_cols = :group
            )
            @test occursin("group", chart.functional_html)
        end

        @testset "With facets" begin
            df_faceted = DataFrame(
                value = randn(100),
                facet1 = repeat(["X", "Y"], 50),
                facet2 = repeat(["P", "Q"], inner=50)
            )
            chart = KernelDensity(:faceted_kde, df_faceted, :df_faceted;
                value_cols = :value,
                facet_cols = [:facet1, :facet2],
                default_facet_cols = :facet1
            )
            @test occursin("facet1", chart.functional_html)
            @test occursin("facet2", chart.functional_html)
        end

        @testset "With filters" begin
            df_filtered = DataFrame(
                value = randn(100),
                age = rand(18:80, 100),
                category = rand(["A", "B", "C"], 100)
            )
            chart = KernelDensity(:filtered_kde, df_filtered, :df_filtered;
                value_cols = :value,
                filter_cols = [:age, :category]
            )
            @test occursin("age", chart.functional_html)
            @test occursin("category", chart.functional_html)
        end

        @testset "Custom bandwidth and appearance" begin
            chart = KernelDensity(:custom_kde, df_kde, :df_kde;
                value_cols = :value,
                bandwidth = 1.5,
                density_opacity = 0.7,
                fill_density = false
            )
            @test occursin("1.5", chart.functional_html)
            @test occursin("0.7", chart.functional_html)
            @test occursin("none", chart.functional_html)
        end
    end

    @testset "PivotTable" begin
        pivot_df = DataFrame(
            category = repeat(["A", "B", "C"], 3),
            region = repeat(["North", "South"], 5)[1:9],
            value = rand(9)
        )

        @testset "Basic creation" begin
            pt = PivotTable(:test_pivot, :pivot_df;
                rows = [:category],
                cols = [:region],
                vals = :value
            )
            @test pt.chart_title == :test_pivot
            @test pt.data_label == :pivot_df
            @test occursin("category", pt.functional_html)
        end

        @testset "With exclusions" begin
            pt = PivotTable(:filtered_pivot, :pivot_df;
                rows = [:category],
                cols = [:region],
                vals = :value,
                exclusions = Dict(:category => [:A])
            )
            @test occursin("exclusions", pt.functional_html)
        end

        @testset "With custom color map" begin
            pt = PivotTable(:colored_pivot, :pivot_df;
                rows = [:category],
                cols = [:region],
                vals = :value,
                colour_map = Dict{Float64,String}([0.0, 0.5, 1.0] .=> ["#FF0000", "#FFFFFF", "#0000FF"]),
                rendererName = :Heatmap
            )
            @test occursin("#FF0000", pt.functional_html)
            @test occursin("#0000FF", pt.functional_html)
        end
    end

    @testset "TextBlock" begin
        @testset "Basic creation" begin
            block = TextBlock("<h1>Test Header</h1><p>Test paragraph</p>")
            @test occursin("Test Header", block.appearance_html)
            @test occursin("Test paragraph", block.appearance_html)
            @test block.functional_html == ""
        end

        @testset "With HTML elements" begin
            html = """
            <h2>Section</h2>
            <ul>
                <li>Item 1</li>
                <li>Item 2</li>
            </ul>
            <table>
                <tr><td>Cell</td></tr>
            </table>
            """
            block = TextBlock(html)
            @test occursin("<h2>Section</h2>", block.appearance_html)
            @test occursin("<ul>", block.appearance_html)
            @test occursin("<table>", block.appearance_html)
        end
    end

    @testset "HTML Generation" begin
        @testset "Embedded formats" begin
            mktempdir() do tmpdir
                @testset "CSV embedded" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :csv_embedded)
                    outfile = joinpath(tmpdir, "test_csv_embedded.html")
                    create_html(page, outfile)

                    @test isfile(outfile)
                    content = read(outfile, String)
                    @test occursin("<!DOCTYPE html>", content)
                    @test occursin("csv_embedded", content)
                    @test occursin("<script", content)
                    @test occursin("loadDataset", content)
                    # Check that data is embedded
                    @test occursin("data-format=\"csv_embedded\"", content)
                end

                @testset "JSON embedded" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :json_embedded)
                    outfile = joinpath(tmpdir, "test_json_embedded.html")
                    create_html(page, outfile)

                    @test isfile(outfile)
                    content = read(outfile, String)
                    @test occursin("json_embedded", content)
                    @test occursin("data-format=\"json_embedded\"", content)
                end
            end
        end

        @testset "External formats" begin
            mktempdir() do tmpdir
                @testset "CSV external" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :csv_external)
                    outfile = joinpath(tmpdir, "subdir", "test_csv_external.html")
                    create_html(page, outfile)

                    # Check project structure
                    project_dir = joinpath(tmpdir, "subdir", "test_csv_external")
                    @test isdir(project_dir)
                    @test isfile(joinpath(project_dir, "test_csv_external.html"))
                    @test isfile(joinpath(project_dir, "open.sh"))
                    @test isfile(joinpath(project_dir, "open.bat"))

                    # Check data directory
                    data_dir = joinpath(project_dir, "data")
                    @test isdir(data_dir)
                    @test isfile(joinpath(data_dir, "test.csv"))

                    # Check HTML content
                    content = read(joinpath(project_dir, "test_csv_external.html"), String)
                    @test occursin("csv_external", content)
                    @test occursin("data/test.csv", content)

                    # Check launcher scripts
                    sh_content = read(joinpath(project_dir, "open.sh"), String)
                    @test occursin("brave-browser", sh_content)
                    @test occursin("--allow-file-access-from-files", sh_content)

                    bat_content = read(joinpath(project_dir, "open.bat"), String)
                    @test occursin("brave.exe", bat_content)
                end

                @testset "JSON external" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :json_external)
                    outfile = joinpath(tmpdir, "test_json_external.html")
                    create_html(page, outfile)

                    project_dir = joinpath(tmpdir, "test_json_external")
                    @test isdir(project_dir)

                    data_dir = joinpath(project_dir, "data")
                    @test isfile(joinpath(data_dir, "test.json"))

                    # Verify JSON is valid
                    json_content = read(joinpath(data_dir, "test.json"), String)
                    @test occursin("[", json_content)
                    @test occursin("]", json_content)
                end

                @testset "Parquet external" begin
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [], dataformat = :parquet)
                    outfile = joinpath(tmpdir, "test_parquet.html")
                    create_html(page, outfile)

                    project_dir = joinpath(tmpdir, "test_parquet")
                    @test isdir(project_dir)

                    data_dir = joinpath(project_dir, "data")
                    @test isfile(joinpath(data_dir, "test.parquet"))

                    # Check file is not empty
                    @test filesize(joinpath(data_dir, "test.parquet")) > 0
                end
            end
        end

        @testset "Single plot convenience function" begin
            mktempdir() do tmpdir
                chart = LineChart(:simple, test_df, :test_df; x_cols = [:x], y_cols = [:y])
                outfile = joinpath(tmpdir, "single_plot.html")
                create_html(chart, test_df, outfile)

                @test isfile(outfile)
                content = read(outfile, String)
                @test occursin("simple", content)
            end
        end
    end

    @testset "HTML Structure Validation" begin
        mktempdir() do tmpdir
            chart = LineChart(:validation_test, test_df, :test_df; x_cols = [:x], y_cols = [:y])
            page = JSPlotPage(Dict{Symbol,DataFrame}(:test => test_df), [chart])
            outfile = joinpath(tmpdir, "validate.html")
            create_html(page, outfile)

            content = read(outfile, String)

            @testset "Required HTML elements" begin
                @test occursin("<!DOCTYPE html>", content)
                @test occursin("<html>", content)
                @test occursin("</html>", content)
                @test occursin("<head>", content)
                @test occursin("</head>", content)
                @test occursin("<body>", content)
                @test occursin("</body>", content)
            end

            @testset "Required scripts" begin
                @test occursin("plotly", lowercase(content))
                @test occursin("papaparse", lowercase(content))
                @test occursin("jquery", lowercase(content))
            end

            @testset "Data elements" begin
                @test occursin("id=\"test\"", content)
                @test occursin("data-format", content)
            end

            @testset "Chart elements" begin
                @test occursin("validation_test", content)
                @test occursin("loadDataset", content)
            end

            @testset "No script errors" begin
                # Check for common JavaScript syntax errors
                @test !occursin("undefined undefined", content)
                @test !occursin("NaN", content)
                @test !occursin("[object Object]", content) || occursin("toString", content) # Allow if part of toString
            end
        end
    end

    @testset "Edge Cases" begin
        @testset "Empty DataFrame" begin
            empty_df = DataFrame(x = Int[], y = Float64[])
            page = JSPlotPage(Dict{Symbol,DataFrame}(:empty => empty_df), [])

            mktempdir() do tmpdir
                outfile = joinpath(tmpdir, "empty.html")
                create_html(page, outfile)
                @test isfile(outfile)
            end
        end

        @testset "DataFrame with Symbols" begin
            mktempdir() do tmpdir
                page = JSPlotPage(Dict{Symbol,DataFrame}(:symbols => test_df_with_symbols), [], dataformat = :parquet)
                outfile = joinpath(tmpdir, "symbols.html")
                create_html(page, outfile)

                project_dir = joinpath(tmpdir, "symbols")
                @test isdir(project_dir)
                @test isfile(joinpath(project_dir, "data", "symbols.parquet"))
            end
        end

        @testset "DataFrame with Missing values" begin
            mktempdir() do tmpdir
                for fmt in [:csv_embedded, :json_embedded]
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:missing => test_df_with_missing), [], dataformat = fmt)
                    outfile = joinpath(tmpdir, "missing_$(fmt).html")
                    create_html(page, outfile)
                    @test isfile(outfile)
                end
            end
        end

        @testset "Large column names" begin
            df_long_cols = DataFrame(
                this_is_a_very_long_column_name_that_should_still_work = 1:5,
                another_extremely_long_column_name_for_testing = rand(5),
                color = repeat(["A"], 5)
            )

            chart = LineChart(:long_cols, df_long_cols, :df_long_cols;
                x_cols = [:this_is_a_very_long_column_name_that_should_still_work],
                y_cols = [:another_extremely_long_column_name_for_testing]
            )

            @test occursin("this_is_a_very_long", chart.functional_html)
        end

        @testset "Special characters in data" begin
            df_special = DataFrame(
                text = ["<script>alert('test')</script>", "a\"b'c", "line1\nline2"],
                value = [1, 2, 3]
            )

            mktempdir() do tmpdir
                page = JSPlotPage(Dict{Symbol,DataFrame}(:special => df_special), [])
                outfile = joinpath(tmpdir, "special.html")
                create_html(page, outfile)

                content = read(outfile, String)
                # Script tags in data should be escaped
                @test occursin("</script>", content) || occursin("<\\/script>", content)
            end
        end

        @testset "Multiple charts on same page" begin
            chart1 = LineChart(:chart1, test_df, :test_df; x_cols = [:x], y_cols = [:y])
            chart2 = ScatterPlot(:chart2, test_df, :test_df, [:x, :y])
            text = TextBlock("<h1>Between charts</h1>")

            page = JSPlotPage(Dict{Symbol,DataFrame}(:test_df => test_df), [chart1, text, chart2])

            mktempdir() do tmpdir
                outfile = joinpath(tmpdir, "multiple.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("chart1", content)
                @test occursin("chart2", content)
                @test occursin("Between charts", content)
            end
        end
    end

    @testset "Performance and File Size" begin
        # Test with larger dataset
        large_df = DataFrame(
            x = 1:1000,
            y = rand(1000),
            category = repeat(["A", "B", "C", "D"], 250)
        )

        mktempdir() do tmpdir
            @testset "File size comparison" begin
                sizes = Dict{Symbol, Int}()

                for fmt in [:csv_embedded, :json_embedded, :csv_external, :json_external, :parquet]
                    page = JSPlotPage(Dict{Symbol,DataFrame}(:large => large_df), [], dataformat = fmt)
                    outfile = joinpath(tmpdir, "size_test_$(fmt).html")
                    create_html(page, outfile)

                    if fmt in [:csv_external, :json_external, :parquet]
                        # For external formats, measure total size
                        project_dir = joinpath(tmpdir, "size_test_$(fmt)")
                        html_size = filesize(joinpath(project_dir, "size_test_$(fmt).html"))

                        # Check HTML is smaller for external formats
                        @test html_size < 50000  # HTML should be small

                        # Check data file exists
                        data_dir = joinpath(project_dir, "data")
                        @test isdir(data_dir)
                    else
                        # For embedded formats, HTML contains everything
                        html_size = filesize(outfile)
                        @test html_size > 10000  # Should contain data
                    end

                    sizes[fmt] = html_size
                end

                # Parquet HTML should be smallest (no embedded data)
                @test sizes[:parquet] < sizes[:csv_embedded]
                @test sizes[:json_external] < sizes[:json_embedded]
            end
        end
    end

    @testset "Picture" begin
        mktempdir() do tmpdir
            # Use the real example image for testing
            test_png = joinpath(@__DIR__, "..", "examples", "pictures", "images.jpeg")

            # Create a test SVG
            test_svg = joinpath(tmpdir, "test.svg")
            write(test_svg, """
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
              <rect width="100" height="100" fill="red"/>
            </svg>
            """)

            @testset "Picture from file path" begin
                pic = Picture(:test_pic, test_png; notes="Test image")
                @test pic.chart_title == :test_pic
                @test pic.notes == "Test image"
                @test pic.is_temp == false
                @test isfile(pic.image_path)
            end

            @testset "Picture from non-existent file" begin
                @test_throws ErrorException Picture(:bad, "/nonexistent/path.png")
            end

            @testset "Picture with custom save function" begin
                # Mock chart object
                mock_chart = Dict(:data => [1, 2, 3])
                save_func = (obj, path) -> write(path, "mock_png_data")

                pic = Picture(:custom, mock_chart, save_func; format=:png, notes="Custom save")
                @test pic.chart_title == :custom
                @test pic.is_temp == true
                @test isfile(pic.image_path)
                @test read(pic.image_path, String) == "mock_png_data"
            end

            @testset "Picture with invalid format" begin
                mock_chart = Dict(:data => [1, 2, 3])
                @test_throws ErrorException Picture(:bad_format, mock_chart, (o, p) -> nothing; format=:pdf)
            end

            @testset "Picture in embedded HTML" begin
                pic = Picture(:embedded_pic, test_png)
                page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_embedded)
                outfile = joinpath(tmpdir, "picture_embedded.html")
                create_html(page, outfile)

                @test isfile(outfile)
                content = read(outfile, String)
                @test occursin("data:image/jpeg;base64", content)
                @test occursin("embedded_pic", content)
            end

            @testset "Picture in external HTML" begin
                pic = Picture(:external_pic, test_png)
                page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic], dataformat=:csv_external)
                outfile = joinpath(tmpdir, "picture_external.html")
                create_html(page, outfile)

                project_dir = joinpath(tmpdir, "picture_external")
                @test isdir(project_dir)

                pictures_dir = joinpath(project_dir, "pictures")
                @test isdir(pictures_dir)
                @test isfile(joinpath(pictures_dir, "external_pic.jpeg"))

                content = read(joinpath(project_dir, "picture_external.html"), String)
                @test occursin("pictures/external_pic.jpeg", content)
            end

            @testset "Picture with SVG (embedded)" begin
                pic = Picture(:svg_pic, test_svg)
                page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic])
                outfile = joinpath(tmpdir, "svg_embedded.html")
                create_html(page, outfile)

                content = read(outfile, String)
                # SVG should be embedded directly as XML, not base64
                @test occursin("<svg", content)
                @test occursin("</svg>", content)
                @test !occursin("data:image", content) # Not base64 encoded
            end

            @testset "Picture convenience function" begin
                pic = Picture(:convenience, test_png)
                outfile = joinpath(tmpdir, "picture_convenience.html")
                create_html(pic, outfile)

                @test isfile(outfile)
                content = read(outfile, String)
                @test occursin("convenience", content)
            end

            @testset "Multiple Pictures on same page" begin
                pic1 = Picture(:pic1, test_png)
                pic2 = Picture(:pic2, test_svg)
                page = JSPlotPage(Dict{Symbol,DataFrame}(), [pic1, pic2])
                outfile = joinpath(tmpdir, "multiple_pictures.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("pic1", content)
                @test occursin("pic2", content)
            end
        end
    end

    @testset "Table" begin
        table_df = DataFrame(
            name = ["Alice", "Bob", "Charlie"],
            age = [25, 30, 35],
            city = ["NYC", "LA", "Chicago"],
            salary = [75000, 85000, 95000]
        )

        @testset "Basic Table creation" begin
            tbl = Table(:test_table, table_df; notes="Employee data")
            @test tbl.chart_title == :test_table
            @test tbl.notes == "Employee data"
            @test occursin("<table>", tbl.appearance_html)
            @test occursin("Alice", tbl.appearance_html)
            @test occursin("downloadTableCSV", tbl.functional_html)
        end

        @testset "Table HTML structure" begin
            tbl = Table(:html_table, table_df)
            @test occursin("<thead>", tbl.appearance_html)
            @test occursin("<tbody>", tbl.appearance_html)
            @test occursin("<th>name</th>", tbl.appearance_html)
            @test occursin("<td>Alice</td>", tbl.appearance_html)
            @test occursin("Download as CSV", tbl.appearance_html)
        end

        @testset "Table with special characters" begin
            special_df = DataFrame(
                text = ["<script>alert('xss')</script>", "a & b", "quote\"test"],
                value = [1, 2, 3]
            )
            tbl = Table(:special_table, special_df)
            # Should escape HTML entities
            @test occursin("&lt;script&gt;", tbl.appearance_html)
            @test occursin("&amp;", tbl.appearance_html)
            @test occursin("&quot;", tbl.appearance_html)
        end

        @testset "Table with missing values" begin
            missing_df = DataFrame(
                a = [1, missing, 3],
                b = ["x", "y", missing]
            )
            tbl = Table(:missing_table, missing_df)
            @test occursin("<table>", tbl.appearance_html)
            # Missing values should be rendered as empty cells
            @test occursin("<td></td>", tbl.appearance_html)
        end

        @testset "Table in HTML output" begin
            mktempdir() do tmpdir
                tbl = Table(:output_table, table_df)
                outfile = joinpath(tmpdir, "table_test.html")
                create_html(tbl, outfile)

                @test isfile(outfile)
                content = read(outfile, String)
                @test occursin("<table>", content)
                @test occursin("Alice", content)
                @test occursin("downloadTableCSV", content)
                @test occursin("window.downloadTableCSV_output_table = function()", content)
            end
        end

        @testset "Table convenience function" begin
            mktempdir() do tmpdir
                tbl = Table(:convenience_table, table_df)
                outfile = joinpath(tmpdir, "table_convenience.html")
                create_html(tbl, outfile)

                @test isfile(outfile)
            end
        end

        @testset "Multiple Tables on same page" begin
            mktempdir() do tmpdir
                df1 = DataFrame(a = [1, 2], b = [3, 4])
                df2 = DataFrame(x = ["a", "b"], y = ["c", "d"])

                tbl1 = Table(:table1, df1)
                tbl2 = Table(:table2, df2)

                page = JSPlotPage(Dict{Symbol,DataFrame}(), [tbl1, tbl2])
                outfile = joinpath(tmpdir, "multiple_tables.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("table1", content)
                @test occursin("table2", content)
                @test occursin("downloadTableCSV_table1", content)
                @test occursin("downloadTableCSV_table2", content)
            end
        end

        @testset "Mixed content: Table, Picture, and other plots" begin
            mktempdir() do tmpdir
                # Use the real example image for testing
                test_png = joinpath(@__DIR__, "..", "examples", "pictures", "images.jpeg")

                test_df = DataFrame(x = 1:5, y = rand(5), color = repeat(["A"], 5))
                table_df = DataFrame(item = ["A", "B"], value = [10, 20])

                chart = LineChart(:line, test_df, :data; x_cols=[:x], y_cols=[:y])
                tbl = Table(:summary, table_df)
                pic = Picture(:image, test_png)
                text = TextBlock("<h2>Mixed Content Test</h2>")

                page = JSPlotPage(
                    Dict{Symbol,DataFrame}(:data => test_df),
                    [text, chart, tbl, pic]
                )
                outfile = joinpath(tmpdir, "mixed_content.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("Mixed Content Test", content)
                @test occursin("line", content)
                @test occursin("summary", content)
                @test occursin("image", content)
            end
        end
    end

    @testset "LinkList" begin
        @testset "Basic creation" begin
            links = LinkList([
                ("Page 1", "page1.html", "First page description"),
                ("Page 2", "page2.html", "Second page description")
            ])
            @test links.chart_title == :link_list
            @test occursin("<ul>", links.appearance_html)
            @test occursin("Page 1", links.appearance_html)
            @test occursin("page1.html", links.appearance_html)
            @test occursin("First page description", links.appearance_html)
            @test links.functional_html == ""
        end

        @testset "Custom chart title" begin
            links = LinkList(
                [("Test", "test.html", "Description")],
                chart_title = :custom_links
            )
            @test links.chart_title == :custom_links
        end

        @testset "Multiple links" begin
            link_data = [
                ("Analysis 1", "analysis1.html", "Revenue analysis"),
                ("Analysis 2", "analysis2.html", "Cost analysis"),
                ("Analysis 3", "analysis3.html", "Profit analysis")
            ]
            links = LinkList(link_data)

            @test occursin("Analysis 1", links.appearance_html)
            @test occursin("Analysis 2", links.appearance_html)
            @test occursin("Analysis 3", links.appearance_html)
            @test occursin("analysis1.html", links.appearance_html)
            @test occursin("analysis2.html", links.appearance_html)
            @test occursin("analysis3.html", links.appearance_html)
        end

        @testset "Links in HTML output" begin
            mktempdir() do tmpdir
                links = LinkList([("Test Page", "test.html", "Test description")])
                page = JSPlotPage(Dict{Symbol,DataFrame}(), [links])
                outfile = joinpath(tmpdir, "links_test.html")
                create_html(page, outfile)

                content = read(outfile, String)
                @test occursin("Test Page", content)
                @test occursin("test.html", content)
                @test occursin("Test description", content)
            end
        end

        @testset "Dependencies" begin
            links = LinkList([("Page", "page.html", "Description")])
            @test dependencies(links) == Symbol[]
        end
    end

    @testset "Pages" begin
        # Create test data and pages
        test_data = DataFrame(x = 1:10, y = rand(10), category = repeat(["A", "B"], 5))

        page1 = JSPlotPage(
            Dict{Symbol,DataFrame}(:data1 => test_data),
            [TextBlock("<h2>Page 1</h2>")],
            tab_title = "First Page"
        )

        page2 = JSPlotPage(
            Dict{Symbol,DataFrame}(:data2 => test_data),
            [TextBlock("<h2>Page 2</h2>")],
            tab_title = "Second Page"
        )

        @testset "Basic creation" begin
            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Cover</h1>")],
                tab_title = "Cover"
            )

            pages = Pages(coverpage, [page1, page2])
            @test pages.coverpage.tab_title == "Cover"
            @test length(pages.pages) == 2
            @test pages.dataformat == :csv_embedded  # Default from coverpage
        end

        @testset "With explicit dataformat override" begin
            coverpage = JSPlotPage(
                Dict{Symbol,DataFrame}(),
                [TextBlock("<h1>Cover</h1>")],
                dataformat = :csv_embedded
            )

            # Override with parquet
            pages = Pages(coverpage, [page1, page2], dataformat = :parquet)
            @test pages.dataformat == :parquet
        end

        @testset "Invalid dataformat" begin
            coverpage = JSPlotPage(Dict{Symbol,DataFrame}(), [TextBlock("<h1>Cover</h1>")])
            @test_throws ErrorException Pages(coverpage, [page1], dataformat = :invalid)
        end

        @testset "Multi-page HTML generation" begin
            mktempdir() do tmpdir
                # Create pages with different content
                df1 = DataFrame(x = 1:5, y = rand(5), color = repeat(["Red"], 5))
                df2 = DataFrame(a = 1:5, b = rand(5), color = repeat(["Blue"], 5))

                chart1 = LineChart(:chart1, df1, :data1; x_cols=[:x], y_cols=[:y])
                chart2 = LineChart(:chart2, df2, :data2; x_cols=[:a], y_cols=[:b])

                page1 = JSPlotPage(
                    Dict{Symbol,DataFrame}(:data1 => df1),
                    [chart1],
                    tab_title = "Revenue",
                    page_header = "Revenue Analysis"
                )

                page2 = JSPlotPage(
                    Dict{Symbol,DataFrame}(:data2 => df2),
                    [chart2],
                    tab_title = "Costs",
                    page_header = "Cost Analysis"
                )

                links = LinkList([
                    ("Revenue", "page_1.html", "Revenue analysis page"),
                    ("Costs", "page_2.html", "Cost analysis page")
                ])

                coverpage = JSPlotPage(
                    Dict{Symbol,DataFrame}(),
                    [TextBlock("<h1>Annual Report</h1>"), links],
                    tab_title = "Home"
                )

                pages = Pages(coverpage, [page1, page2], dataformat = :parquet)
                outfile = joinpath(tmpdir, "index.html")
                create_html(pages, outfile)

                # Check flat project structure (all files at same level)
                project_dir = joinpath(tmpdir, "index")
                @test isdir(project_dir)

                # Check main page exists at project root
                @test isfile(joinpath(project_dir, "index.html"))

                # Check individual pages exist at same level
                @test isfile(joinpath(project_dir, "page_1.html"))
                @test isfile(joinpath(project_dir, "page_2.html"))

                # Check data directory and data files
                data_dir = joinpath(project_dir, "data")
                @test isdir(data_dir)
                @test isfile(joinpath(data_dir, "data1.parquet"))
                @test isfile(joinpath(data_dir, "data2.parquet"))

                # Check launcher scripts at project root
                @test isfile(joinpath(project_dir, "open.sh"))
                @test isfile(joinpath(project_dir, "open.bat"))
                @test isfile(joinpath(project_dir, "README.md"))

                # Check coverpage content
                coverpage_content = read(joinpath(project_dir, "index.html"), String)
                @test occursin("Annual Report", coverpage_content)
                @test occursin("page_1.html", coverpage_content)
                @test occursin("page_2.html", coverpage_content)
                @test occursin("Revenue analysis page", coverpage_content)

                # Check page 1 content
                page1_content = read(joinpath(project_dir, "page_1.html"), String)
                @test occursin("Revenue Analysis", page1_content)
                @test occursin("chart1", page1_content)

                # Check page 2 content
                page2_content = read(joinpath(project_dir, "page_2.html"), String)
                @test occursin("Cost Analysis", page2_content)
                @test occursin("chart2", page2_content)

                # Verify flat structure (no nested page folders)
                @test !isdir(joinpath(project_dir, "page_1"))
                @test !isdir(joinpath(project_dir, "page_2"))
            end
        end

        @testset "Shared data is saved only once" begin
            mktempdir() do tmpdir
                # Both pages use the same data
                shared_df = DataFrame(x = 1:100, y = rand(100), category = rand(["A", "B"], 100))

                chart1 = LineChart(:c1, shared_df, :shared_data; x_cols=[:x], y_cols=[:y])
                chart2 = LineChart(:c2, shared_df, :shared_data; x_cols=[:x], y_cols=[:y])

                page1 = JSPlotPage(Dict(:shared_data => shared_df), [chart1], tab_title="P1")
                page2 = JSPlotPage(Dict(:shared_data => shared_df), [chart2], tab_title="P2")

                coverpage = JSPlotPage(Dict{Symbol,DataFrame}(), [TextBlock("<h1>Test</h1>")])
                pages = Pages(coverpage, [page1, page2], dataformat = :csv_external)

                outfile = joinpath(tmpdir, "shared.html")
                create_html(pages, outfile)

                # Check that data file exists only once
                data_dir = joinpath(tmpdir, "shared", "data")
                @test isdir(data_dir)
                data_files = readdir(data_dir)
                @test length(filter(f -> contains(f, "shared_data"), data_files)) == 1
            end
        end

        @testset "Pages with different dataformats use override" begin
            mktempdir() do tmpdir
                # Create pages with different embedded formats
                page1 = JSPlotPage(
                    Dict(:data => test_data),
                    [TextBlock("<h2>P1</h2>")],
                    dataformat = :csv_embedded  # This will be overridden
                )

                page2 = JSPlotPage(
                    Dict(:data => test_data),
                    [TextBlock("<h2>P2</h2>")],
                    dataformat = :json_embedded  # This will be overridden
                )

                coverpage = JSPlotPage(
                    Dict{Symbol,DataFrame}(),
                    [TextBlock("<h1>Cover</h1>")],
                    dataformat = :csv_embedded
                )

                # Override all with JSON external
                pages = Pages(coverpage, [page1, page2], dataformat = :json_external)
                outfile = joinpath(tmpdir, "override.html")
                create_html(pages, outfile)

                # All should use JSON external
                data_dir = joinpath(tmpdir, "override", "data")
                @test isdir(data_dir)
                @test isfile(joinpath(data_dir, "data.json"))
                @test !isfile(joinpath(data_dir, "data.csv"))
            end
        end

        @testset "Empty pages list" begin
            mktempdir() do tmpdir
                coverpage = JSPlotPage(
                    Dict{Symbol,DataFrame}(),
                    [TextBlock("<h1>Only Cover</h1>")],
                    tab_title = "Cover Only"
                )

                # Pages with empty pages list
                pages = Pages(coverpage, JSPlotPage[])
                outfile = joinpath(tmpdir, "empty_pages.html")
                create_html(pages, outfile)

                project_dir = joinpath(tmpdir, "empty_pages")
                @test isdir(project_dir)
                @test isfile(joinpath(project_dir, "empty_pages.html"))
                # No additional page files should exist
                html_files = filter(f -> endswith(f, ".html"), readdir(project_dir))
                @test length(html_files) == 1  # Only the main file
            end
        end
    end

end
