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

  it "can redirect" do
    out = Tempfile.new
    res = (Sluice::Cmd["echo", "hi"] > out).run
    Process.waitpid(res.pid)
    assert_equal "hi\n", File.read(out.path)
  end

  it "can redirect a pipeline" do
    out = Tempfile.new
    res = (Sluice::Cmd["echo", "hi"] | Sluice::Cmd["wc", "-c"] > out).run
    Process.waitpid(res.pid)

    assert_equal "3\n", File.read(out.path)
  end

  it "stitches a pipeline" do
    p = (Sluice::Cmd["ls"] | Sluice::Cmd["wc", "-l"])
    res = p.run
    assert_equal(["13"], res.to_a)
  end
end
