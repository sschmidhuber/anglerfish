
const PDFTOTEXT_INSTALLED = isinstalled("pdftotext")
const PANDOC_INSTALLED = isinstalled("pandoc")

# read


"""
    pdftotext(path)::TextContent

Extracts text from a PDF file at the specified path using the pdftotext command-line tool. Returns a TextContent object containing the extracted text. Throws an error if pdftotext is not installed or if text extraction fails.
"""
function pdftotext(path)::TextContent
    if !PDFTOTEXT_INSTALLED
        throw("pdftotext is not installed on this system")
    end

    exec = ["pdftotext", "-layout", path, "-"]
    try
        output = readchomp(pipeline(Cmd(exec), stderr=devnull))
        return TextContent(; type="text", text=output)
    catch error
        throw("failed to extract text from PDF: $error")
    end
end


function convert2md(path)::TextContent
    if !PANDOC_INSTALLED
        throw("pandoc is not installed on this system")
    end

    inpu

    exec = ["pandoc", path, "-f", "html", "-t", "markdown"]
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
        elseif mime == MIME("application/pdf")
            if PDFTOTEXT_INSTALLED
                return pdftotext(path)
            else
                return "file type: $mime is not supported, because of missing dependency pdftotext. Please install poppler-utils to enable PDF text extraction."
            end
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
        description="reads the content of a file at the specified path. The file must be within the allowed directories ($(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " and "))) and of a supported type (text, image od PDF). Returns a Content object containing the file data or an error message if the file cannot be read.",
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