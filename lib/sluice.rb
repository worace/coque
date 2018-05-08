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

    def stdout=(s)
      if defined? @stdout
        raise RedirectionError.new("Can't set stdout of #{self} to #{s}, is already set to #{stdout}")
      else
        @stdout = getio(s)
      end
    end

    def stdin=(s)
      if defined? @stdin
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

  end

  class RedirectionError < RuntimeError
  end

  class Result
    attr_reader :pid
    include Enumerable

    def initialize(pid, out)
      @pid = pid
      @out = out
    end

    def each(&block)
      @out.each_line do |line|
        block.call(line.chomp)
      end
    end

    def wait
      Process.waitpid(pid)
      self
    end
  end

  class BaseCmd
    include Redirectable

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

  end

  class Cmd < BaseCmd
    attr_reader :args
    def initialize(args)
      @args = args
    end

    def to_s
      "<Cmd #{args.inspect}>"
    end

    def self.[](*args)
      Cmd.new(args)
    end

    def run
      if self.stdin.nil?
        inr, inw = IO.pipe
        inw.close
        self.stdin = inr
      end

      if self.stdout.nil?
        outr, outw = IO.pipe
        self.stdout = outw
      end

      pid = spawn(args.join(" "), in: stdin, stdin.fileno => stdin.fileno, out: stdout, stdout.fileno => stdout.fileno)
      stdout.close
      Result.new(pid, outr)
    end
  end

  class Crb < BaseCmd
    def initialize(&block)
      @block = block
    end

    def run
      pid = fork do
        STDOUT.reopen(stdout)
        stdin.each_line(&@block)
      end
      stdout.close
      Result.new(pid, stdout)
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
end
