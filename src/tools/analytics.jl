
const GNUPLOT_INSTALLED = isinstalled("gnuplot")

# describe table

"""
    describe_table(path)::TextContent

Describes a CSV table at the specified path. Returns a summary of the table including the number of rows and columns, as well as basic statistics for each column (such as data type, minimum, mean, maximum, and number of missing values). If the file cannot be read or is not a valid CSV file, an error message is returned instead.
"""
function describe_table(path)::TextContent
    if !isvalidpath(path, "read")
        return TextContent(; type="text", text="ERROR: invalid path or insufficient permissions to read file at $path")
    elseif !isfile(path)
        return TextContent(; type="text", text="ERROR: path $path is not a file")
    elseif !endswith(lowercase(path), ".csv")
        return TextContent(; type="text", text="ERROR: file type not supported for description. Only CSV files are supported.")
    end

    try
        data = CSV.read(path, DataFrame; stripwhitespace=true, strict=true, stringtype=String)
        n_rows, n_cols = size(data)
        
        stats = @chain describe(data) begin
            @select(:variable, :min, :mean, :max, :nmissing)
            @rename(:Column = :variable, :Min = :min, :Mean = :mean, :Max = :max, :"Missing Values" = :nmissing)
        end
        
        description = "Table has $n_rows rows (without header) and $n_cols columns.\n\n**Summary**\n" * pretty_table(String, stats; backend=:markdown, show_first_column_label_only=true)

        return TextContent(; type="text", text=description)
    catch error
        return TextContent(; type="text", text="failed to describe table: $error")
    end    
end


function init_describe_table_tool(config::Dict)
    describe_table_tool = MCPTool(
        name="describe_table",
        description="describes a CSV table at the specified path. Returns a summary of the table including the number of rows and columns, as well as basic statistics for each column (such as data type, minimum, mean, maximum, and number of missing values). Use this tool to get an overview of the structure and contents of a CSV, without having to read the entire file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file to be described",
                required = true
            )
        ],
        handler = params -> describe_table(params["path"])
    )

    TOOLS[describe_table_tool.name] = describe_table_tool
end

push!(INIT_FUNCTIONS, init_describe_table_tool)

# execute_sql

"""
    execute_sql(source_path::String, query::String, sink_path::Union{Nothing,String}=nothing, persist_changes=false)::TextContent

Executes an SQL query on a CSV table at the specified path.

Arguments:
- `source_path::String`: the path to the CSV file to be queried. The file must be a valid CSV file and the path must be accessible with read permissions.
- `query::String`: the SQL query to execute on the CSV data. The table name that corresponds to the CSV file name (without file extension, e.g. "finance" when querying a file named "finance.csv"). All SQLite compatible SQL syntax is supported.
- `sink_path::Union{Nothing,String}`: optional path where the result of the SQL query should be stored as a CSV file. If not provided, the result will be returned as markdown-formatted table text content. If provided, the path must be accessible with write permissions and must have a .csv file extension.
- `persist_changes::Bool`: if true, any changes made to the data (e.g. through UPDATE or DELETE statements) will be persisted back to the original CSV file. Use with caution, as this can modify the original data.

Returns:
- `TextContent`: if `sink_path` is not provided, returns the result of the SQL query as markdown-formatted table text content. If `sink_path` is provided, returns a success message if the query executed successfully and the result was written to the specified path, or an error message if the operation failed.
"""
function execute_sql(source_path::String, query::String, sink_path::Union{Nothing,String}=nothing, persist_changes=false)::TextContent
    local db

    if !persist_changes && !isvalidpath(source_path, "read")
        return TextContent(; type="text", text="ERROR: access denied or invalid path: $path, you have only read permissions for the following directories: $(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " and ")).")
    elseif persist_changes && !isvalidpath(source_path, "write")
        return TextContent(; type="text", text="ERROR: access denied or invalid path: $path, you have only write permissions for the following directories: $(join(READ_WRITE_DIRECTORIES, ", ", " and ")).")
    elseif !isfile(source_path)
        return TextContent(; type="text", text="ERROR: $source_path is not a file")
    elseif !endswith(lowercase(source_path), ".csv")
        return TextContent(; type="text", text="ERROR: file type not supported for SQL querying. Only CSV files are supported.")
    end

    if !isnothing(sink_path)
        if splitext(sink_path)[2] != ".csv"
            return TextContent(; type="text", text="ERROR: file type not supported for SQL query result output. Only CSV files are supported.")
        elseif !isvalidpath(sink_path, "write")
            return TextContent(; type="text", text="ERROR: access denied or invalid path: $sink_path, you have only write permissions for the following directories: $(join(READ_WRITE_DIRECTORIES, ", ", " and ")).")
        end        
    end

    try
        data = CSV.read(source_path, DataFrame; stripwhitespace=true, strict=true, stringtype=String)
        db = SQLite.DB()
        SQLite.load!(data, db, basename(source_path) |> splitext |> first)
        result = DBInterface.execute(db, query) |> DataFrame
        if persist_changes
            # persist changes back to original CSV file
            updated_data = DBInterface.execute(db, "SELECT * FROM $(basename(source_path) |> splitext |> first)") |> DataFrame
            CSV.write(source_path, updated_data)
        end

        if  !isempty(result) && isnothing(sink_path)
            result_md = pretty_table(String, result; backend=:markdown, show_first_column_label_only=true)
            return TextContent(; type="text", text=result_md)
        elseif isempty(result) && isnothing(sink_path)
            return TextContent(; type="text", text="SQL query executed successfully, no results to display.")
        elseif isempty(result) && !isnothing(sink_path)
            return TextContent(; type="text", text="SQL query executed successfully, no results to write to $sink_path.")
        else
            CSV.write(sink_path, result)
            return TextContent(; type="text", text="SQL query executed successfully, result written to $sink_path.")
        end        
    catch error
        return TextContent(; type="text", text="failed to execute SQL query: $error")
    finally
        SQLite.close(db)
    end
end


function init_execute_sql_tool(config::Dict)
    execute_sql_tool = MCPTool(
        name="execute_sql",
        description="executes an SQL query on a CSV table at the specified path. The result of the query is returned as markdown-formatted table text content, or stored as CSV file if a sink path is provided.",
        parameters=[
            ToolParameter(
                name = "source_path",
                type = "str",
                description = "the path to the CSV file to be queried",
                required = true
            ),
            ToolParameter(
                name = "query",
                type = "str",
                description = "the SQL query to execute on the CSV data. The table name that corresponds to the CSV file name (without file extension, e.g. \"finance\" when querying a file named \"finance.csv\"). All SQLite compatible SQL syntax is supported.",
                required = true
            ),
            ToolParameter(
                name = "sink_path",
                type = "str",
                description = "path where the result of the SQL query should be stored as a CSV file. If not provided, the result will be returned as markdown-formatted table text content.",
                required = false
            ),
            ToolParameter(
                name = "persist_changes",
                type = "bool",
                description = "if true, any changes made to the data (e.g. through UPDATE or DELETE statements) will be persisted back to the original CSV file. Use with caution, as this can modify the original data. Write permissions wo the source path are required to enable this option.",
                required = false
            )
        ],
        handler = params -> execute_sql(params["source_path"], params["query"], get(params, "sink_path", nothing), parse_bool(get(params, "persist_changes", false), false))
    )

    TOOLS[execute_sql_tool.name] = execute_sql_tool
end


push!(INIT_FUNCTIONS, init_execute_sql_tool)


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