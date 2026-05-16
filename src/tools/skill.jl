
struct Skill
    name::String
    description::String
    skilldir::String
end

function Base.show(io::IO, s::Skill)
    print(io, "$(s.name): $(s.description)")
end

const SKILLS = Dict{String,Skill}()


"""
    parse_skill(path::String)::Skill

Parses the `SKILL.md` file in the given directory path and returns a `Skill` struct containing the name, description and
path of the skill. If the `SKILL.md` file is not found or cannot be parsed, returns `nothing`.

Arguments:
- `path`: The directory path whithin the skill is defined. The function will look for a `SKILL.md` file in the given directory.

Returns:
- `Skill` struct containing the name, description and path of the skill if the `SKILL.md` file is found and successfully parsed, otherwise returns `nothing`.
"""
function parse_skill(path::String)::Union{Nothing,Skill}
    local name, description
    skill_md_path = joinpath(path, "SKILL.md")

    if !isfile(skill_md_path)
        @warn "no file found at $skill_md_path"
        return nothing
    end

    try
        content = read(skill_md_path, String)
        
        # extract frontmatter
        frontmatter_regex = r"^---\s*\n(.*?)\n---\s*$"ms
        frontmatter_match = match(frontmatter_regex, content)

        if isnothing(frontmatter_match)
            @warn "no frontmatter found in SKILL.md at $skill_md_path"
            return nothing
        end
        frontmatter = frontmatter_match.captures[1]

        # get name and description from frontmatter
        name_regex = r"\s*name:\s*(.+)"i
        description_regex = r"\s*description:\s*(.+)"i
        name_match = match(name_regex, frontmatter)
        description_match = match(description_regex, frontmatter)
        if name_match === nothing || description_match === nothing
            @warn "name or description not found in frontmatter of SKILL.md at $skill_md_path"
            return nothing
        end
        name = strip(name_match.captures[1])
        description = strip(description_match.captures[1])
    catch error
        @warn "failed to parse SKILL.md file at $skill_md_path: $error"
        return nothing
    end

    return Skill(name, description, path)
end


"""
    scan(directory::String)::Vector{Skill}

Scans the given directory for subdirectories containing a `SKILL.md` file, parses the file and returns a vector of
`Skill` structs representing the skills found in the directory.
"""
function scan_skills(directory::String)::Vector{Skill}
    skills = Skill[]
    if !isdir(directory)
        @warn "directory $directory does not exist or is not a directory"
        return skills
    end

    for entry in readdir(directory, join=true)
        if isdir(entry)
            skill = parse_skill(entry)
            if !isnothing(skill)
                push!(skills, skill)
            end
        end
    end

    return skills
end


"""
    skill_activation(name::String)::TextContent

Given the name of a skill, returns the content of the corresponding `SKILL.md` file as a `TextContent` object. If the
skill is not found or the `SKILL.md` file cannot be read, returns a `TextContent` object containing an error message.
"""
function skill_activation(name::String)::TextContent
    if haskey(SKILLS, name)
        skill = SKILLS[name]
    else
        return TextContent(; text="Skill '$name' not found")        
    end

    try
        return TextContent(; text=read(joinpath(skill.skilldir, "SKILL.md"), String))
    catch error
        return TextContent(; text="Failed to read SKILL.md for skill '$name': $error")
    end    
end


function init_skill_activation_tool(config::Dict)
    @info "initialize skill activation tool"
    local skill_directories
    try
        skill_directories = config["directories"]["skills"]
    catch error
        @warn "failed to read skill directories from config: $error"
        return nothing
    end

    if isempty(skill_directories)
        @warn "no skill directories specified in config"
        return nothing
    end

    for dir in skill_directories
        for skill in scan_skills(dir)
            SKILLS[skill.name] = skill
        end
    end

    available = if isempty(SKILLS)
        ""
    else
        "\n* " * join(sort(collect(keys(SKILLS))), "\n* ", "")
    end

    skill_activation_tool = MCPTool(
        name="skill",
        description="Activates a skill by name, returning the full content of the skill's SKILL.md file. Available skills: $available.",
        parameters=[
            ToolParameter(
                name = "name",
                type = "str",
                description = "the name of the skill to activate",
                required = true
            )
        ],
        handler = params -> skill_activation(params["name"])
    )

    TOOLS[skill_activation_tool.name] = skill_activation_tool
end

push!(INIT_FUNCTIONS, init_skill_activation_tool)
