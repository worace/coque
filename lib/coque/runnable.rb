module Coque
  module Runnable
    def to_a
      run.to_a
    end

    def to_a!
      res = run
      rows = res.to_a
      unless res.exit_code == 0
        raise "Coque Command Failed: #{self}"
      end
      rows
    end

    def success?
      run.success?
    end

    def run!
      if !success?
        raise "Coque Command Failed: #{self}"
      else
        self
      end
    end

    def run
      log_start
      get_result
    end

    def log_start
      if Coque.logger
        Coque.logger.info("Executing Coque Command: #{self.to_s}")
      end
    end
  end
end
