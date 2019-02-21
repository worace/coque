module Coque
  module Runnable
    def to_a
      run.to_a
    end

    def success?
      run.success?
    end

    def run!
      if !success?
        raise "Coque Command Failed: #{self}"
      end
    end

    def run
      log_start
      start_time = Time.now
      result = get_result
      end_time = Time.now
      log_end(end_time - start_time)
      result
    end

    def log_end(seconds)
      if Coque.logger
        Coque.logger.info("Coque Command: #{self.to_s} finished in #{seconds} seconds.")
      end
    end

    def log_start
      if Coque.logger
        Coque.logger.info("Executing Coque Command: #{self.to_s}")
      end
    end
  end
end
