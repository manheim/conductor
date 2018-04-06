require 'rails_helper'

RSpec.describe Producer::IterativeDatabaseProducer do
  let(:logger) { Rails.logger }
  let(:delay) { :not_used }

  context "::produce_work" do
    context "no messages need sending" do
      it "pushes nothing and exits" do
        input_queue = []
        described_class.produce_work input_queue, delay
        expect(input_queue.size).to eq 0
      end
    end

    context "some messages need sending" do
      let!(:messages) do
        [
          create(:message, body: "test", shard_id: 1, needs_sending: true),
          create(:message, body: "test", shard_id: 2, needs_sending: true),
          create(:message, body: "test", shard_id: 3, needs_sending: false)
        ]
      end

      before do
        allow(Settings).to receive(:iterative_producer_batch_size).and_return 1
      end

      it "only pushes shard ids that have a message that needs sending" do
        input_queue = SizedQueue.new 10
        described_class.produce_work input_queue, delay
        expect(input_queue.size).to eq 2
        expected = [input_queue.pop, input_queue.pop]
        expect(expected).to match_array(['1','2'])
      end

      it "doesn't iterate through all batches as it comes in" do
        input_queue = SizedQueue.new 1
        t = Thread.new do
          described_class.produce_work input_queue, delay
        end
        shard1 = input_queue.pop
        create(:message, body: "test", shard_id: 5, needs_sending: true)
        create(:message, body: "test", shard_id: 6, needs_sending: true)
        create(:message, body: "test", shard_id: 7, needs_sending: true)
        shard2 = input_queue.pop
        expect([shard1, shard2]).to match_array(['1','2'])
        Timeout::timeout(2) do
          t.join
        end
      end
    end
  end
end
