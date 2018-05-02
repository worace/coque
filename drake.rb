require "open3"
require "pry"

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
      puts "Spawn command: #{cmd}"
      pids << cmd.run(in_read, out_write)

      in_read = out_read
      in_write = out_write
    end
    out_write.close
    [pids, out_read]
  end
end

class Cmd
  attr_reader :args
  def initialize(args)
    @args = args
  end

  def to_s
    "Cmd to run: `#{args.inspect}`"
  end

  def self.[](*args)
    puts args.inspect
    Cmd.new(args)
  end

  def command
    args.join(" ")
  end

  def run(stdin, stdout)
    spawn(args.join(" "), in: stdin, stdin => stdin, out: stdout, stdout => stdout)
  end

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

class Crb
  def initialize(&block)
    @block = block
  end

  def run(stdin, stdout)
    fork do
      STDOUT.reopen(stdout)
      stdin.each_line(&@block)
    end
  end

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

# TODO
# [ ] Stdin redirect ( < )
# [ ] Stdout redirect ( > )
# [ ] Stderr redirect ( > )
# [ ] ENV setting
# [ ] Chdir
# [ ] Backgrounding

c = Cmd['cat', '/usr/share/dict/words'] | Cmd['head'] | Crb.new { |line| puts "crb - #{line}" }
puts "pipeline: #{c}"
pids, out = c.run
puts "Spawned pids: #{pids}"
out.each_line { |l| puts l }
