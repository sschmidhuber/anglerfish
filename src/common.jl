"""
    validate_path(path::AbstractString, access::String)

Validates that the given path is within the allowed directories for the specified access type ("read" or "write").

Arguments:
- `path`: The file or directory path to validate.
- `access`: The type of access being requested, either "read" or "write".
"""
function validate_path(path::AbstractString, access::String)::Bool
    if access == "read"
        allowed_directories = union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES)
    elseif access == "write"
        allowed_directories = READ_WRITE_DIRECTORIES
    else
        @warn "invalid access type: $access. Must be 'read' or 'write'."
        return false
    end

    try
        for allowed in allowed_directories
            if startswith(realpath(isdir(path) ? path : dirname(path)), realpath(allowed))
                return true
            end
        end        
    catch error
        @warn "error validating directory: $(error)"
        return false
    end
    return false
end



"""
    isinstalled(cmd::AbstractString)

Checks if a command is available on the system. Returns true if the command is found, false otherwise.
"""
function isinstalled(cmd::AbstractString)::Bool
    try
        if Sys.iswindows()
            run(pipeline(`where $cmd`, stderr=devnull, stdout=devnull))
        else
            run(pipeline(`which $cmd`, stderr=devnull, stdout=devnull))
        end
        return true
    catch
        return false
    end
end