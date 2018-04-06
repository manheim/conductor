class UnsentWatcher
  include MetricsGenerator

  def unsent_count
    Message.where(needs_sending: true).count
  end

  def failed_count
    Message.where(needs_sending: true)
           .where.not(processed_count: 0)
           .count
  end

  def most_failing_unsent_messages(limit = 10)
    ids = Message.where(needs_sending: true)
           .where.not(processed_count: 0)
           .order(processed_count: :desc).limit(limit).pluck(:id)
    Message.where(id: ids).to_a.sort_by {|m| [m.processed_count, m.id] }.reverse
  end

  def unsent_count_over_threshold? unsent_count
    unsent_count > Settings.unsent_message_count_threshold
  end

  def metrics
    unsent_message_count = unsent_count
    too_many_unsent_messages = unsent_count_over_threshold? unsent_message_count
    generate_metric_block(:too_many_unsent_messages, unsent_message_count, too_many_unsent_messages)
  end
end
