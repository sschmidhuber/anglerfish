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
end