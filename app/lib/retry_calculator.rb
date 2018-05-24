class RetryCalculator
  def initialize(settings)
    @failure_delay = settings[:failure_delay]
    @failure_exponent_base = settings[:failure_exponent_base]
    @max_failure_delay = settings[:max_failure_delay]
    @max_exponent_value = settings[:max_exponent_value]
  end

  def next_retry(message)
    return Time.now unless message.last_failed_at
    exponent = [message.processed_count, @max_exponent_value].min - 1
    multiplier = [1, @failure_exponent_base ** exponent].max
    delay = if @max_failure_delay.nil?
              @failure_delay * multiplier
            else
              [@max_failure_delay, @failure_delay * multiplier].min
            end
    message.last_failed_at + delay
  end
end
