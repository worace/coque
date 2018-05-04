require "test_helper"

describe Sluice do
  it "tests" do
    assert true
  end

  it "has version" do
    refute_nil ::Sluice::VERSION
  end

  it "runs a command" do
    pid, out = Sluice::Cmd["ls"].run
    puts pid
    assert(out.readlines.map(&:chomp).include?("Rakefile"))
  end
end
