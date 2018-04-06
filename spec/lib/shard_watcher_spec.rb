require 'rails_helper'

RSpec.describe ShardWatcher do
  it 'exists' do
    expect(described_class).not_to be nil
  end

  describe "#shards_blocked_over_threshold" do
    let(:threshold) { rand(1..10) }
    before do
      allow(Settings).to receive(:unhealthy_shard_threshold).and_return threshold
    end
    subject { described_class.new.shards_blocked_over_threshold? described_class.new.shards_blocked }

    context "number of shards blocked under threshold" do
      before do
        allow_any_instance_of(ShardWatcher).to receive(:shards_blocked).and_return threshold-1
      end

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "number of shards blocked at threshold" do
      before do
        allow_any_instance_of(ShardWatcher).to receive(:shards_blocked).and_return threshold
      end

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "number of shards blocked exceeds threshold" do
      before do
        allow_any_instance_of(ShardWatcher).to receive(:shards_blocked).and_return threshold + 1
      end

      it "returns true" do
        expect(subject).to be true
      end
    end
  end

  describe '#shards_blocked' do
    subject { described_class.new.shards_blocked }
    let(:threshold) { rand(5..10) }

    before do
      allow(Settings).to receive(:blocked_shard_message_failure_threshold).and_return threshold
    end

    let(:current_time) { DateTime.now }
    let(:thirty_seconds_from_now) { DateTime.now + 30.seconds }
    context 'there are no messages in the conductor' do
      it 'returns zero for the number of shards blocked' do
        expect(subject).to eq 0
      end
    end

    it 'respects blocked_shard_message_failure_threshold' do
      create_list(:failed_message, 100, processed_count: rand(0..threshold*2))
      right_answer = Message.select(:shard_id).distinct
                     .where('processed_count > ? AND needs_sending = ?', threshold, true)
                     .count
      expect(subject).to eq right_answer
    end

    context '100 messages have been successfully sent' do
      before do
        create_list(:sent_message, 100)
      end
      it 'returns zero for the number of shards blocked' do
        expect(subject).to eq 0
      end
    end

    context '50 messages successfully sent and 30 messages with random shards have failed' do
      let(:shard_list) { Array.new(30) { rand(1..1024) } }
      before do
        create_list(:sent_message, 50)
        shard_list.each do |shard|
          create(:failed_message, shard_id: shard,
                                  processed_count: rand(threshold+1..threshold+100))
        end
      end
      it 'returns the number of blocked shards' do
        expect(subject).to eq shard_list.uniq.count
      end
    end
  end
end
