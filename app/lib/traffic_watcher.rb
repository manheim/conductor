class TrafficWatcher
  include ActionView::Helpers::DateHelper
  include MetricsGenerator

  def too_long_since_last_message? message_created_at
    return false unless message_created_at
    Time.now - message_created_at > Settings.most_expected_minutes_between_messages
  end

  def last_message_created_at
    newest_message.try(:created_at)
  end

  def readable_message_age message_created_at
    return '' if message_created_at.nil?
    time_ago_in_words(message_created_at)
  end

  def metrics
    message_created_at = last_message_created_at
    age_of_last_message = readable_message_age message_created_at
    no_message_received_lately = too_long_since_last_message? message_created_at
    generate_metric_block(:no_messages_received, age_of_last_message, no_message_received_lately && business_hours)
  end

  private

  def newest_message
    Message.last
  end
end
