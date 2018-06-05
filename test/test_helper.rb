$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require 'simplecov'

SimpleCov.start

# Maybe let's us track when forking?
# pid = Process.pid
# SimpleCov.at_exit do
#   SimpleCov.result.format! if Process.pid == pid
# end

require "coque"
require "minitest/autorun"
require "minitest/reporters"
require "minitest/spec"

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new
