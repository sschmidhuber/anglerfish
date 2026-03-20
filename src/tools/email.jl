# compose email

function init_email_tools(config::Dict)
    @info "initialize email tools"
    compose_email_tool = MCPTool(
        name="compose_email",
        description="composes an email based on the given subject, content, recipient and attachment. The email is not actually sent, but is opened in the users email client to review and send.",
        parameters=[
            ToolParameter(
                name = "subject",
                type = "str",
                description = "the subject of the email",
                required = false
            ),
            ToolParameter(
                name = "to",
                type = "array",
                description = "array of email addresses of the recipients",
                required = false
            ),
            ToolParameter(
                name = "cc",
                type = "array",
                description = "array of email addresses to be CC'd",
                required = false
            ),
            ToolParameter(
                name = "bcc",
                type = "array",
                description = "array of email addresses to be BCC'd",
                required = false
            ),
            ToolParameter(
                name = "content",
                type = "str",
                description = "the content of the email",
                required = false
            ),
            ToolParameter(
                name = "attachments",
                type = "array",
                description = "array of file paths to attach to the email",
                required = false
            )
        ],
        handler=params -> begin
            msg = compose_email(
                get(params, "subject", ""),
                get(params, "to", []),
                get(params, "cc", []),
                get(params, "bcc", []),
                get(params, "content", ""),
                get(params, "attachments", [])
            )
            return TextContent(; type="text", text=msg)
        end
    )
    TOOLS[compose_email_tool.name] = compose_email_tool
end


"""
    compose_email(subject="", to=[], cc=[], bcc=[], content="", attachments=[])

Composes an email with the default email client on Linux.
"""
function compose_email(subject="", to=[], cc=[], bcc=[], content="", attachments=[])
    try
        exec = ["xdg-email", "--utf8"]
        !isempty(subject) && append!(exec, ["--subject", subject])
        if !isempty(cc)
            append!(exec, ["--cc"])
            append!(exec, cc)
        end
        if !isempty(bcc)
            append!(exec, ["--bcc"])
            append!(exec, bcc)
        end
        !isempty(content) && append!(exec, ["--body", content])
        for attachment in attachments
            append!(exec, ["--attach", attachment])
        end
        !isempty(to) && append!(exec, to)

        run(Cmd(exec); wait=false)
    catch err
        return "failed to compose email: $err"
    end

    return "successfully opened email client with precomposed email"
end

if Sys.islinux()
    push!(INIT_FUNCTIONS, init_email_tools)
end