require "pathname"

module Coque
  module Redirectable
    attr_reader :stdin, :stdout, :stderr

    def >(io)
      clone.tap do |c|
        c.stdout = io
      end
    end

    def <(io)
      clone.tap do |c|
        c.stdin = io
      end
    end

    def >>(io)
      clone.tap do |c|
        c.stderr = io
      end
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
end
