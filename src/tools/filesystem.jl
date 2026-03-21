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
    
    if !validate_path(directory, "read")
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


# search file

function desktop_search_tool()::Uinon{String,Nothing}
    if Sys.iswindows()
        return nothing # not implemented yet
    elseif Sys.isapple()
        return nothing # not implemented yet
    else
        return "desktop_search tool is not implemented on this operating system yet"
    end
end