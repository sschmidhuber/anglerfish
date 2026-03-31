# read

const MAX_IMAGE_DIMENSION = 1024


"""
    downscale_image(path, mime)

Returns image data (as `Vector{UInt8}`) for the given image file. If either dimension
exceeds `MAX_IMAGE_DIMENSION`, the image is resized while preserving the aspect ratio.
"""
function downscale_image(path::AbstractString, mime::MIME)::Vector{UInt8}
    img = FileIO.load(path)
    h, w = size(img)

    if w <= MAX_IMAGE_DIMENSION && h <= MAX_IMAGE_DIMENSION
        return read(path)
    end

    scale = min(MAX_IMAGE_DIMENSION / w, MAX_IMAGE_DIMENSION / h)
    new_w = round(Int, w * scale)
    new_h = round(Int, h * scale)
    resized = imresize(img, (new_h, new_w))

    fmt = typeof(FileIO.query(path)).parameters[1]
    io = IOBuffer()
    FileIO.save(FileIO.Stream{fmt}(io), resized)
    return take!(io)
end


"""
    read_file(path)

Reads the content of a file at the specified path. The file must be within the allowed directories and of a supported type (text or image). Returns a Content object containing the file data or an error message if the file cannot be read.
"""
function read_file(path::AbstractString)::Union{TextContent,ImageContent,String}
    if !isvalidpath(path, "read")
        return "access denied or invalid path: $path"
    elseif !isfile(path)
        return "file not found: $path"
    end

    try
        mime = mime_from_path(path)
        if string(mime)[1:4] == "text"
            return TextContent(; type="text", text=read(path, String))
        elseif string(mime)[1:5] == "image"
            data = downscale_image(path, mime)
            return ImageContent(; type="image", data=data, mime_type=string(mime))
        else
            return "file type: $mime is not supported for reading"
            # TODO: read more types
        end        
    catch err
        return "failed to read file: $err"
    end
end


function init_read_file_tool(config::Dict)
    @info "initialize read file tool"
    read_file_tool = MCPTool(
        name="read_file",
        description="reads the content of a file at the specified path. The file must be within the allowed directories ($(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " and "))) and of a supported type (text or image). Returns a Content object containing the file data or an error message if the file cannot be read.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the absolute path to the file to be read",
                required = true
            )
        ],
        handler = params -> begin
            res = read_file(params["path"])
            if res isa String
                return TextContent(; type="text", text=res)
            else
                return res
            end
        end
    )
    TOOLS[read_file_tool.name] = read_file_tool
end

push!(INIT_FUNCTIONS, init_read_file_tool)

# TODO: add tests


# write


# write as