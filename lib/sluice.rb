require "sluice/version"

module Sluice
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
  end

  class BaseCmd
    attr_reader :stdin, :stdout

    def |(other)
      case other
      when Cmd
        Pipeline.new([self, other])
      when Crb
        Pipeline.new([self, other])
      when Pipeline
        Pipeline.new([self] + other.commands)
      end
    end

    def >(io)
      @stdout = io
      self
    end

    def stdout=(s)
      if defined? @stdout
        raise RedirectionError.new("Can't set stdout of #{self} to #{s}, is already set to #{stdout}")
      else
        @stdout = s
      end
    end

    def stdin=(s)
      if defined? @stdin
        raise RedirectionError.new("Can't set stdin of #{self} to #{s}, is already set to #{stdin}")
      else
        @stdin = s
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
    attr_reader :commands, :stdout
    def initialize(commands = [])
      @commands = commands
    end

    def to_s
      "Pipeline of #{commands.join("|")}"
    end

    def |(other)
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
      # ([nil] + commands + [nil]).each_cons do |left, right|
      #   if left.nil?
      #     start_r, start_w = IO.pipe
      #   end
      # end

      start_r, start_w = IO.pipe
      start_w.close
      commands.reduce(start_r) do |stdin, cmd|
        cmd.stdin = stdin
        next_r, next_w = IO.pipe
        cmd.stdout = next_w
        next_r
      end
    end

    def run
      stdout = stitch
      results = commands.map(&:run)
      Result.new(results.last.pid, stdout)
    end

    def >(io)
      @stdout = io
      self
    end
  end
end
