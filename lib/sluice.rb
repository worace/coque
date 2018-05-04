require "sluice/version"

module Sluice
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
  end

  class Cmd < BaseCmd
    attr_reader :args
    def initialize(args)
      @args = args
    end

    def self.[](*args)
      Cmd.new(args)
    end

    def run(stdin = nil, stdout = nil)
      if stdin.nil?
        inr, inw = IO.pipe
        inw.close
        stdin = inr
      end

      if stdout.nil?
        outr, outw = IO.pipe
        stdout = outw
      end

      pid = spawn(args.join(" "), in: stdin, stdin => stdin, out: stdout, stdout => stdout)
      stdout.close
      Result.new(pid, outr)
    end
  end

  class Crb < BaseCmd
    def initialize(&block)
      @block = block
    end

    def run(stdin = nil, stdout = nil)
      fork do
        STDOUT.reopen(stdout)
        stdin.each_line(&@block)
      end
    end
  end

  class Pipeline
    attr_reader :commands
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

    def run
      commands = self.commands
      pids = []

      in_read, in_write = IO.pipe
      out_read = nil
      out_write = nil

      while commands.any? do
        in_write.close
        out_read, out_write = IO.pipe

        cmd = commands.shift
        pids << cmd.run(in_read, out_write)

        in_read = out_read
        in_write = out_write
      end
      out_write.close
      [pids, out_read]
    end
  end
end
