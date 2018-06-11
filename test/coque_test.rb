require "test_helper"

TMP = `cd /tmp && pwd -P`.chomp
TEST_FILE = "./test/words.txt"

describe Coque do
  it "tests" do
    assert true
  end

  it "has version" do
    refute_nil ::Coque::VERSION
  end

  it "runs a command" do
    res = Coque["ls"].run
    assert(res.include?("Rakefile"))
    assert(res.pid > 0)
  end

  it "doesn't cache results" do
    res = Coque["printf", '"1\n\2\n3\n"'].run
    assert_equal(3, res.count)
    assert_equal(0, res.count)
  end

  it "can store as array" do
    res = Coque["printf", '"1\n\2\n3\n"'].run.to_a
    assert_equal(3, res.count)
    # Can check a second time as result is cached
    assert_equal(3, res.count)
  end

  it "can pipe together commands" do
    res = (Coque["printf", '"1\n\2\n3\n"'] | Coque["wc", "-l"]).run
    assert_equal(["3"], res.map(&:strip))
  end

  it "can pipe to ruby" do
    assert_equal("hi", Coque["echo", "hi"].run.sort.first)
    res = (Coque["echo", "hi"] | Coque::Rb.new { |l| puts l.upcase }).run
    assert_equal("HI", res.sort.first)
  end

  it "can combine multiple pipelines with pipe" do
    p1 = Coque["printf", '"a\nb\nab\n1\n2\n"'] | Coque["head", "-n", "3"]
    p2 = Coque["grep", "a"] | Coque["tail", "-n", "1"]

    combined = p1 | p2

    assert_equal ["ab"], combined.run.to_a

  end

  it "can redirect stdout" do
    out = Tempfile.new
    (Coque["echo", "hi"] > out).run.wait
    assert_equal "hi\n", File.read(out.path)
  end

  it "can redirect various IO types" do
    c = Coque["echo", "hi"]
    Dir.mktmpdir("coque_tests") do |dir|
      path = dir + "/test.txt"

      (c > File.open(path, "w")).run.wait
      assert_equal ["hi\n"], File.readlines(path).to_a

      FileUtils.rm(path)

      (c > path).run.wait
      assert_equal ["hi\n"], File.readlines(path).to_a

      FileUtils.rm(path)
      (c > Pathname(path)).run.wait
      assert_equal ["hi\n"], File.readlines(path).to_a

      FileUtils.rm(path)
      (c > File.open(path, "w")).run.wait
      assert_equal ["hi\n"], File.readlines(path).to_a

      # Raises on unhandled type
      assert_raises ArgumentError do
        c > Object.new
      end
    end

  end

  it "can redirect a pipeline stdout" do
    out = Tempfile.new
    (Coque["echo", "hi"] | Coque["wc", "-c"] > out).run.wait

    assert_equal "3\n", File.read(out.path).lstrip
  end

  it "redirects with ruby" do
    out = Tempfile.new
    (Coque["echo", "hi"] |
     Coque["wc", "-c"] |
     Coque::Rb.new { |l| puts l.to_i + 1 } > out).run.wait

    assert_equal "4\n", File.read(out.path)
  end

  it "can redirect stdin of command" do
    res = (Coque["head", "-n", "1"] < TEST_FILE).run.to_a
    assert_equal ["acculturation"], res
  end

  it "can redirect stdin of pipeline" do
    res = ((Coque["head", "-n", "5"] < TEST_FILE) | Coque["wc", "-l"]).run.to_a
    assert_equal ["5"], res.map(&:lstrip)
  end

  it "can include already-redirected command in pipeline" do
    out = Tempfile.new
    c = Coque["wc", "-c"] > out
    (Coque["echo", "hi"] | c).run.wait
    assert_equal("3\n", File.read(out.path).lstrip)
  end

  it "Changes stdin of command when including it in pipeline" do
    lines = Coque["printf", "\"1\n2\n3\n\""]
    redirected = (Coque["head", "-n", "5"] < TEST_FILE)

    assert_equal ["acculturation", "balustrades", "bantamweights", "begat", "brisk"], redirected.to_a
    assert_equal ["1", "2", "3"], (lines | redirected).to_a
  end

  it "Changes stdin of RB command when includign it in pipeline" do
    lines = Coque["printf", "\"1\n2\n3\n\""]
    redirected = (Coque.rb { |l| puts l.upcase } < TEST_FILE)
    assert_equal "ACCULTURATION", redirected.to_a.first

    assert_equal ["1", "2", "3"], (lines | redirected).to_a
  end

  it "uses tail command's stdout when including in pipeline" do
    out = Tempfile.new
    lines = Coque["printf", "\"1\n2\n3\n\""]
    redirected = (Coque["head", "-n", "5"] > out)
    (lines | redirected).run.wait
    assert_equal "1\n2\n3\n", File.read(out)
  end

  it "stores exit code in result" do
    cmd = Coque["cat", "/sgsadg/asgdasdg/asgsagsg/ag"] >= "/dev/null"
    res = cmd.run.wait
    assert_equal 1, res.exit_code
  end

  it "can redirect stderr" do
    out = Tempfile.new
    cmd = Coque["cat", "/sgsadg/asgdasdg/asgsagsg/ag"] >= out
    cmd.run.wait
    assert_equal "cat: /sgsadg/asgdasdg/asgsagsg/ag: No such file or directory\n", File.read(out.path)
  end

  it "can manipulate context properties" do
    ctx = Coque::Context.new
    assert_equal Hash.new, ctx.env
    refute ctx.disinherits_env?
    assert ctx.dir.is_a?(String)
    assert ctx.disinherit_env.disinherits_env?
  end

  it "can chdir" do
    ctx = Coque::Context.new.chdir("/tmp")
    assert_equal [TMP], ctx["pwd"].run.to_a
  end

  it "can set env" do
    ctx = Coque::Context.new.setenv(pizza: "pie")
    assert_equal ["pie"], ctx["echo", "$pizza"].run.to_a
  end

  it "can unset baseline env" do
    ENV["COQUE_TEST"] = "testing"
    assert_equal ["testing"], Coque["echo", "$COQUE_TEST"].run.to_a
    ctx = Coque::Context.new.disinherit_env
    assert_equal [""], ctx["echo", "$COQUE_TEST"].run.to_a
  end

  it "inits Rb with noop by default" do
    c = Coque::Rb.new
    assert_equal [], c.run.to_a
  end

  it "can set pre/post commands for crb" do
    c = Coque::Rb.new.pre { puts "pizza" }.post { puts "pie"}
    assert_equal ["pizza", "pie"], c.run.to_a
  end

  it "can create Rb command from a context" do
    ctx = Coque::Context.new
    input = ctx["echo", "hi"]
    cmd = input | ctx.rb { |l| puts l.upcase }.pre { puts "pizza"}

    assert_equal ["pizza", "HI"], cmd.run.to_a
  end

  it "applies ENV settings to CRB commands" do
    ctx = Coque::Context.new.setenv(pizza: "pie")
    cmd = ctx.rb.pre { puts ENV["pizza"]}
    assert_equal ["pie"], cmd.run.to_a
  end

  it "disinherits env for Rb" do
    ENV["COQUE_TEST"] = "testing"
    ctx = Coque::Context.new.disinherit_env
    cmd = ctx.rb.pre { puts ENV["COQUE_TEST"]}
    assert_equal [""], cmd.run.to_a
    # Clearing env in subprocess doesn't affect parent
    assert_equal "testing", ENV["COQUE_TEST"]
  end

  it "chdirs for Rb" do
    ctx = Coque::Context.new.chdir("/tmp")
    assert_equal [TMP], ctx.rb.pre { puts Dir.pwd }.run.to_a
  end

  it "can clone partially-applied commands" do
    local = Coque::Context.new
    echo = local["echo"]

    assert_equal ["hi"], echo["hi"].run.to_a
    assert_equal ["ho"], echo["ho"].run.to_a
    assert_equal "3", (echo["ho"] | Coque["wc", "-c"]).run.first.lstrip
  end

  it "can subsequently redirect a partially-applied command" do
    local = Coque::Context.new
    echo = local["echo"]

    o1 = Tempfile.new
    o2 = Tempfile.new

    (echo["hi"] > o1).run.wait
    (echo["ho"] > o2).run.wait

    assert_equal "hi\n", File.read(o1)
    assert_equal "ho\n", File.read(o2)
  end

  it "can create context from the top-level namespace" do
    assert Coque.context.is_a?(Coque::Context)

    assert_equal "/tmp", Coque.context(dir: "/tmp").dir
    assert_equal "pie", Coque.context(env: {pizza: "pie"}).env[:pizza]
    assert Coque.context(disinherits_env: true).disinherits_env?
  end

  it "can use top-level helper method to construct pipeline of multiple commands" do
    echo = Coque["echo", "-n", "hi"]
    wc = Coque["wc", "-c"]

    pipe = Coque.pipeline(echo, wc)
    assert_equal ["2"], pipe.run.to_a.map(&:lstrip)
  end

  it "can create Rb commands from top-level" do
    assert_equal ["hi"], Coque.rb.pre { puts "hi" }.run.to_a
  end

  it "can re-use Sh with different out streams" do
    local = Coque::Context.new
    echo = local["echo", "hi"]

    o1 = Tempfile.new
    o2 = Tempfile.new

    (echo > o1).run.wait
    (echo > o2).run.wait

    assert_equal "hi\n", File.read(o1)
    assert_equal "hi\n", File.read(o2)
  end

  it "can re-use Rb with different out streams" do
    local = Coque::Context.new
    echo = local.rb.pre { puts "hi" }

    o1 = Tempfile.new
    o2 = Tempfile.new

    (echo > o1).run.wait
    (echo > o2).run.wait

    assert_equal "hi\n", File.read(o1)
    assert_equal "hi\n", File.read(o2)
  end

  it "can re-use a command in different pipelines" do
    e = Coque["echo", "hi"]

    assert_equal ["3"], (e | Coque["wc", "-c"]).run.to_a.map(&:lstrip)

    assert_equal ["h"], (e | Coque["head", "-c", "1"]).run.to_a
  end

  it "can use pre/post blocks of Rb commands to maintain state" do
    rb_wc = Coque.rb { @lines += 1 }.pre { @lines = 0 }.post { puts @lines }

    assert_equal "15", (rb_wc < TEST_FILE).run.first
  end

  it "can use ruby enumerable as Source" do
    colors = ["red", "green", "purple"]
    nums = 1..50
    assert_equal "50", (Coque.source(nums) | Coque["wc", "-l"]).run.first.lstrip
    colors = ["red", "green", "purple"]
    assert_equal ["Red", "gReen", "puRple"], (Coque.source(colors) | Coque["sed", "\"s/r/R/\""]).run.to_a
  end

  # TODO
  # [X] Can partial-apply command args and add more using []
  # [X] Can apply chdir, env, and disinherit_env to Rb forks
  # [X] Can fork CRB from context
  # [X] Can provide pre/post blocks for Rb
  # [X] Can use partial-applied command multiple times with different STDOUTs
  # [X] Can Fix 2> redirection operator (>err? >=)
  # [X] Coque.pipeline helper method
  # [X] Rename to Coque
  # [X] Coque.context helper method
  # [ ] Append-mode redirection operators (>= and >>err)
  # [-] Usage examples in readme
  # [X] Intro text
  # [ ] Theme image for readme (https://upload.wikimedia.org/wikipedia/commons/3/36/Nyst_1878_-_Cerastoderma_parkinsoni_R-klep.jpg ?)
  # [X] Allow mutliple pipe usages for single command
  # [X] Add Coque.source to dump RB enumerables into pipelines
end
