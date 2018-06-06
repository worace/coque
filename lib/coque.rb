require "coque/redirectable"
require "coque/cmd"
require "coque/sh"
require "coque/rb"
require "coque/context"
require "coque/errors"
require "coque/pipeline"
require "coque/result"
require "coque/version"

module Coque
  def self.context(dir: Dir.pwd, env: {}, disinherits_env: false)
    Context.new(dir, env, disinherits_env)
  end

  def self.[](*args)
    Context.new[*args]
  end

  def self.rb(&block)
    Rb.new(Context.new, &block)
  end

  def self.pipeline(*commands)
    commands.reduce(:|)
  end
end
