
const GNUPLOT_INSTALLED = isinstalled("gnuplot")

# describe table

function describe_table(path)::TextContent
    try
        data = CSV.read(path, DataFrame; stripwhitespace=true, strict=true, stringtype=String)
        n_rows, n_cols = size(data)
        column_names = names(data)
        column_types = eltype.(eachcol(data))
        description = "The table has $n_rows rows and $n_cols columns.\n"
        description *= "Column names and types:\n"
        for (name, type) in zip(column_names, column_types)
            description *= "- $name: $type\n"
        end
        return TextContent(; type="text", text=description)
    catch
    end
    
end

# sql query

# plotting

"""
    gnuplot()

Generates a plot using gnuplot based on the provided script. The script should be a valid gnuplot script that defines the plot to be generated.
"""
function gnuplot(script::String, working_directory::String)::TextContent
    if !GNUPLOT_INSTALLED
        return TextContent(; type="text", text="gnuplot is not installed on this system")
    end
    
    # create temporary script file
    script_path = joinpath(tempdir(), "plot_script.gp")
    open(script_path, "w") do io
        write(io, script)
    end

    # execute gnuplot command
    exec = ["gnuplot", script_path]
    try
        stdout_buf = IOBuffer()
        stderr_buf = IOBuffer()
        run(pipeline(Cmd(Cmd(exec); ignorestatus=true, dir=working_directory); stdout=stdout_buf, stderr=stderr_buf))
        out = chomp(String(take!(stdout_buf)) * String(take!(stderr_buf)))
        if isempty(out)
            return TextContent(; type="text", text="gnuplot executed successfully")
        else
            return TextContent(; type="text", text="error: $out")
        end
    catch error
        return TextContent(; type="text", text="failed to generate plot with gnuplot: $error")
    finally
        # clean up temporary script file
        rm(script_path, force=true)
    end
end


function init_plotting_tool(config::Dict)
    if !GNUPLOT_INSTALLED
        return nothing
    else
        @info "initialize plotting tool"
    end

    plotting_tool = MCPTool(
        name="gnuplot",
        description="generates a plot using gnuplot. The script has to be a valid gnuplot script that defines the plot to be generated. Returns a success message if the plot is generated successfully, or an error message if the operation fails.",
        parameters=[
            ToolParameter(
                name = "script",
                type = "str",
                description = "the gnuplot script that defines the plot to be generated. This has to be a valid gnuplot script.",
                required = true
            ),
            ToolParameter(
                name = "working_directory",
                type = "str",
                description = "the working directory where the gnuplot command should be executed. This can be used to specify the location of any data files that the gnuplot script references.",
                required = true
            )
        ],
        handler = params -> gnuplot(params["script"], params["working_directory"])
    )

    TOOLS[plotting_tool.name] = plotting_tool
end

push!(INIT_FUNCTIONS, init_plotting_tool)