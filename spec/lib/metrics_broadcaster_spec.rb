require 'rails_helper'

# concerns: getting metrics broadcast out of system
# behaviors: given a set of metrics will broadcast those metrics to data dog

RSpec.describe MetricsBroadcaster do

  let(:shards_blocked) { rand(100) }
  let(:unsent_messages) { rand(100) }
  let(:oldest_message) { '2 minutes ago' }
  let(:no_messages_received_in) { 'about 21 hours' }
  let(:undeliverable_percentage) { rand(100) }
  let(:healthy) { [true, false].sample }
  let(:metrics) {[
    {
      metric_name: :shards_blocked_over_threshold,
      metric_value: shards_blocked,
      in_violation: false
    },
    {
      metric_name: :too_many_unsent_messages,
      metric_value: unsent_messages,
      in_violation: !healthy
    },
    {
      metric_name: :oldest_message_older_than_threshold,
      metric_value: oldest_message,
      in_violation: false
    },
    {
      metric_name: :no_messages_received,
      metric_value: no_messages_received_in,
      in_violation: false
    },
    {
      metric_name: :undeliverable_message_percentage,
      metric_value: undeliverable_percentage,
      in_violation: false
    }
  ]}

  let(:platform_adapter_1) { double('platform_adapter', send_scalar_metric: nil, send_health: nil) }
  let(:platform_adapter_2) { double('platform_adapter', send_scalar_metric: nil, send_health: nil) }
  let(:platform_adapters) {[ platform_adapter_1, platform_adapter_2 ]}
  subject { described_class.new(*platform_adapters) }

  describe 'broadcasting metrics out of system (#broadcast!)' do
    it 'broadcasts shards_blocked_over_threshold as scalar' do
      platform_adapters.each do |adapter|
        expect(adapter).to receive(:send_scalar_metric).with(:shards_blocked_over_threshold,
                                                        shards_blocked)
      end
      subject.broadcast! metrics, healthy
    end

    it 'broadcasts too_many_unsent_messages as scalar unsent_message_count' do
      platform_adapters.each do |adapter|
        expect(adapter).to receive(:send_scalar_metric).with(:unsent_message_count,
                                                        unsent_messages)
      end
      subject.broadcast! metrics, healthy
    end

    it 'broadcasts undeliverable_message_percentage if enabled' do
      allow_any_instance_of(UndeliverableWatcher).to receive(:active?).and_return true
      platform_adapters.each do |adapter|
        expect(adapter).to receive(:send_scalar_metric).with(:undeliverable_message_percentage,
                                                        undeliverable_percentage)
      end
      subject.broadcast! metrics, healthy
    end

    it 'does not broadcast undeliverable_message_percentage when disabled' do
      allow_any_instance_of(UndeliverableWatcher).to receive(:active?).and_return false
      platform_adapters.each do |adapter|
        expect(adapter).to_not receive(:send_scalar_metric).with(:undeliverable_message_percentage,
                                                        undeliverable_percentage)
      end
      subject.broadcast! metrics, healthy
    end

    it 'broadcasts health' do
      platform_adapters.each do |adapter|
        expect(adapter).to receive(:send_health).with(healthy)
      end
      subject.broadcast! metrics, healthy
    end
  end
end
