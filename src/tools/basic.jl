# date time

function init_date_time_tool(config::Dict)
    @info "initialize date time tool"
    date_time_tool = MCPTool(
        name="date_time",
        description="returns the current local date and time as timestamp (ISO 8601 format: YYYY-MM-DDThh:mm:ss.fff)",
        parameters=[],
        handler=params -> TextContent(; type="text", text=string(now()))
    )
    push!(TOOLS, date_time_tool)
end

push!(INIT_FUNCTIONS, init_date_time_tool)


# user data

function init_user_data_tool(config::Dict)
    @info "initialize user data tool"
    user_data_tool = MCPTool(
        name="user_data",
        description="returns a set of data about the user, including name, day of birth, address, email ...",
        parameters=[],
        handler=params -> TextContent(; type="text", text=Dict(
            "master_data" => config["user_data"],
            "address" => config["user_address"]
        ) |> JSON.json
        )
    )
    push!(TOOLS, user_data_tool)
end

push!(INIT_FUNCTIONS, init_user_data_tool)


# system info

function init_system_info_tool(config::Dict)
    @info "initialize system info tool"
    system_info_tool = MCPTool(
        name="system_info",
        description="returns a set of data about the system, including os, cpu and memory (in GiB)",
        parameters=[],
        handler=params -> TextContent(; type="text", text=Dict(
            "os" => Sys.KERNEL |> string,
            "cpu" => Sys.CPU_NAME,
            "architecture" => Sys.ARCH, 
            "cores" => Sys.CPU_THREADS,
            "memory" => ceil(Int, Sys.total_memory() / 1_073_741_824)
            ) |> JSON.json
        )
    )
    push!(TOOLS, system_info_tool)
end

push!(INIT_FUNCTIONS, init_system_info_tool)


# open files

function init_open_file_tool(config::Dict)
    @info "initialize open file tool"
    open_file_tool = MCPTool(
        name="open_file",
        description="opens a file with the default application for that file type. The file path must be absolute.",
        parameters=[
            ToolParameter(
                name = "file_path",
                type = "str",
                description = "the absolute path to the file to be opened",
                required = true
            )
        ],
        handler=params -> TextContent(; type="text", text=open_file(params["file_path"]))
    )
    push!(TOOLS, open_file_tool)    
end


"""
    open_file(path)

Opens a file with the default application for that file type. The file path must be absolute.
"""
function open_file(path)
    if !isfile(path)
        return "file not found: $path"
    end

    try
        if Sys.iswindows()
            run(`cmd /c start "" "$path"`)
        elseif Sys.isapple()
            run(`open "$path"`)
        else
            run(`xdg-open "$path"`)
        end
        return "successfully opened file: $path"
    catch err
        return "failed to open file: $err"
    end
end

push!(INIT_FUNCTIONS, init_open_file_tool)
