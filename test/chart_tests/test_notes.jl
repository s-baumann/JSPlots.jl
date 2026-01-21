using Test
using JSPlots
using DataFrames

# Explicitly import internal functions for testing
import JSPlots: dependencies, js_dependencies

@testset "Notes" begin
    @testset "Basic creation with defaults" begin
        notes = Notes()

        @test notes.template == "Add your notes here..."
        @test notes.heading == "Notes"
        @test notes.textfilename == "notes.txt"
        @test notes.chart_id == :notes
    end

    @testset "Creation with custom parameters" begin
        notes = Notes(
            template = "Custom template text",
            heading = "My Observations",
            textfilename = "observations.txt"
        )

        @test notes.template == "Custom template text"
        @test notes.heading == "My Observations"
        @test notes.textfilename == "observations.txt"
        @test notes.chart_id == :observations
    end

    @testset "Chart ID sanitization" begin
        # Filename with special characters should be sanitized
        notes = Notes(textfilename = "my-notes.file.txt")
        @test notes.chart_id == :my_notes_file

        notes2 = Notes(textfilename = "notes with spaces.txt")
        @test notes2.chart_id == :notes_with_spaces
    end

    @testset "Multi-line template" begin
        template = """Key Observations:
- Point 1
- Point 2

Summary:
"""
        notes = Notes(template = template, heading = "Analysis")
        @test notes.template == template
        @test occursin("Point 1", notes.template)
    end

    @testset "dependencies function" begin
        notes = Notes()
        deps = dependencies(notes)
        @test deps == Symbol[]
    end

    @testset "js_dependencies function" begin
        notes = Notes()
        js_deps = js_dependencies(notes)
        @test js_deps == String[]
    end

    @testset "generate_notes_html - embedded format" begin
        notes = Notes(
            template = "Test content",
            heading = "Test Heading",
            textfilename = "test.txt"
        )

        result = JSPlots.generate_notes_html(notes, :csv_embedded, "")

        # Check HTML structure
        @test occursin("notes-container", result.html)
        @test occursin("Test Heading", result.html)
        @test occursin("Test content", result.html)
        @test occursin("Created on page generation", result.html)

        # No JavaScript for embedded formats
        @test result.js == ""
    end

    @testset "generate_notes_html - empty template shows no notes" begin
        notes = Notes(template = "", heading = "Empty Notes")

        result = JSPlots.generate_notes_html(notes, :csv_embedded, "")

        @test occursin("No notes provided", result.html)
    end

    @testset "generate_notes_html - external format creates file" begin
        mktempdir() do tmpdir
            notes = Notes(
                template = "External template",
                heading = "External Heading",
                textfilename = "external_notes.txt"
            )

            result = JSPlots.generate_notes_html(notes, :parquet, tmpdir)

            # Check HTML structure
            @test occursin("notes-container", result.html)
            @test occursin("External Heading", result.html)
            @test occursin("Loading notes...", result.html)
            @test occursin("notes/external_notes.txt", result.html)

            # Check JavaScript was generated
            @test !isempty(result.js)
            @test occursin("fetch", result.js)
            @test occursin("external_notes.txt", result.js)

            # Check file was created
            notes_file = joinpath(tmpdir, "notes", "external_notes.txt")
            @test isfile(notes_file)
            @test read(notes_file, String) == "External template"
        end
    end

    @testset "generate_notes_html - preserves existing file" begin
        mktempdir() do tmpdir
            # Create notes directory and file first
            notes_dir = joinpath(tmpdir, "notes")
            mkpath(notes_dir)
            notes_file = joinpath(notes_dir, "existing.txt")
            write(notes_file, "User edited content")

            notes = Notes(
                template = "Original template",
                heading = "Test",
                textfilename = "existing.txt"
            )

            result = JSPlots.generate_notes_html(notes, :parquet, tmpdir)

            # File should not be overwritten
            @test read(notes_file, String) == "User edited content"
        end
    end

    @testset "Notes in JSPlotPage - embedded" begin
        df = DataFrame(x = 1:5, y = rand(5))
        notes = Notes(heading = "Page Notes", template = "Some notes")

        page = JSPlotPage(
            Dict{Symbol, Any}(:data => df),
            [notes];
            dataformat = :csv_embedded
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "test.html")
            create_html(page, output_file)

            @test isfile(output_file)
            html_content = read(output_file, String)

            # Check notes appear in HTML
            @test occursin("Page Notes", html_content)
            @test occursin("notes-container", html_content)
            @test occursin("Some notes", html_content)
        end
    end

    @testset "Notes in JSPlotPage - external format" begin
        df = DataFrame(x = 1:5, y = rand(5))
        notes = Notes(
            heading = "External Notes",
            template = "Edit me",
            textfilename = "my_notes.txt"
        )

        page = JSPlotPage(
            Dict{Symbol, Any}(:data => df),
            [notes];
            tab_title = "Notes Test",
            dataformat = :parquet
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "notes_test.html")
            create_html(page, output_file)

            project_dir = joinpath(tmpdir, "notes_test")
            @test isdir(project_dir)

            # Check notes directory was created
            notes_dir = joinpath(project_dir, "notes")
            @test isdir(notes_dir)

            # Check notes file was created
            notes_file = joinpath(notes_dir, "my_notes.txt")
            @test isfile(notes_file)
            @test read(notes_file, String) == "Edit me"

            # Check HTML contains notes
            html_file = joinpath(project_dir, "notes_test.html")
            html_content = read(html_file, String)
            @test occursin("External Notes", html_content)
            @test occursin("notes/my_notes.txt", html_content)
        end
    end

    @testset "Multiple Notes on same page" begin
        df = DataFrame(x = 1:3)

        notes1 = Notes(heading = "Methods", textfilename = "methods.txt", template = "Method 1")
        notes2 = Notes(heading = "Results", textfilename = "results.txt", template = "Result 1")
        notes3 = Notes(heading = "Conclusions", textfilename = "conclusions.txt", template = "Conclusion 1")

        page = JSPlotPage(
            Dict{Symbol, Any}(:data => df),
            [notes1, notes2, notes3];
            dataformat = :parquet
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "multi_notes.html")
            create_html(page, output_file)

            project_dir = joinpath(tmpdir, "multi_notes")
            notes_dir = joinpath(project_dir, "notes")

            # All three notes files should exist
            @test isfile(joinpath(notes_dir, "methods.txt"))
            @test isfile(joinpath(notes_dir, "results.txt"))
            @test isfile(joinpath(notes_dir, "conclusions.txt"))

            # HTML should contain all headings
            html_content = read(joinpath(project_dir, "multi_notes.html"), String)
            @test occursin("Methods", html_content)
            @test occursin("Results", html_content)
            @test occursin("Conclusions", html_content)
        end
    end

    @testset "Notes with other chart types" begin
        df = DataFrame(x = 1:10, y = rand(10))

        chart = LineChart(:test_chart, df, :data; x_cols = [:x], y_cols = [:y], title = "Test Chart")
        notes = Notes(heading = "Chart Analysis", template = "Observations about the chart")

        page = JSPlotPage(
            Dict{Symbol, Any}(:data => df),
            [chart, notes];
            dataformat = :parquet
        )

        mktempdir() do tmpdir
            output_file = joinpath(tmpdir, "chart_with_notes.html")
            create_html(page, output_file)

            project_dir = joinpath(tmpdir, "chart_with_notes")

            # Both chart and notes should be in HTML
            html_content = read(joinpath(project_dir, "chart_with_notes.html"), String)
            @test occursin("Test Chart", html_content)
            @test occursin("Chart Analysis", html_content)
            @test occursin("notes-container", html_content)
        end
    end

    @testset "Notes CSS styling" begin
        # Check that NOTES_STYLE contains expected CSS
        @test occursin("notes-container", JSPlots.NOTES_STYLE)
        @test occursin("#fffde7", JSPlots.NOTES_STYLE)  # Pale yellow
        @test occursin("notes-header", JSPlots.NOTES_STYLE)
        @test occursin("notes-heading", JSPlots.NOTES_STYLE)
        @test occursin("notes-modified", JSPlots.NOTES_STYLE)
        @test occursin("notes-content", JSPlots.NOTES_STYLE)
    end

    @testset "JavaScript template escaping" begin
        # Template with backticks should be escaped
        notes = Notes(
            template = "Code: `var x = 1`",
            heading = "Code Notes",
            textfilename = "code_notes.txt"
        )

        mktempdir() do tmpdir
            result = JSPlots.generate_notes_html(notes, :parquet, tmpdir)

            # Backticks should be escaped in JS
            @test occursin("\\`", result.js)
        end
    end
end

println("Notes tests completed successfully!")
