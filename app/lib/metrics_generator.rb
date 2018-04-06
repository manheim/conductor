module MetricsGenerator
  def generate_metric_block metric_name, metric_value, in_violation
    {
      metric_name: metric_name,
      metric_value: metric_value,
      in_violation: in_violation
    }
  end

  def business_hours
    now = Time.now.utc
    # 7am - 8pm EST
    (11..23).cover?(now.hour) || now.hour == 0
  end
end
