module Coque
  class Rb < Cmd
    NOOP = Proc.new { }
    attr_reader :block, :pre_block, :post_block
    def initialize(context = Context.new, &block)
      if block_given?
        @block = block
      else
        @block = NOOP
      end
      @pre_block = nil
      @post_block = nil
      @context = context
    end

    def pre(&block)
      if block_given?
        @pre_block = block
      end
      self
    end

    def post(&block)
      if block_given?
        @post_block = block
      end
      self
    end

    def run
      ensure_default_fds

      pid = fork do
        STDOUT.reopen(stdout)
        Dir.chdir(context.dir)
        if context.disinherits_env?
          ENV.clear
        end
        context.env.each do |k,v|
          ENV[k] = v
        end
        @pre_block.call if @pre_block
        stdin.each_line(&@block)
        @post_block.call if @post_block
      end
      stdout.close
      Result.new(pid, stdout_read)
    end
  end
end
