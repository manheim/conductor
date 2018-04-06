class PagerAttendant
  include Concerns::Workers

  def initialize(options = {})
    pagerduty_service_key = options[:pagerduty_service_key] || Settings.pagerduty_service_key
    @pagerduty = Pagerduty.new(pagerduty_service_key)
    @incident_key = "#{Settings.new_relic_app_name} Alert"
  end

  def refresh_pages! metrics
    with_thread_error_handling(self.class.name, false) do
      work_without_error_handling metrics
    end
  end

  private
  def work_without_error_handling health_metrics
    info 'Running'

    if @pagerduty.service_key.blank?
      info 'No service key provided, unable to alert on monitored triggers'
      return
    end

    metrics_in_violation = health_metrics.select { |metric| metric[:in_violation] }

    if metrics_in_violation.empty?
      incident = @pagerduty.get_incident @incident_key
      incident.acknowledge if incident
      incident.resolve if incident

      info 'System healthy, no alerts triggered'
    else
      alert_messages = [].tap do |arr|
        metrics_in_violation.each do |metric|
          arr << generate_alert_message(metric[:metric_name], metric[:metric_value])
        end
      end
      client = Settings.new_relic_app_name

      warn "Triggering alert for #{client}: #{alert_messages.join ';'}"
      warn "Full system health status: #{health_metrics}"

      @pagerduty.trigger(
        alert_messages.join(';'),
        {
          incident_key: @incident_key,
          client: client,
          client_url: Settings.conductor_health_page_url,
          details: health_metrics
        }
      )
    end
  end

  def generate_alert_message health_status, metric_data
    alert_message_prefix_text = Settings.pagerduty_application_name ? "#{Settings.pagerduty_application_name}: " : ""
    case health_status
    when :shards_blocked_over_threshold
      "#{alert_message_prefix_text}Number of blocked shards exceed threshold, current number: #{metric_data}"
    when :too_many_unsent_messages
      "#{alert_message_prefix_text}Number of unsent messages exceeds alert threshold, current queue depth: #{metric_data}"
    when :oldest_message_older_than_threshold
      "#{alert_message_prefix_text}An unsent message has exceeded age threshold, age of message: #{metric_data}"
    when :no_messages_received
      "#{alert_message_prefix_text}No messages received in last #{metric_data} minutes"
    else
      "#{alert_message_prefix_text}Unknown health status: #{health_status.to_s}, metric value: #{metric_data}"
    end
  end

  def get_health_metrics
    HealthWatcher.new.health_status
  end

end
