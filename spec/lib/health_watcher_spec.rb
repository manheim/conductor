require 'rails_helper'
require 'ostruct'

RSpec.describe HealthWatcher do
  it 'exists' do
    expect(described_class).not_to be nil
  end

  let(:now) { Time.now }
  let(:threshold) { rand(1..4) }
  let(:traffic_watcher_metrics) {
      {
        metric_name: :no_messages_received,
        metric_value: '0 minutes ago',
        in_violation: false
      }
  }
  let(:shard_watcher_metrics) {
      {
        metric_name: :shards_blocked_over_threshold,
        metric_value: 0,
        in_violation: false
      }
  }
  let(:old_message_watcher_metrics) {
      {
        metric_name: :oldest_message_older_than_threshold,
        metric_value: '0 minutes ago',
        in_violation: false
      }
  }
  let(:unsent_watcher_metrics) {
      {
        metric_name: :too_many_unsent_messages,
        metric_value: 0,
        in_violation: false
      }
  }
  let(:undeliverable_watcher_metrics) {
      {
        metric_name: :undeliverable_message_percentage,
        metric_value: 0,
        in_violation: false
      }
  }
  let(:undeliverable_watcher_active) { true }

  before do
    allow_any_instance_of(TrafficWatcher).to receive(:metrics).and_return(traffic_watcher_metrics)
    allow_any_instance_of(ShardWatcher).to receive(:metrics).and_return(shard_watcher_metrics)
    allow_any_instance_of(OldMessageWatcher).to receive(:metrics).and_return(old_message_watcher_metrics)
    allow_any_instance_of(UnsentWatcher).to receive(:metrics).and_return(unsent_watcher_metrics)
    allow_any_instance_of(UndeliverableWatcher).to receive(:metrics).and_return(undeliverable_watcher_metrics)
    allow_any_instance_of(UndeliverableWatcher).to receive(:active?).and_return(undeliverable_watcher_active)
  end

  describe '#healthy?' do
    context 'no problems exist' do
      it 'is healthy' do
        expect(subject).to be_healthy
      end
    end

    context "more than threshold shards are blocked" do
      let(:shard_watcher_metrics) {
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: 0,
            in_violation: true
          }
      }

      it "is not healthy" do
        expect(subject).not_to be_healthy
      end
    end

    context "there is a old message which should be processed and is not" do
      let(:old_message_watcher_metrics) {
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: '0 minutes ago',
            in_violation: true
          }
      }
      it "is not healthy" do
        expect(subject).not_to be_healthy
      end
    end

    context "there are more than threshold number of unsent messages" do
      let(:unsent_watcher_metrics) {
          {
            metric_name: :too_many_unsent_messages,
            metric_value: 0,
            in_violation: true
          }
      }
      it "is not healthy" do
        expect(subject).not_to be_healthy
      end
    end

    context "there are undeliverable messages" do
      let(:undeliverable_watcher_metrics) {
        {
          metric_name: :undeliverable_message_percentage,
          metric_value: 90,
          in_violation: true
        }
      }
      it "is not healthy" do
        expect(subject).not_to be_healthy
      end

      context "undeliverable watcher is not active" do
        let(:undeliverable_watcher_active) { false }
        it "is healthy healthy" do
          expect(subject).to be_healthy
        end
      end
    end
  end

  describe '#health_status' do
    context "more than threshold shards are blocked" do
      let(:blocked_shards) { rand(10..20) }
      let(:shard_watcher_metrics) {
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: blocked_shards,
            in_violation: true
          }
      }

      it "indicates reason is blocked shards" do
        expect(subject.health_status).to include(
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: blocked_shards,
            in_violation: true
          })
      end
    end

    context "there is a old message which should be processed and is not" do
      let(:oldest_time){ ["1 hour ago", "20 minutes ago", "30 minutes ago"].sample }
      let(:old_message_watcher_metrics) {
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: oldest_time,
            in_violation: true
          }
      }

      it "indicates there is an old message" do
        expect(subject.health_status).to include(
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: oldest_time,
            in_violation: true
          }
        )
      end
    end

    context "there are more than threshold number of unsent messages" do
      let(:unsent_messages){ rand(1000..9999) }
      let(:unsent_watcher_metrics) {
          {
            metric_name: :too_many_unsent_messages,
            metric_value: unsent_messages,
            in_violation: true
          }
      }
      it "indicates there are too many unsent messages" do
        expect(subject.health_status).to include(
          {
            metric_name: :too_many_unsent_messages,
            metric_value: unsent_messages,
            in_violation: true
          }
        )
      end
    end

    context "there are undeliverable messages in window" do
      let(:value) { rand(1..99) }
      let(:undeliverable_watcher_metrics) {
        {
          metric_name: :undeliverable_message_percentage,
          metric_value: value,
          in_violation: true
        }
      }
      it "indicates there is a high undeliverable message percent" do
        expect(subject.health_status).to include(
          {
            metric_name: :undeliverable_message_percentage,
            metric_value: value,
            in_violation: true
          }
        )
      end
    end

    context "system is healthy, no problems exist" do

      it "returns a full list of status details" do
        expect(subject.health_status).to eq(
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: "0 minutes ago",
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: "0 minutes ago",
              in_violation: false
            },
            {
              metric_name: :undeliverable_message_percentage,
              metric_value: 0,
              in_violation: false
            }
          ])
      end

      context "undeliverable watcher is not active" do
        let(:undeliverable_watcher_active) { false }
        it "returns a full list of status details" do
          expect(subject.health_status).to eq(
            [
              {
                metric_name: :shards_blocked_over_threshold,
                metric_value: 0,
                in_violation: false
              },
              {
                metric_name: :too_many_unsent_messages,
                metric_value: 0,
                in_violation: false
              },
              {
                metric_name: :oldest_message_older_than_threshold,
                metric_value: "0 minutes ago",
                in_violation: false
              },
              {
                metric_name: :no_messages_received,
                metric_value: "0 minutes ago",
                in_violation: false
              }
            ])
        end
      end
    end
  end

  describe ':is_healthy?' do
    context 'no stats are in violation' do
      it 'is healthy' do
        expect(subject.class.is_healthy?(subject.health_status)).to eq true
      end
    end

    context 'one or more stats are in violation' do
      before do
        shard_watcher_metrics[:in_violation] = true
      end
      it 'is not healthy' do
        expect(subject.class.is_healthy?(subject.health_status)).to eq false
      end
    end
  end
end
