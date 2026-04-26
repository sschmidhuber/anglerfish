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