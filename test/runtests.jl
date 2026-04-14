#using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))

using Test
using JSON
using ModelContextProtocol

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
            shell_result = shell_tool.handler(Dict("command" => "echo Hello World", "open_terminal" => false)).text
            @test shell_result == "Hello World"

            # test foreground execution of a simple command (this will open a terminal window, so we can't easily automate checking the result, but we can at least check that it doesn't return an error)
            shell_result_foreground = shell_tool.handler(Dict("command" => "echo Hello Foreground; sleep 2", "open_terminal" => "True")).text
            @test startswith(shell_result_foreground, "command executed in foreground with terminal:")

            # test execution with working directory specified
            shell_result_with_wd = shell_tool.handler(Dict("command" => "pwd", "working_directory" => ro_dir, "open_terminal" => false)).text
            @test strip(shell_result_with_wd) == ro_dir

            # test execution with invalid working directory specified (should default to home or first allowed directory)
            shell_result_with_invalid_wd = shell_tool.handler(Dict("command" => "pwd", "working_directory" => "/invalid/directory", "foreground" => false)).text
            @test strip(shell_result_with_invalid_wd) == homedir() || strip(shell_result_with_invalid_wd) == first(Anglerfish.READ_ONLY_DIRECTORIES)
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
        end

        @testset "Write File" begin
            write_file_tool = Anglerfish.TOOLS["write_file"]

            # test writing to a file in a read-write directory
            write_file_result = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test_write.txt"), "content" => "This is a test.")).text
            @test write_file_result == "file written successfully to: $(joinpath(rw_dir, "test_write.txt"))"
            @test read(joinpath(rw_dir, "test_write.txt"), String) == "This is a test."

            # test writing to a file in a read-only directory (should return an error)
            write_file_result_read_only = write_file_tool.handler(Dict("path" => joinpath(ro_dir, "test_write.txt"), "content" => "This should fail.")).text
            @test startswith(write_file_result_read_only, "access denied or invalid path:")

            # test writing to a file with an invalid path (should return an error)
            write_file_result_invalid_path = write_file_tool.handler(Dict("path" => "/invalid/directory/test_write.txt", "content" => "This should also fail.")).text
            @test startswith(write_file_result_invalid_path, "access denied or invalid path:")

            # test writing raw content by creating a julia file and checking that it can be executed
            write_file_result_raw = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test_script.jl"), "content" => "println(\"Hello from test script\")", "raw" => true)).text
            @test write_file_result_raw == "file written successfully to: $(joinpath(rw_dir, "test_script.jl"))"
            script_output = readchomp(`julia $(joinpath(rw_dir, "test_script.jl"))`)
            @test script_output == "Hello from test script"

            # create PDF file
            write_file_result_pdf = write_file_tool.handler(Dict("path" => joinpath(rw_dir, "test.pdf"), "content" => "# Test PDF\n\nThis is a test PDF file. ☀️", "raw" => false)).text
            @test write_file_result_pdf == "file written successfully to: $(joinpath(rw_dir, "test.pdf"))"
            @test isfile(joinpath(rw_dir, "test.pdf"))

            # clean up test files
            rm(joinpath(rw_dir, "test_write.txt"))
            rm(joinpath(rw_dir, "test_script.jl"))
            rm(joinpath(rw_dir, "test.pdf"))
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