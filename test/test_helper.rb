$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "sluice"

require "minitest/autorun"
require "minitest/reporters"
require "minitest/spec"

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new
