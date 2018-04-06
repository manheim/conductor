module Concerns
  module Workers
    extend ActiveSupport::Concern

    included do
      send(:include, Logging)
      send(:include, InstanceMethods)
    end

    module InstanceMethods
      def with_thread_error_handling(name, retry_on_error)
        begin
          begin
            perform_action_with_newrelic_trace(name: name, category: :task)  do
              yield
            end
          ensure
            ActiveRecord::Base.clear_active_connections!
          end
        rescue => e
          log_error(e)
          if retry_on_error
            sleep 1
            retry
          else
            return
          end
        rescue Exception => e
          error("An unrecoverable error has occurred. Going to log and reraise.")
          log_error(e)
          raise
        end
      end

      def with_worker_lock(name)
        if Message.advisory_lock_exists?(name)
          info "Lock already exists for name \"#{name}\", another worker must be running"
          if Rails.env.test?
            info Message.connection.execute("show processlist").to_a.join("\n")
          end
        end

        Message.with_advisory_lock(name, 0) do
          info "Aquired advisory lock for #{name}"
          yield
        end
      end
    end
  end
end
