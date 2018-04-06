class OldMessageWatcher
  include ActionView::Helpers::DateHelper
  include MetricsGenerator

  def readable_message_age message_age
    return '' if message_age.nil?
    time_ago_in_words(message_age)
  end

  def oldest_message_created_time
    oldest_unsent_message.try(:created_at)
  end

  def oldest_older_than_threshold? message_age
    return false if message_age.nil?
    Time.now - message_age > Settings.unhealthy_message_age_in_seconds
  end

  def metrics
    oldest_message_created_time = oldest_message_created_time
    readable_oldest_message_age = readable_message_age oldest_message_created_time
    oldest_message_too_old = oldest_older_than_threshold? oldest_message_created_time

    generate_metric_block(:oldest_message_older_than_threshold, readable_oldest_message_age, oldest_message_too_old)
  end

  protected

  def oldest_unsent_message
    id = Message.where(needs_sending: true).order(id: :asc).pluck(:id).first
    Message.where(id: id).first
  end
end
