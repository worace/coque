require "test_helper"

describe Sluice do
  it "tests" do
    assert true
  end

  it "has version" do
    refute_nil ::Sluice::VERSION
  end

  it "runs a command" do
    res = Sluice::Cmd["ls"].run
    assert(res.include?("Rakefile"))
    assert(res.pid > 0)
  end

  it "isn't cache by default" do
    res = Sluice::Cmd["ls"].run
    assert_equal(13, res.count)
    assert_equal(0, res.count)
  end

  it "can store as array" do
    res = Sluice::Cmd["ls"].run.to_a
    assert_equal(13, res.count)
    # Can check a second time as result is cached
    assert_equal(13, res.count)
  end

  it "can pipe together commands" do
    res = (Sluice::Cmd["ls"] | Sluice::Cmd["wc", "-l"]).run
    assert_equal(["13"], res.map(&:strip))
  end

  it "can pipe to ruby" do
    assert_equal("hi", Sluice::Cmd["echo", "hi"].run.sort.first)
    res = (Sluice::Cmd["echo", "hi"] | Sluice::Crb.new { |l| puts l.upcase }).run
    assert_equal("HI", res.sort.first)
  end

  it "can redirect stdout" do
    out = Tempfile.new
    res = (Sluice::Cmd["echo", "hi"] > out).run.wait
    assert_equal "hi\n", File.read(out.path)
  end

  it "can redirect a pipeline stdout" do
    out = Tempfile.new
    (Sluice::Cmd["echo", "hi"] | Sluice::Cmd["wc", "-c"] > out).run.wait

    assert_equal "3\n", File.read(out.path)
  end

  it "redirects with ruby" do
    out = Tempfile.new
    (Sluice::Cmd["echo", "hi"] |
     Sluice::Cmd["wc", "-c"] |
     Sluice::Crb.new { |l| puts l.to_i + 1 } > out).run.wait

    assert_equal "4\n", File.read(out.path)
  end

  it "can redirect stdin of command" do
    res = (Sluice::Cmd["head", "-n", "1"] < "/usr/share/dict/words").run.to_a
    assert_equal ["A"], res
  end

  it "can redirect stdin of pipeline" do
    res = ((Sluice::Cmd["head", "-n", "5"] < "/usr/share/dict/words") | Sluice::Cmd["wc", "-l"]).run.to_a
    assert_equal ["5"], res
  end

  it "can include already-redirected command in pipeline" do
    out = Tempfile.new
    c = Sluice::Cmd["wc", "-c"] > out
    (Sluice::Cmd["echo", "hi"] | c).run.wait
    assert_equal("3\n", File.read(out.path))
  end

  it "cannot add command with already-redirected stdin as subsequent step of pipeline" do
    redirected = (Sluice::Cmd["head", "-n", "5"] < "/usr/share/dict/words")
    assert_raises(Sluice::RedirectionError) do
      Sluice::Cmd["printf", "1\n2\n3\n4\n5\n"] | redirected
    end

    pipeline = (Sluice::Cmd["printf", "1\n2\n3\n"] | Sluice::Cmd["head", "-n", "2"])
    next_cmd = Sluice::Cmd["wc", "-c"] < "/usr/share/dict/words"
    assert_raises(Sluice::RedirectionError) do
      pipeline | next_cmd
    end
  end

  it "cannot pipe stdout-redirected command to subsequent command" do
    out = Tempfile.new
    redirected = Sluice::Cmd["echo", "hi"] > Tempfile.new
    assert_raises(Sluice::RedirectionError) do
      redirected | Sluice::Cmd["wc", "-c"]
    end

    pipeline = (Sluice::Cmd["printf", "1\n2\n3\n"] | Sluice::Cmd["head", "-n", "2"]) > Tempfile.new
    assert_raises(Sluice::RedirectionError) do
      pipeline | Sluice::Cmd["wc", "-c"]
    end
  end

  it "stores exit code in result" do
    cmd = Sluice::Cmd["cat", "/sgsadg/asgdasdg/asgsagsg/ag"]
    res = cmd.run.wait
    assert_equal 1, res.exit_code
  end
end
