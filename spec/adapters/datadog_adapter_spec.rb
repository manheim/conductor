require 'rails_helper'

# concerns: pushing metrics to data dog
# behaviors: given a name and a value will push a scalar metric to DD

RSpec.describe DatadogAdapter do

  let(:dclient) { double(Dogapi::Client) }
  let(:datadog_api_key) { rand(100).to_s }
  let(:metric_name) { "name_#{rand(100)}" }
  let(:metric_value) { rand(100) }
  let(:team) { "Team_#{rand(100)}" }
  let(:app) { "App_#{rand(100)}" }
  let(:healthy) { [true, false].sample }
  let(:environment) { "test_#{rand(100)}_env" }

  before do
    allow(Settings).to receive(:app_env).and_return environment
    allow(Settings).to receive(:team_name).and_return team
    allow(Settings).to receive(:associated_application_name).and_return app
    allow(Settings).to receive(:datadog_api_key).and_return datadog_api_key
    allow(Dogapi::Client).to receive(:new).and_return(dclient)
  end

  describe 'pushing health (#send_health)' do
    it 'pushes service check to data dog' do
      expect(dclient).to receive(:service_check)
      subject.send_health healthy
    end

    it 'pushes formatted name' do
      formatted_name = "#{team}.#{app}.conductor.healthy"
      expect(dclient).to receive(:service_check).with(formatted_name, anything, anything, anything)
      subject.send_health healthy
    end

    it 'pushes host as conductor' do
      expect(dclient).to receive(:service_check).with(anything, 'conductor', anything, anything)
      subject.send_health healthy
    end

    context "app_env is set" do
      it 'pushes tags' do
        tags = ["environment:#{Settings.app_env}"]
        expect(dclient).to receive(:service_check).with(anything, anything, anything, { tags: tags })
        subject.send_health healthy
      end
    end

    context 'app_env is not set' do
      let(:environment) { nil }
      it 'pushes without tags' do
        tags = ["environment:#{Settings.app_env}"]
        expect(dclient).to receive(:service_check).with(anything, anything, anything, { tags: [] })
        subject.send_health healthy
      end
    end

    context 'is healthy' do
      let(:healthy) { true }
      it 'pushes value of 0' do
        expect(dclient).to receive(:service_check).with(anything, anything, 0, anything)
        subject.send_health healthy
      end
    end

    context 'is not healthy' do
      let(:healthy) { false }
      it 'pushes value of 1' do
        expect(dclient).to receive(:service_check).with(anything, anything, 1, anything)
        subject.send_health healthy
      end
    end
  end

  describe 'pushing scalar (#send_scalar_metric)' do
    it 'pushes metric to datadog' do
      expect(dclient).to receive(:emit_point)
      subject.send_scalar_metric metric_name, metric_value
    end

    it 'pushes the same value its given' do
      expect(dclient).to receive(:emit_point).with(anything, metric_value, anything)
      subject.send_scalar_metric metric_name, metric_value
    end

    context 'app env is set' do
      it 'pushes tags' do
        tags = ["environment:#{environment}"]
        expect(dclient).to receive(:emit_point).with(anything, anything, { tags: tags })
        subject.send_scalar_metric metric_name, metric_value
      end
    end

    context 'app env is not set' do
      let(:environment) { nil }
      it 'does not push tags' do
        expect(dclient).to receive(:emit_point).with(anything, anything, { tags: [] })
        subject.send_scalar_metric metric_name, metric_value
      end
    end

    context 'team name and app name are set' do
      it 'pushes metric name formated as <team>.<app>.conductor.<metric_name>' do
        formatted_name = "#{team}.#{app}.conductor.#{metric_name}"
        expect(dclient).to receive(:emit_point).with(formatted_name, anything, anything)
        subject.send_scalar_metric metric_name, metric_value
      end
    end
  end

  context 'team name is not configured' do
    before do
      allow(Settings).to receive(:team_name).and_return nil
    end

    it 'does not push scalar metric' do
      expect(dclient).not_to receive(:emit_point)
      subject.send_scalar_metric metric_name, metric_value
    end

    it 'does not push health' do
      expect(dclient).not_to receive(:service_check)
      subject.send_health healthy
    end

    it 'does not instantiate dd client' do
      expect(Dogapi::Client).not_to receive(:new)
      subject.send_scalar_metric metric_name, metric_value
    end
  end

  context 'app name is not configured' do
    before do
      allow(Settings).to receive(:associated_application_name).and_return nil
    end

    it 'does not push scalar metric' do
      expect(dclient).not_to receive(:emit_point)
      subject.send_scalar_metric metric_name, metric_value
    end

    it 'does not push health' do
      expect(dclient).not_to receive(:service_check)
      subject.send_health healthy
    end

    it 'does not instantiate dd client' do
      expect(Dogapi::Client).not_to receive(:new)
      subject.send_scalar_metric metric_name, metric_value
    end
  end

  context 'api key is not configured' do
    before do
      allow(Settings).to receive(:datadog_api_key).and_return nil
    end

    it 'does not push scalar metric' do
      expect(dclient).not_to receive(:emit_point)
      subject.send_scalar_metric metric_name, metric_value
    end

    it 'does not push health' do
      expect(dclient).not_to receive(:service_check)
      subject.send_health healthy
    end

    it 'does not instantiate dd client' do
      expect(Dogapi::Client).not_to receive(:new)
      subject.send_scalar_metric metric_name, metric_value
    end
  end


end
