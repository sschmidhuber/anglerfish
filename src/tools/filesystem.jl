
# read directory

"""
    read_directory(directory, filter=[])

Reads the contents of a directory and returns a list of files and subdirectories. The directory must be within the allowed directories specified in the configuration.

# Arguments
- `directory`: The absolute path to the directory to be read.
- `filter`: An optional vector of file extensions to filter the results (e.g. `[".txt", ".md"]`).
"""
function read_directory(directory, filter=[])
    files = []
    directories= []
    
    if !isvalidpath(directory, "read")
        return "access denied: $directory"
    end

    if !isempty(filter)
        filter = lowercase.(filter)
        filter = ifelse.(startswith.(filter, "."), filter, "." .* filter)
    end

    try
        for entry in readdir(directory)
            full_path = joinpath(directory, entry)
            if isfile(full_path)
                if isempty(filter) 
                    push!(files, full_path)
                else
                    if lowercase(splitext(full_path)[2]) in filter
                        push!(files, full_path)
                    end
                end
            elseif isdir(full_path)
                push!(directories, full_path)
            end
        end
        return Dict("files" => files, "directories" => directories)
    catch error
        return "Error reading directory: $(error)"
    end
end


function init_read_directory_tool(config)
    @info "initialize read directory tool"
    read_directory_tool = MCPTool(
        name="read_directory",
        description="reads the contents of a directory and returns a list of files and subdirectories. The directory must be within the allowed directories: $(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " or "))",
        parameters=[
            ToolParameter(
                name = "directory",
                type = "str",
                description = "the absolute path to the directory to be read",
                required = true
            ),
            ToolParameter(
                name = "filter",
                type = "array",
                description = "an optional list of file extensions to filter the results (e.g. ['.txt', '.md'])",
                required = false
            )
        ],
        handler=params -> begin
            try
                result = read_directory(params["directory"], get(params, "filter", []))
                if result isa String
                    return TextContent(; type="text", text=result)
                else
                    return TextContent(; type="text", text=Dict(
                        "files" => result["files"],
                        "directories" => result["directories"]
                    ) |> JSON.json)
                end
            catch error
                return TextContent(; type="text", text="failed to read directory: $(error)")
            end
        end
    )
    TOOLS[read_directory_tool.name] = read_directory_tool
end

push!(INIT_FUNCTIONS, init_read_directory_tool)

# file search

function file_search_func()::Union{Function,Nothing}
    if Sys.iswindows()
        return nothing # not implemented yet
    else
        if isinstalled("find")
            return find_cmd    
        end
    end

    return nothing
end


"""
    find_cmd(keywords, directories=[], only_files=true, exclude_hidden=true)::Union{Vector{String}, String}

Executes a search for files and directories matching the specified keywords within the allowed directories. Returns a vector of matching paths or an error message.
# Arguments
- `keywords`: A vector of keywords to search for in file and directory names.
- `directories`: An optional vector of directories to limit the search to. If empty, searches all allowed directories.
- `filter`: An optional vector of file extensions to filter the results (e.g. `[".txt", ".md"]`).
- `only_files`: If true, only returns files. If false, returns both files and directories.
- `exclude_hidden`: If true, excludes hidden files and directories from the search results.
"""
function find_cmd(keywords, directories=[], filter=[], only_files=true, exclude_hidden=true)::Union{Dict, String}
    dirs = ifelse(isempty(directories) && all(isvalidpath.(directories, "read")), union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), directories)
    exec = ["find", dirs...]
    if exclude_hidden
        append!(exec, ["-name", ".*", "-prune", "-o"])
    end
    if only_files
        append!(exec, ["-type", "f"])
    end
    if length(keywords) == 1
        append!(exec, ["-iname", "*$(keywords[1])*"])
    elseif length(keywords) > 1
        append!(exec, ["(", (join(map(k -> "-iname *$(k)*", keywords), " -o ") |> split .|> String)..., ")"])
    else
        return "no keywords provided for search"
    end
    if exclude_hidden
        append!(exec, ["-print"])
    end
    @debug "Executing find command: $(join(exec, " "))"
    cmd = Cmd(exec)
    try
        output = read(ignorestatus(cmd), String)
        results = split(output, "\n", keepempty=false)
        directories = []
        files = []
        for result in results
            if isdir(result)
                push!(directories, result)
            elseif isfile(result) && (isempty(filter) || lowercase(splitext(result)[2]) in lowercase.(filter))
                push!(files, result)
            end
        end

        return Dict("files" => files, "directories" => directories)
    catch error
        return "error executing find command: $(error)"
    end
end


function init_file_search_tool(config::Dict)
    @info "initialize file search tool"
    search_function = file_search_func()
    if isnothing(search_function)
        @warn "file search tool is not available on this system, no supported search command found"
        return        
    end
    file_search_tool = MCPTool(
        name="file_search",
        description="searches for files and directories matching the specified keywords within the allowed directories. Returns a list of matching paths.",
        parameters=[
            ToolParameter(
                name = "keywords",
                type = "array",
                description = "a list of keywords to search for in file and directory names",
                required = true
            ),
            ToolParameter(
                name = "directories",
                type = "array",
                description = "an optional list of directories to limit the search to. If empty, searches all allowed directories.",
                required = false
            ),
            ToolParameter(
                name = "filter",
                type = "array",
                description = "an optional list of file extensions to filter the results (e.g. ['.txt', '.md'])",
                required = false
            ),
            ToolParameter(
                name = "only_files",
                type = "bool",
                description = "if true, only returns files. If false, returns both files and directories. Default is true.",
                required = false
            )
        ],
        handler=params -> begin
            try
                only_files = parse_bool(get(params, "only_files", false), false)
                result = search_function(params["keywords"], get(params, "directories", []), get(params, "filter", []), only_files)
                if result isa String
                    return TextContent(; type="text", text=result)
                else
                    return TextContent(; type="text", text=JSON.json(result))
                end
            catch error
                return TextContent(; type="text", text="failed to execute file search: $(error)")
            end
        end
    )

    TOOLS[file_search_tool.name] = file_search_tool
end

push!(INIT_FUNCTIONS, init_file_search_tool)
