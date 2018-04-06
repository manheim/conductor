class DatadogAdapter
  include Logging

  def initialize
    if configured?
      @client = Dogapi::Client.new api_key
    else
      debug "not setting up, not configured"
    end
  end

  def send_scalar_metric name, value
    if configured?
      send_metric name, value
    else
      debug "not configured, not sending metric"
    end
  end

  def send_health healthy
    if configured?
      send_service_check healthy
    else
      debug "not configured, not sending health"
    end
  end

  private

  def send_metric name, value
    metric_name = format name
    debug "sending metric #{metric_name} => #{value}"
    @client.emit_point metric_name, value, { tags: tags }
  end

  def send_service_check healthy
    value = healthy ? 0 : 1
    debug "sending health service check: #{health_check_name} [#{value}]"
    @client.service_check(health_check_name, 'conductor', value, { tags: tags })
  end

  def format name
    "#{team_name}.#{app_name}.conductor.#{name}"
  end

  def health_check_name
    "#{team_name}.#{app_name}.conductor.healthy"
  end

  def team_name
    Settings.team_name
  end

  def app_name
    Settings.associated_application_name
  end

  def api_key
    Settings.datadog_api_key
  end

  def configured?
    team_name && app_name && api_key
  end

  def env
    Settings.app_env
  end

  def tags
    if env.nil?
      []
    else
      ["environment:#{env}"]
    end
  end
end
