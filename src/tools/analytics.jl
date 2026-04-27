
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
    label_rotation(labels::Vector{String})::Float64

Determines the appropriate label rotation angle for x-axis tick labels based on the number of columns and the maximum length of the column names. If there are fewer than 5 columns and the maximum column name length is less than 15 characters, no rotation is applied (0 degrees). Otherwise, a rotation of 30 degrees (pi/6 radians) is applied to improve readability and prevent overlap of long labels.
"""
function label_rotation(labels::Vector{String})::Float64
    if length(labels) < 5 && maximum(length.(labels)) < 15
        return 0.0
    else
        return pi / 6        
    end
end

const SUPPORTED_PLOT_OUTPUT_FORMATS = [".png", ".svg"]


"""
    validate_plot_request(path::String, output_path::Union{Nothing,String}=nothing)::Union{Nothing,TextContent}

Validates the input parameters for a plot generation request. The function checks if the specified input file path is
valid, accessible with read permissions, and points to a CSV file. If an output path is provided, it also checks if the
path is valid, accessible with write permissions, and has a supported image file extension (e.g. .png or .svg). If any
of the checks fail, a TextContent object containing an appropriate error message is returned. If all checks pass, the
function returns `nothing`, indicating that the request is valid and can proceed with plot generation.
"""
function validate_plot_request(path::String, output_path::Union{Nothing,String}=nothing)::Union{Nothing,TextContent}
    if !isvalidpath(path, "read")
        return TextContent(; type="text", text="ERROR: access denied or invalid path: $path, you have only read permissions for the following directories: $(join(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES), ", ", " and ")).")
    elseif !isfile(path)
        return TextContent(; type="text", text="ERROR: $path is not a file")
    elseif !endswith(lowercase(path), ".csv")
        return TextContent(; type="text", text="ERROR: file type not supported for plotting. Only CSV files are supported.")
    elseif !isnothing(output_path) && !isvalidpath(output_path, "write")
        return TextContent(; type="text", text="ERROR: access denied or invalid path: $output_path, you have only write permissions for the following directories: $(join(READ_WRITE_DIRECTORIES, ", ", " and ")).")
    elseif !isnothing(output_path) && !(splitext(output_path)[2] in SUPPORTED_PLOT_OUTPUT_FORMATS)
        return TextContent(; type="text", text="ERROR: file type not supported for plot output. Supported image formats are: .png and .svg.")
    end

    return nothing
end


"""
    load_plot_table(path::String)::DataFrame

Loads a CSV file from the specified path into a DataFrame for plotting. The function reads the CSV file using the CSV.jl
package, with options to strip whitespace from string fields, enforce strict parsing to catch any formatting issues,
and treat all string fields as String type to prevent automatic type inference that could lead to unexpected data types.
If the file cannot be read or is not a valid CSV file, an error will be thrown.
"""
function load_plot_table(path::String)::DataFrame
    return CSV.read(path, DataFrame; stripwhitespace=true, strict=true, stringtype=String)
end


"""
    coerce_numeric_values(values)

Coerces a vector of values to Float64 where possible. For each value in the input vector, the function checks if it is
missing, a real number, or a string that can be parsed as a float. If the value is missing or cannot be coerced to a
float, it is returned as `missing`. Otherwise, the coerced float value is returned. The result is a new vector of the
same length with values converted to Float64 where possible and `missing` for non-coercible values.
"""
function coerce_numeric_values(values)
    return map(values) do value
        if ismissing(value)
            missing
        elseif value isa Real
            Float64(value)
        elseif value isa AbstractString
            tryparse(Float64, value)
        else
            missing
        end
    end
end

"""
    coerce_numeric_columns!(data::DataFrame, columns::Vector{String})

Coerces the specified columns of a DataFrame to numeric values in-place. For each column name in the `columns` vector,
the function applies the `coerce_numeric_values` function to the corresponding column in the DataFrame, replacing the
original values with their coerced numeric versions. This allows for consistent numeric data types in the specified
columns, which is important for accurate plotting and analysis. The function modifies the input DataFrame directly
and does not return a value.
"""
function coerce_numeric_columns!(data::DataFrame, columns::Vector{String})
    for column in unique(columns)
        data[!, column] = coerce_numeric_values(data[!, column])
    end
end


"""
    collect_numeric_values(values)::Vector{Float64}

Collects numeric values from a vector, filtering out any missing or non-numeric entries. The function iterates through
the input `values` vector and checks each value to determine if it is not missing and not nothing. If a value passes
this check, it is converted to a Float64 and included in the resulting vector. The output is a new vector containing
only the valid numeric values as Float64, which can be used for plotting or further analysis.
"""
function collect_numeric_values(values)::Vector{Float64}
    return [Float64(value) for value in values if !ismissing(value) && !isnothing(value)]
end


"""
    resolve_plot_palette(colors::Vector{String}, series_count::Int)

