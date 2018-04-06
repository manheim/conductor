class RuntimeSettings < ActiveRecord::Base
  self.table_name = :runtime_settings
  serialize :settings, JSON

  def self.recent_settings_model
    RuntimeSettings.last || RuntimeSettings.new
  end

  def self.recent_settings
    RuntimeSettings.last.try(:settings) || {}
  end

  def self.recent_settings_cached
    Rails.cache.fetch(
      "RuntimeSettings",
      expires_in: Settings.runtime_settings_cache_expiration_seconds.seconds
    ) do
      recent_settings
    end
  end

  def self.update_settings(settings)
    recent_settings_model.tap do |model|
      model.settings = settings
      model.save!
    end
  end

  module Config
    def self.method_missing(method, *args, &block)
      settings = RuntimeSettings.recent_settings_cached
      if(settings.has_key?(method.to_s))
        settings[method.to_s]
      elsif Settings.respond_to?(method)
        Settings.public_send(method)
      else
        raise NoMethodError.new("undefined method '#{method}' for RuntimeSettings::Config:Module")
      end
    end
  end
end
