require "sluice/version"
require "pathname"

module Sluice
  module Redirectable
    attr_reader :stdin, :stdout, :stderr

    def >(io)
      self.stdout = io
      self
    end

    def <(io)
      self.stdin = io
      self
    end

    def >>(io)
      self.stderr = io
      self
    end

    def getio(io)
      case io
      when String
        File.open(io)
      when Pathname
        File.open(io)
      when IO
        io
      when File
        io
      when Tempfile
        io
      else
        raise ArgumentError.new("Can't redirect stream to #{io}, must be String, Pathname, or IO")
      end
    end

    def stdin_redirected?
      defined? @stdin
    end

    def stdout_redirected?
      defined? @stdout
    end

    def stderr_redirected?
      defined? @stderr
    end

    def stderr=(s)
      if stderr_redirected?
        raise RedirectionError.new("Can't set stderr of #{self} to #{s}, is already set to #{stderr}")
      else
        @stderr = getio(s)
      end
    end

    def stdout=(s)
      if stdout_redirected?
        raise RedirectionError.new("Can't set stdout of #{self} to #{s}, is already set to #{stdout}")
      else
        @stdout = getio(s)
      end
    end

    def stdin=(s)
      if stdin_redirected?
        raise RedirectionError.new("Can't set stdin of #{self} to #{s}, is already set to #{stdin}")
      else
        @stdin = getio(s)
      end
    end

    def verify_redirectable(other)
      if self.stdout_redirected?
        raise RedirectionError.new("Can't pipe #{self} into #{other} -- #{self}'s STDIN is already redirected")
      end

      if other.stdin_redirected?
        raise RedirectionError.new("Can't pipe #{self} into #{other} -- #{other}'s STDIN is already redirected")
      end
    end

    private

    def stdout_read
      if defined? @stdout_read
        @stdout_read
      else
        nil
      end
    end
  end

  class RedirectionError < RuntimeError
  end

  class Result
    attr_reader :pid, :exit_code
    include Enumerable

    def initialize(pid, out)
      @pid = pid
      @out = out
    end

    def each(&block)
      @out.each_line do |line|
        block.call(line.chomp)
      end
      unless defined? @exit_code
        wait
      end
    end

    def wait
      _, status = Process.waitpid2(pid)
      @exit_code = status.exitstatus
      self
    end
  end

  class BaseCmd
    include Redirectable
    attr_reader :context

    def |(other)
      verify_redirectable(other)
      case other
      when Cmd
        Pipeline.new([self, other])
      when Crb
        Pipeline.new([self, other])
      when Pipeline
        Pipeline.new([self] + other.commands)
      end
    end

    def ensure_default_fds
      if self.stdin.nil?
        inr, inw = IO.pipe
        inw.close
        self.stdin = inr
      end

      if self.stdout.nil?
        outr, outw = IO.pipe
        self.stdout = outw
        # only used for Result if this is the last command in a pipe
        @stdout_read = outr
      end
    end
  end

  class Cmd < BaseCmd
    attr_reader :args
    def initialize(context, args)
      @context = context
      @args = args
    end

    def to_s
      "<Cmd #{args.inspect}>"
    end

    def self.[](*args)
      Context.new[*args]
    end

    def run
      ensure_default_fds
      opts = {in: stdin, stdin.fileno => stdin.fileno,
              out: stdout, stdout.fileno => stdout.fileno,
              chdir: context.dir, unsetenv_others: !context.inherits_env?}

      # Redirect err to out:
      # {err: [:child, :out]}
      err_opts = if stderr
                   {err: stderr, stderr.fileno => stderr.fileno}
                 else
                   {}
                 end

      pid = spawn(context.env, args.join(" "), opts.merge(err_opts))

      stdout.close
      Result.new(pid, stdout_read)
    end
  end

  class Crb < BaseCmd
    NOOP = Proc.new { }
    attr_reader :block, :pre_block, :post_block
    def initialize(context = Context.new, &block)
      if block_given?
        @block = block
      else
        @block = NOOP
      end
      @pre_block = nil
      @post_block = nil
      @context = context
    end

    def pre(&block)
      if block_given?
        @pre_block = block
      end
      self
    end

    def post(&block)
      if block_given?
        @post_block = block
      end
      self
    end

    def run
      ensure_default_fds

      pid = fork do
        STDOUT.reopen(stdout)
        context.env.each do |k,v|
          ENV[k] = v
        end
        @pre_block.call if @pre_block
        stdin.each_line(&@block)
        @post_block.call if @post_block
      end
      stdout.close
      Result.new(pid, stdout_read)
    end
  end

  class Pipeline
    include Redirectable

    attr_reader :commands
    def initialize(commands = [])
      @commands = commands
    end

    def to_s
      "<Pipeline #{commands.join(" | ")} >"
    end

    def |(other)
      verify_redirectable(other)
      case other
      when Pipeline
        Pipeline.new(commands + other.commands)
      when Cmd
        Pipeline.new(commands + [other])
      when Crb
        Pipeline.new(commands + [other])
      end
    end

    def stitch
      # Set head in
      if commands.first.stdin.nil?
        start_r, start_w = IO.pipe
        start_w.close
        commands.first.stdin = start_r
      end

      # Connect intermediate in/outs
      commands.each_cons(2) do |left, right|
        read, write = IO.pipe
        left.stdout = write
        right.stdin = read
      end

      # Set tail out
      if self.stdout
        commands.last.stdout = stdout
        stdout
      elsif commands.last.stdout
        commands.last.stdout
      else
        next_r, next_w = IO.pipe
        commands.last.stdout = next_w
        next_r
      end
    end

    def run
      stdout = stitch
      results = commands.map(&:run)
      Result.new(results.last.pid, stdout)
    end
  end

  class Context
    attr_reader :dir, :env
    def initialize(dir = Dir.pwd, env = {}, inherits_env = true)
      @dir = dir
      @env = env
      @inherits_env = inherits_env
    end

    def inherits_env?
      @inherits_env
    end

    def [](*args)
      Cmd.new(self, args)
    end

    def rb(&block)
      Crb.new(self, &block)
    end

    def chdir(new_dir)
      Context.new(new_dir, env, inherits_env?)
    end

    def setenv(opts)
      opts = opts.map { |k,v| [k.to_s, v.to_s] }.to_h
      Context.new(dir, self.env.merge(opts), inherits_env?)
    end

    def disinherit_env
      Context.new(dir, {}, false)
    end
  end
end
