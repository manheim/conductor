class UndeliverableWatcher
  include MetricsGenerator

  attr_reader :window_size

  def initialize
    @window_size = 10.minutes
  end

  def metrics
    generate_metric_block :undeliverable_message_percentage, undeliverable_percent, unhealthy?
  end

  # percent is returned from 0 -> 100
  def undeliverable_percent
    total, fails = total_count, messages_given_up_on_count
    if total == 0
      return 0
    elsif fails == 0
      return 0
    else
      return (fails / total) * 100
    end
  end

  def threshold_set?
    !([nil, -1].include? threshold)
  end

  def active?
    !([nil, -1].include? threshold)
  end

  private

  def total_count
    window_start = begining_of_window
    Message.where('last_failed_at > ? OR succeeded_at > ?',
                  window_start, window_start).count.to_f
  end

  def messages_given_up_on_count
    window_start = begining_of_window
    Message.where('(succeeded_at is NULL AND needs_sending = 0) AND (last_failed_at > ?)',
                  window_start)
    .count.to_f
  end

  def begining_of_window
    DateTime.now - @window_size
  end

  def unhealthy?
    undeliverable_percent >= threshold
  end

  def threshold
    Settings.undeliverable_percent_health_threshold
  end

end
