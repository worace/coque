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

    def clone
      self.class.new(context, &block).pre(&pre_block).post(&post_block)
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

    def get_result
      stdin, stdoutr, stdoutw = get_default_fds

      pid = fork do
        STDOUT.reopen(stdoutw)
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
      stdoutw.close
      Result.new(pid, stdoutr)
    end
  end
end
