@testset "Calendar" begin
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
                "description" => "* Milk\n* Bread\n* Eggs"
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
            ),
            Dict(
                "type" => "event",
                "title" => "Sommer Urlaub",
                "start" => "2027-07-02",
                "end" => "2027-07-16",
                "description" => "Familienurlaub",
                "location" => "Gasteinertal, Österreich"
            ),
            Dict(
                "type" => "event",
                "title" => "Multiple days with time",
                "start" => "2027-04-01T10:00:00",
                "end" => "2027-04-03T08:00:00",
                "description" => "An event, longer than a single day, with an exact start and end time."
            ),
            Dict(
                "type" => "event",
                "title" => "Two day event",
                "start" => "2027-01-07",
                "end" => "2027-01-08",
                "description" => "Two day event without specific time"
            )
        ]
    )).text
    @test calendar_result == "successfully created a calendar file and opened it in the default calendar client"
end