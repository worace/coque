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
    assert_equal("CODE_OF_CONDUCT.md", Sluice::Cmd["ls"].run.first)
    res = (Sluice::Cmd["ls"] | Sluice::Crb.new { |l| puts l.downcase }).run
    assert_equal("code_of_conduct.md", res.first)
  end
end
