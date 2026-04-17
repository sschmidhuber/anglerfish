# shell

"""
    execute_bash(command::String, wd::String, terminal::String, foreground=false, isolated=true)::TextContent

Executes a bash command in an isolated environment using bubblewrap (bwrap). The command is executed with limited access
to the filesystem and system resources based on the allowed directories configured for Anglerfish.

Arguments:
- `command`: The bash command to execute.
- `wd`: The working directory to execute the command in. Must be an allowed directory. If not specified or invalid, defaults to the home directory or the first allowed directory.
- `terminal`: The terminal emulator to use for foreground execution (e.g. "gnome-terminal", "xterm", "konsole"). Required if `foreground` is true.
- `foreground`: If true, the command is executed in the foreground with the specified terminal. If false, the command is executed in the background and the output is returned as text. Default is false.
- `isolated`: If true, the command is executed in an isolated environment using bubblewrap. If false, the command
"""
function execute_bash(command::String, wd::String, terminal::String, foreground=false, isolated=true)::TextContent
    exitcode = nothing
    output = IOBuffer()
    error = IOBuffer()

    if !Sys.islinux() && !Sys.isapple()
        return TextContent(; type="text", text="ERROR: shell command execution is only supported on Linux and macOS")
    elseif !isolated
        return TextContent(; type="text", text="ERROR: not isolated bash access is currently not supported")
    elseif foreground && !isinstalled(terminal)
        return TextContent(; type="text", text="ERROR: $terminal is required for executing shell commands in the foreground, but it is not installed on this system")
    elseif !isinstalled("bwrap")
        return TextContent(; type="text", text="ERROR: bwrap (bubblewrap) is required for executing shell commands in isolation, but it is not installed on this system")
    end

    exec = String[]
    try
        if foreground
            append!(exec, ["setsid", "--fork", terminal, "-e"])
        end
        append!(exec, [
            "bwrap",
            "--dev", "/dev",
            "--proc", "/proc",
            "--tmpfs", "/tmp",
            "--ro-bind-try", "/bin", "/bin",
            "--ro-bind-try", "/lib", "/lib",
            "--ro-bind-try", "/lib64", "/lib64",
            "--ro-bind-try", "/usr", "/usr",
            "--ro-bind-try", "/etc", "/etc",
            "--ro-bind-try", "/sys", "/sys",
            "--ro-bind-try", "/sbin", "/sbin",
            "--ro-bind-try", "/var", "/var"
        ])
        foreach(dir -> append!(exec, ["--ro-bind-try", dir, dir]), READ_ONLY_DIRECTORIES)
        foreach(dir -> append!(exec, ["--bind", dir, dir]), READ_WRITE_DIRECTORIES)
        if !isempty(wd) && isvalidpath(wd, "read")
            append!(exec, ["--chdir", wd])
        elseif isvalidpath(Base.Filesystem.homedir(), "read")
            append!(exec, ["--chdir", Base.Filesystem.homedir()])
        elseif !isempty(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES))
            append!(exec, ["--chdir", union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES)[1]])
        end
        append!(exec, ["bash", "-c", command])
        @debug "Executing shell command with bubblewrap: $(join(exec, " "))"
        if foreground
            cmd = Cmd(exec)
            run(pipeline(cmd, stdin=devnull, stdout=devnull, stderr=devnull); wait=true)
            return TextContent(; type="text", text="command executed in terminal")
        else            
            cmd = Cmd(exec) |> ignorestatus
            process = run(pipeline(cmd; stdin=devnull, stdout=output, stderr=error))
            exitcode = process.exitcode
        end
    catch err
        return TextContent(; type="text", text="ERROR: tool error during execution: $err")
    end

    response = Dict("exitcode" => exitcode, "stdout" => String(take!(output)) |> chomp, "stderr" => String(take!(error)) |> chomp)
    return TextContent(; type="text", text=JSON.json(response))
end


"""
    list_of_commands()

Returns a list of common system commands that are typically available on Linux systems. This list is used to inform the
LLM client about the commands they can use when executing shell commands through the tool.
"""
function list_of_commands()
    commands = ["ls", "head", "tail", "cd", "mkdir", "rmdir", "rm", "cp", "mv", "ln", "ps", "df", "du", "free",
        "ping", "awk", "sed", "grep", "tree", "curl", "wget", "ffmpeg", "convert", "gzip", "tar", "unzip", "zip",
        "bzip2", "7z", "pandoc", "jq", "python", "python3", "node", "git", "deno", "bun"]
    
    return filter(cmd -> isinstalled(cmd), commands)
end


function init_shell_tool(config::Dict)
    @info "initialize shell tool"
    if !Sys.islinux()
        @info "shell command execution is only supported on Linux, shell tool will not be initialized"
        return nothing
    end
    shell_tool = MCPTool(
        name="shell",
        description="executes a bash command or script. The command resp. script has read-only access to: $(join(READ_ONLY_DIRECTORIES, ", ", " and ")) and read-write access to: $(join(READ_WRITE_DIRECTORIES, ", ", " and ")). All usual system commands are available e.g. $(join(list_of_commands(), ", ", " and ")).",
        parameters=[
            ToolParameter(
                name = "command",
                type = "str",
                description = "the bash command or script to execute",
                required = true
            ),
            ToolParameter(
                name = "working_directory",
                type = "str",
                description = "the working directory to execute the command resp. script in. Must be an allowed directory. If not specified or invalid, defaults to the home directory or the first allowed directory.",
                required = false
            ),
            ToolParameter(
                name = "open_terminal",
                type = "bool",
                description = "if true, the command is executed in a terminal application (e.g. xterm) this can be used if user interaction is required or terminal output should be visible to the user. If false (default), the command is executed directly and the output is returned by the tool call. In that case the user can't see the terminal wiondow.",
                required = false
            )
        ],
        handler = params -> begin
            execute_bash(params["command"], get(params, "working_directory", ""), config["applications"]["terminal"], parse_bool(get(params, "open_terminal", false), false))
        end
    )
    TOOLS[shell_tool.name] = shell_tool
end

push!(INIT_FUNCTIONS, init_shell_tool)