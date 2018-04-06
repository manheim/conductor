class BasicAuthMiddleware < Faraday::Response::Middleware
  def call(env)
    basic_auth = Base64.encode64("#{Settings.destination_auth_username}:#{Settings.destination_auth_password}")
    basic_auth.gsub!("\n", '')
    env[:request_headers]['Authorization'] = "Basic #{basic_auth}"
    @app.call(env)
  end
end


