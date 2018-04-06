class HealthWatcher
  def healthy?
    !(too_many_shards_blocked || any_message_too_old || too_many_unsent_messages || too_many_undeliverable_messages)
  end

  def health_status
    [].tap do |arr|
      arr << shard_watcher_metrics
      arr << unsent_watcher_metrics
      arr << old_message_watcher_metrics
      arr << traffic_watcher_metrics
      arr << undeliverable_watcher_metrics if undeliverable_watcher_active?
    end
  end

  def self.is_healthy? metrics
    metric_in_violation = metrics.detect { |metric| metric[:in_violation] }
    metric_in_violation.nil?
  end

  private

  def shard_watcher_metrics
    ShardWatcher.new.metrics
  end

  def too_many_shards_blocked
    shard_watcher_metrics[:in_violation]
  end

  def old_message_watcher_metrics
    OldMessageWatcher.new.metrics
  end

  def any_message_too_old
    old_message_watcher_metrics[:in_violation]
  end

  def unsent_watcher_metrics
    UnsentWatcher.new.metrics
  end

  def too_many_unsent_messages
    unsent_watcher_metrics[:in_violation]
  end

  def traffic_watcher_metrics
    TrafficWatcher.new.metrics
  end

  def no_message_received_lately
    traffic_watcher_metrics[:in_violation]
  end

  def undeliverable_watcher_metrics
    UndeliverableWatcher.new.metrics
  end

  def too_many_undeliverable_messages
    if undeliverable_watcher_active?
      undeliverable_watcher_metrics[:in_violation]
    else
      false
    end
  end

  def undeliverable_watcher_active?
    UndeliverableWatcher.new.active?
  end
end
