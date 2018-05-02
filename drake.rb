require "open3"
require "pry"

def run_fork(stdin, stdout, &block)
  fork do
    STDOUT.reopen(stdout)
    stdin.each_line(&block)
  end
end

def three_step
  writers = []
  a_in_read, a_in_write = IO.pipe
  a_out_read, a_out_write = IO.pipe

  a_unused = [a_out_write]

  p1 = spawn('echo "a\nb\nc\nab\n"',
             out: a_out_write,
             a_out_write => a_out_write,
             in: a_in_read,
             a_in_read => a_in_read)

  b_out_read, b_out_write = IO.pipe
  b_unused = [b_out_write]

  a_unused.each(&:close)
  run_fork(a_out_read, b_out_write) { |l| puts "~~ - #{l}" }

  c_out_read, c_out_write = IO.pipe
  c_unused = [c_out_write]

  p2 = spawn('grep a',
             out: c_out_write,
             c_out_write => c_out_write,
             in: b_out_read,
             b_out_read => b_out_read)
  b_unused.each(&:close)

  # Q: Why do we have to close these? do the spawned processes not close them?
  c_unused.each(&:close)
  puts c_out_read.read
end

three_step

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

  def combine
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
    # Open3.pipeline(*commands.map(&:args))
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
  end
end

c = Cmd['cat', '/usr/share/dict/words'] | Cmd['head'] | Crb.new { |line| puts "crb - #{line}" }
puts "pipeline: #{c}"
pids, out = c.run
puts "Spawned pids: #{pids}"
puts out.read
