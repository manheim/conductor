require 'rails_helper'

# Concern: Deciding if a message needs sending
# Behavior: Given a message record returns whether it needs sending

RSpec.describe SendingDecider do

  let(:max_num_retries) { rand(1..10) }
  let(:message_needs_sending) { true }
  let(:message_processed_count) { 0 }
  let(:message) { Message.new(needs_sending: message_needs_sending,
                              processed_count: message_processed_count) }
  subject { described_class.new message }

  before do
    allow(Settings).to receive(:max_number_of_retries).and_return max_num_retries
  end

  describe 'deciding if message needs to be sent (#needs_sending?)' do

    context 'the last attempt to send the message was successful' do
      before do
        subject.send_succeeded
      end
      it 'returns false' do
        expect(subject.needs_sending?).to eq false
      end
    end

    context 'message has its needs_sending flag set true' do
      let(:message_needs_sending) { true }
      it 'returns true' do
        expect(subject.needs_sending?).to eq true
      end

      context 'max_retry setting is set' do
        context 'the number of attempted sends is more than the max number of retries' do
          let(:message_processed_count) { max_num_retries + rand(1..10) }
          it 'returns false' do
            expect(subject.needs_sending?).to eq false
          end
        end

        context 'the number of attempted sends is equal to the max number of retries' do
          let(:message_processed_count) { max_num_retries }
          it 'returns false' do
            expect(subject.needs_sending?).to eq false
          end
        end

        context 'sends have been attempted and max number of retries is set to -1 (infinity)' do
          let(:max_num_retries) { -1 }
          let(:message_processed_count) { rand(1..10) }
          it 'returns true' do
            expect(subject.needs_sending?).to eq true
          end
        end

        context 'sends have been attempted and max number of retries is set to blank string (infinity)' do
          let(:max_num_retries) { '' }
          let(:message_processed_count) { rand(1..10) }
          it 'returns true' do
            expect(subject.needs_sending?).to eq true
          end
        end

        context 'sends have been attempted and max number of retries is set to nil (infinity)' do
          let(:max_num_retries) { nil }
          let(:message_processed_count) { rand(1..10) }
          it 'returns true' do
            expect(subject.needs_sending?).to eq true
          end
        end

      end
    end

    context 'message has its needs_sending flag set false' do
      let(:message_needs_sending) { false }
      it 'returns false' do
        expect(subject.needs_sending?).to eq false
      end
    end


  end
end
