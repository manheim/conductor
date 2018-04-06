require 'rails_helper'

RSpec.describe RuntimeSettings, type: :model do
  def override_setting(setting, new_value)
    original_value = Settings.public_send(setting)
    Settings.public_send("#{setting}=", new_value)
    yield
  ensure
    Settings.public_send("#{setting}=", original_value)
  end

  describe "workers_enabled" do
    context "setting exists" do
      it "uses database setting" do
        setting_value = rand(999999999)
        setting = {workers_enabled: setting_value}
        RuntimeSettings.update_settings setting

        expect(RuntimeSettings::Config.workers_enabled).to be setting_value
      end
    end

    context "if not in RuntimeSettings" do
      it "falls back to the Settings" do
        setting = {not_workers_enabled: rand(999999)}
        RuntimeSettings.update_settings setting

        setting_value = rand(99999999)

        override_setting(:workers_enabled, setting_value) do
          expect(RuntimeSettings::Config.workers_enabled).to be setting_value
        end
      end
    end

    context "sets null as the setting" do
      it "uses database setting" do
        setting = {workers_enabled: nil}
        RuntimeSettings.update_settings setting

        expect(RuntimeSettings::Config.workers_enabled).to be nil
      end
    end

    context "no settings exist" do
      it "falls back to the Settings" do
        setting_value = rand(99999999)
        override_setting(:workers_enabled, setting_value) do
          expect(RuntimeSettings::Config.workers_enabled).to be setting_value
        end
      end
    end
  end

  describe "some number setting" do
    it "uses database setting if available" do
      setting_value = rand(999999999)
      setting_name = "setting_#{rand(999999999)}"
      setting = {setting_name => setting_value}
      RuntimeSettings.update_settings setting

      expect(RuntimeSettings::Config.send(setting_name)).to eq setting_value
    end

    describe "no Setting setting exists" do
      it "raises a no method error" do
        setting_name = "setting_#{rand(999999999)}"
        expect{RuntimeSettings::Config.send(setting_name)}.to raise_error NoMethodError, /RuntimeSettings/
      end
    end
  end

  describe "multiple settings exist" do
    it "uses the most recent one" do
      setting_name = "setting_#{rand(999999999)}"

      setting = {setting_name => rand(999999999)}
      RuntimeSettings.update_settings setting

      setting_value = rand(999999999)
      setting = {setting_name => setting_value}
      RuntimeSettings.update_settings setting

      expect(RuntimeSettings::Config.send(setting_name)).to eq setting_value
    end
  end

  describe "multiple settings exist" do
    it "uses the most recent one" do
      setting_name = "setting_#{rand(999999999)}"

      setting = {setting_name => rand(999999999)}
      RuntimeSettings.update_settings setting

      setting_value = rand(999999999)
      setting = {setting_name => setting_value}
      RuntimeSettings.update_settings setting

      expect(RuntimeSettings::Config.send(setting_name)).to eq setting_value
    end
  end

  describe "caching" do
    it "caches the settings" do
      setting_name = "setting_#{rand(999999999)}"

      first_setting_value = rand(999999999)
      setting = {setting_name => first_setting_value}
      RuntimeSettings.update_settings setting

      RuntimeSettings::Config.send(setting_name)

      setting = {setting_name => rand(999999999)}
      RuntimeSettings.update_settings setting

      expect(RuntimeSettings::Config.send(setting_name)).to eq first_setting_value
    end

  end

end

