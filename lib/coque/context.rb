module Coque
  class Context
    attr_reader :dir, :env
    def initialize(dir = Dir.pwd, env = {}, disinherits_env = false)
      @dir = dir
      @env = env
      @disinherits_env = disinherits_env
    end

    def disinherits_env?
      @disinherits_env
    end

    def [](*args)
      Cmd.new(self, args)
    end

    def rb(&block)
      RbCmd.new(self, &block)
    end

    def chdir(new_dir)
      Context.new(new_dir, env, disinherits_env?)
    end

    def setenv(opts)
      opts = opts.map { |k,v| [k.to_s, v.to_s] }.to_h
      Context.new(dir, self.env.merge(opts), disinherits_env?)
    end

    def disinherit_env
      Context.new(dir, {}, true)
    end
  end
end
