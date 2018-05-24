require 'rails_helper'

RSpec.describe Producer::UnprocessedShardsProducer do
  let(:logger) { Rails.logger }
  let(:delay) { rand(2) }
  let(:failure_delay) { rand(2) }
  let(:settings) do
    {
      threaded_worker_failure_delay: failure_delay,
      threaded_worker_failure_exponent_base: 1,
      threaded_worker_no_work_delay: delay,
      threaded_worker_max_exponent_value: 5
    }
  end

  context "::produce_work" do
    context "some messages need sending" do
      let!(:messages) do
        [
          create(:message, body: "test", shard_id: 1, needs_sending: true),
          create(:message, body: "test", shard_id: 2, needs_sending: true),
          create(:message, body: "test", shard_id: 3, needs_sending: false)
        ]
      end
      it "only pushes shard ids that have a message that needs sending" do
        input_queue = SizedQueue.new 10
        producer = described_class.new input_queue, settings
        producer.produce_work
        expect(input_queue.size).to eq 2
        expected = [input_queue.pop, input_queue.pop]
        expect(expected).to match_array(['1','2'])
      end

      it "only pushes unlocked shard id's onto the queue" do
        Message.with_advisory_lock("message-1", 0) do
          expect(Message.advisory_lock_exists?("message-1")).to eq true
          input_queue = SizedQueue.new 10
          producer = described_class.new input_queue, settings
          producer.produce_work
          expect(input_queue.size).to eq 1
          expected = [input_queue.pop]
          expect(expected).to match_array(['2'])
        end
      end
    end

    context "with NULL shard_id" do
      let!(:messages) do
        [
          create(:message, body: "test", shard_id: nil, needs_sending: true),
          create(:message, body: "test", shard_id: nil, needs_sending: true),
          create(:message, body: "test", shard_id: nil, needs_sending: false)
        ]
      end

      it "pushes the nil shard_id onto the queue" do
        input_queue = SizedQueue.new 10
        producer = described_class.new input_queue, settings
        producer.produce_work
        expect(input_queue.size).to eq 1
        expected = [input_queue.pop]
        expect(expected).to match_array([nil])
      end
    end

    context "all shards are being processed" do
      let!(:messages) do
        [
          create(:message, body: "test", shard_id: 1, needs_sending: true),
          create(:message, body: "test", shard_id: 2, needs_sending: false),
        ]
      end
      it "sleeps if there are no shards to work on" do
        Message.with_advisory_lock("message-1", 0) do
          expect(Message.advisory_lock_exists?("message-1")).to eq true
          input_queue = SizedQueue.new 10
          producer = described_class.new input_queue, settings
          expect(Kernel).to receive(:sleep).with(delay)
          producer.produce_work
          expect(input_queue.size).to eq 0
        end

      end

      it "logs if there are no shards to work on" do
        Message.with_advisory_lock("message-1", 0) do
          expect(Message.advisory_lock_exists?("message-1")).to eq true
          input_queue = SizedQueue.new 10
          expect(logger).to receive(:debug).with(/All shards are processing/)
          producer = described_class.new input_queue, settings
          producer.produce_work
        end
      end

    end

    context "all messages have been sent" do
      let!(:messages) do
        [
          create(:message, body: "test", shard_id: 1, needs_sending: false),
          create(:message, body: "test", shard_id: 2, needs_sending: false),
        ]
      end
      it "sleeps if there are no shards to work on" do
        input_queue = SizedQueue.new 10
        expect(Kernel).to receive(:sleep).with(delay)
        producer = described_class.new input_queue, settings
        producer.produce_work
        expect(input_queue.size).to eq 0
      end
      it "logs if there are no shards to work on" do
        input_queue = SizedQueue.new 10
        expect(logger).to receive(:debug).with(/All shards are processing/)
        producer = described_class.new input_queue, settings
        producer.produce_work
      end
    end
  end

  context "ignoring failed message shards no exponential backoff" do
    let!(:messages) do
      [
        create(:message, body: "test", shard_id: 1, needs_sending: false, last_failed_at: nil),
        create(:message, body: "test", shard_id: 1, needs_sending: false, last_failed_at: nil),

        create(:message, body: "test", shard_id: 2, needs_sending: false, last_failed_at: nil),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: nil),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: 10.seconds.ago),
        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 4, needs_sending: true, last_failed_at: 45.seconds.ago),
        create(:message, body: "test", shard_id: 4, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 5, needs_sending: false, last_failed_at: 40.seconds.ago),

        create(:message, body: "test", shard_id: 6, needs_sending: true, last_failed_at: 40.seconds.ago),

        create(:message, body: "test", shard_id: 7, needs_sending: false, last_failed_at: 10.seconds.ago),
        create(:message, body: "test", shard_id: 7, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 8, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 9, needs_sending: true, last_failed_at: 50.seconds.ago),
      ]
    end

    let(:expected_shards_with_no_failure) { ["2", "8", "7"] }
    let(:expected_shards_with_failure) { ["9", "4", "6"] }
    let(:expected_shards) { expected_shards_with_no_failure + expected_shards_with_failure }

    let(:failure_delay_seconds) { 30 }

    it "finds all shards that did not fail or failed later than the wait period in order of last_failed_at (null is first)" do
      input_queue = []
      settings[:threaded_worker_failure_delay] = failure_delay_seconds
      producer = described_class.new input_queue, settings
      producer.produce_work
      expect(input_queue).to match_array(expected_shards)

      expect(input_queue[0..2]).to match_array(expected_shards_with_no_failure)
      expect(input_queue[3..5]).to eq(expected_shards_with_failure)
    end
  end

  context "ignoring failed message shards with exponential backoff" do
    let!(:messages) do
      [
        create(:message, body: "test", shard_id: 1, needs_sending: false, last_failed_at: nil),
        create(:message, body: "test", shard_id: 1, needs_sending: false, last_failed_at: nil),

        create(:message, body: "test", shard_id: 2, needs_sending: false, last_failed_at: nil),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: nil),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: 10.seconds.ago, processed_count: 1),
        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 4, needs_sending: true, last_failed_at: 25.seconds.ago, processed_count: 2),
        create(:message, body: "test", shard_id: 4, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 5, needs_sending: false, last_failed_at: 40.seconds.ago),

        create(:message, body: "test", shard_id: 6, needs_sending: true, last_failed_at: 45.seconds.ago, processed_count: 3),

        create(:message, body: "test", shard_id: 7, needs_sending: false, last_failed_at: 10.seconds.ago),
        create(:message, body: "test", shard_id: 7, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 8, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 9, needs_sending: true, last_failed_at: 85.seconds.ago, processed_count: 4),

        create(:message, body: "test", shard_id: 10, needs_sending: true, last_failed_at: 20.seconds.ago, processed_count: 2),
        create(:message, body: "test", shard_id: 10, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 11, needs_sending: true, last_failed_at: 40.seconds.ago, processed_count: 3),
        create(:message, body: "test", shard_id: 11, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 12, needs_sending: true, last_failed_at: 80.seconds.ago, processed_count: 4),
        create(:message, body: "test", shard_id: 12, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 13, needs_sending: true, last_failed_at: 100.seconds.ago, processed_count: 5),
        create(:message, body: "test", shard_id: 13, needs_sending: true, last_failed_at: nil),
      ]
    end

    let(:expected_shards_with_no_failure) { ["2", "8", "7"] }
    let(:expected_shards_with_failure) { ["9", "6", "4"] }
    let(:expected_shards) { expected_shards_with_no_failure + expected_shards_with_failure }

    let(:failure_delay_seconds) { 10 }
    let(:failure_exponent_base) { 2 }

    it "finds all shards that did not fail or failed later than the wait period in order of last_failed_at (null is first)" do
      input_queue = []
      settings[:threaded_worker_failure_delay] = failure_delay_seconds
      settings[:threaded_worker_failure_exponent_base] = failure_exponent_base
      producer = described_class.new input_queue, settings
      producer.produce_work
      expect(input_queue).to match_array(expected_shards)

      expect(input_queue[0..2]).to match_array(expected_shards_with_no_failure)
      expect(input_queue[3..5]).to eq(expected_shards_with_failure)
    end
  end

  context "ignoring failed message shards with exponential backoff but max failure delay configured" do
    let!(:messages) do
      [
        create(:message, body: "test", shard_id: 1, needs_sending: false, last_failed_at: nil),
        create(:message, body: "test", shard_id: 1, needs_sending: false, last_failed_at: nil),

        create(:message, body: "test", shard_id: 2, needs_sending: false, last_failed_at: nil),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: nil),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: 10.seconds.ago, processed_count: 1),
        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 4, needs_sending: true, last_failed_at: 25.seconds.ago, processed_count: 2),
        create(:message, body: "test", shard_id: 4, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 5, needs_sending: false, last_failed_at: 40.seconds.ago),

        create(:message, body: "test", shard_id: 6, needs_sending: true, last_failed_at: 45.seconds.ago, processed_count: 3),

        create(:message, body: "test", shard_id: 7, needs_sending: false, last_failed_at: 10.seconds.ago),
        create(:message, body: "test", shard_id: 7, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 8, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 9, needs_sending: true, last_failed_at: 85.seconds.ago, processed_count: 4),

        create(:message, body: "test", shard_id: 10, needs_sending: true, last_failed_at: 20.seconds.ago, processed_count: 2),
        create(:message, body: "test", shard_id: 10, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 11, needs_sending: true, last_failed_at: 40.seconds.ago, processed_count: 3),
        create(:message, body: "test", shard_id: 11, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 12, needs_sending: true, last_failed_at: 80.seconds.ago, processed_count: 4),
        create(:message, body: "test", shard_id: 12, needs_sending: true, last_failed_at: nil),

        create(:message, body: "test", shard_id: 13, needs_sending: true, last_failed_at: 100.seconds.ago, processed_count: 5),
        create(:message, body: "test", shard_id: 13, needs_sending: true, last_failed_at: nil),
      ]
    end

    let(:expected_shards_with_no_failure) { ["2", "8", "7"] }
    let(:expected_shards_with_failure) { ["13", "9", "12", "6", "4"] }
    let(:expected_shards) { expected_shards_with_no_failure + expected_shards_with_failure }

    let(:failure_delay_seconds) { 10 }
    let(:failure_exponent_base) { 2 }

    it "finds all shards that did not fail or failed later than the wait period in order of last_failed_at (null is first)" do
      input_queue = []
      settings[:threaded_worker_failure_delay] = failure_delay_seconds
      settings[:threaded_worker_failure_exponent_base] = failure_exponent_base
      settings[:threaded_worker_max_failure_delay] = 75
      producer = described_class.new input_queue, settings
      producer.produce_work
      expect(input_queue).to match_array(expected_shards)

      expect(input_queue[0..2]).to match_array(expected_shards_with_no_failure)
      expect(input_queue[3..-1]).to eq(expected_shards_with_failure)
    end
  end

  context "with exponential backoff" do
    let!(:messages) do
      [
        create(:message, body: "test", shard_id: 1, needs_sending: true, last_failed_at: 1000.year.ago, processed_count: 16000),
        create(:message, body: "test", shard_id: 2, needs_sending: true, last_failed_at: 1000.year.ago, processed_count: 300),
        create(:message, body: "test", shard_id: 3, needs_sending: true, last_failed_at: 1.hour.ago, processed_count: 300),
      ]
    end

    it "finds shards that have large processed counts (no database error)" do
      input_queue = []
      settings[:threaded_worker_failure_delay] = 1
      settings[:threaded_worker_failure_exponent_base] = 2
      settings[:threaded_worker_max_exponent_value] = 300
      producer = described_class.new input_queue, settings
      producer.produce_work
      expect(input_queue).to match_array(["1", "2"])
    end
  end
end
