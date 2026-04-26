#using Pkg; Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "src", "Anglerfish.jl"))

using CSV
using DataFrames
using JSON
using ModelContextProtocol
using Test

push!(ARGS, "TEST_MODE")

Anglerfish.init()

ro_dir = joinpath(@__DIR__, "testdata", "read_only")
rw_dir = joinpath(@__DIR__, "testdata", "read_write")
append!(Anglerfish.READ_ONLY_DIRECTORIES, [ro_dir])
append!(Anglerfish.READ_WRITE_DIRECTORIES, [rw_dir])

@testset "Tools" verbose=true begin
    include(joinpath(@__DIR__, "tools", "basic_tools.jl"))
    include(joinpath(@__DIR__, "tools", "email.jl"))
    include(joinpath(@__DIR__, "tools", "calendar.jl"))
    include(joinpath(@__DIR__, "tools", "filesystem.jl"))
    include(joinpath(@__DIR__, "tools", "shell_command_execution.jl"))
    include(joinpath(@__DIR__, "tools", "io.jl"))
    include(joinpath(@__DIR__, "tools", "analytics.jl"))
end;


include(joinpath(@__DIR__, "common_functions.jl"))