#using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))

using Test
using JSON

push!(ARGS, "TEST_MODE")

Anglerfish.init()

current_dir = @__DIR__
append!(Anglerfish.READ_ONLY_DIRECTORIES, [current_dir])

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
    @test open_file_tool.handler(Dict("file_path" => joinpath(@__DIR__, "runtests.jl"))).text == "successfully opened file: $(joinpath(@__DIR__, "runtests.jl"))"
    @test open_file_tool.handler(Dict("file_path" => joinpath(current_dir, "non_existent_file.txt"))).text == "access denied or invalid path: $(joinpath(current_dir, "non_existent_file.txt"))"
end


@testset "System Info" begin
    system_info_tool = Anglerfish.TOOLS["system_info"]
    system_info_result = (system_info_tool.handler(nothing)).text |> JSON.parse
    @test system_info_result["os"] == Sys.KERNEL |> string
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
            "attachments" => [joinpath(@__DIR__, "runtests.jl")]
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


@testset "Filesystem" verbose=true begin
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
            read_directory_result_with_filter = read_directory_tool.handler(Dict("directory" => first(Anglerfish.READ_ONLY_DIRECTORIES), "filter" => [".jl"])).text |> JSON.parse
            @test all(endswith(".jl"), read_directory_result_with_filter["files"])

            # Test with multiple extension filter
            read_directory_result_with_multiple_filter = read_directory_tool.handler(Dict("directory" => first(Anglerfish.READ_ONLY_DIRECTORIES), "filter" => [".jl", ".md"])).text |> JSON.parse
            @test all(x -> endswith(x, ".jl") || endswith(x, ".md"), read_directory_result_with_multiple_filter["files"])
        end

        @testset "File Search" begin
            # get file search command function
            file_search_func = Anglerfish.file_search_func()
            @test file_search_func !== nothing

            # search with no keywords provided for search
            find_cmd_result = Anglerfish.find_cmd([], [first(Anglerfish.READ_ONLY_DIRECTORIES)], true, true)
            @test find_cmd_result == "no keywords provided for search"

            # search with one keyword and no directories provided (should search all allowed directories)
            find_cmd_result_single_keyword = Anglerfish.find_cmd(["runtests"])
            @test any(endswith("runtests.jl"), find_cmd_result_single_keyword["files"])

            # search with multiple keywords and no directories provided (should search all allowed directories)
            find_cmd_result_multiple_keywords = Anglerfish.find_cmd(["runtests", "non_existent_file"])
            @test any(endswith("runtests.jl"), find_cmd_result_multiple_keywords["files"])
            @test !any(endswith("non_existent_file"), find_cmd_result_multiple_keywords["files"])

            # search with one keyword and specific directory provided
            find_cmd_result_single_keyword_with_directory = Anglerfish.find_cmd(["runtests"], [current_dir])
            @test any(endswith("runtests.jl"), find_cmd_result_single_keyword_with_directory["files"])

            # test handler with single keyword and specific directory provided
            file_search_tool = Anglerfish.TOOLS["file_search"]
            file_search_result = file_search_tool.handler(Dict("keywords" => ["runtests"], "directories" => [current_dir], "only_files" => "true")).text |> JSON.parse
            @test any(endswith("runtests.jl"), file_search_result["files"])

            # test handler with multiple keywords and specific directory provided
            file_search_result_multiple_keywords = file_search_tool.handler(Dict("keywords" => ["runtests", "non_existent_file"], "directories" => [current_dir], "only_files" => "true")).text |> JSON.parse
            @test any(endswith("runtests.jl"), file_search_result_multiple_keywords["files"])
            @test !any(endswith("non_existent_file"), file_search_result_multiple_keywords["files"])
        end
end

end;


@testset "Common Functions" verbose=true begin

@testset "Path Validation" begin
    # Test with a valid path that should be allowed for reading but not writing
    @test Anglerfish.validate_path(current_dir, "read") == true
    @test Anglerfish.validate_path(current_dir, "write") == false

    # Test with a path that should be denied
    @test Anglerfish.validate_path("/", "read") == false
    @test Anglerfish.validate_path("/", "write") == false

    # Test with an invalid access type
    @test Anglerfish.validate_path(current_dir, "execute") == false
end

@testset "Command Availability" begin
    # Test with a common command that should be available
    @test Anglerfish.isinstalled("echo") == true

    # Test with a command that is unlikely to be available
    @test Anglerfish.isinstalled("some_non_existent_command_12345") == false
end

end;