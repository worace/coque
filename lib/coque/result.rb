class Coque::Result
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

  def success?
    to_a
    exit_code == 0
  end
end
