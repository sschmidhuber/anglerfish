#using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))

using CSV
using DataFrames
using JSON
using ModelContextProtocol
using Test

push!(ARGS, "TEST_MODE")

Anglerfish.init()

ro_dir = joinpath(@__DIR__, "testdata", "read_only")
rw_dir = joinpath(@__DIR__, "testdata", "read_write")
append!(Anglerfish.READ_ONLY_DIRECTORIES, [ro_dir])
append!(Anglerfish.READ_WRITE_DIRECTORIES, [rw_dir])

@testset "Tools" verbose=true begin

@testset "Date Time" begin
    date_time_tool = Anglerfish.TOOLS["date_time"]
    date_time_result = (date_time_tool.handler(nothing)).text |> JSON.parse
    @test haskey(date_time_result, "time")
    @test haskey(date_time_result, "date")
    @test haskey(date_time_result, "timezone")
    @test haskey(date_time_result, "day_of_week")
    @test haskey(date_time_result, "week_of_year")
end


@test_skip @testset "Open File" begin
    open_file_tool = Anglerfish.TOOLS["open_file"]
    @test open_file_tool.handler(Dict("file_path" => joinpath(ro_dir, "test file 1.txt"))).text == "successfully opened file: $(joinpath(ro_dir, "test file 1.txt"))"
    @test open_file_tool.handler(Dict("file_path" => joinpath(ro_dir, "non_existent_file.txt"))).text == "file not found: $(joinpath(ro_dir, "non_existent_file.txt"))"
end


@testset "System Info" begin
    system_info_tool = Anglerfish.TOOLS["system_info"]
    system_info_result = (system_info_tool.handler(nothing)).text |> JSON.parse
    @test contains(system_info_result["os"], "Linux") || contains(system_info_result["os"], "Darwin")
    @test system_info_result["cpu"] == Sys.CPU_NAME
    @test system_info_result["architecture"] == Sys.ARCH |> string
    @test system_info_result["cores"] == Sys.CPU_THREADS
    @test haskey(system_info_result, "memory")
end

@test_skip @testset "Email" begin
    compose_email_tool = Anglerfish.TOOLS["compose_email"]
    @test compose_email_tool.handler(Dict(
            "subject" => "",
            "to" => [],
            "cc" => [],
            "bcc" => [],
            "content" => "Test Content",
            "attachments" => []
        )).text == "successfully opened email client with precomposed email"
    @test compose_email_tool.handler(Dict(
            "subject" => "Test Subject",
            "to" => [],
            "cc" => [],
            "bcc" => [],
            "content" => "Random Text",
            "attachments" => []
        )).text == "successfully opened email client with precomposed email"
    @test compose_email_tool.handler(Dict(
            "subject" => "Test Subject",
            "to" => ["grace.hopper@navy.mil", "alan.turing@oxford.edu"],
            "cc" => ["albert.einstein@stanford.edu"],
            "bcc" => ["erwin.schroedinger@uniwien.at"],
            "content" => "Test Content",
            "attachments" => [joinpath(ro_dir, "Testdokument ÄÜÖ.md")]
        )).text == "successfully opened email client with precomposed email"
end


@test_skip @testset "Calendar" begin
    calendar_tool = Anglerfish.TOOLS["calendar_items"]
    calendar_result = calendar_tool.handler(Dict(
        "items" => [
            Dict(
                "type" => "event",
                "title" => "Meeting with Bob",
                "start" => "2024-07-01T10:00:00",
                "end" => "2024-07-01T11:00:00",
                "description" => "Discuss project updates",
                "location" => "Zoom"
            ),
            Dict(
                "type" => "todo",
                "title" => "Buy groceries",
                "due" => "2024-07-02T18:00:00",
                "description" => "Milk, Bread, Eggs"
            ),
            Dict(
                "type" => "todo",
                "title" => "Finish report",
                "due" => "2024-07-03",
                "description" => "Complete the quarterly report"
            ),
            Dict(
                "type" => "event",
                "title" => "Independence Day",
                "start" => "2024-07-04",
                "end" => "2024-07-04",
                "description" => "Celebrate Independence Day",
                "location" => "USA"
            ),
            Dict(
                "type" => "event",
                "title" => "Project Deadline",
                "start" => "2027-07-15",
                "description" => "Submit final project report",
                "url" => "https://www.example.com/project-details"
            )
        ]
    )).text
    @test calendar_result == "successfully created a calendar file and opened it in the default calendar client"
