require 'rails_helper'

RSpec.describe UnsentWatcher do
  it 'exists' do
    expect(described_class).not_to be nil
  end

  let(:current_time) { DateTime.now }
  let(:thirty_seconds_ago) { current_time - 30.seconds }

  describe "#unsent_count_over_threshold?" do
    subject { described_class.new.unsent_count_over_threshold? described_class.new.unsent_count }
    let(:threshold) { rand(10..20) }
    let(:unsent_count) { 0 }

    before do
      allow(Settings).to receive(:unsent_message_count_threshold).and_return threshold
      allow_any_instance_of(UnsentWatcher).to receive(:unsent_count).and_return unsent_count
    end

    context "unsent count below threshold" do
      let(:unsent_count) { threshold - 1 }
      it "returns false" do
        expect(subject).to eq false
      end
    end

    context "unsent count above threshold" do
      let(:unsent_count) { threshold + 1 }
      it "returns true" do
        expect(subject).to eq true
      end
    end
  end

  describe "#most_failing_unsent_messages" do

    subject { described_class.new }

    context "multiple messages, no attempts to send have been made, no failures" do
      before do
        create_list(:message, 10)
      end
      it "returns an empty collection" do
        expect(subject.most_failing_unsent_messages).to be_empty
      end
    end

    context "single message received, it has failed at least 1 time and has not succeeded" do
      let!(:failing_message) do
        create(:failed_message)
      end

      it "returns enumerable containing single message" do
        expect(subject.most_failing_unsent_messages.first).to eq failing_message
        expect(subject.most_failing_unsent_messages.length).to eq 1
      end
    end

    context "two messages received, one has succeeded the other has failed at least 10 times and has not succeeded" do
      let!(:failing_message) do
        create(:failed_message)
      end
      let!(:passinging_message) do
        create(:sent_message)
      end

      it "returns enumerable containing single message" do
        expect(subject.most_failing_unsent_messages.first).to eq failing_message
        expect(subject.most_failing_unsent_messages.length).to eq 1
      end
    end

    context "all messages have been sent" do
      before do
        create_list(:sent_message, 10)
      end
      it "returns an empty enumerable" do
        expect(subject.most_failing_unsent_messages.empty?).to be true
      end
    end

    context "multiple failing messages received which have failed at least 1 time" do
      before do
        create_list(:failed_message, 11)
      end

      it "returns enumerable containing 10 failing messages" do
        expect(subject.most_failing_unsent_messages.length).to eq 10
      end

      it "only returns objects which need sending" do
        uniq_need_sending_values = subject.most_failing_unsent_messages.map(&:needs_sending).uniq
        expect(uniq_need_sending_values).to eq [true]
      end

      it "returns collection ordered so that most failing messages are first" do
        correct_messages = Message.where(needs_sending: true).order(processed_count: :desc, id: :desc).first(10)
        expect(subject.most_failing_unsent_messages).to eq correct_messages
      end

      it "limits the failing results" do
        correct_messages = Message.where(needs_sending: true).order(processed_count: :desc, id: :desc).first(2)
        expect(subject.most_failing_unsent_messages(2)).to eq correct_messages
      end
    end
  end

  describe '#unsent_count' do
    subject { described_class.new.unsent_count }

    let(:thirty_seconds_from_now) { DateTime.now + 30.seconds }

    context 'no messages are in the conductor' do
      it 'returns a rate of zero' do
        expect(subject).to eq 0
      end
    end

    context '100 messages which have not been sent' do
      before do
        create_list(:message, 100)
      end

      it 'returns an unsent count of 100' do
        expect(subject).to eq 100
      end
    end

    context '50 unsent messages, 50 sent messages' do
      before do
        create_list(:sent_message, 50)
        create_list(:failed_message, 50)
      end
      it 'returns an unsent count of 50' do
        expect(subject).to eq 50
      end
    end

    context '100 messages exist which have all been sent' do
      before do
        create_list(:sent_message, 100)
      end

      it 'returns an unsent count of 0' do
        expect(subject).to eq 0
      end
    end
  end

  describe '#failed_count' do
    subject { described_class.new.failed_count }

    let(:thirty_seconds_from_now) { DateTime.now + 30.seconds }

    context 'no messages are in the conductor' do
      it 'returns zero' do
        expect(subject).to eq 0
      end
    end

    context '100 messages which have not been sent, 60 failed' do
      before do
        create_list(:message, 40, processed_count: 0)
        create_list(:message, 60, processed_count: 5)
      end

      it 'returns a failed count of 60' do
        expect(subject).to eq 60
      end
    end

    context '50 unsent messages, 50 sent messages, 20 unsent have failed' do
      before do
        create_list(:sent_message, 10)
        create_list(:sent_message, 40, processed_count: 1)
        create_list(:failed_message, 30, processed_count: 0)
        create_list(:failed_message, 20, processed_count: 3)
      end

      it 'returns a failed count of 20' do
        expect(subject).to eq 20
      end
    end

    context '100 messages exist which have all been sent, and some had failed' do
      before do
        create_list(:sent_message, 60, processed_count: 0)
        create_list(:sent_message, 40, processed_count: 2)
      end

      it 'returns a failed count of 0' do
        expect(subject).to eq 0
      end
    end
  end
end
