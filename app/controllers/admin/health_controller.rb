
module Admin
  class HealthController < Admin::ApplicationController
    def index
      undeliverable_watcher = UndeliverableWatcher.new

      Octopus.using(read_from_database) do
        @processing_rate = RateWatcher.new.get_rate
        @unsent_count = UnsentWatcher.new.unsent_count
        @shards_blocked = ShardWatcher.new.shards_blocked
        @oldest_msg_age = OldMessageWatcher.new.readable_message_age OldMessageWatcher.new.oldest_message_created_time
        @failed_count = UnsentWatcher.new.failed_count
        if undeliverable_watcher.active?
          @undeliverable_percent = undeliverable_watcher.undeliverable_percent
          @undeliverable_window = undeliverable_watcher.window_size / 60
        end
      end
    end

    def stats
      Octopus.using(read_from_database) do
        render json: {
          healthy: HealthWatcher.new.healthy?,
          health: HealthWatcher.new.health_status,
          processing_rate: RateWatcher.new.get_rate
        }
      end
    end
  end
end
