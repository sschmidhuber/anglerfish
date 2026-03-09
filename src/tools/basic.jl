date_time_tool = MCPTool(
    name = "date_time",
    description = "returns the current local date and time as timestamp (ISO 8601 format: YYYY-MM-DDThh:mm:ss.fff)",
    parameters = [],
    handler = params -> TextContent(; type="text", text=string(now()))
)

push!(TOOLS, date_time_tool)