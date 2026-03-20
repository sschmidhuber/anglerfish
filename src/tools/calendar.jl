# calendar items

struct Event
    title::String
    created_timestamp::DateTime
    uid::UUID
    description::Union{String,Nothing}
    location::Union{String,Nothing}
    start_time::Union{Date,DateTime}
    end_time::Union{Date,DateTime,Nothing}
    url::Union{String,Nothing}
end

Event(title, description, location, start_time, end_time, url) = Event(title, now(), uuid4(), description, location, start_time, end_time, url)


struct Todo
    title::String
    created_timestamp::DateTime
    uid::UUID
    description::Union{String,Nothing}
    location::Union{String,Nothing}
    start_time::Union{Date,DateTime,Nothing}
    due_time::Union{Date,DateTime,Nothing}
    priority::Union{String,Nothing}
    url::Union{String,Nothing}
end

Todo(title, description, location, start_time, due_time, priority, url) = Todo(title, now(), uuid4(), description, location, start_time, due_time, priority, url)


struct Calendar
    items::Vector{Union{Event,Todo}}
end


function ics_time(dt::DateTime)
    "TZID=$(localzone()):$(Dates.format(dt, "yyyymmddTHHMMSS"))"
end

function ics_time(d::Date)
    "VALUE=DATE:$(Dates.format(d, "yyyymmdd"))"
end

"""
    ics_timestamp(dt::DateTime)

Expects a UTC DateTime object and returns a string representation in the format "yyyymmddTHHMMSSZ" which is used in ics files to represent timestamps.
"""
function ics_timestamp(dt::DateTime)
    "$(Dates.format(dt, "yyyymmddTHHMMSS"))Z"
end

function ics_component(event::Event)
    component = "BEGIN:VEVENT\nUID:$(string(event.uid))\nSUMMARY:$(event.title)\n"
    !isnothing(event.description) && (component *= "DESCRIPTION:$(event.description)\n")
    !isnothing(event.location) && (component *= "LOCATION:$(event.location)\n")
    component *= "DTSTAMP:$(ics_timestamp(event.created_timestamp))\n"
    component *= "DTSTART;$(ics_time(event.start_time))\n"
    if event.start_time isa Date
        component *= "DTEND;$(ics_time(event.start_time + Day(1)))\n"
    elseif isnothing(event.end_time)
        component *= "DTEND;$(ics_time(event.start_time + Hour(1)))\n"
    else
        component *= "DTEND;$(ics_time(event.end_time))\n"
    end
    !isnothing(event.url) && (component *= "URL:$(event.url)\n")
    component *= "END:VEVENT"
end

function ics_component(todo::Todo)
    component = "BEGIN:VTODO\nUID:$(string(todo.uid))\nSUMMARY:$(todo.title)\n"
    !isnothing(todo.description) && (component *= "DESCRIPTION:$(todo.description)\n")
    !isnothing(todo.location) && (component *= "LOCATION:$(todo.location)\n")
    component *= "DTSTAMP:$(ics_timestamp(todo.created_timestamp))\n"
    !isnothing(todo.start_time) && (component *= "DTSTART;$(ics_time(todo.start_time))\n")
    !isnothing(todo.due_time) && (component *= "DUE;$(ics_time(todo.due_time))\n")
    if !isnothing(todo.priority)
        if todo.priority == "high"
            p = 1
        elseif todo.priority == "medium"
            p = 5
        elseif todo.priority == "low"
            p = 9
        else
            p = 5
        end
        component *= "PRIORITY:$p\n"
    end
    !isnothing(todo.url) && (component *= "URL:$(todo.url)\n")
    component *= "END:VTODO"
end

function ics_calendar(calendar::Calendar)
    ics = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Anglerfish//NONSGML / icalendar //EN\n"
    components = map(item -> ics_component(item), calendar.items)
    ics *= join(components, "\n")
    ics *= "\nEND:VCALENDAR"
end


