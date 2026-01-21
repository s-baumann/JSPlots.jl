using Test
using JSPlots
using CSV
using DataFrames
using Dates

@testset "ReportIndex" begin
    @testset "add_to_manifest creates new manifest" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            add_to_manifest(manifest_path,
                path = "2024-01-15",
                html_filename = "index.html",
                description = "Daily Analysis",
                date = Date(2024, 1, 15)
            )

            @test isfile(manifest_path)

            # Read with types to prevent date-like string auto-parsing
            df = CSV.read(manifest_path, DataFrame;
                types=Dict(:path => String, :html_filename => String, :description => String))
            @test nrow(df) == 1
            @test df[1, :path] == "2024-01-15"
            @test df[1, :html_filename] == "index.html"
            @test df[1, :description] == "Daily Analysis"
            @test df[1, :date] == Date(2024, 1, 15)
            @test hasproperty(df, :added_to_manifest)
        end
    end

    @testset "add_to_manifest with extra columns" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            add_to_manifest(manifest_path,
                path = "2024-01-15",
                html_filename = "index.html",
                description = "Daily Analysis",
                date = Date(2024, 1, 15),
                category = "daily",
                author = "Stuart"
            )

            df = CSV.read(manifest_path, DataFrame)
            @test df[1, :category] == "daily"
            @test df[1, :author] == "Stuart"
        end
    end

    @testset "add_to_manifest updates existing entry" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add initial entry
            add_to_manifest(manifest_path,
                path = "2024-01-15",
                html_filename = "index.html",
                description = "Version 1",
                date = Date(2024, 1, 15)
            )

            # Update same path
            add_to_manifest(manifest_path,
                path = "2024-01-15",
                html_filename = "index.html",
                description = "Version 2",
                date = Date(2024, 1, 15)
            )

            df = CSV.read(manifest_path, DataFrame)
            @test nrow(df) == 1  # Still only 1 entry
            @test df[1, :description] == "Version 2"
        end
    end

    @testset "add_to_manifest maintains sort order" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add in non-chronological order
            add_to_manifest(manifest_path, path="2024-01-15", html_filename="index.html",
                description="Jan", date=Date(2024, 1, 15))
            add_to_manifest(manifest_path, path="2024-03-01", html_filename="index.html",
                description="Mar", date=Date(2024, 3, 1))
            add_to_manifest(manifest_path, path="2024-02-10", html_filename="index.html",
                description="Feb", date=Date(2024, 2, 10))

            df = CSV.read(manifest_path, DataFrame)
            @test nrow(df) == 3

            # Should be sorted newest first
            @test df[1, :date] == Date(2024, 3, 1)
            @test df[2, :date] == Date(2024, 2, 10)
            @test df[3, :date] == Date(2024, 1, 15)
        end
    end

    @testset "add_to_manifest adds new column to existing manifest" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add without extra column
            add_to_manifest(manifest_path, path="2024-01-15", html_filename="index.html",
                description="First", date=Date(2024, 1, 15))

            # Add with extra column
            add_to_manifest(manifest_path, path="2024-02-20", html_filename="index.html",
                description="Second", date=Date(2024, 2, 20), category="new")

            df = CSV.read(manifest_path, DataFrame)
            @test hasproperty(df, :category)
            @test ismissing(df[2, :category])  # First entry has missing for new column (it's now row 2 after sort)
            @test df[1, :category] == "new"
        end
    end

    @testset "add_to_manifest errors when missing column without fill_missing" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add with extra column
            add_to_manifest(manifest_path, path="2024-01-15", html_filename="index.html",
                description="First", date=Date(2024, 1, 15), category="test")

            # Try to add without the category column - should error
            @test_throws ErrorException add_to_manifest(manifest_path,
                path="2024-02-20", html_filename="index.html",
                description="Second", date=Date(2024, 2, 20))
        end
    end

    @testset "add_to_manifest with fill_missing" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add with extra column
            add_to_manifest(manifest_path, path="2024-01-15", html_filename="index.html",
                description="First", date=Date(2024, 1, 15), category="test")

            # Add without extra column but with fill_missing=true
            add_to_manifest(manifest_path, path="2024-02-20", html_filename="index.html",
                description="Second", date=Date(2024, 2, 20), fill_missing=true)

            df = CSV.read(manifest_path, DataFrame)
            @test nrow(df) == 2
            @test ismissing(df[1, :category])  # Second entry (now row 1) has missing
        end
    end

    @testset "ManifestEntry struct" begin
        entry = ManifestEntry(
            path = "2024-01-15",
            html_filename = "report.html",
            description = "Test Report",
            date = Date(2024, 1, 15),
            extra_columns = Dict(:category => "daily")
        )

        @test entry.path == "2024-01-15"
        @test entry.html_filename == "report.html"
        @test entry.description == "Test Report"
        @test entry.date == Date(2024, 1, 15)
        @test entry.extra_columns[:category] == "daily"
    end

    @testset "ManifestEntry with add_to_manifest" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            entry = ManifestEntry(
                path = "2024-01-15",
                html_filename = "report.html",
                description = "Test Report",
                date = Date(2024, 1, 15),
                extra_columns = Dict(:category => "daily")
            )

            add_to_manifest(manifest_path, entry)

            # Read with types to prevent date-like string auto-parsing
            df = CSV.read(manifest_path, DataFrame;
                types=Dict(:path => String, :html_filename => String, :description => String))
            @test nrow(df) == 1
            @test df[1, :path] == "2024-01-15"
            @test df[1, :category] == "daily"
        end
    end

    @testset "get_manifest_columns" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Non-existent file returns required columns
            cols = get_manifest_columns(manifest_path)
            @test cols == JSPlots.MANIFEST_REQUIRED_COLS

            # After creating manifest, returns actual columns
            add_to_manifest(manifest_path, path="test", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15), extra_col="value")

            cols = get_manifest_columns(manifest_path)
            @test :path in cols
            @test :html_filename in cols
            @test :description in cols
            @test :date in cols
            @test :extra_col in cols
            @test :added_to_manifest in cols
        end
    end

    @testset "ReportIndex construction" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Create a manifest
            add_to_manifest(manifest_path, path="2024-01-15", html_filename="index.html",
                description="Test Report", date=Date(2024, 1, 15))

            # Construct ReportIndex
            idx = ReportIndex(:test_index, manifest_path, title="Test Archive")

            @test idx.chart_title == :test_index
            @test idx.manifest_path == manifest_path
            @test idx.title == "Test Archive"
            @test idx.default_sort_by == :date
            @test isnothing(idx.default_group_by)
        end
    end

    @testset "ReportIndex with grouping options" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            add_to_manifest(manifest_path, path="2024-01-15", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15), category="daily")

            idx = ReportIndex(:test_index, manifest_path,
                title="Reports",
                default_group_by=:category,
                default_then_group_by=:date,
                default_sort_by=:description
            )

            @test idx.default_group_by == :category
            @test idx.default_then_group_by == :date
            @test idx.default_sort_by == :description
        end
    end

    @testset "ReportIndex warns on missing manifest" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "nonexistent.csv")

            # Should warn but not error
            @test_logs (:warn, r"Manifest file does not exist") begin
                ReportIndex(:test_index, manifest_path)
            end
        end
    end

    @testset "ReportIndex appearance_html contains expected elements" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")
            add_to_manifest(manifest_path, path="test", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15))

            idx = ReportIndex(:my_index, manifest_path, title="My Reports")

            # Check CSS classes
            @test occursin("reportindex-container-my_index", idx.appearance_html)
            @test occursin("reportindex-controls-my_index", idx.appearance_html)
            @test occursin("reportindex-link-missing-my_index", idx.appearance_html)

            # Check title
            @test occursin("<h2>My Reports</h2>", idx.appearance_html)

            # Check selectors
            @test occursin("groupby1_my_index", idx.appearance_html)
            @test occursin("groupby2_my_index", idx.appearance_html)
            @test occursin("sortby_my_index", idx.appearance_html)
        end
    end

    @testset "ReportIndex functional_html contains expected elements" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")
            add_to_manifest(manifest_path, path="test", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15))

            idx = ReportIndex(:my_index, manifest_path)

            # Check JavaScript functions
            @test occursin("loadManifest", idx.functional_html)
            @test occursin("parseCSVLine", idx.functional_html)
            @test occursin("updateDisplay_my_index", idx.functional_html)
            @test occursin("toggleGroup_my_index", idx.functional_html)
            @test occursin("checkMissingFiles", idx.functional_html)
        end
    end

    @testset "ReportIndex dependencies" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")
            add_to_manifest(manifest_path, path="test", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15))

            idx = ReportIndex(:my_index, manifest_path)

            @test JSPlots.dependencies(idx) == Symbol[]
            @test JSPlots.js_dependencies(idx) == JSPlots.JS_DEP_JQUERY
        end
    end

    @testset "MANIFEST_REQUIRED_COLS" begin
        @test JSPlots.MANIFEST_REQUIRED_COLS == [:path, :html_filename, :description, :date]
    end

    @testset "ReportIndex default_then_group_by is nothing by default" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")
            add_to_manifest(manifest_path, path="test", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15))

            idx = ReportIndex(:test_index, manifest_path)

            @test isnothing(idx.default_then_group_by)
        end
    end

    @testset "ReportIndex in JSPlotPage integration" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add some entries
            add_to_manifest(manifest_path, path="reports", html_filename="report1.html",
                description="Report 1", date=Date(2024, 1, 15), category="daily")
            add_to_manifest(manifest_path, path="reports", html_filename="report2.html",
                description="Report 2", date=Date(2024, 2, 20), category="weekly")

            idx = ReportIndex(:my_index, manifest_path,
                title="Test Reports",
                default_group_by=:category)

            page = JSPlotPage(Dict{Symbol,Any}(), [idx])

            output_file = joinpath(tmpdir, "index.html")
            create_html(page, output_file)

            @test isfile(output_file)
            html_content = read(output_file, String)

            # Check ReportIndex elements in HTML
            @test occursin("reportindex-container-my_index", html_content)
            @test occursin("Test Reports", html_content)
            @test occursin("loadManifest", html_content)
        end
    end

    @testset "ManifestEntry with empty extra_columns" begin
        entry = ManifestEntry(
            path = "2024-01-15",
            html_filename = "report.html",
            description = "Test Report",
            date = Date(2024, 1, 15)
        )

        @test entry.path == "2024-01-15"
        @test isempty(entry.extra_columns)
    end

    @testset "add_to_manifest with different filenames same path" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")

            # Add two entries with same path but different filenames
            add_to_manifest(manifest_path, path="2024-01", html_filename="report1.html",
                description="Report 1", date=Date(2024, 1, 15))
            add_to_manifest(manifest_path, path="2024-01", html_filename="report2.html",
                description="Report 2", date=Date(2024, 1, 20))

            df = CSV.read(manifest_path, DataFrame)
            @test nrow(df) == 2  # Both should exist (different filenames)
        end
    end

    @testset "ReportIndex functional_html contains default values" begin
        mktempdir() do tmpdir
            manifest_path = joinpath(tmpdir, "manifest.csv")
            add_to_manifest(manifest_path, path="test", html_filename="index.html",
                description="Test", date=Date(2024, 1, 15), category="test_cat")

            idx = ReportIndex(:my_index, manifest_path,
                default_group_by=:category,
                default_then_group_by=:date,
                default_sort_by=:description)

            # Check default values are in JavaScript
            @test occursin("DEFAULT_GROUP_BY_1 = 'category'", idx.functional_html)
            @test occursin("DEFAULT_GROUP_BY_2 = 'date'", idx.functional_html)
            @test occursin("DEFAULT_SORT_BY = 'description'", idx.functional_html)
        end
    end
end

println("ReportIndex tests completed successfully!")
