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