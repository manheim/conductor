module Logging
  def self.included base
    base.send(:include, ::NewRelic::Agent::Instrumentation::ControllerInstrumentation)
    base.send(:include, ::NewRelic::Agent::MethodTracer)
    base.extend ClassAndInstanceMethods
    base.send(:include, ClassAndInstanceMethods)
  end

  module ClassAndInstanceMethods
    def log_error(e)
      NewRelic::Agent.notice_error(e)
      log("Error occurred: #{[e.message] + e.backtrace}", :error)
    end

    def debug(message)
      log(message, :debug)
    end

    def info(message)
      log(message, :info)
    end

    def warn(message)
      log(message, :warn)
    end

    def error(message)
      log(message, :error)
    end

    def log(message, level = :info)
      full_message = "[#{self.class.name}][#{Process.pid}][#{Thread.current.object_id}] - #{message}"
      Rails.logger.public_send(level, full_message)
    end
  end
end
