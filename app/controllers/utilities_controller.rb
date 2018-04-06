class UtilitiesController < ApplicationController
  skip_before_action :authenticate

  def configuration
    render json: {
      buildNumber: add_build_number("/version.txt")
    }
  end


  def elb_health_check
    render status: 200, text: ""
  end

  def root
    render status: 200, text: root_text
  end

  protected

  def root_text
    "Welcome to conductor";
  end

  def add_build_number(filename)
    path = if ENV['RAILS_RELATIVE_URL_ROOT']
             File.join(ENV['RAILS_RELATIVE_URL_ROOT'], filename)
           else
             File.join(Rails.root, 'lib', filename)
           end
    File.exists?(path) ? File.read(path).chomp.to_s : ''
  end

end