Resolves a color palette for plotting based on the provided vector of color names and the number of series to be
plotted. If the `colors` vector is empty or its length does not match the `series_count`, a default color palette is
generated using the `Makie.wong_colors()` function, which provides a set of visually distinct colors.
"""
function resolve_plot_palette(colors::Vector{String}, series_count::Int)
    if series_count <= 0
        return Any[]
    elseif isempty(colors) || length(colors) != series_count
        base_palette = Makie.wong_colors()
        return [base_palette[mod1(index, length(base_palette))] for index in 1:series_count]
    else
        return [getcolor(color) for color in colors]
    end
end

"""
    resolve_heatmap_colormap(colors::Vector{String})

Resolves a colormap for heatmap plots based on the provided vector of color names. If the input vector is empty, the
function returns the default :viridis colormap. If specific color names are provided, it constructs a custom colormap
using those colors. The function uses the `getcolor` function to convert color names to their corresponding color values
and creates a gradient colormap with `Makie.cgrad`. This allows for flexible customization of heatmap colors while
providing a sensible default when no colors are specified.
"""
function resolve_heatmap_colormap(colors::Vector{String})
    if isempty(colors)
        return :viridis
    end

    return Makie.cgrad([getcolor(color) for color in colors])
end


"""
    save_plot_content(fig::Figure, output_path::Union{Nothing,String}=nothing)::Content

Saves a Makie figure to an image file or returns it as base64-encoded image content. If `output_path` is provided,
the figure is saved to the specified path and a success message is returned. If `output_path` is not provided, the
figure is saved to a temporary PNG file, downscaled for efficient encoding, and returned as an ImageContent object
with the image data encoded in base64 format. The function ensures that any temporary files created during the
process are removed after use to prevent clutter and manage resources effectively.
"""
function save_plot_content(fig::Figure, output_path::Union{Nothing,String}=nothing)::Content
    tempfile = nothing

    try
        if isnothing(output_path)
            tempfile = tempname() * ".png"
            save(tempfile, fig)
            data = downscale_image(tempfile)
            return ImageContent(; type="image", data=data, mime_type="image/png")
        else
            save(output_path, fig)
            return TextContent(; type="text", text="plot generated successfully and saved to $output_path")
        end
    finally
        if !isnothing(tempfile) && isfile(tempfile)
            rm(tempfile, force=true)
        end
    end
end


"""
    parse_optional_int(input)::Union{Nothing,Int}

Parses an optional integer value from the input. If the input is `nothing`, the function returns `nothing`. If the input
is an integer, it is returned as an `Int`. If the input is a string, the function attempts to parse it as an integer; if
parsing fails, it returns 0. For any other input types, the function also returns 0. This utility function allows for
flexible handling of optional integer parameters that may be provided in different formats.
"""
function parse_optional_int(input)::Union{Nothing,Int}
    if isnothing(input)
        return nothing
    elseif input isa Integer
        return Int(input)
    elseif input isa AbstractString
        parsed = tryparse(Int, input)
        return isnothing(parsed) ? 0 : parsed
    else
        return 0
    end
end


"""
    plot_bar(path::String, xcolumn::String, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, with_legend::Bool=true, stacked::Bool=false)::Content

Generates a bar plot from a CSV file at the specified path.

