class ApplicationController < ActionController::Base

  def append_info_to_payload(payload)
    super
    if !request.get? || response.status.to_s[0] != "2"
      payload[:headers] = Hash[request.headers.select { |k, v| k.starts_with?("HTTP_") && (!k.include?("AUTH") || k.include?("USER_CONTEXT"))}]
      payload[:response] = response.body
    end
  end

end
