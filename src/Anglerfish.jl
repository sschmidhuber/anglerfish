module Anglerfish

using BaseDirs
using Dates
using FileIO
using ImageTransformations
using MIMEs
using JSON
using ModelContextProtocol
using TimeZones
using TOML
using UUIDs

const TOOLS = Dict{String,ModelContextProtocol.MCPTool}()
const INIT_FUNCTIONS = Function[]
const READ_ONLY_DIRECTORIES = []
const READ_WRITE_DIRECTORIES = []

include("common.jl")
include("tools/basic.jl")
include("tools/email.jl")
include("tools/calendar.jl")
include("tools/filesystem.jl")
include("tools/shell.jl")
include("tools/io.jl")

export main


"""
    configure(template, config_path)

Configure Anglerfish by reading a template config file, modifying it as needed, and writing the final config to the specified path.
"""
function configure(template, config_path)
    config = TOML.parsefile(template)
    anglerfish_data_dir = joinpath(BaseDirs.DATA_HOME, "anglerfish")
    config["filesystem"]["read_only"] = [Base.Filesystem.homedir()]
    config["filesystem"]["read_write"] = [anglerfish_data_dir]
    mkpath(anglerfish_data_dir)
    
    open(config_path, "w") do io
        TOML.print(io, config)
    end
end


"""
    init()

Load configuration and run tool initialization functions.
"""
function init()
    config_path = joinpath(BaseDirs.CONFIG_HOME, "anglerfish", "config.toml")
    local config
    if !isfile(config_path)
        mkpath(joinpath(BaseDirs.CONFIG_HOME, "anglerfish"))
        configure(joinpath(@__DIR__, "config.toml"), config_path)
        @info "No config file found. A default config has been created at $config_path."
    end
    try
        config = TOML.parsefile(config_path)
    catch error
        @error "failed to parse config file at $config_path: $error"
        exit(1)
    end
    config = TOML.parsefile(config_path)

    append!(READ_ONLY_DIRECTORIES, config["filesystem"]["read_only"])
    append!(READ_WRITE_DIRECTORIES, config["filesystem"]["read_write"])

    for init in INIT_FUNCTIONS
        init(config)
    end
end


function @main(ARGS)
    if length(ARGS) == 1 && ARGS[1] == "TEST_MODE"
        return nothing
    end

    init()

    server = mcp_server(;
        name="Anglerfish",
        version="0.1.0",
        tools=TOOLS |> values |> collect,
        description="A MCP server which turns your favorite MCP client into a agentic personal assistant"
    )

    if !isinteractive()
        @info "start Anglerfish MCP server"
        start!(server)
    end

    return nothing
end

end

using .Anglerfish
