@test_skip @testset "Email" begin
    compose_email_tool = Anglerfish.TOOLS["compose_email"]
    @test compose_email_tool.handler(Dict(
            "subject" => "",
            "to" => [],
            "cc" => [],
            "bcc" => [],
            "content" => "Test Content",
            "attachments" => []
        )).text == "successfully opened email client with precomposed email"
    @test compose_email_tool.handler(Dict(
            "subject" => "Test Subject",
            "to" => [],
            "cc" => [],
            "bcc" => [],
            "content" => "Random Text",
            "attachments" => []
        )).text == "successfully opened email client with precomposed email"
    @test compose_email_tool.handler(Dict(
            "subject" => "Test Subject",
            "to" => ["grace.hopper@navy.mil", "alan.turing@oxford.edu"],
            "cc" => ["albert.einstein@stanford.edu"],
            "bcc" => ["erwin.schroedinger@uniwien.at"],
            "content" => "Test Content",
            "attachments" => [joinpath(ro_dir, "Testdokument ÄÜÖ.md")]
        )).text == "successfully opened email client with precomposed email"
end