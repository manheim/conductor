class MessageCreator
  attr_accessor :options, :settings, :params, :request

  def initialize(options)
    self.options = options
    self.settings = options[:settings]
    self.params = options[:params]
    self.request = options[:request]
  end

  def create
    body = request.body.read
    headers = http_headers

    shard_id = ShardIdProvider.new(
      settings: settings,
      headers: headers,
      body: body
    ).shard_id

    needs_sending = NeedsSendingDecider.new(
      { http_headers: headers, settings: settings, body: body }
    ).needs_sending?

    Message.transaction do
      message = Message.create(
        body: body,
        headers: headers.to_json,
        shard_id: shard_id,
        needs_sending: needs_sending
      )
      create_extraction message
    end
  end

  def http_headers
    sent_headers = request.env.select {|k,v| k =~ /^HTTP_[A-Z_]+$/}
    extracted_headers = sent_headers.inject({}) do |acc, (k, v)|
      converted_key = k.gsub(/^HTTP_/, "").gsub("_", "-").downcase.camelize
      acc[converted_key] = v
      acc
    end

    if request.content_type
      extracted_headers["Content-type"] = request.content_type
    end

    x_forwarded_for = request.headers["X-Forwarded-For"].to_s.split(/, +/)
    x_forwarded_for << request.env["REMOTE_ADDR"]

    # Not clear we'd ever want to preserve the host
    extracted_headers.delete('Host')

    extracted_headers['X-Forwarded-Host'] = request.host.to_s
    extracted_headers['X-Forwarded-Port'] = request.port.to_s
    extracted_headers['X-Forwarded-For'] = x_forwarded_for.join(", ")

    extracted_headers
  end

  def create_extraction message
    words = settings[:search_text_words].split(",").map {|w| w.strip }

    options = {
      number_of_characters: settings[:search_text_number_characters],
      words: words,
      extraction_direction: settings[:search_text_extraction_direction],
      message: message
    }

    extractor = GenericMessageIndexExtractor.new options

    text = extractor.extract
    SearchText.create(message: message, text: text)
    AlternateSearchText.create(message: message, text: text)
  end
end
