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

  def self.source(enumerable)
    Coque.rb.post do
      enumerable = enumerable.to_enum
      while !STDOUT.closed?
        begin
          el = enumerable.next
          $stderr.puts("source iter #{el}")
          $stderr.puts(STDOUT.inspect)
          puts_res = STDOUT.puts(el.to_s)
          $stderr.puts("wrote el: #{el} -- res: #{puts_res.inspect}")
          Signal.trap("PIPE", "EXIT")
        rescue StopIteration
          $stderr.puts("Rescued stop iter")
          exit
        rescue Errno::EPIPE
          $stderr.puts("broke pipe")
          exit
        end
      end
    end
  end
end
