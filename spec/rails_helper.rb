# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'spec_helper'

abort("The Rails environment is running in production mode!") if Rails.env.production?

ActiveRecord::Migration.maintain_test_schema!

require 'webmock/rspec'

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.before(:each) { Rails.cache.clear }
end


Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }
