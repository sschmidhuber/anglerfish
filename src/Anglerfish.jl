module Anglerfish

using ModelContextProtocol
using Dates

const TOOLS = ModelContextProtocol.MCPTool[]

include("tools/basic.jl")

export main

function @main(ARGS)
    @info "start Anglerfish MCP server"
    server = mcp_server(
        name="Anglerfish",
        description="A MCP server which turns your favorite MCP client into a agentic personal assistant",
        tools=TOOLS
    )

    start!(server)
end

end

using .Anglerfish
