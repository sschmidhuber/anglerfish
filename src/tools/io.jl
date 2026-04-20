
const SUPPORTED_IMAGE_FORMATS = [".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tiff"]
const PDFTOTEXT_INSTALLED = isinstalled("pdftotext")
const PANDOC_INSTALLED = isinstalled("pandoc")
const PANDOC_INPUT_FORMATS = [".docx", ".pptx", ".odt", ".doc", ".rtf", ".epub", ".html"]
const PANDOC_OUTPUT_FORMATS = [".html", ".docx", ".odt", ".doc", ".pptx"]   # except for PDF, which requires a LaTeX engine and additional configuration
const PANDOC_PDF_ENGINE = if isinstalled("lualatex")
    "lualatex"
elseif isinstalled("xelatex")
    "xelatex"
elseif isinstalled("pdflatex")
    "pdflatex"
else
    ""
end

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


"""
    convert2md(path)::TextContent

Converts a file at the specified path to markdown format using the pandoc command-line tool. Returns a TextContent object containing the converted markdown text. Throws an error if pandoc is not installed or if the conversion fails.
"""
function convert2md(path)::TextContent
    if !PANDOC_INSTALLED
        throw("pandoc is not installed on this system")
    end

    media_directory = joinpath(tempdir(), "anglerfish")
    mkpath(media_directory)

    exec = ["pandoc", path, "-t", "markdown", "--extract-media", media_directory]
    try
        output = readchomp(pipeline(Cmd(exec), stderr=devnull))
        return TextContent(; type="text", text=output)
    catch error
        throw("failed to convert file to markdown with pandoc: $error")
    end
end


"""
    read_file(path)

Reads the content of a file at the specified path. The file must be within the allowed directories and of a supported type (text or image). Returns a Content object containing the file data or an error message if the file cannot be read.
"""
function read_file(path::AbstractString)::Union{TextContent,ImageContent,String}
    if !isvalidpath(path, "read")
        return "ERROR: access denied or invalid path: $path, you have only read permissions for the following directories: $(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " and "))."
    elseif !isfile(path)
        return "file not found: $path"
    end

    try
        mime = mime_from_path(path)
        if mime == MIME("text/csv")
            data = CSV.read(path, DataFrame; stripwhitespace=true, strict=true, stringtype=String)
            table_md = pretty_table(String, data; backend=:markdown, show_first_column_label_only=true)
            return TextContent(; type="text", text=table_md)
        elseif string(mime)[1:4] == "text"
            return TextContent(; type="text", text=read(path, String))
        elseif splitext(path)[2] in SUPPORTED_IMAGE_FORMATS
            data = downscale_image(path)
            return ImageContent(; type="image", data=data, mime_type=string(mime))
        elseif mime == MIME("application/pdf")
            if PDFTOTEXT_INSTALLED
                return pdftotext(path)
            else
                return "file type: $mime is not supported, because of missing dependency pdftotext. Please install poppler-utils to enable PDF text extraction."
            end
        elseif splitext(path)[2] in PANDOC_INPUT_FORMATS
            if PANDOC_INSTALLED
                return convert2md(path)
            else
                return "file type: $mime is not supported, because of missing dependency pandoc. Please install pandoc to enable conversion of various document formats to markdown."
            end
        else
            return "file type: $mime is not supported as input format"
        end
    catch err
        return "failed to read file: $err"
    end
end


