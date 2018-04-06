# All Administrate controllers inherit from this `Admin::ApplicationController`,
# making it the ideal place to put authentication logic or other
# before_filters.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    include Concerns::BasicAuthentication

    before_action :populate_is_healthy

    def populate_is_healthy
      @is_healthy = HealthWatcher.new.healthy?
    end

    def read_from_database
      params[:use_master] ? :master : :replica
    end
  end

end
