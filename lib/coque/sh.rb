module Coque
  module Cmd
    class Sh
      attr_reader :args
      def initialize(context, args)
        @context = context
        @args = args
      end

      def to_s
        "<Cmd::Sh #{args.inspect}>"
      end

      def [](*new_args)
        Cmd.new(self.context, self.args + new_args)
      end

      def run
        ensure_default_fds
        opts = {in: stdin, stdin.fileno => stdin.fileno,
                out: stdout, stdout.fileno => stdout.fileno,
                chdir: context.dir, unsetenv_others: context.disinherits_env?}

        # Redirect err to out: (e.g. for 2>&1)
        # {err: [:child, :out]}
        err_opts = if stderr
                     {err: stderr, stderr.fileno => stderr.fileno}
                   else
                     {}
                   end

        pid = spawn(context.env, args.join(" "), opts.merge(err_opts))

        stdout.close
        Result.new(pid, stdout_read)
      end
    end

  end
end
