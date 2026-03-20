include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))

using Test
using JSON

push!(ARGS, "TEST_MODE")

Anglerfish.init()


@testset "Date Time Tool" begin
    date_time_tool = Anglerfish.TOOLS["date_time"]
    date_time_result = (date_time_tool.handler(nothing)).text |> JSON.parse
    @test haskey(date_time_result, "time")
    @test haskey(date_time_result, "date")
    @test haskey(date_time_result, "timezone")
    @test haskey(date_time_result, "day_of_week")
    @test haskey(date_time_result, "week_of_year")
end


@testset "Open File Tool" begin
    open_file_tool = Anglerfish.TOOLS["open_file"]
    @test open_file_tool.handler(Dict("file_path" => joinpath(@__DIR__, "runtests.jl"))).text == "successfully opened file: $(joinpath(@__DIR__, "runtests.jl"))"
    @test open_file_tool.handler(Dict("file_path" => "non_existent_file.txt")).text == "file not found: non_existent_file.txt"
end


@testset "System Info Tool" begin
    system_info_tool = Anglerfish.TOOLS["system_info"]
    system_info_result = (system_info_tool.handler(nothing)).text |> JSON.parse
    @test system_info_result["os"] == Sys.KERNEL |> string
    @test system_info_result["cpu"] == Sys.CPU_NAME
    @test system_info_result["architecture"] == Sys.ARCH |> string
    @test system_info_result["cores"] == Sys.CPU_THREADS
    @test haskey(system_info_result, "memory")
end


@testset "Email Tool" begin
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


@testset "Calendar Tool" begin
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