Arguments:
- `path::String`: the path to the CSV file containing the data to be plotted. The file must be a valid CSV file and the path must be accessible with read permissions.
- `xcolumn::String`: the name of the column in the CSV file to be used for the x-axis of the plot.
- `ycolumns::Vector{String}`: a vector of column names in the CSV file to be used for the y-axis of the plot. Multiple columns can be specified to create a grouped or stacked bar plot.
- `output_path::Union{Nothing,String}`: optional path where the generated plot should be saved as an image file (e.g. PNG). If not provided, the plot will be returned as a base64-encoded string in an ImageContent object. If provided, the path must be accessible with write permissions and must have a valid image file extension (e.g. .png, .jpg, .svg).
- `title::Union{Nothing,String}`: optional title for the plot. If not provided, no title will be displayed.
- `x_axis_label::Union{Nothing,String}`: optional label for the x-axis. Defaults to the selected x-column name.
- `y_axis_label::Union{Nothing,String}`: optional label for the y-axis. Defaults to the selected y-column name for single-series plots and no label for multi-series plots.
- `colors::Vector{String}`: optional vector of color names. If not provided, a default color palette will be used. Supported color names are: "blue", "orange", "green", "purple", "lightblue", "red", and "yellow".
- `with_legend::Bool`: whether to include a legend in the plot when multiple y-columns are specified. Default is true.
- `stacked::Bool`: whether to create a stacked bar plot when multiple y-columns are specified. Default is false (grouped bar plot).
"""
function plot_bar(path::String, xcolumn::String, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true, stacked::Bool=false)::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    end

    try
        data = load_plot_table(path)
        if !(xcolumn in names(data))
            return TextContent(; type="text", text="ERROR: x-column '$xcolumn' not found in CSV file.")
        elseif isempty(ycolumns)
            return TextContent(; type="text", text="ERROR: at least one y-column must be provided.")
        elseif !all(ycol -> ycol in names(data), ycolumns)
            return TextContent(; type="text", text="ERROR: one or more y-columns not found in CSV file.")
        end

        coerce_numeric_columns!(data, ycolumns)

        # create plot
        xlabels = string.(data[!, xcolumn])
        positions = Int[]
        heights = Float64[]
        groups = Int[]
        group_labels = String[]

        for (group_index, ycol) in enumerate(ycolumns)
            push!(group_labels, ycol)
            for (row_index, value) in enumerate(data[!, ycol])
                if !ismissing(value) && !isnothing(value)
                    push!(positions, row_index)
                    push!(heights, value)
                    push!(groups, group_index)
                end
            end
        end

        if isempty(heights)
            return TextContent(; type="text", text="ERROR: no numeric values found in the selected y-columns.")
        end

        fig = Figure(size=(1440, 900))
        axis = Axis(
            fig[1, 1];
            xticks=(collect(1:length(xlabels)), xlabels),
            xticklabelrotation=label_rotation(xlabels),
            xlabel=isnothing(x_axis_label) ? "" : x_axis_label,
            ylabel=isnothing(y_axis_label) ? "" : y_axis_label,
            title=isnothing(title) ? "" : title
        )

        palette = resolve_plot_palette(colors, length(ycolumns))
        bar_colors = length(ycolumns) == 1 ? palette[1] : [palette[group] for group in groups]

        plot = if length(ycolumns) == 1
            barplot!(axis, positions, heights; color=bar_colors, strokecolor=:black, strokewidth=1)
        elseif stacked
            barplot!(axis, positions, heights; stack=groups, color=bar_colors, strokecolor=:black, strokewidth=1)
        else
            barplot!(axis, positions, heights; dodge=groups, color=bar_colors, strokecolor=:black, strokewidth=1, n_dodge=length(ycolumns))
        end

        # add legend if multiple y-columns and with_legend is true
        if with_legend && length(ycolumns) > 1
            legend_elements = [PolyElement(polycolor=palette[index], strokecolor=:black, strokewidth=1) for index in eachindex(group_labels)]
            Legend(fig[1, 2], legend_elements, group_labels)
        end

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end

end


function init_plot_bar_tool(config::Dict)
    plot_bar_tool = MCPTool(
        name="plot_bar",
        description="generates a bar plot based on the data of a CSV table. Supports single-series, grouped, and stacked bar charts and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "xcolumn",
                type = "str",
                description = "the column to use for x-axis categories",
                required = true
            ),
            ToolParameter(
                name = "ycolumns",
                type = "array",
                description = "one or more numeric columns to plot as bar heights",
                required = true
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "x_axis_label",
                type = "str",
                description = "optional label for the x-axis",
                required = false
            ),
            ToolParameter(
                name = "y_axis_label",
                type = "str",
                description = "optional label for the y-axis",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names for the bars. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\". If not provided, a default color palette will be used.",
                required = false
            ),
            ToolParameter(
                name = "with_legend",
                type = "bool",
                description = "whether to include a legend when plotting multiple y-columns",
                required = false
            ),
            ToolParameter(
                name = "stacked",
                type = "bool",
                description = "whether multiple y-columns should be stacked instead of grouped",
                required = false
            )
        ],
        handler = params -> plot_bar(
            params["path"],
            params["xcolumn"],
            String.(params["ycolumns"]);
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            x_axis_label=get(params, "x_axis_label", nothing),
            y_axis_label=get(params, "y_axis_label", nothing),
            colors=get(params, "colors", String[]),
            with_legend=parse_bool(get(params, "with_legend", true), true),
            stacked=parse_bool(get(params, "stacked", false), false)
        )
    )

    TOOLS[plot_bar_tool.name] = plot_bar_tool
end

push!(INIT_FUNCTIONS, init_plot_bar_tool)


"""
    plot_line(path::String, xcolumn::String, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content

Generates a line plot from a CSV file at the specified path.

Arguments:
- `path::String`: the path to the CSV file containing the data to be plotted. The file must be a valid CSV file and the path must be accessible with read permissions.
- `xcolumn::String`: the name of the column in the CSV file to be used for the x-axis of the plot.
- `ycolumns::Vector{String}`: a vector of column names in the CSV file to be used for the y-axis of the plot. Multiple columns can be specified to create a multi-series line plot.
- `output_path::Union{Nothing,String}`: optional path where the generated plot should be saved as an image file (e.g. PNG). If not provided, the plot will be returned as a base64-encoded string in an ImageContent object. If provided, the path must be accessible with write permissions and must have a valid image file extension (e.g. .png or .svg).
- `title::Union{Nothing,String}`: optional title for the plot. If not provided, no title will be displayed.
- `x_axis_label::Union{Nothing,String}`: optional label for the x-axis. Defaults to the selected x-column name.
- `y_axis_label::Union{Nothing,String}`: optional label for the y-axis. Defaults to the selected y-column name for single-series plots and no label for multi-series plots.
- `colors::Vector{String}`: optional vector of color names. If not provided, a default color palette will be used. Supported color names are: "blue", "orange", "green", "purple", "lightblue", "red", and "yellow".
- `with_legend::Bool`: whether to include a legend in the plot when multiple y-columns are specified. Default is true.
"""
function plot_line(path::String, xcolumn::String, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    end

    try
        data = load_plot_table(path)
        if !(xcolumn in names(data))
            return TextContent(; type="text", text="ERROR: x-column '$xcolumn' not found in CSV file.")
        elseif isempty(ycolumns)
            return TextContent(; type="text", text="ERROR: at least one y-column must be provided.")
        elseif !all(ycol -> ycol in names(data), ycolumns)
            return TextContent(; type="text", text="ERROR: one or more y-columns not found in CSV file.")
        end

        coerce_numeric_columns!(data, ycolumns)

        parsed_xvalues = coerce_numeric_values(data[!, xcolumn])
        xlabels = string.(data[!, xcolumn])
        use_numeric_x = all(value -> !ismissing(value) && !isnothing(value), parsed_xvalues)
        xvalues = use_numeric_x ? Float64.(parsed_xvalues) : collect(1:nrow(data))

        palette = resolve_plot_palette(colors, length(ycolumns))

        fig = Figure(size=(1440, 900))
        axis = Axis(
            fig[1, 1];
            xlabel=isnothing(x_axis_label) ? "" : x_axis_label,
            ylabel=isnothing(y_axis_label) ? "" : y_axis_label,
            title=isnothing(title) ? "" : title
        )

        if !use_numeric_x
            axis.xticks = (collect(1:length(xlabels)), xlabels)
            axis.xticklabelrotation = label_rotation(xlabels)
        end

        plotted_any_series = false
        for (index, ycol) in enumerate(ycolumns)
            points_x = Float64[]
            points_y = Float64[]
            for row_index in eachindex(data[!, ycol])
                yvalue = data[row_index, ycol]
                if !ismissing(yvalue) && !isnothing(yvalue)
                    push!(points_x, use_numeric_x ? xvalues[row_index] : Float64(row_index))
                    push!(points_y, yvalue)
                end
            end

            if !isempty(points_y)
                lines!(axis, points_x, points_y; color=palette[index], linewidth=3, label=ycol)
                scatter!(axis, points_x, points_y; color=palette[index], markersize=10)
                plotted_any_series = true
            end
        end

        if !plotted_any_series
            return TextContent(; type="text", text="ERROR: no numeric values found in the selected y-columns.")
        end

        if with_legend && length(ycolumns) > 1
            legend_elements = [LineElement(color=palette[index], linewidth=3) for index in eachindex(ycolumns)]
            Legend(fig[1, 2], legend_elements, ycolumns)
        end

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end
end


function init_plot_line_tool(config::Dict)
    plot_line_tool = MCPTool(
        name="plot_line",
        description="generates a line plot based on the data of a CSV table. Supports single-series and multi-series line charts and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "xcolumn",
                type = "str",
                description = "the column to use for x-axis values or categories",
                required = true
            ),
            ToolParameter(
                name = "ycolumns",
                type = "array",
                description = "one or more numeric columns to plot as line series",
                required = true
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "x_axis_label",
                type = "str",
                description = "optional label for the x-axis",
                required = false
            ),
            ToolParameter(
                name = "y_axis_label",
                type = "str",
                description = "optional label for the y-axis",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names for the line series. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\". If not provided, a default color palette will be used.",
                required = false
            ),
            ToolParameter(
                name = "with_legend",
                type = "bool",
                description = "whether to include a legend when plotting multiple y-columns",
                required = false
            )
        ],
        handler = params -> plot_line(
            params["path"],
            params["xcolumn"],
            String.(params["ycolumns"]);
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            x_axis_label=get(params, "x_axis_label", nothing),
            y_axis_label=get(params, "y_axis_label", nothing),
            colors=get(params, "colors", String[]),
            with_legend=parse_bool(get(params, "with_legend", true), true)
        )
    )

    TOOLS[plot_line_tool.name] = plot_line_tool
end

push!(INIT_FUNCTIONS, init_plot_line_tool)


"""
    plot_box(path::String, xcolumn::String, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content

Generates a box plot from a CSV file at the specified path.

Arguments:
- `path::String`: the path to the CSV file containing the data to be plotted. The file must be a valid CSV file and the path must be accessible with read permissions.
- `xcolumn::String`: the name of the column in the CSV file to be used for grouping the box plots on the x-axis.
- `ycolumns::Vector{String}`: a vector of numeric column names in the CSV file to be plotted as box plot distributions. Multiple columns can be specified to create grouped box plots.
- `output_path::Union{Nothing,String}`: optional path where the generated plot should be saved as an image file (e.g. PNG). If not provided, the plot will be returned as a base64-encoded string in an ImageContent object. If provided, the path must be accessible with write permissions and must have a valid image file extension (e.g. .png or .svg).
- `title::Union{Nothing,String}`: optional title for the plot. If not provided, no title will be displayed.
- `x_axis_label::Union{Nothing,String}`: optional label for the x-axis. Defaults to the selected x-column name.
- `y_axis_label::Union{Nothing,String}`: optional label for the y-axis. Defaults to the selected y-column name for single-series plots and no label for multi-series plots.
- `colors::Vector{String}`: optional vector of color names. If not provided, a default color palette will be used. Supported color names are: "blue", "orange", "green", "purple", "lightblue", "red", and "yellow".
- `with_legend::Bool`: whether to include a legend in the plot when multiple y-columns are specified. Default is true.
"""
function plot_box(path::String, xcolumn::String, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    end

    try
        data = load_plot_table(path)
        if !(xcolumn in names(data))
            return TextContent(; type="text", text="ERROR: x-column '$xcolumn' not found in CSV file.")
        elseif isempty(ycolumns)
            return TextContent(; type="text", text="ERROR: at least one y-column must be provided.")
        elseif !all(ycol -> ycol in names(data), ycolumns)
            return TextContent(; type="text", text="ERROR: one or more y-columns not found in CSV file.")
        end

        coerce_numeric_columns!(data, ycolumns)

        xlabels = string.(data[!, xcolumn])
        unique_xlabels = unique(xlabels)
        xlookup = Dict(label => Float64(index) for (index, label) in enumerate(unique_xlabels))

        palette = resolve_plot_palette(colors, length(ycolumns))

        positions = Float64[]
        values = Float64[]
        groups = Int[]

        for (group_index, ycol) in enumerate(ycolumns)
            for row_index in 1:nrow(data)
                yvalue = data[row_index, ycol]
                xlabel = xlabels[row_index]
                if !ismissing(yvalue) && !isnothing(yvalue) && haskey(xlookup, xlabel)
                    push!(positions, xlookup[xlabel])
                    push!(values, yvalue)
                    push!(groups, group_index)
                end
            end
        end

        if isempty(values)
            return TextContent(; type="text", text="ERROR: no numeric values found in the selected y-columns.")
        end

        fig = Figure(size=(1440, 900))
        axis = Axis(
            fig[1, 1];
            xticks=(collect(1:length(unique_xlabels)), unique_xlabels),
            xticklabelrotation=label_rotation(unique_xlabels),
            xlabel=isnothing(x_axis_label) ? "" : x_axis_label,
            ylabel=isnothing(y_axis_label) ? "" : y_axis_label,
            title=isnothing(title) ? "" : title
        )

        if length(ycolumns) == 1
            boxplot!(axis, positions, values; color=palette[1])
        else
            box_colors = [palette[group] for group in groups]
            boxplot!(axis, positions, values; dodge=groups, n_dodge=length(ycolumns), color=box_colors)
        end

        if with_legend && length(ycolumns) > 1
            legend_elements = [PolyElement(polycolor=palette[index]) for index in eachindex(ycolumns)]
            Legend(fig[1, 2], legend_elements, ycolumns)
        end

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end
end


function init_plot_box_tool(config::Dict)
    plot_box_tool = MCPTool(
        name="plot_box",
        description="generates a box plot based on the data of a CSV table. Supports single-series and grouped multi-series box plots and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "xcolumn",
                type = "str",
                description = "the column to use for grouping categories on the x-axis",
                required = true
            ),
            ToolParameter(
                name = "ycolumns",
                type = "array",
                description = "one or more numeric columns to plot as box plot distributions",
                required = true
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "x_axis_label",
                type = "str",
                description = "optional label for the x-axis",
                required = false
            ),
            ToolParameter(
                name = "y_axis_label",
                type = "str",
                description = "optional label for the y-axis",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names for the box plot series. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\". If not provided, a default color palette will be used.",
                required = false
            ),
            ToolParameter(
                name = "with_legend",
                type = "bool",
                description = "whether to include a legend when plotting multiple y-columns",
                required = false
            )
        ],
        handler = params -> plot_box(
            params["path"],
            params["xcolumn"],
            String.(params["ycolumns"]);
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            x_axis_label=get(params, "x_axis_label", nothing),
            y_axis_label=get(params, "y_axis_label", nothing),
            colors=get(params, "colors", String[]),
            with_legend=parse_bool(get(params, "with_legend", true), true)
        )
    )

    TOOLS[plot_box_tool.name] = plot_box_tool
end

push!(INIT_FUNCTIONS, init_plot_box_tool)


"""
    plot_scatter(path::String, xcolumns::Vector{String}, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content

Generates a scatter plot from a CSV file at the specified path.
"""
function plot_scatter(path::String, xcolumns::Vector{String}, ycolumns::Vector{String}; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    elseif isempty(xcolumns) || isempty(ycolumns)
        return TextContent(; type="text", text="ERROR: at least one x/y-column pair must be provided.")
    elseif length(xcolumns) != length(ycolumns)
        return TextContent(; type="text", text="ERROR: xcolumns and ycolumns must have the same number of entries.")
    end

    try
        data = load_plot_table(path)
        selected_columns = unique(vcat(xcolumns, ycolumns))
        if !all(column -> column in names(data), selected_columns)
            return TextContent(; type="text", text="ERROR: one or more x/y-columns not found in CSV file.")
        end

        coerce_numeric_columns!(data, selected_columns)
        palette = resolve_plot_palette(colors, length(xcolumns))

        fig = Figure(size=(1440, 900))
        axis = Axis(
            fig[1, 1];
            xlabel=isnothing(x_axis_label) ? "" : x_axis_label,
            ylabel=isnothing(y_axis_label) ? "" : y_axis_label,
            title=isnothing(title) ? "" : title
        )

        plotted_series = Any[]
        series_labels = String[]

        for (index, (xcolumn_name, ycolumn_name)) in enumerate(zip(xcolumns, ycolumns))
            points_x = Float64[]
            points_y = Float64[]

            for row_index in 1:nrow(data)
                xvalue = data[row_index, xcolumn_name]
                yvalue = data[row_index, ycolumn_name]
                if !ismissing(xvalue) && !isnothing(xvalue) && !ismissing(yvalue) && !isnothing(yvalue)
                    push!(points_x, Float64(xvalue))
                    push!(points_y, Float64(yvalue))
                end
            end

            if !isempty(points_x)
                series_label = ycolumn_name == xcolumn_name ? ycolumn_name : "$ycolumn_name vs $xcolumn_name"
                push!(plotted_series, scatter!(axis, points_x, points_y; color=palette[index], markersize=14, label=series_label))
                push!(series_labels, series_label)
            end
        end

        if isempty(plotted_series)
            return TextContent(; type="text", text="ERROR: no numeric x/y pairs found in the selected columns.")
        end

        if with_legend && length(plotted_series) > 1
            Legend(fig[1, 2], plotted_series, series_labels)
        end

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end
end


function init_plot_scatter_tool(config::Dict)
    plot_scatter_tool = MCPTool(
        name="plot_scatter",
        description="generates a scatter plot based on parallel x-column and y-column series from a CSV table and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "xcolumns",
                type = "array",
                description = "one or more numeric columns to use as x-values; each entry pairs with the y-column at the same index",
                required = true
            ),
            ToolParameter(
                name = "ycolumns",
                type = "array",
                description = "one or more numeric columns to use as y-values; each entry pairs with the x-column at the same index",
                required = true
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "x_axis_label",
                type = "str",
                description = "optional label for the x-axis",
                required = false
            ),
            ToolParameter(
                name = "y_axis_label",
                type = "str",
                description = "optional label for the y-axis",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names for the scatter series. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\". If not provided, a default color palette will be used.",
                required = false
            ),
            ToolParameter(
                name = "with_legend",
                type = "bool",
                description = "whether to include a legend when plotting multiple series",
                required = false
            )
        ],
        handler = params -> plot_scatter(
            params["path"],
            String.(params["xcolumns"]),
            String.(params["ycolumns"]);
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            x_axis_label=get(params, "x_axis_label", nothing),
            y_axis_label=get(params, "y_axis_label", nothing),
            colors=get(params, "colors", String[]),
            with_legend=parse_bool(get(params, "with_legend", true), true)
        )
    )

    TOOLS[plot_scatter_tool.name] = plot_scatter_tool
end

push!(INIT_FUNCTIONS, init_plot_scatter_tool)


"""
    plot_hist(path::String, column::String; bins::Union{Nothing,Int}=nothing, output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[])::Content

Generates a histogram from a CSV file at the specified path.
"""
function plot_hist(path::String, column::String; bins::Union{Nothing,Int}=nothing, output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[])::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    elseif !isnothing(bins) && bins <= 0
        return TextContent(; type="text", text="ERROR: bins must be a positive integer.")
    end

    try
        data = load_plot_table(path)
        if !(column in names(data))
            return TextContent(; type="text", text="ERROR: column '$column' not found in CSV file.")
        end

        data[!, column] = coerce_numeric_values(data[!, column])
        values = collect_numeric_values(data[!, column])
        if isempty(values)
            return TextContent(; type="text", text="ERROR: no numeric values found in the selected column.")
        end

        palette = resolve_plot_palette(colors, 1)
        fig = Figure(size=(1440, 900))
        axis = Axis(
            fig[1, 1];
            xlabel=isnothing(x_axis_label) ? "" : x_axis_label,
            ylabel=isnothing(y_axis_label) ? "" : y_axis_label,
            title=isnothing(title) ? "" : title
        )

        if isnothing(bins)
            hist!(axis, values; color=palette[1], strokecolor=:black, strokewidth=1)
        else
            hist!(axis, values; bins=bins, color=palette[1], strokecolor=:black, strokewidth=1)
        end

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end
end


function init_plot_hist_tool(config::Dict)
    plot_hist_tool = MCPTool(
        name="plot_hist",
        description="generates a histogram based on a numeric column of a CSV table and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "column",
                type = "str",
                description = "the numeric column to use for histogram values",
                required = true
            ),
            ToolParameter(
                name = "bins",
                type = "int",
                description = "optional number of histogram bins",
                required = false
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "x_axis_label",
                type = "str",
                description = "optional label for the x-axis",
                required = false
            ),
            ToolParameter(
                name = "y_axis_label",
                type = "str",
                description = "optional label for the y-axis",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names for the histogram bars. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\". If not provided, a default color palette will be used.",
                required = false
            )
        ],
        handler = params -> plot_hist(
            params["path"],
            params["column"];
            bins=parse_optional_int(get(params, "bins", nothing)),
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            x_axis_label=get(params, "x_axis_label", nothing),
            y_axis_label=get(params, "y_axis_label", nothing),
            colors=get(params, "colors", String[])
        )
    )

    TOOLS[plot_hist_tool.name] = plot_hist_tool
end

push!(INIT_FUNCTIONS, init_plot_hist_tool)


"""
    plot_pie(path::String, labels_column::String, values_column::String; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content

Generates a pie chart from a CSV file at the specified path.
"""
function plot_pie(path::String, labels_column::String, values_column::String; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, colors::Vector{String}=String[], with_legend::Bool=true)::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    end

    try
        data = load_plot_table(path)
        if !(labels_column in names(data))
            return TextContent(; type="text", text="ERROR: labels column '$labels_column' not found in CSV file.")
        elseif !(values_column in names(data))
            return TextContent(; type="text", text="ERROR: values column '$values_column' not found in CSV file.")
        end

        data[!, values_column] = coerce_numeric_values(data[!, values_column])
        values = Float64[]
        labels = String[]

        for row_index in 1:nrow(data)
            label_value = data[row_index, labels_column]
            numeric_value = data[row_index, values_column]
            if ismissing(label_value) || isnothing(label_value)
                continue
            elseif ismissing(numeric_value) || isnothing(numeric_value) || numeric_value <= 0
                return TextContent(; type="text", text="ERROR: pie chart values must be positive numeric values.")
            end

            push!(labels, string(label_value))
            push!(values, Float64(numeric_value))
        end

        if isempty(values)
            return TextContent(; type="text", text="ERROR: no positive numeric values found for the selected pie chart columns.")
        end

        palette = resolve_plot_palette(colors, length(values))

        fig = Figure(size=(1440, 900))
        axis = Axis(fig[1, 1]; title=isnothing(title) ? "" : title, autolimitaspect=1)
        hidedecorations!(axis)
        hidespines!(axis)
        pie!(axis, values; color=palette, strokecolor=:white, strokewidth=2, radius=2)

        if with_legend
            legend_elements = [PolyElement(polycolor=palette[index], strokecolor=:white, strokewidth=1) for index in eachindex(labels)]
            Legend(fig[1, 2], legend_elements, labels)
        end

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end
end


function init_plot_pie_tool(config::Dict)
    plot_pie_tool = MCPTool(
        name="plot_pie",
        description="generates a pie chart based on a label column and a numeric values column from a CSV table and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "labels_column",
                type = "str",
                description = "the column that provides the pie slice labels",
                required = true
            ),
            ToolParameter(
                name = "values_column",
                type = "str",
                description = "the numeric column that provides the pie slice values",
                required = true
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names for the pie slices. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\". If not provided, a default color palette will be used.",
                required = false
            ),
            ToolParameter(
                name = "with_legend",
                type = "bool",
                description = "whether to include a legend for the pie slices",
                required = false
            )
        ],
        handler = params -> plot_pie(
            params["path"],
            params["labels_column"],
            params["values_column"];
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            colors=get(params, "colors", String[]),
            with_legend=parse_bool(get(params, "with_legend", true), true)
        )
    )

    TOOLS[plot_pie_tool.name] = plot_pie_tool
end

push!(INIT_FUNCTIONS, init_plot_pie_tool)


"""
    plot_heatmap(path::String, xcolumn::String, ycolumn::String, value_column::String; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[])::Content

Generates a heatmap from a CSV file at the specified path.
"""
function plot_heatmap(path::String, xcolumn::String, ycolumn::String, value_column::String; output_path::Union{Nothing,String}=nothing, title::Union{Nothing,String}=nothing, x_axis_label::Union{Nothing,String}=nothing, y_axis_label::Union{Nothing,String}=nothing, colors::Vector{String}=String[])::Content
    validation_error = validate_plot_request(path, output_path)
    if !isnothing(validation_error)
        return validation_error
    end

    try
        data = load_plot_table(path)
        if !(xcolumn in names(data))
            return TextContent(; type="text", text="ERROR: x-column '$xcolumn' not found in CSV file.")
        elseif !(ycolumn in names(data))
            return TextContent(; type="text", text="ERROR: y-column '$ycolumn' not found in CSV file.")
        elseif !(value_column in names(data))
            return TextContent(; type="text", text="ERROR: value column '$value_column' not found in CSV file.")
        end

        data[!, value_column] = coerce_numeric_values(data[!, value_column])

        xlabels = unique(string.(data[!, xcolumn]))
        ylabels = unique(string.(data[!, ycolumn]))
        xlookup = Dict(label => index for (index, label) in enumerate(xlabels))
        ylookup = Dict(label => index for (index, label) in enumerate(ylabels))
        value_matrix = fill(NaN, length(xlabels), length(ylabels))
        value_counts = Dict{Tuple{String, String}, Int}()

        for row_index in 1:nrow(data)
            xvalue = data[row_index, xcolumn]
            yvalue = data[row_index, ycolumn]
            numeric_value = data[row_index, value_column]

            if ismissing(xvalue) || isnothing(xvalue) || ismissing(yvalue) || isnothing(yvalue) || ismissing(numeric_value) || isnothing(numeric_value)
                continue
            end

            xindex = xlookup[string(xvalue)]
            yindex = ylookup[string(yvalue)]
            key = (string(xvalue), string(yvalue))
            if isnan(value_matrix[xindex, yindex])
                value_matrix[xindex, yindex] = Float64(numeric_value)
                value_counts[key] = 1
            else
                count = get(value_counts, key, 1)
                value_matrix[xindex, yindex] = ((value_matrix[xindex, yindex] * count) + Float64(numeric_value)) / (count + 1)
                value_counts[key] = count + 1
            end
        end

        if all(isnan, value_matrix)
            return TextContent(; type="text", text="ERROR: no numeric values found in the selected value column.")
        end

        fig = Figure(size=(1440, 900))
        axis = Axis(
            fig[1, 1];
            xticks=(collect(1:length(xlabels)), xlabels),
            yticks=(collect(1:length(ylabels)), ylabels),
            xticklabelrotation=label_rotation(xlabels),
            xlabel=isnothing(x_axis_label) ? "" : x_axis_label,
            ylabel=isnothing(y_axis_label) ? "" : y_axis_label,
            title=isnothing(title) ? "" : title
        )

        heatmap_plot = heatmap!(axis, collect(1:length(xlabels)), collect(1:length(ylabels)), value_matrix; colormap=resolve_heatmap_colormap(colors))
        Colorbar(fig[1, 2], heatmap_plot, label=value_column)

        return save_plot_content(fig, output_path)
    catch error
        return TextContent(; type="text", text="failed to generate plot: $error")
    end
end


function init_plot_heatmap_tool(config::Dict)
    plot_heatmap_tool = MCPTool(
        name="plot_heatmap",
        description="generates a heatmap based on categorical x/y columns and a numeric value column from a CSV table and can return the plot as image content or save it to an output image file.",
        parameters=[
            ToolParameter(
                name = "path",
                type = "str",
                description = "the path to the CSV file containing the data to be plotted",
                required = true
            ),
            ToolParameter(
                name = "xcolumn",
                type = "str",
                description = "the column to use for heatmap x-axis categories",
                required = true
            ),
            ToolParameter(
                name = "ycolumn",
                type = "str",
                description = "the column to use for heatmap y-axis categories",
                required = true
            ),
            ToolParameter(
                name = "value_column",
                type = "str",
                description = "the numeric column to use for heatmap cell values",
                required = true
            ),
            ToolParameter(
                name = "output_path",
                type = "str",
                description = "optional output image path (.png or .svg)",
                required = false
            ),
            ToolParameter(
                name = "title",
                type = "str",
                description = "optional plot title",
                required = false
            ),
            ToolParameter(
                name = "x_axis_label",
                type = "str",
                description = "optional label for the x-axis",
                required = false
            ),
            ToolParameter(
                name = "y_axis_label",
                type = "str",
                description = "optional label for the y-axis",
                required = false
            ),
            ToolParameter(
                name = "colors",
                type = "array",
                description = "optional vector of color names used to build the heatmap color gradient. Supported color names are: \"blue\", \"orange\", \"green\", \"purple\", \"lightblue\", \"red\", and \"yellow\".",
                required = false
            )
        ],
        handler = params -> plot_heatmap(
            params["path"],
            params["xcolumn"],
            params["ycolumn"],
            params["value_column"];
            output_path=get(params, "output_path", nothing),
            title=get(params, "title", nothing),
            x_axis_label=get(params, "x_axis_label", nothing),
            y_axis_label=get(params, "y_axis_label", nothing),
            colors=get(params, "colors", String[])
        )
    )

    TOOLS[plot_heatmap_tool.name] = plot_heatmap_tool
end

push!(INIT_FUNCTIONS, init_plot_heatmap_tool)


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