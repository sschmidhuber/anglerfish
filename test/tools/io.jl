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