class SendingDecider

  def initialize message
    @message = message
    @send_succeeded = nil
  end

  def needs_sending?
    if has_max? && at_or_above_max?
      return false
    end
    if @send_succeeded
      return false
    end
    @message.needs_sending
  end

  def send_succeeded
    @send_succeeded = true
  end
  private

  def has_max?
    !([nil, -1, ''].include? Settings.max_number_of_retries)
  end

  def at_or_above_max?
    @message.processed_count >= Settings.max_number_of_retries
  end

end
