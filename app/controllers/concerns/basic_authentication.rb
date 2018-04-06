module Concerns
  module BasicAuthentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate

      def authenticate
        if Settings.basic_auth_enabled
          authenticate_or_request_with_http_basic do |username, password|
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
    end
  end
end
