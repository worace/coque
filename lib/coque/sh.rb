module Coque
  class Sh < Cmd
    attr_reader :args, :context
    def initialize(context, args, stdin = nil, stdout = nil, stderr = nil)
      @context = context
      @args = args
      self.stdin = stdin if stdin
      self.stdout = stdout if stdout
      self.stderr = stderr if stderr
    end

    def clone
      self.class.new(context, args, stdin, stdout, stderr)
    end

    def to_s
      "<Coque::Sh #{args.inspect}>"
    end

    def inspect
      to_s
    end

    def [](*new_args)
      self.class.new(self.context, self.args + new_args)
    end

    def run
      stdin, stdoutr, stdoutw = get_default_fds
      opts = {in: stdin, stdin.fileno => stdin.fileno,
              out: stdoutw, stdoutw.fileno => stdoutw.fileno,
              chdir: context.dir, unsetenv_others: context.disinherits_env?}

      # Redirect err to out: (e.g. for 2>&1)
      # {err: [:child, :out]}
      err_opts = if stderr
                   {err: stderr, stderr.fileno => stderr.fileno}
                 else
                   {}
                 end

      pid = spawn(context.env, args.join(" "), opts.merge(err_opts))

      stdoutw.close
      Result.new(pid, stdoutr)
    end
  end
end
