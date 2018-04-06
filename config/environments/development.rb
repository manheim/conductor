Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  config.cache_store = :memory_store, { size: 33554432 } # 32 megs

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['utilities#elb_health_check']
  config.lograge.custom_options = lambda do |event|
    {}.tap do |options|
      options[:payload] = event.payload
    end
  end
end
