class RuntimeSettingsApiController < ApplicationController
  include Concerns::BasicAuthentication

  before_filter do
    if Settings.basic_auth_enabled && session[:user_role] != "admin"
      render status: 401, text: ''
    end
  end

  def show
    logger.info "showing runtime settings"
    render json: { settings: RuntimeSettings.recent_settings }
  end

  def update
    logger.info "update call for runtime settings with data #{params[:settings]}"
    if params[:settings] && params[:settings].is_a?(Hash)
      RuntimeSettings.update_settings(params[:settings])
      render status: 204, text: ''
    else
      render status: 400, text: ''
    end
  end
end
