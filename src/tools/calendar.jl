# calendar items

function init_calendar_tools(cofnig::Dict)
    @info "initialize calendar tools"
    create_event_tool = MCPTool(
        name="create_event",
        description="creates a calendar event based on the given title, description, start and end time. The event is opened in the users calendar client to review and import.",
        parameters=[
            ToolParameter(
                name = "title",
                type = "str",
                description = "title of the event",
                required = true
            ),
            ToolParameter(
                name = "description",
                type = "str",
                description = "description of the event",
                required = false
            ),
            ToolParameter(
                name = "start_time",
                type = "str",
                description = "start time of the event in ISO 8601 format (e.g., 2024-01-01T10:00:00), or just the date for all day events (e.g., 2024-01-01)",
                required = true
            ),
            ToolParameter(
                name = "end_time",
                type = "str",
                description = "end time of the event in ISO 8601 format (e.g., 2024-01-01T11:00:00), or omitted for all day events (in which case the event will be treated as an all day event on the start date)",
                required = false
            )
        ],
        handler=params -> begin
            start_time = tryparse(DateTime, params["start_time"], dateformat"yyyy-mm-ddTHH:MM:SS")
            if isnothing(start_time)
                start_time = tryparse(Date, params["start_time"], dateformat"yyyy-mm-dd")
            else
                if haskey(params, "end_time")
                    end_time = tryparse(DateTime, params["end_time"], dateformat"yyyy-mm-ddTHH:MM:SS")
                else
                    end_time = start_time + Hour(1)                    
                end                
            end
            if isnothing(start_time)
                return "invalid start_time format. start_time should be in ISO 8601 format, either as a full datetime (e.g., 2024-01-01T10:00:00) or just a date for all day events (e.g., 2024-01-01)."
            end

            msg = create_calendar_event(
                params["title"],
                haskey(params, "description") ? params["description"] : "",
                start_time,
                end_time
            )
            return TextContent(; type="text", text=msg)
        end
    )
    push!(TOOLS, create_event_tool)
end


"""
    create_calendar_event(title, description, start_time, end_time)

Creates temporary ics file, representing the given event based on the given title, description, start time and end time. The event is not actually created, but is opened in the users calendar client to review and create.
"""
function create_calendar_event(title, description=nothing, start_time=today(), end_time=nothing)
    fmt_date(d) = Dates.format(DateTime(d), "yyyymmddTHHMMSS")
    if start_time isa Date && isnothing(end_time)
        end_time = start_time + Day(1)
        dtstart = "DTSTART;DATE:$(Dates.format(DateTime(start_time), "yyyymmdd"))"
        dtend = "DTEND;DATE:$(Dates.format(DateTime(end_time), "yyyymmdd"))"
    elseif start_time isa DateTime && end_time isa DateTime
        dtstart = "DTSTART;TZID=$(localzone()):$(fmt_date(start_time))"
        dtend = "DTEND;TZID=$(localzone()):$(fmt_date(end_time))"
    else
        return "invalid date format. For all day events, start_time should be a Date and end_time should be omitted. For events with specific start and end times, both start_time and end_time should be DateTime objects."
    end

    ics_content = """BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Anglerfish//NONSGML / icalendar //EN
        BEGIN:VEVENT
        SUMMARY:$title
        $(isnothing(description) ? "" : "DESCRIPTION:$description\n")$dtstart
        $dtend
        DTSTAMP:$(fmt_date(now(TimeZones.utc_tz)))Z
        UID:$(string(uuid4()))
        END:VEVENT
        END:VCALENDAR"""

    @show tempfile = tempname(; cleanup=true, suffix=".ics")
    open(tempfile, "w") do f
        write(f, ics_content)
    end

    try
        if Sys.iswindows()
            run(`cmd /c start "" "$tempfile"`)
        elseif Sys.isapple()
            run(`open "$tempfile"`)
        else
            run(`xdg-open "$tempfile"`)
        end
        return "successfully created a calendar event"
    catch err
        return "failed to create a calendar event: $err"
    end
end


push!(INIT_FUNCTIONS, init_calendar_tools)