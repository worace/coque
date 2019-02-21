require "coque/redirectable"
require "coque/runnable"
require "coque/cmd"
require "coque/sh"
require "coque/rb"
require "coque/context"
require "coque/errors"
require "coque/pipeline"
require "coque/result"
require "coque/version"

module Coque
  @@logger = nil
  def self.logger=(logger)
    @@logger = logger
  end

  def self.logger
    @@logger
  end

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

  def self.source(enumerable)
    Coque.rb.post { enumerable.each { |e| puts e} }
  end
end