end


    @testset "Filesystem" verbose = false begin
        @testset "Read Directory" begin
            # Test with allowed directory
            read_directory_tool = Anglerfish.TOOLS["read_directory"]
            read_directory_result = read_directory_tool.handler(Dict("directory" => first(Anglerfish.READ_ONLY_DIRECTORIES))).text |> JSON.parse
            @test haskey(read_directory_result, "files")
            @test haskey(read_directory_result, "directories")

            # Test with not allowed directory
            read_directory_error = read_directory_tool.handler(Dict("directory" => "/")).text
            @test read_directory_error == "access denied: /"

            # Test with single extension filter
            read_directory_result_with_filter = read_directory_tool.handler(Dict("directory" => first(Anglerfish.READ_ONLY_DIRECTORIES), "filter" => [".md"])).text |> JSON.parse
            @test all(endswith(".md"), read_directory_result_with_filter["files"])

            # Test with multiple extension filter
            read_directory_result_with_multiple_filter = read_directory_tool.handler(Dict("directory" => first(Anglerfish.READ_ONLY_DIRECTORIES), "filter" => [".jl", ".md"])).text |> JSON.parse
            @test all(x -> endswith(x, ".jl") || endswith(x, ".md"), read_directory_result_with_multiple_filter["files"])
        end

        @testset "File Search" begin
            # get file search command function
            file_search_func = Anglerfish.file_search_func()
            @test file_search_func !== nothing

            # search with no keywords provided for search
            find_cmd_result = Anglerfish.find_cmd([], [first(Anglerfish.READ_ONLY_DIRECTORIES)], [], true, true)
            @test find_cmd_result == "no keywords provided for search"

            # search with one keyword and no directories provided (should search all allowed directories)
            find_cmd_result_single_keyword = Anglerfish.find_cmd(["dokument"])
            @test any(endswith("Testdokument ÄÜÖ.md"), find_cmd_result_single_keyword["files"])

            # search with multiple keywords and no directories provided (should search all allowed directories)
            find_cmd_result_multiple_keywords = Anglerfish.find_cmd(["dokument", "non_existent_file"])
            @test any(endswith("Testdokument ÄÜÖ.md"), find_cmd_result_multiple_keywords["files"])
            @test !any(endswith("non_existent_file"), find_cmd_result_multiple_keywords["files"])

            # search with one keyword and specific directory provided
            find_cmd_result_single_keyword_with_directory = Anglerfish.find_cmd(["file 1"], [ro_dir])
            @test any(endswith("test file 1.txt"), find_cmd_result_single_keyword_with_directory["files"])

            # search with one keyword and file extension filter provided
            find_cmd_result_single_keyword_with_filter = Anglerfish.find_cmd(["file"], [ro_dir], [".txt"])
            @test any(endswith("test file 1.txt"), find_cmd_result_single_keyword_with_filter["files"])
            @test all(endswith(".txt"), find_cmd_result_single_keyword_with_filter["files"])

            # test handler with single keyword and specific directory provided
            file_search_tool = Anglerfish.TOOLS["file_search"]
            file_search_result = file_search_tool.handler(Dict("keywords" => ["file"], "directories" => [ro_dir], "only_files" => "true")).text |> JSON.parse
            @test any(endswith("test file 1.txt"), file_search_result["files"])

            # test handler with multiple keywords and specific directory provided
            file_search_result_multiple_keywords = file_search_tool.handler(Dict("keywords" => ["ÄÜÖ", "non_existent_file"], "directories" => [ro_dir], "only_files" => "True")).text |> JSON.parse
            @test any(endswith("Testdokument ÄÜÖ.md"), file_search_result_multiple_keywords["files"])
            @test !any(endswith("non_existent_file"), file_search_result_multiple_keywords["files"])

            # test handler with single keyword, specific directory, and file extension filter provided
            file_search_result_single_keyword_with_filter = file_search_tool.handler(Dict("keywords" => ["file"], "directories" => [ro_dir], "filter" => [".txt"], "only_files" => true)).text |> JSON.parse
            @test any(endswith("test file 1.txt"), file_search_result_single_keyword_with_filter["files"])
            @test all(endswith(".txt"), file_search_result_single_keyword_with_filter["files"])
        end
    end

    @testset "Shell Command Execution" begin
        # only run shell command execution tests on Linux
        if Sys.islinux()
            shell_tool = Anglerfish.TOOLS["shell"]

            # test background execution of a simple command
            shell_result = shell_tool.handler(Dict("command" => "echo Hello World", "open_terminal" => false)).text |> JSON.parse
            @test shell_result["stdout"] == "Hello World"
            @test shell_result["stderr"] == ""
            @test shell_result["exitcode"] == 0

            # test background execution of a command that produces an error
            shell_result_error = shell_tool.handler(Dict("command" => "ls --invalidargument", "open_terminal" => false)).text |> JSON.parse
            println(shell_result_error)
            @test shell_result_error["stdout"] == ""
            @test contains(shell_result_error["stderr"], "--invalidargument")
            @test shell_result_error["exitcode"] != 0

            # test foreground execution of a simple command (this will open a terminal window, so we can't easily automate checking the result, but we can at least check that it doesn't return an error)
            shell_result_foreground = shell_tool.handler(Dict("command" => "echo Hello Foreground; sleep 2", "open_terminal" => "True")).text
            @test startswith(shell_result_foreground, "command executed in terminal")

            # test execution with working directory specified
            shell_result_with_wd = shell_tool.handler(Dict("command" => "pwd", "working_directory" => ro_dir, "open_terminal" => false)).text |> JSON.parse
            @test shell_result_with_wd["stdout"] == ro_dir

            # test execution with invalid working directory specified (should default to home or first allowed directory)
            shell_result_with_invalid_wd = shell_tool.handler(Dict("command" => "pwd", "working_directory" => "/invalid/directory")).text |> JSON.parse
            @test shell_result_with_invalid_wd["stdout"] == homedir()
        end
    end

    @testset "IO" begin
        @testset "Read File" begin
            read_file_tool = Anglerfish.TOOLS["read_file"]

            # test reading a text file
            read_file_result_text = read_file_tool.handler(Dict("path" => joinpath(ro_dir, "test file 1.txt"))).text
            @test read_file_result_text == "Test file 1\n"

            # test reading an image file (this will just check that it returns an ImageContent object with the correct mime type, since we can't easily automate checking the actual image data)
            read_file_result_image = read_file_tool.handler(Dict("path" => joinpath(ro_dir, "Julia_prog_language.png")))
            @test read_file_result_image isa ImageContent
            @test read_file_result_image.mime_type == "image/png"

            # test reading a non-existent file
            read_file_result_non_existent = read_file_tool.handler(Dict("path" => joinpath(ro_dir, "non_existent_file.txt"))).text
            @test startswith(read_file_result_non_existent, "file not found:")

            # test reading a file with unsupported type (assuming .exe is not supported)
            read_file_result_unsupported = read_file_tool.handler(Dict("path" => joinpath(ro_dir, "application.deb"))).text
            @test startswith(read_file_result_unsupported, "file type:")

            # read a CSV table
            read_file_result_csv = read_file_tool.handler(Dict("path" => joinpath(ro_dir, "test_table.csv"))).text
            @test contains(read_file_result_csv, "Alice") && contains(read_file_result_csv, "Bob") && contains(read_file_result_csv, "Age") && contains(read_file_result_csv, "City")
        end

        @testset "Write File" begin
            write_file_tool = Anglerfish.TOOLS["write_file"]

            # test writing to a file in a read-write directory
            write_file_result = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test_write.txt"), "content" => "This is a test.")).text
            @test write_file_result == "file written successfully to: $(joinpath(rw_dir, "test_write.txt"))"
            @test read(joinpath(rw_dir, "test_write.txt"), String) == "This is a test."

            # test writing to a file in a read-only directory (should return an error)
            write_file_result_read_only = write_file_tool.handler(Dict("path" => joinpath(ro_dir, "test_write.txt"), "content" => "This should fail.")).text
            @test startswith(write_file_result_read_only, "ERROR: access denied or invalid path:")

            # test writing to a file with an invalid path (should return an error)
            write_file_result_invalid_path = write_file_tool.handler(Dict("path" => "/invalid/directory/test_write.txt", "content" => "This should also fail.")).text
            @test startswith(write_file_result_invalid_path, "ERROR: access denied or invalid path:")

            # test writing raw content by creating a julia file and checking that it can be executed
            write_file_result_raw = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test_script.jl"), "content" => "println(\"Hello from test script\")", "raw" => true)).text
            @test write_file_result_raw == "file written successfully to: $(joinpath(rw_dir, "test_script.jl"))"
            script_output = readchomp(`julia $(joinpath(rw_dir, "test_script.jl"))`)
            @test script_output == "Hello from test script"

            # create PDF file
            write_file_result_pdf = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test.pdf"), "content" => "# Test PDF\n\nThis is a test PDF file. ☀️", "raw" => false)).text
            @test write_file_result_pdf == "file written successfully to: $(joinpath(rw_dir, "test.pdf"))"
            @test isfile(joinpath(rw_dir, "test.pdf"))

            # create CSV table
            csv_content = "Name,Age,City\nAlice,30,New York\nBob,25,Los Angeles"
            write_table_result = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test_table.csv"), "content" => csv_content, "raw" => true)).text
            @test write_table_result == "file written successfully to: $(joinpath(rw_dir, "test_table.csv"))"
            @test isfile(joinpath(rw_dir, "test_table.csv"))
            table_data = CSV.File(joinpath(rw_dir, "test_table.csv")) |> DataFrame
            @test size(table_data) == (2, 3)
            @test names(table_data) == ["Name", "Age", "City"]
            @test table_data[1, :] |> collect == ["Alice", 30, "New York"]
            @test table_data[2, :] |> collect == ["Bob", 25, "Los Angeles"]

            # clean up test files
            rm(joinpath(rw_dir, "test_write.txt"))
            rm(joinpath(rw_dir, "test_script.jl"))
            rm(joinpath(rw_dir, "test.pdf"))
            rm(joinpath(rw_dir, "test_table.csv"))
        end
    end


    @testset "Analytics" begin

        @test_skip @testset "Gnuplot" begin
            plotting_tool = Anglerfish.TOOLS["gnuplot"]

            # test plotting from CSV data file, creating a PNG output, and checking that the output file is created successfully. Since we can't easily automate checking the actual plot output, we'll just check that gnuplot executes without error and creates the output file.
            datafile = joinpath(ro_dir, "test_datafile.csv")
            gnuplot_csv_script = """
            set terminal pngcairo
            set output '$(joinpath(rw_dir, "test_plot.png"))'
            set datafile separator ","
            plot '$datafile' using 1:2 with lines title 'Column 1', '$datafile' using 1:3 with lines title 'Column 2'
            """
            gnuplot_csv_result = plotting_tool.handler(Dict("script" => gnuplot_csv_script, "working_directory" => ro_dir)).text
            @test contains(gnuplot_csv_result, "gnuplot executed successfully")

            incorrect_gnuplot_script = """set terminal web size 1200,600 enhanced font 'Arial,14'
            set output '/home/stefan/Downloads/open_llm_overall_score_bar.png'

            # Title for the plot
            set title "Top Open-Weight LLMs: Overall Benchmark Score Comparison" \
                font "Arial Bold,20" textcolor "black"

            # Y-axis formatting
            set yrange [0:100]
            set ytics nomirror format "%.1f"
            set ylabel "Score / Capability Index" font "Arial,14"

            # X-axis labels rotated for better readability
            set xtics rotate by -45 offset 0,-20 textcolor "black"
            set xlabel "Model" font "Arial,14"

            # Enable legend
            set key outside right top box

            # Bar styling
            set style fill solid
            set bar width 0.85

            # Data plotting (manual since we have tab-separated data)
            plot "plot_overall_scores.txt" using (\$0+1):2:(stringcolumn(3)) \
                with boxes title "Model Scores" lc rgbpalette notitle, \
                 "" using 0:0 with emptychars"""
            gnuplot_incorrect_result = plotting_tool.handler(Dict("script" => incorrect_gnuplot_script, "working_directory" => ro_dir)).text
            @test contains(gnuplot_incorrect_result, "line 21: undefined variable: width")

            # clean up test plot file if it was created
            if isfile(joinpath(rw_dir, "test_plot.png"))
                rm(joinpath(rw_dir, "test_plot.png"))
            end
        end

        @testset "Describe Table" begin
            describe_table_tool = Anglerfish.TOOLS["describe_table"]

            # test describing a valid CSV file
            describe_result = describe_table_tool.handler(Dict("path" => joinpath(ro_dir, "test_table.csv"))).text
            @test contains(describe_result, "Table has 26 rows (without header) and 6 columns.")
            @test contains(describe_result, "Column") && contains(describe_result, "Min") && contains(describe_result, "Mean") && contains(describe_result, "Max") && contains(describe_result, "Missing Values")

            # test describing a non-existent file
            describe_non_existent = describe_table_tool.handler(Dict("path" => joinpath(ro_dir, "non_existent_file.csv"))).text
            @test startswith(describe_non_existent, "ERROR: path")

            # test describing a file that is not a CSV
            describe_not_csv = describe_table_tool.handler(Dict("path" => joinpath(ro_dir, "test file 1.txt"))).text
            @test startswith(describe_not_csv, "ERROR: file type not supported")
        end

        @testset "Plot Bar" begin
            plot_bar_tool = Anglerfish.TOOLS["plot_bar"]
            output_path_png = joinpath(rw_dir, "test_barplot.png")
            output_path_svg = joinpath(rw_dir, "test_barplot.svg")

            # plot to PNG file with title, single y-column
            plot_result = plot_bar_tool.handler(Dict(
                "path" => joinpath(ro_dir, "test_table.csv"),
                "xcolumn" => "Name",
                "ycolumns" => ["Age"],
                "output_path" => output_path_png,
                "title" => "Ages",
                "x_axis_label" => "Students",
                "y_axis_label" => "Years"
            )).text
            @test startswith(plot_result, "plot generated successfully")
            @test isfile(output_path_png)
            @test filesize(output_path_png) > 0

            # plot to SVG file without title, multiple y-columns
            plot_result_multiple_y = plot_bar_tool.handler(Dict(
                "path" => joinpath(ro_dir, "test_table.csv"),
                "xcolumn" => "Sex",
                "ycolumns" => ["Height", "Weight"],
                "colors" => ["blue", "red"],
                "output_path" => output_path_svg
            )).text
            @test startswith(plot_result_multiple_y, "plot generated successfully")
            @test isfile(output_path_svg)
            @test filesize(output_path_svg) > 0

            # return plot as image content, multiple y-columns, stacked
            plot_result_image = plot_bar_tool.handler(Dict(
                "path" => joinpath(ro_dir, "test_table.csv"),
                "xcolumn" => "Sex",
                "ycolumns" => ["Height", "Weight"],
                "stacked" => true
            ))
            @test plot_result_image isa ImageContent;
            @test plot_result_image.mime_type == "image/png";

            # clean up test plot file
            isfile(output_path_png) && rm(output_path_png)
            isfile(output_path_svg) && rm(output_path_svg)
        end

        @testset "Plot Line" begin
            plot_line_tool = Anglerfish.TOOLS["plot_line"]
            output_path_png = joinpath(rw_dir, "test_lineplot.png")
            output_path_svg = joinpath(rw_dir, "test_lineplot.svg")

            # plot to PNG file using a categorical x-axis
            plot_result = plot_line_tool.handler(Dict(
                "path" => joinpath(ro_dir, "test_table.csv"),
                "xcolumn" => "Name",
                "ycolumns" => ["Age"],
                "output_path" => output_path_png,
                "title" => "Ages Over Students",
                "x_axis_label" => "Students",
                "y_axis_label" => "Years"
            )).text
            @test startswith(plot_result, "plot generated successfully")
            @test isfile(output_path_png)
            @test filesize(output_path_png) > 0

            # plot to SVG file using a numeric x-axis with multiple series
            plot_result_multiple_y = plot_line_tool.handler(Dict(
                "path" => joinpath(ro_dir, "test_table.csv"),
                "xcolumn" => "Name",
                "ycolumns" => ["Height", "Weight"],
                "colors" => ["blue", "green"],
                "output_path" => output_path_svg
            )).text
            @test startswith(plot_result_multiple_y, "plot generated successfully")
            @test isfile(output_path_svg)
            @test filesize(output_path_svg) > 0

            # return plot as image content
            plot_result_image = plot_line_tool.handler(Dict(
                "path" => joinpath(ro_dir, "test_table.csv"),
                "xcolumn" => "Age",
                "ycolumns" => ["Height", "Weight"]
            ))
            @test plot_result_image isa ImageContent
            @test plot_result_image.mime_type == "image/png"

            isfile(output_path_png) && rm(output_path_png)
            isfile(output_path_svg) && rm(output_path_svg)
        end

        @testset "Execute SQL" begin
            execute_sql_tool = Anglerfish.TOOLS["execute_sql"]

            # test executing a simple SELECT query on a valid CSV file
            sql_result = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test_table.csv"), "query" => "SELECT Name, Age FROM test_table WHERE City = 'New York'")).text
            @test contains(sql_result, "Alice") && contains(sql_result, "30") && !contains(sql_result, "Bob")

            # execute a simple SELECT query and write the result to a new CSV file, then check that the output file is created and contains the expected data
            sql_result_with_sink = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test_table.csv"), "query" => "SELECT Name, City FROM test_table WHERE Age <= 28", "sink_path" => joinpath(rw_dir, "sql_output.csv"))).text
            @test startswith(sql_result_with_sink, "SQL query executed successfully, result written to")
            @test isfile(joinpath(rw_dir, "sql_output.csv"))
            sql_output_data = CSV.File(joinpath(rw_dir, "sql_output.csv")) |> DataFrame
            @test size(sql_output_data) == (9, 2)
            @test names(sql_output_data) == ["Name", "City"]
            @test sql_output_data[1, :] |> collect == ["Bob", "Los Angeles"]

            # modify the original CSV file with an UPDATE query and check that the changes are persisted when persist_changes is true
            CSV.write(joinpath(rw_dir, "update_table.csv"), DataFrame(Name=["Alice", "Bob"], Age=[30, 25], City=["New York", "Los Angeles"]))
            sql_update_result = execute_sql_tool.handler(Dict("source_path" => joinpath(rw_dir, "update_table.csv"), "query" => "UPDATE update_table SET Age = Age + 1 WHERE Name = 'Bob'", "persist_changes" => true)).text
            @test startswith(sql_update_result, "SQL query executed successfully")
            updated_table_data = CSV.read(joinpath(rw_dir, "update_table.csv"), DataFrame)
            @test updated_table_data[updated_table_data.Name .== "Bob", :Age][1] == 26

            # test executing a query with an invalid path
            sql_invalid_path = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "non_existent_file.csv"), "query" => "SELECT * FROM test_table")).text
            @test startswith(sql_invalid_path, "ERROR:")

            # test executing a query on a file that is not a CSV
            sql_not_csv = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test file 1.txt"), "query" => "SELECT * FROM test_table")).text
            @test startswith(sql_not_csv, "ERROR: file type not supported")

            # test executing a query with invalid SQL syntax
            sql_invalid_syntax = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test_table.csv"), "query" => "SELEC Name FROM test_table")).text
            @test contains(sql_invalid_syntax, "failed to execute SQL query") && contains(sql_invalid_syntax, "SELEC")

            # clean up test files
            isfile(joinpath(rw_dir, "sql_output.csv")) && rm(joinpath(rw_dir, "sql_output.csv"))
            isfile(joinpath(rw_dir, "update_table.csv")) && rm(joinpath(rw_dir, "update_table.csv"))
        end
    end
