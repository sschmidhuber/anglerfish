# date time

function init_date_time_tool(config::Dict)
    @info "initialize date time tool"
    date_time_tool = MCPTool(
        name="date_time",
        description="returns the current local date, time, timezone, day of week and week of year",
        parameters=[],
        handler=params -> date_time()
    )
    TOOLS[date_time_tool.name] = date_time_tool
end

function date_time()
    t = now()
    Dict(
        "time" => Dates.format(t, "HH:MM"),
        "date" => Date(t),
        "timezone" => localzone() |> string,
        "day_of_week" => string(Dates.dayname(t)),
        "week_of_year" => week(t)
    )
end

push!(INIT_FUNCTIONS, init_date_time_tool)


# user data

function init_user_data_tool(config::Dict)
    @info "initialize user data tool"
    user_data_tool = MCPTool(
        name="user_data",
        description="returns a set of data about the user, including name, day of birth, address, email ...",
        parameters=[],
        handler=params -> Dict(
            "master_data" => config["user_data"],
            "address" => config["user_address"]
        )
    )
    TOOLS[user_data_tool.name] = user_data_tool
end

push!(INIT_FUNCTIONS, init_user_data_tool)


# system info

function system_info()
    dict = Dict(
        "cpu" => Sys.CPU_NAME,
        "architecture" => Sys.ARCH, 
        "cores" => Sys.CPU_THREADS,
        "memory" => "$(ceil(Int, Sys.total_memory() / 1_073_741_824)) GiB"
    )

    if Sys.islinux()        
        osrelease = readchomp("/etc/os-release")
        for line in split(osrelease, "\n")
            if startswith(line, "PRETTY_NAME=")
                dict["os"] = line[14:end-1]
                break
            end
        end
    elseif Sys.isapple()
        dict["os"] = "macOS"
    elseif Sys.iswindows()
        dict["os"] = "Windows"
    elseif Sys.isbsd()
        dict["os"] = "BSD"
    else
        dict["os"] = "unknown"
    end

    return dict
end

function init_system_info_tool(config::Dict)
    @info "initialize system info tool"
    system_info_tool = MCPTool(
        name="system_info",
        description="returns a set of data about the system, including os, cpu and memory",
        parameters=[],
        handler=params -> system_info()
    )
    TOOLS[system_info_tool.name] = system_info_tool
end

push!(INIT_FUNCTIONS, init_system_info_tool)


# open files

function init_open_file_tool(config::Dict)
    @info "initialize open file tool"
    open_file_tool = MCPTool(
        name="open_file",
        description="opens a file with the default application for that file type. The file path must be absolute and within the allowed directories: $(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " or "))",
        parameters=[
            ToolParameter(
                name = "file_path",
                type = "string",
                description = "the absolute path to the file to be opened",
                required = true
            )
        ],
        handler=params -> open_file(params["file_path"])
    )
    TOOLS[open_file_tool.name] = open_file_tool
end


"""
    open_file(path)

Opens a file with the default application for that file type. The file path must be absolute.
"""
function open_file(path)
    if !isvalidpath(path, "read")
        return "access denied or invalid path: $path"
    elseif !isfile(path)
        return "file not found: $path"
    end

    try
        if Sys.iswindows()
            run(`cmd /c start "" "$path"`)
        elseif Sys.isapple()
            run(`open "$path"`)
        else
            run(Cmd(["xdg-open", path]))
        end
    catch err
        return "failed to open file: $err"
    end
    
    return "successfully opened file: $path"
end

push!(INIT_FUNCTIONS, init_open_file_tool)


#=
bwrap --ro-bind /bin /bin --dev /dev --proc /proc --ro-bind /run /run --ro-bind-try /lib
64 /lib64  --ro-bind /tmp /tmp --ro-bind /var /var --ro-bind /etc /etc --ro-bind /lib /lib --ro-bind /sys /sys --ro-bind /usr /u
sr bash -c 'ls'
=#