function init_calendar_tool(cofnig::Dict)
    @info "initialize calendar tools"
    calendar_tool = MCPTool(
        name="calendar_items",
        description="Create one or multiple calendar items (events or todos). The calendar entries are not actually created, but are opened in the users calendar client to review and import.",
        input_schema = Dict{String,Any}(
            "type" => "object",
            "properties" => Dict{String,Any}(
                "items" => Dict{String,Any}(
                    "type" => "array",
                    "description" => "array of calendar items to create",
                    "items" => Dict{String,Any}(
                        "type" => "object",
                        "properties" => Dict(
                            "type" => Dict{String,Any}(
                                "type" => "string",
                                "enum" => ["event", "todo"],
                                "description" => "type of the calendar item"),
                            "title" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "title of the calendar item"),
                            "description" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "description of the calendar item"),
                            "location" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "location of the calendar item"),
                            "start" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "start time of the calendar item in ISO 8601 format (e.g., 2024-01-01T10:00:00), or start date for all day events (e.g., 2024-01-01). For event items this is a required field."),
                            "end" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "end time of the calendar entry in ISO 8601 format (e.g., 2024-01-01T11:00:00), or omitted for all day events (in which case the event will be treated as an all day event on the start date)"),
                            "due" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "due time or date of a todo item in ISO 8601 format (e.g., 2024-01-01T10:00:00 or 2024-01-01)"),
                            "priority" => Dict{String,Any}(
                                "type" => "string",
                                "enum" => ["low", "medium", "high"],
                                "description" => "priority of a todo item, either \"low\", \"medium\", or \"high\""),
                            "url" => Dict{String,Any}(
                                "type" => "string",
                                "description" => "a url associated with the calendar item")
                            ),
                        "required" => ["type", "title"])
                    )
                ),
            "required" => ["items"]
            ),
        handler=params -> begin
            local res
            try
                res = create_calendar_items(params["items"])
            catch err
                res = "failed to create calendar items: $err"
            end
            
            TextContent(; type="text", text=res)
        end
    )
    TOOLS[calendar_tool.name] = calendar_tool
end


"""
    create_calendar_items(params)

Expects an array of calendar items, where each item is a dictionary with the following structure:
- type: "event" or "todo"
- title: string (required)
- description: string (optional)
- location: string (optional)
- start: string in ISO 8601 format (e.g., "2024-01-01T10:00:00" or "2024-01-01") (required for events, optional for todos)
- end: string in ISO 8601 format (e.g., "2024-01-01T11:00:00" or "2024-01-01") (optional, only applicable for events)
- due: string in ISO 8601 format (e.g., "2024-01-01T10:00:00" or "2024-01-01") (optional, only applicable for todos)
- priority: "low", "medium", or "high" (optional, only applicable for todos)
- url: string (optional)
"""
function create_calendar_items(params)
    items = map(params) do item
        if item["type"] == "event"
            start_time = tryparse(DateTime, item["start"], dateformat"yyyy-mm-ddTHH:MM:SS")
            end_time = tryparse(DateTime, get(item, "end", ""), dateformat"yyyy-mm-ddTHH:MM:SS") 
            if isnothing(start_time)
                start_time = tryparse(Date, item["start"], dateformat"yyyy-mm-dd")
                end_time = tryparse(DateTime, get(item, "end", ""), dateformat"yyyy-mm-dd")              
            end
            if isnothing(start_time)
                throw(ErrorException("Failed to create calendar items: invalid start time format for event item. start time should be in ISO 8601 format, either as a full datetime (e.g., 2024-01-01T10:00:00) or just a date for all day events (e.g., 2024-01-01)."))
            elseif !haskey(item, "title")
                throw(ErrorException("Failed to create calendar items: missing required field \"title\" for event item."))
            end

            return Event(item["title"], get(item, "description", nothing), get(item, "location", nothing), start_time, end_time, get(item, "url", nothing))
        elseif item["type"] == "todo"
            if !haskey(item, "title")
                throw(ErrorException("Failed to create calendar items: missing required field \"title\" for todo item."))
            end

            if haskey(item, "start")
                start_time = tryparse(DateTime, item["start"], dateformat"yyyy-mm-ddTHH:MM:SS")
                if isnothing(start_time)
                    start_time = tryparse(Date, item["start"], dateformat"yyyy-mm-dd")
                end
            else
                start_time = nothing
            end

            if haskey(item, "due")
                due_time = tryparse(DateTime, item["due"], dateformat"yyyy-mm-ddTHH:MM:SS")
                if isnothing(due_time)
                    due_time = tryparse(Date, item["due"], dateformat"yyyy-mm-dd")
                end
            else
                due_time = nothing
            end            

            return Todo(item["title"], get(item, "description", nothing), get(item, "location", nothing), start_time, due_time, get(item, "priority", nothing), get(item, "url", nothing))
        else
            throw(ErrorException("Failed to create calendar items: Unsupported celendar item type \"$(item["type"])\". Supported types are \"event\" and \"todo\"."))
        end        
    end

    calendar = Calendar(items)
    ics_content = ics_calendar(calendar)
    tempfile = tempname(; suffix=".ics")
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
        return "successfully created a calendar file and opened it in the default calendar client"
    catch err
        return "failed to open the a calendar file: $err"
    end
end

push!(INIT_FUNCTIONS, init_calendar_tool)