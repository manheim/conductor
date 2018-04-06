class ShardWatcher
  include MetricsGenerator
  def shards_blocked
    Message.select(:shard_id).distinct
           .where('processed_count > ? AND needs_sending = ?',
                  Settings.blocked_shard_message_failure_threshold, true)
           .count
  end

  def shards_blocked_over_threshold? shards_blocked
    shards_blocked > Settings.unhealthy_shard_threshold
  end


  def metrics
    num_shards_blocked = shards_blocked
    too_many_shards_blocked = shards_blocked_over_threshold? num_shards_blocked
    generate_metric_block(:shards_blocked_over_threshold, num_shards_blocked, too_many_shards_blocked)
  end
end
