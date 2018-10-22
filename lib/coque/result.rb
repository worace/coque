class Coque::Result
  attr_reader :pid, :exit_code
  include Enumerable

  def initialize(pid, out)
    @pid = pid
    @out = out
  end

  def each(&block)
    begin
      @out.each_line do |line|
        block.call(line.chomp)
      end
    rescue IOError
      # If the command was redirected to an existing standard output stream,
      # i.e. $stdout or $stderr, that output will be streamed as executed, so
      # attempting to read from it here will fail.
      # There may be a better way to handle this case, but for now this is working ok.
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

  def success?
    wait
    exit_code == 0
  end
end
