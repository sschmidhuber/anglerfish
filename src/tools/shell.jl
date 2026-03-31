# shell

"""
    execute_bash(command::String, wd::String, terminal::String, foreground=false, isolated=true)

Executes a bash command in an isolated environment using bubblewrap (bwrap). The command is executed with limited access to the filesystem and system resources based on the allowed directories configured for Anglerfish.

Arguments:
- `command`: The bash command to execute.
- `wd`: The working directory to execute the command in. Must be an allowed directory. If not specified or invalid, defaults to the home directory or the first allowed directory.
- `terminal`: The terminal emulator to use for foreground execution (e.g. "gnome-terminal", "xterm", "konsole"). Required if `foreground` is true.
- `foreground`: If true, the command is executed in the foreground with the specified terminal. If false, the command is executed in the background and the output is returned as text. Default is false.
- `isolated`: If true, the command is executed in an isolated environment using bubblewrap. If false, the command
"""
function execute_bash(command::String, wd::String, terminal::String, foreground=false, isolated=true)::String
    if !Sys.islinux() && !Sys.isapple()
        return "shell command execution is only supported on Linux and macOS"
    elseif !isolated
        return "not isolated bash access is currently not supported"
    elseif foreground && !isinstalled(terminal)
        return "$terminal is required for executing shell commands in the foreground, but it is not installed on this system"
    elseif !isinstalled("bwrap")
        return "bwrap (bubblewrap) is required for executing shell commands in isolation, but it is not installed on this system"
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
        elseif isvalidpath(Sys.homedir(), "read")
             append!(exec, ["--chdir", Sys.homedir()])
        elseif !isempty(union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES))
             append!(exec, ["--chdir", union(READ_ONLY_DIRECTORIES, READ_WRITE_DIRECTORIES)[1]])       
        end
        append!(exec, ["bash", "-c", command])
        @debug "Executing shell command with bubblewrap: $(join(exec, " "))"
        if foreground
            cmd = Cmd(exec)
            run(pipeline(cmd, stdin=devnull, stdout=devnull, stderr=devnull); wait=true)
            return "command executed in foreground with terminal: $terminal"
        else
            cmd = Cmd(exec)
            output = read(ignorestatus(cmd), String)
            return isnothing(output) ? "" : chomp(output)
        end            
    catch err
        return "failed to execute command: $err"
    end
end


function list_of_commands()
    cmds = String[]
    isinstalled("awk") && push!(cmds, "awk")
    isinstalled("sed") && push!(cmds, "sed")
    isinstalled("grep") && push!(cmds, "grep")
    isinstalled("find") && push!(cmds, "find")
    isinstalled("tree") && push!(cmds, "tree")
    isinstalled("curl") && push!(cmds, "curl")
    isinstalled("wget") && push!(cmds, "wget")
    isinstalled("ffmpeg") && push!(cmds, "ffmpeg")
    isinstalled("convert") && push!(cmds, "convert (ImageMagick)")
    isinstalled("gzip") && push!(cmds, "gzip")
    isinstalled("tar") && push!(cmds, "tar")
    isinstalled("unzip") && push!(cmds, "unzip")
    isinstalled("zip") && push!(cmds, "zip")
    isinstalled("bzip2") && push!(cmds, "bzip2")
    isinstalled("7z") && push!(cmds, "7z (p7zip)")
    isinstalled("pandoc") && push!(cmds, "pandoc")
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
                name = "foreground",
                type = "bool",
                description = "if true, the command is executed in the foreground this can be used if user interaction is required or terminal output should be visible to the user. If false (default), the command is executed in the background and the output is returned by the tool call. In that case the user can't see the terminal wiondow.",
                required = false
            )
        ],
        handler=params -> begin
            res = execute_bash(params["command"], get(params, "working_directory", ""), config["applications"]["terminal"], parse_bool(get(params, "foreground", false), false))
            return TextContent(; type="text", text=res)
        end
    )
    TOOLS[shell_tool.name] = shell_tool
end

push!(INIT_FUNCTIONS, init_shell_tool)