@testset "Basic tools" begin
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
end