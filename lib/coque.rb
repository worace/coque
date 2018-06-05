require "coque/base_cmd"
require "coque/cmd"
require "coque/context"
require "coque/errors"
require "coque/pipeline"
require "coque/redirectable"
require "coque/result"
require "coque/version"

module Coque
  def self.context(dir: Dir.pwd, env: {}, disinherits_env: false)
    Context.new(dir, env, disinherits_env)
  end

  def self.[](*args)
    Context.new[*args]
  end

  def self.pipeline(*commands)
    commands.reduce(:|)
  end
end
