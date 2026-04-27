@testset "Analytics" begin
    @test_skip @testset "Gnuplot" begin
        plotting_tool = Anglerfish.TOOLS["gnuplot"]

        # test plotting from CSV data file, creating a PNG output, and checking that the output file is created successfully. Since we can't easily automate checking the actual plot output, we'll just check that gnuplot executes without error and creates the output file.
        datafile = joinpath(ro_dir, "test_datafile.csv")
        gnuplot_csv_script = """
        set terminal pngcairo
        set output '$(joinpath(rw_dir, "test_plot.png"))'
        set datafile separator ","
        plot '$datafile' using 1:2 with lines title 'Column 1', '$datafile' using 1:3 with lines title 'Column 2'
        """
        gnuplot_csv_result = plotting_tool.handler(Dict("script" => gnuplot_csv_script, "working_directory" => ro_dir)).text
        @test contains(gnuplot_csv_result, "gnuplot executed successfully")

        incorrect_gnuplot_script = """set terminal web size 1200,600 enhanced font 'Arial,14'
        set output '/home/stefan/Downloads/open_llm_overall_score_bar.png'

        # Title for the plot
        set title "Top Open-Weight LLMs: Overall Benchmark Score Comparison" \
            font "Arial Bold,20" textcolor "black"

        # Y-axis formatting
        set yrange [0:100]
        set ytics nomirror format "%.1f"
        set ylabel "Score / Capability Index" font "Arial,14"

        # X-axis labels rotated for better readability
        set xtics rotate by -45 offset 0,-20 textcolor "black"
        set xlabel "Model" font "Arial,14"

        # Enable legend
        set key outside right top box

        # Bar styling
        set style fill solid
        set bar width 0.85

        # Data plotting (manual since we have tab-separated data)
        plot "plot_overall_scores.txt" using (\$0+1):2:(stringcolumn(3)) \
            with boxes title "Model Scores" lc rgbpalette notitle, \
             "" using 0:0 with emptychars"""
        gnuplot_incorrect_result = plotting_tool.handler(Dict("script" => incorrect_gnuplot_script, "working_directory" => ro_dir)).text
        @test contains(gnuplot_incorrect_result, "line 21: undefined variable: width")

        # clean up test plot file if it was created
        if isfile(joinpath(rw_dir, "test_plot.png"))
            rm(joinpath(rw_dir, "test_plot.png"))
        end
    end

    @testset "Describe Table" begin
        describe_table_tool = Anglerfish.TOOLS["describe_table"]

        # test describing a valid CSV file
        describe_result = describe_table_tool.handler(Dict("path" => joinpath(ro_dir, "test_table.csv"))).text
        @test contains(describe_result, "Table has 26 rows (without header) and 6 columns.")
        @test contains(describe_result, "Column") && contains(describe_result, "Min") && contains(describe_result, "Mean") && contains(describe_result, "Max") && contains(describe_result, "Missing Values")

        # test describing a non-existent file
        describe_non_existent = describe_table_tool.handler(Dict("path" => joinpath(ro_dir, "non_existent_file.csv"))).text
        @test startswith(describe_non_existent, "ERROR: path")

        # test describing a file that is not a CSV
        describe_not_csv = describe_table_tool.handler(Dict("path" => joinpath(ro_dir, "test file 1.txt"))).text
        @test startswith(describe_not_csv, "ERROR: file type not supported")
    end

    @testset "Plot Bar" begin
        plot_bar_tool = Anglerfish.TOOLS["plot_bar"]
        output_path_png = joinpath(rw_dir, "test_barplot.png")
        output_path_svg = joinpath(rw_dir, "test_barplot.svg")

        # plot to PNG file with title, single y-column
        plot_result = plot_bar_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Name",
            "ycolumns" => ["Age"],
            "output_path" => output_path_png,
            "title" => "Ages",
            "x_axis_label" => "Students",
            "y_axis_label" => "Years"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        # plot to SVG file without title, multiple y-columns
        plot_result_multiple_y = plot_bar_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Sex",
            "ycolumns" => ["Height", "Weight"],
            "colors" => ["blue", "red"],
            "output_path" => output_path_svg
        )).text
        @test startswith(plot_result_multiple_y, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        # return plot as image content, multiple y-columns, stacked
        plot_result_image = plot_bar_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Sex",
            "ycolumns" => ["Height", "Weight"],
            "stacked" => true
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        # clean up test plot file
        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    @testset "Plot Line" begin
        plot_line_tool = Anglerfish.TOOLS["plot_line"]
        output_path_png = joinpath(rw_dir, "test_lineplot.png")
        output_path_svg = joinpath(rw_dir, "test_lineplot.svg")

        # plot to PNG file using a categorical x-axis
        plot_result = plot_line_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Name",
            "ycolumns" => ["Age"],
            "output_path" => output_path_png,
            "title" => "Ages Over Students",
            "x_axis_label" => "Students",
            "y_axis_label" => "Years"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        # plot to SVG file using a numeric x-axis with multiple series
        plot_result_multiple_y = plot_line_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Name",
            "ycolumns" => ["Height", "Weight"],
            "colors" => ["blue", "green"],
            "output_path" => output_path_svg
        )).text
        @test startswith(plot_result_multiple_y, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        # return plot as image content
        plot_result_image = plot_line_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Age",
            "ycolumns" => ["Height", "Weight"]
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    @testset "Plot Box" begin
        plot_box_tool = Anglerfish.TOOLS["plot_box"]
        output_path_png = joinpath(rw_dir, "test_boxplot.png")
        output_path_svg = joinpath(rw_dir, "test_boxplot.svg")

        # plot to PNG file with grouped categories from one numeric column
        plot_result = plot_box_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Sex",
            "ycolumns" => ["Age"],
            "output_path" => output_path_png,
            "title" => "Age Distribution by Sex",
            "x_axis_label" => "Sex",
            "y_axis_label" => "Age"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        # plot to SVG file with multiple grouped series
        plot_result_multiple_y = plot_box_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Sex",
            "ycolumns" => ["Weight", "Height"],
            "colors" => ["blue", "green"],
            "output_path" => output_path_svg
        )).text
        @test startswith(plot_result_multiple_y, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        # return plot as image content
        plot_result_image = plot_box_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Sex",
            "ycolumns" => ["Height", "Weight"]
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    @testset "Plot Scatter" begin
        plot_scatter_tool = Anglerfish.TOOLS["plot_scatter"]
        output_path_png = joinpath(rw_dir, "test_scatterplot.png")
        output_path_svg = joinpath(rw_dir, "test_scatterplot.svg")

        plot_result = plot_scatter_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumns" => ["Age"],
            "ycolumns" => ["Height"],
            "output_path" => output_path_png,
            "title" => "Height vs Age",
            "x_axis_label" => "Age",
            "y_axis_label" => "Height"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        plot_result_svg = plot_scatter_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumns" => ["Age", "Weight"],
            "ycolumns" => ["Height", "Height"],
            "colors" => ["blue", "red"],
            "output_path" => output_path_svg
        )).text
        @test startswith(plot_result_svg, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        plot_result_image = plot_scatter_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumns" => ["Age", "Weight"],
            "ycolumns" => ["Height", "Age"]
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        scatter_invalid = plot_scatter_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumns" => ["Age"],
            "ycolumns" => ["Height", "Weight"]
        )).text
        @test startswith(scatter_invalid, "ERROR: xcolumns and ycolumns")

        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    @testset "Plot Hist" begin
        plot_hist_tool = Anglerfish.TOOLS["plot_hist"]
        output_path_png = joinpath(rw_dir, "test_histplot.png")
        output_path_svg = joinpath(rw_dir, "test_histplot.svg")

        plot_result = plot_hist_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "column" => "Age",
            "bins" => 6,
            "output_path" => output_path_png,
            "title" => "Age Distribution",
            "x_axis_label" => "Age",
            "y_axis_label" => "Frequency"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        plot_result_svg = plot_hist_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "column" => "Height",
            "colors" => ["green"],
            "output_path" => output_path_svg
        )).text
        @test startswith(plot_result_svg, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        plot_result_image = plot_hist_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "column" => "Weight"
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        hist_invalid = plot_hist_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "column" => "Name"
        )).text
        @test startswith(hist_invalid, "ERROR: no numeric values found")

        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    @testset "Plot Pie" begin
        plot_pie_tool = Anglerfish.TOOLS["plot_pie"]
        output_path_png = joinpath(rw_dir, "test_pieplot.png")
        output_path_svg = joinpath(rw_dir, "test_pieplot.svg")

        plot_result = plot_pie_tool.handler(Dict(
            "path" => joinpath(ro_dir, "budget_germany.csv"),
            "labels_column" => "Einzelplan",
            "values_column" => "Anteil",
            "output_path" => output_path_png,
            "title" => "Budget Germany 2025"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        plot_result_svg = plot_pie_tool.handler(Dict(
            "path" => joinpath(ro_dir, "budget_germany.csv"),
            "labels_column" => "Einzelplan",
            "values_column" => "Anteil",
            "colors" => ["blue", "orange", "green", "purple", "lightblue", "red", "yellow"],
            "output_path" => output_path_svg,
            "with_legend" => false
        )).text
        @test startswith(plot_result_svg, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        plot_result_image = plot_pie_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "labels_column" => "Sex",
            "values_column" => "Weight"
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        pie_invalid = plot_pie_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "labels_column" => "Sex",
            "values_column" => "City"
        )).text
        @test startswith(pie_invalid, "ERROR: pie chart values must be positive numeric values")

        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    
    @testset "Plot Heatmap" begin
        plot_heatmap_tool = Anglerfish.TOOLS["plot_heatmap"]
        output_path_png = joinpath(rw_dir, "test_heatmap.png")
        output_path_svg = joinpath(rw_dir, "test_heatmap.svg")
        heatmap_path = joinpath(ro_dir, "test_heatmap.csv")

        plot_result = plot_heatmap_tool.handler(Dict(
            "path" => heatmap_path,
            "xcolumn" => "Department",
            "ycolumn" => "Month",
            "value_column" => "Score",
            "output_path" => output_path_png,
            "title" => "Department Scores",
            "x_axis_label" => "Department",
            "y_axis_label" => "Month"
        )).text
        @test startswith(plot_result, "plot generated successfully")
        @test isfile(output_path_png)
        @test filesize(output_path_png) > 0

        plot_result_svg = plot_heatmap_tool.handler(Dict(
            "path" => heatmap_path,
            "xcolumn" => "Department",
            "ycolumn" => "Month",
            "value_column" => "Score",
            "colors" => ["blue", "yellow", "red"],
            "output_path" => output_path_svg
        )).text
        @test startswith(plot_result_svg, "plot generated successfully")
        @test isfile(output_path_svg)
        @test filesize(output_path_svg) > 0

        plot_result_image = plot_heatmap_tool.handler(Dict(
            "path" => heatmap_path,
            "xcolumn" => "Department",
            "ycolumn" => "Month",
            "value_column" => "Score"
        ))
        @test plot_result_image isa ImageContent
        @test plot_result_image.mime_type == "image/png"

        heatmap_invalid = plot_heatmap_tool.handler(Dict(
            "path" => joinpath(ro_dir, "test_table.csv"),
            "xcolumn" => "Sex",
            "ycolumn" => "City",
            "value_column" => "Name"
        )).text
        @test startswith(heatmap_invalid, "ERROR: no numeric values found")

        isfile(output_path_png) && rm(output_path_png)
        isfile(output_path_svg) && rm(output_path_svg)
    end

    @testset "Execute SQL" begin
        execute_sql_tool = Anglerfish.TOOLS["execute_sql"]

        # test executing a simple SELECT query on a valid CSV file
        sql_result = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test_table.csv"), "query" => "SELECT Name, Age FROM test_table WHERE City = 'New York'" )).text
        @test contains(sql_result, "Alice") && contains(sql_result, "30") && !contains(sql_result, "Bob")

        # execute a simple SELECT query and write the result to a new CSV file, then check that the output file is created and contains the expected data
        sql_result_with_sink = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test_table.csv"), "query" => "SELECT Name, City FROM test_table WHERE Age <= 28", "sink_path" => joinpath(rw_dir, "sql_output.csv"))).text
        @test startswith(sql_result_with_sink, "SQL query executed successfully, result written to")
        @test isfile(joinpath(rw_dir, "sql_output.csv"))
        sql_output_data = CSV.File(joinpath(rw_dir, "sql_output.csv")) |> DataFrame
        @test size(sql_output_data) == (9, 2)
        @test names(sql_output_data) == ["Name", "City"]
        @test sql_output_data[1, :] |> collect == ["Bob", "Los Angeles"]

        # modify the original CSV file with an UPDATE query and check that the changes are persisted when persist_changes is true
        CSV.write(joinpath(rw_dir, "update_table.csv"), DataFrame(Name=["Alice", "Bob"], Age=[30, 25], City=["New York", "Los Angeles"]))
        sql_update_result = execute_sql_tool.handler(Dict("source_path" => joinpath(rw_dir, "update_table.csv"), "query" => "UPDATE update_table SET Age = Age + 1 WHERE Name = 'Bob'", "persist_changes" => true)).text
        @test startswith(sql_update_result, "SQL query executed successfully")
        updated_table_data = CSV.read(joinpath(rw_dir, "update_table.csv"), DataFrame)
        @test updated_table_data[updated_table_data.Name .== "Bob", :Age][1] == 26

        # test executing a query with an invalid path
        sql_invalid_path = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "non_existent_file.csv"), "query" => "SELECT * FROM test_table")).text
        @test startswith(sql_invalid_path, "ERROR:")

        # test executing a query on a file that is not a CSV
        sql_not_csv = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test file 1.txt"), "query" => "SELECT * FROM test_table")).text
        @test startswith(sql_not_csv, "ERROR: file type not supported")

        # test executing a query with invalid SQL syntax
        sql_invalid_syntax = execute_sql_tool.handler(Dict("source_path" => joinpath(ro_dir, "test_table.csv"), "query" => "SELEC Name FROM test_table")).text
        @test contains(sql_invalid_syntax, "failed to execute SQL query") && contains(sql_invalid_syntax, "SELEC")

        # clean up test files
        isfile(joinpath(rw_dir, "sql_output.csv")) && rm(joinpath(rw_dir, "sql_output.csv"))
        isfile(joinpath(rw_dir, "update_table.csv")) && rm(joinpath(rw_dir, "update_table.csv"))
    end
end