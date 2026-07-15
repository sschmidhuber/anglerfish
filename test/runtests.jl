#using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))

using CSV
using DataFrames
using JSON
using ModelContextProtocol
using Test

push!(ARGS, "TEST_MODE")

cd(@__DIR__)
Anglerfish.init()

ro_dir = joinpath("testdata", "read_only")
rw_dir = joinpath("testdata", "read_write")
skill_dir = first(Anglerfish.SKILLS_DIRECTORIES)



@testset "Tools" verbose=true begin
    include(joinpath(@__DIR__, "tools", "basic_tools.jl"))
    #include(joinpath(@__DIR__, "tools", "email.jl"))
    #include(joinpath(@__DIR__, "tools", "calendar.jl"))
    include(joinpath(@__DIR__, "tools", "filesystem.jl"))
    include(joinpath(@__DIR__, "tools", "shell_command_execution.jl"))
    include(joinpath(@__DIR__, "tools", "io.jl"))
    include(joinpath(@__DIR__, "tools", "analytics.jl"))
    include(joinpath(@__DIR__, "tools", "skills.jl"))
end;


include(joinpath(@__DIR__, "common_functions.jl"))