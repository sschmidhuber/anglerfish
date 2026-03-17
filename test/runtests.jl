include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))
using Test


@testset "Basic tools" begin
    @test Anglerfish.open_file(joinpath(@__DIR__, "runtests.jl")) == "successfully opened file: $(joinpath(@__DIR__, "runtests.jl"))"
    @test Anglerfish.open_file("non_existent_file.txt") == "file not found: non_existent_file.txt"
end


@testset "Email tools" begin    
    # Test the compose_email function with various parameters
    @test Anglerfish.compose_email() == "successfully opened email client with precomposed email"
    @test Anglerfish.compose_email("Test Subject") == "successfully opened email client with precomposed email"
    @test Anglerfish.compose_email("Test Subject", ["grace.hopper@navy.mil", "alan.turing@oxford.edu"], ["albert.einstein@stanford.edu"], ["erwin.schroedinger@uniwien.at"], "Test Content", [joinpath(@__DIR__, "runtests.jl")]) == "successfully opened email client with precomposed email"
end