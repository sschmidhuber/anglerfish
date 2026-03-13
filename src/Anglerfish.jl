module Anglerfish

using BaseDirs
using Dates
using JSON
using ModelContextProtocol
using TOML

const TOOLS = ModelContextProtocol.MCPTool[]
const INIT_FUNCTIONS = Function[]

include("tools/basic.jl")
include("tools/email.jl")

export main

function @main(ARGS)
    @info "initialize Anglerfish"
    config_path = joinpath(BaseDirs.CONFIG_HOME, "anglerfish", "config.toml")
    if !isfile(config_path)
        mkpath(joinpath(BaseDirs.CONFIG_HOME, "anglerfish"))
        cp(joinpath(@__DIR__, "config.toml"), config_path)
        @info "No config file found. A default config has been created at $config_path."
    end
    config = TOML.parsefile(config_path)

    for init in INIT_FUNCTIONS
        init(config)
    end

    @info "start Anglerfish MCP server"
    server = mcp_server(;
        name="Anglerfish",
        version="0.1.0",
        tools=TOOLS,
        description="A MCP server which turns your favorite MCP client into a agentic personal assistant"
    )

    start!(server)
end


end

using .Anglerfish
