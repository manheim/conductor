class NeedsSendingDecider
  attr_accessor :options, :settings, :http_headers, :body

  def initialize(options)
    self.options = options
    self.settings = options[:settings]
    self.http_headers = options[:http_headers]
    self.body = options[:body]
  end

  def needs_sending?
    return false if settings[:disable_message_sending]

    if settings[:inbound_message_filter].present?
      begin
        !!JMESPath.search(settings[:inbound_message_filter], JSON.parse(body))
      rescue JMESPath::Errors::Error
        return false
      end
    else
      http_headers[settings[:enable_tag].to_s.downcase.camelize] != "false"
    end
  end
end
