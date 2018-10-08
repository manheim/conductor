module Concerns
  module BasicAuthentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate

      def authenticate
        if Settings.basic_auth_enabled
          if request.headers['conductor-authorization']
            base64_token = request.headers['conductor-authorization'].split(' ').second
            username, password = Base64.decode64(base64_token).split(":")
            unless check_auth(username, password)
              message = "HTTP Basic: Access denied.\n"
              render text: message, status: 401
            end
          else
            authenticate_or_request_with_http_basic do |username, password|
              check_auth(username, password)
            end
          end
        end
      end
    end

    def check_auth(username, password)
      if username == Settings.basic_auth_user && password == Settings.basic_auth_password
        session[:user_role] = "admin"
        true
      elsif username == Settings.readonly_username && password == Settings.readonly_password
        session[:user_role] = "readonly_user"
        true
      else
        false
      end
    end
  end
end
