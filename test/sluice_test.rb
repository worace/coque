require "test_helper"

TMP = `cd /tmp && pwd -P`.chomp

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
    (Sluice::Cmd["echo", "hi"] > out).run.wait
    assert_equal "hi\n", File.read(out.path)
  end

  it "can redirect a pipeline stdout" do
    out = Tempfile.new
    (Sluice::Cmd["echo", "hi"] | Sluice::Cmd["wc", "-c"] > out).run.wait

    assert_equal "3\n", File.read(out.path).lstrip
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
    assert_equal ["5"], res.map(&:lstrip)
  end

  it "can include already-redirected command in pipeline" do
    out = Tempfile.new
    c = Sluice::Cmd["wc", "-c"] > out
    (Sluice::Cmd["echo", "hi"] | c).run.wait
    assert_equal("3\n", File.read(out.path).lstrip)
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
    cmd = Sluice::Cmd["cat", "/sgsadg/asgdasdg/asgsagsg/ag"] >> "/dev/null"
    res = cmd.run.wait
    assert_equal 1, res.exit_code
  end

  it "can redirect stderr" do
    out = Tempfile.new
    cmd = Sluice::Cmd["cat", "/sgsadg/asgdasdg/asgsagsg/ag"] >> out
    cmd.run.wait
    assert_equal "cat: /sgsadg/asgdasdg/asgsagsg/ag: No such file or directory\n", File.read(out.path)
  end

  it "can manipulate context properties" do
    ctx = Sluice::Context.new
    assert_equal Hash.new, ctx.env
    refute ctx.disinherits_env?
    assert ctx.dir.is_a?(String)
    assert ctx.disinherit_env.disinherits_env?
  end

  it "can chdir" do
    ctx = Sluice::Context.new.chdir("/tmp")
    assert_equal [TMP], ctx["pwd"].run.to_a
  end

  it "can set env" do
    ctx = Sluice::Context.new.setenv(pizza: "pie")
    assert_equal ["pie"], ctx["echo", "$pizza"].run.to_a
  end

  it "can unset baseline env" do
    ENV["SLUICE_TEST"] = "testing"
    assert_equal ["testing"], Sluice::Cmd["echo", "$SLUICE_TEST"].run.to_a
    ctx = Sluice::Context.new.disinherit_env
    assert_equal [""], ctx["echo", "$SLUICE_TEST"].run.to_a
  end

  it "inits Crb with noop by default" do
    c = Sluice::Crb.new
    assert_equal [], c.run.to_a
  end

  it "can set pre/post commands for crb" do
    c = Sluice::Crb.new.pre { puts "pizza" }.post { puts "pie"}
    assert_equal ["pizza", "pie"], c.run.to_a
  end

  it "can create Crb command from a context" do
    ctx = Sluice::Context.new
    input = ctx["echo", "hi"]
    cmd = input | ctx.rb { |l| puts l.upcase }.pre { puts "pizza"}

    assert_equal ["pizza", "HI"], cmd.run.to_a
  end

  it "applies ENV settings to CRB commands" do
    ctx = Sluice::Context.new.setenv(pizza: "pie")
    cmd = ctx.rb.pre { puts ENV["pizza"]}
    assert_equal ["pie"], cmd.run.to_a
  end

  it "disinherits env for Crb" do
    ENV["SLUICE_TEST"] = "testing"
    ctx = Sluice::Context.new.disinherit_env
    cmd = ctx.rb.pre { puts ENV["SLUICE_TEST"]}
    assert_equal [""], cmd.run.to_a
    # Clearing env in subprocess doesn't affect parent
    assert_equal "testing", ENV["SLUICE_TEST"]
  end

  it "chdirs for Crb" do
    ctx = Sluice::Context.new.chdir("/tmp")
    assert_equal [TMP], ctx.rb.pre { puts Dir.pwd }.run.to_a
  end

  it "can clone partially-applied commands" do
    local = Sluice::Context.new
    echo = local["echo"]

    assert_equal ["hi"], echo["hi"].run.to_a
    assert_equal ["ho"], echo["ho"].run.to_a
  end

  it "can subsequently redirect a partially-applied command" do
    local = Sluice::Context.new
    echo = local["echo"]

    o1 = Tempfile.new
    o2 = Tempfile.new

    (echo["hi"] > o1).run.wait
    (echo["ho"] > o2).run.wait

    assert_equal "hi\n", File.read(o1)
    assert_equal "ho\n", File.read(o2)
  end

  # TODO
  # [X] Can partial-apply command args and add more using []
  # [ ] Can use partial-applied command multiple times with different STDOUTs
  # [ ] Can Fix 2> redirection operator (>err? )
  # [X] Can apply chdir, env, and disinherit_env to Crb forks
  # [X] Can fork CRB from context
  # [X] Can provide pre/post blocks for Crb
end
