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

  it "can buffer to array" do
    res = Sluice::Cmd["ls"].run.to_a
    assert_equal(13, res.count)
    # Can check a second time as result is cached
    assert_equal(13, res.count)
  end
end
