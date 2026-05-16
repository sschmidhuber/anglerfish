@testset "Skill" begin
    @testset "Parse Skill" begin
        skill = Anglerfish.parse_skill(joinpath(skill_dir, "sed-file-editing"))
        @test !isnothing(skill)
        @test skill.name == "sed-file-editing"
        @test startswith(skill.description, "Edit files in-place using sed (stream editor).")
        @test skill.skilldir == joinpath(skill_dir, "sed-file-editing")

        # invalid path
        skill = Anglerfish.parse_skill(joinpath(skill_dir, "non_existent_skill"))
        @test isnothing(skill)

        # invalid SKILL.md (missing frontmatter)
        skill = Anglerfish.parse_skill(joinpath(skill_dir, "no-frontmatter"))
        @test isnothing(skill)

        # invalid SKILL.md (missing name in frontmatter)
        skill = Anglerfish.parse_skill(joinpath(skill_dir, "no-name"))
        @test isnothing(skill)
    end

    @testset "Scan" begin
        skills = Anglerfish.scan_skills(skill_dir)
        @test length(skills) == 3
        @test skills[1].name == "d2-diagrams"
        @test startswith(skills[1].description, "'Create architecture, flow, sequence, entity-relationship, and class diagrams using D2 language and the d2 CLI.")
        @test skills[1].skilldir == joinpath(skill_dir, "d2-diagrams")

        # invalid skill directory
        skills = Anglerfish.scan_skills(joinpath(skill_dir, "non_existent_directory"))
        @test length(skills) == 0

        # skill directory with invalid SKILL.md
        skills = Anglerfish.scan_skills(joinpath(skill_dir, "no-frontmatter"))
        @test length(skills) == 0

        # skill directory with invalid SKILL.md (missing name in frontmatter)
        skills = Anglerfish.scan_skills(joinpath(skill_dir, "no-name"))
        @test length(skills) == 0

        # skill directory with non-file SKILL.md
        skills = Anglerfish.scan_skills(joinpath(skill_dir, "d2-diagrams", "references"))
        @test length(skills) == 0
    end

    @testset "Skill Activation Tool" begin
        skill_activation_tool = Anglerfish.TOOLS["skill"]

        # valid skill
        result = skill_activation_tool.handler(Dict("name" => "scientific-plots"))
        @test occursin("scientific-plots", result.text)

        # invalid skill
        result = skill_activation_tool.handler(Dict("name" => "non_existent"))
        @test result.text == "Skill 'non_existent' not found"
    end
end