@testset "Shell Command Execution" begin
    # only run shell command execution tests on Linux
    if Sys.islinux()
        shell_tool = Anglerfish.TOOLS["shell"]

        # test background execution of a simple command
        shell_result = shell_tool.handler(Dict("command" => "echo Hello World", "open_terminal" => false)).text |> JSON.parse
        @test shell_result["stdout"] == "Hello World"
        @test shell_result["stderr"] == ""
        @test shell_result["exitcode"] == 0

        # test background execution of a command that produces an error
        shell_result_error = shell_tool.handler(Dict("command" => "ls --invalidargument", "open_terminal" => false)).text |> JSON.parse
        println(shell_result_error)
        @test shell_result_error["stdout"] == ""
        @test contains(shell_result_error["stderr"], "--invalidargument")
        @test shell_result_error["exitcode"] != 0

        # test foreground execution of a simple command (this will open a terminal window, so we can't easily automate checking the result, but we can at least check that it doesn't return an error)
        shell_result_foreground = shell_tool.handler(Dict("command" => "echo Hello Foreground; sleep 2", "open_terminal" => "True")).text
        @test startswith(shell_result_foreground, "command executed in terminal")

        # test execution with working directory specified
        shell_result_with_wd = shell_tool.handler(Dict("command" => "pwd", "working_directory" => ro_dir, "open_terminal" => false)).text |> JSON.parse
        @test shell_result_with_wd["stdout"] == ro_dir

        # test execution with invalid working directory specified (should default to home or first allowed directory)
        shell_result_with_invalid_wd = shell_tool.handler(Dict("command" => "pwd", "working_directory" => "/invalid/directory")).text |> JSON.parse
        @test shell_result_with_invalid_wd["stdout"] == homedir()
    end
end