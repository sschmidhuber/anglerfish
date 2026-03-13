# date time

function init_date_time_tool(config::Dict)
    @info "initialize date_time_tool"
    date_time = MCPTool(
        name="date_time",
        description="returns the current local date and time as timestamp (ISO 8601 format: YYYY-MM-DDThh:mm:ss.fff)",
        parameters=[],
        handler=params -> TextContent(; type="text", text=string(now()))
    )
    push!(TOOLS, date_time)
end

push!(INIT_FUNCTIONS, init_date_time_tool)


# user data

function init_user_data_tool(config::Dict)
    @info "initialize user_data_tool"
    user_data = MCPTool(
        name="user_data",
        description="returns a set of data about the user, including name, day of birth, address, email ...",
        parameters=[],
        handler=params -> TextContent(; type="text", text=Dict(
            "master_data" => config["user_data"],
            "address" => config["user_address"]
        ) |> JSON.json
        )
    )
    push!(TOOLS, user_data)
end

push!(INIT_FUNCTIONS, init_user_data_tool)