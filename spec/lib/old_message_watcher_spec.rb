require 'rails_helper'

RSpec.describe OldMessageWatcher do

  let(:now) { Time.zone.now }

  before { Timecop.freeze }
  after { Timecop.return }

  it 'exists' do
    expect(described_class).not_to be nil
  end

  describe '#oldest_older_than_threshold?' do

    let(:threshold) { rand(1..5).minutes }
    before do
      allow(Settings).to receive(:unhealthy_message_age_in_seconds).and_return threshold
    end

    subject { described_class.new.oldest_older_than_threshold?(described_class.new.oldest_message_created_time) }

    context "there are no messages" do
      it "returns false" do
        expect(subject).to eq false
      end
    end

    context "no messages are older than threshold" do
      before do
        create_list(:failed_message, 2, created_at: now - threshold + 1.seconds,
                                        processed_at: now,
                                        updated_at: now)
      end
      it "returns false" do
        expect(subject).to eq false
      end
    end

    context "one failed of many messages is older than threshold" do
      let(:older_than_threshold) { now - threshold - 1.minute }
      before do
        create_list(:sent_message, 2, created_at: now,
                                      processed_at: now,
                                      updated_at: now)
        create(:failed_message, created_at: older_than_threshold,
                                processed_at: now,
                                updated_at: now)
      end
      it "returns true" do
        expect(subject).to eq true
      end
    end
  end

  describe '#readable_message_age' do

    before { Timecop.freeze }
    after { Timecop.return }

    subject { described_class.new.readable_message_age(described_class.new.oldest_message_created_time) }

    context 'no messages are in the conductor' do
      it 'returns blank string' do
        expect(subject).to eq ''
      end
    end

    context 'two unsent messages exist with differing created_at timestamps' do
      let(:earlier_time) { now - 29.seconds }
      before do
        create(:failed_message, created_at: now,
                                processed_at: now,
                                updated_at: now)
        create(:failed_message, created_at: earlier_time,
                                processed_at: earlier_time,
                                updated_at: earlier_time)
      end


      it 'returns the age of the oldest message in words' do
        expect(subject).to eq 'less than a minute'
      end
    end

    context 'all messages have already been sent' do
      before do
        create(:sent_message)
      end

      it 'returns blank string' do
        expect(subject).to eq ''
      end
    end

    context 'one sent message exists with a created_at stamp older than an unsent message' do
      let(:earlier_time) { now - 29.seconds }
      let(:minute_ago) { now - 1.minute }
      before do
        create(:failed_message, created_at: earlier_time,
                                processed_at: earlier_time,
                                updated_at: earlier_time)
        create(:sent_message, created_at: minute_ago,
                              processed_at: minute_ago,
                              updated_at: minute_ago)
      end


      it 'returns the age of the oldest unsent message in words' do
        expect(subject).to eq 'less than a minute'
      end
    end
  end
end
