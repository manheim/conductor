class RetryCalculator
  def initialize(settings)
    @failure_delay = settings[:failure_delay]
    @failure_exponent_base = settings[:failure_exponent_base]
  end

  def next_retry(message)
    return Time.now unless message.last_failed_at
    multiplier = [1, @failure_exponent_base ** (message.processed_count - 1)].max
    message.last_failed_at + @failure_delay * multiplier
  end
end