end;


@testset "Common Functions" verbose = true begin

    @testset "Path Validation" begin
        # Test with a valid path that should be allowed for reading but not writing
        @test Anglerfish.isvalidpath(ro_dir, "read") == true
        @test Anglerfish.isvalidpath(ro_dir, "write") == false

        # Test with a path that should be denied
        @test Anglerfish.isvalidpath("/", "read") == false
        @test Anglerfish.isvalidpath("/", "write") == false

        # Test with an invalid access type
        @test Anglerfish.isvalidpath(rw_dir, "execute") == false
    end

    @testset "Command Availability" begin
        # Test with a common command that should be available
        @test Anglerfish.isinstalled("echo") == true

        # Test with a command that is unlikely to be available
        @test Anglerfish.isinstalled("some_non_existent_command_12345") == false
    end

    @testset "Tryparse Bool" begin
        @test Anglerfish.parse_bool("true", false) == true
        @test Anglerfish.parse_bool("True", false) == true
        @test Anglerfish.parse_bool("false", false) == false
        @test Anglerfish.parse_bool("False", false) == false
        @test Anglerfish.parse_bool(true, false) == true
        @test Anglerfish.parse_bool(false, true) == false
        @test Anglerfish.parse_bool(nothing, true) == true
        @test Anglerfish.parse_bool("not_a_bool", false) == false
    end

end;