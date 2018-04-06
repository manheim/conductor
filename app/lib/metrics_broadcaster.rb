class MetricsBroadcaster
  include Logging

  def initialize *platform_adapters
    @platform_adapters = platform_adapters
  end

  def broadcast! metrics, healthy
    info "broadcasting metrics [#{metrics.length}]"
    @platform_adapters.each do |adapter|
      value = value_for :shards_blocked_over_threshold, metrics
      debug "broadcasting shards_blocked_over_threshold to #{adapter} with value #{value}"
      adapter.send_scalar_metric :shards_blocked_over_threshold, value

      value = value_for :too_many_unsent_messages, metrics
      debug "broadcasting too_many_unsent_messages to #{adapter} with value #{value}"
      adapter.send_scalar_metric :unsent_message_count, value

      if UndeliverableWatcher.new.active?
        value = value_for :undeliverable_message_percentage, metrics
        debug "broadcasting undeliverable_message_percentage to #{adapter} with value #{value}"
        adapter.send_scalar_metric :undeliverable_message_percentage, value
      end

      debug "broadcasting health to #{adapter} with value #{healthy}"
      adapter.send_health healthy
    end
  end

  private

  def value_for metric_name, metrics
    metrics.detect{|m| m[:metric_name] == metric_name }[:metric_value]
  end
end
