require 'rails_helper'

RSpec.describe RateWatcher do
  it 'exists' do
    expect(described_class).not_to be nil
  end

  describe '#get_rate' do
    subject { described_class.new.get_rate }

    context 'no messages have been rececived' do
      it 'returns a rate of zero' do
        expect(subject).to eq 0
      end
    end

    before { Timecop.freeze }
    after { Timecop.return }
    let(:within_the_last_minute) { DateTime.now - 30.seconds }

    context '100 messages have been successfully sent in the last minute' do
      before do
        create_list(:sent_message, 100, created_at: within_the_last_minute,
                                        updated_at: within_the_last_minute,
                                        processed_at: within_the_last_minute,
                                        succeeded_at: within_the_last_minute)
      end
      it 'returns a rate of 100' do
        expect(subject).to eq 100
      end
    end

    context '50 messages have been successfully sent and 50 messages have failed in the last minute' do
      before do
        create_list(:sent_message, 50, created_at: within_the_last_minute,
                                       updated_at: within_the_last_minute,
                                       processed_at: within_the_last_minute,
                                       succeeded_at: within_the_last_minute)
        create_list(:failed_message, 50, created_at: within_the_last_minute,
                                         updated_at: within_the_last_minute,
                                         processed_at: within_the_last_minute)
      end
      it 'returns a rate of 50' do
        expect(subject).to eq 50
      end
    end

    context '100 messages have been unsuccesfully sent in the last minute' do
      before do
        create_list(:failed_message, 100, created_at: within_the_last_minute,
                                          updated_at: within_the_last_minute,
                                          processed_at: within_the_last_minute)
      end
      it 'returns a rate of 0' do
        expect(subject).to eq 0
      end
    end
  end
end
