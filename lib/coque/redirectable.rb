require "pathname"

module Coque
  module Redirectable
    attr_reader :stdin, :stdout, :stderr

    def out(io)
      clone.tap do |c|
        c.stdout = io
      end
    end

    def >(io)
      out(io)
    end

    def in(io)
      clone.tap do |c|
        c.stdin = io
      end
    end

    def <(io)
      self.in(io)
    end

    def err(io)
      clone.tap do |c|
        c.stderr = io
      end
    end

    def >=(io)
      err(io)
    end

    def getio(io, mode = "r")
      case io
      when STDERR
        io.dup
      when STDOUT
        io.dup
      when String
        File.open(io, mode)
      when Pathname
        File.open(io, mode)
      when IO
        io
      when Tempfile
        io
      else
        raise ArgumentError.new("Can't redirect stream to #{io}, must be String, Pathname, or IO")
      end
    end

    def stderr=(s)
      @stderr = getio(s, "w")
    end

    def stdout=(s)
      @stdout = getio(s, "w")
    end

    def stdin=(s)
      @stdin = getio(s, "r")
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
