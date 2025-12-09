using Test
using JSPlots
include("test_data.jl")

@testset "HTML Generation and Data Formats" begin
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
end