function init_read_file_tool(config::Dict)
    @info "initialize read file tool"
    read_file_tool = MCPTool(
        name="read_file",
        description="reads the content of a file at the specified path. The file must be within the allowed directories ($(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " and "))).",
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


# read as image
# makes only sense after LM-Studio can process image content as model context

# write

"""
    write_file(content::String, path::String; raw=false)::String

Writes the specified content to a file at the given path. The path must be within the writable directories.
If `raw` is true, the content is written directly to the file as text. If `raw` is false (default), the content is
expected to be valid markdown and will be converted to the file type inferred from the file extension.
Returns a success message if the file is written successfully, or an error message if the operation fails.
"""
function write_file(content::String, path::String; raw=false, working_directory::Union{Nothing,String}=nothing)::String
    if !isvalidpath(path, "write")
        return "ERROR: access denied or invalid path: $path, you have only write permissions for the following directories: $(join(READ_WRITE_DIRECTORIES, ", ", " and "))."
    end

    target_file_extension = splitext(path)[2] |> lowercase

    if raw || target_file_extension in (".txt", ".md")
        try
            open(path, "w") do io
                write(io, content)
            end
            return "file written successfully to: $path"
        catch err
            return "failed to write file: $err"
        end
    elseif target_file_extension == ".pdf"
        if PANDOC_INSTALLED && !isempty(PANDOC_PDF_ENGINE)
            tempfile = tempname() * ".md"
            exec = ["pandoc", tempfile, "-o", path, "--pdf-engine=$PANDOC_PDF_ENGINE"]
            try
                open(tempfile, "w") do io
                    write(io, content)
                end
                if isnothing(working_directory)
                    run(pipeline(Cmd(exec), stderr=devnull))
                else
                    run(pipeline(Cmd(Cmd(exec); dir=working_directory), stderr=devnull))
                end
                rm(tempfile)
                return "file written successfully to: $path"
            catch err
                if isfile(tempfile)
                    rm(tempfile)
                end
                return "ERROR: failed to write file with pandoc conversion: $err"
            end
        else
            return "ERROR: can't create PDF, due to missing dependencies. Please install pandoc and a LaTeX engine (lualatex, xelatex or pdflatex)."
        end
    elseif target_file_extension in PANDOC_OUTPUT_FORMATS && PANDOC_INSTALLED
        tempfile = tempname() * ".md"
        exec = ["pandoc", tempfile, "-o", path, "--pdf-engine=lualatex"]
        try
            open(tempfile, "w") do io
                write(io, content)
            end
            if isnothing(working_directory)
                run(pipeline(Cmd(exec), stderr=devnull))
            else
                run(pipeline(Cmd(Cmd(exec); dir=working_directory), stderr=devnull))
            end
            rm(tempfile)
            return "file written successfully to: $path"
        catch err
            if isfile(tempfile)
                rm(tempfile)
            end
            return "ERROR: failed to write file with pandoc conversion: $err"
        end
    else
        return "ERROR: failed to write file: \"$(basename(path))\", unsupported output format or missing dependency pandoc for format conversion. Please install pandoc to enable conversion of markdown to various document formats."
    end
end


function init_write_file_tool(config::Dict)
    @info "initialize write file tool"
    write_file_tool = MCPTool(
        name="write_file",
        description="writes the specified content to a file at the given path. The path must be within the writable directories: $(join(READ_WRITE_DIRECTORIES, ", ", " and ")). If `raw` is true, the content is written directly to the file as text. If `raw` is false (default), the content is expected to be valid markdown and will be converted to the file type inferred from the file extension. Supported file formats are: $(join(PANDOC_OUTPUT_FORMATS, ", ", " and ")). Returns a success message if the file is written successfully, or an error message if the operation fails.",
        parameters=[
            ToolParameter(
                name = "content",
                type = "str",
                description = "the content to be written to the file. If `raw` is false, this should be valid markdown text.",
                required = true
            ),
            ToolParameter(
                name = "path",
                type = "str",
                description = "the absolute path where the file should be written",
                required = true
            ),
            ToolParameter(
                name = "raw",
                type = "bool",
                description = "if true, writes content directly as text without format conversion. If false (default), treats content as markdown and converts it to the target format based on file extension.",
                required = false
            ),
            ToolParameter(
                name = "working_directory",
                type = "str",
                description = "the working directory where the pandoc command should be executed for format conversion. This can be used to specify the location of any media files that the markdown content references.",
                required = false
            )
        ],
        handler = params -> begin
            res = write_file(params["content"], params["path"]; raw=parse_bool(get(params, "raw", false), false), working_directory=get(params, "working_directory", nothing))
            return TextContent(; type="text", text=res)
        end
    )
    TOOLS[write_file_tool.name] = write_file_tool
end

push!(INIT_FUNCTIONS, init_write_file_tool)

