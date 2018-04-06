require 'rails_helper'

RSpec.describe TrafficWatcher do
  include ActionView::Helpers::DateHelper
  let(:now) { Time.zone.now }

  before { Timecop.freeze }
  after { Timecop.return }

  it 'exists' do
    expect(described_class).not_to be nil
  end

  describe '#too_long_since_last_message?' do
    let(:threshold) { rand(1..5).minutes }
    before do
      allow(Settings).to receive(:most_expected_minutes_between_messages).and_return threshold
    end

    subject { described_class.new.too_long_since_last_message? described_class.new.last_message_created_at }

    context "there are no messages" do
      it "returns true" do
        expect(subject).to be false
      end
    end

    context "messages are arriving at expected intervals" do
      before do
        create_list(:sent_message, 2, created_at: now - threshold - 1.seconds)
        create_list(:sent_message, 2, created_at: now - threshold + 1.seconds)
      end
      it "returns false" do
        expect(subject).to be false
      end
    end

    context "messages are not arriving at expected intervals" do
      before do
        create_list(:sent_message, 2, created_at: now - threshold - 1.seconds)
      end

      it "returns true" do
        expect(subject).to be true
      end
    end

  end

  describe '#last_message_created_at' do
    context "there are messages" do
      let(:age) { rand(10..20) }

      before do
        create(:sent_message, created_at: now - age.minutes - 3.minutes)
        create(:sent_message, created_at: now - age.minutes - 2.minutes)
        create(:sent_message, created_at: now - age.minutes - 1.minutes)
        create(:sent_message, created_at: now - age.minutes)
      end

      it "determines age of newest message correctly" do
        expect(subject.readable_message_age subject.last_message_created_at).to eq "#{age} minutes"
      end
    end
    context "there are no messages" do
      it "returns nil" do
        expect(subject.last_message_created_at).to eq nil
      end
    end
  end

  describe '#metrics' do
    subject { described_class.new }

    context "business hours" do
      let(:time_ago) { rand(45..180) }
      let(:created_at) { Time.now - time_ago.minutes }
      before do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,14,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
      end

      it "raises an alert" do
        expect(subject.metrics).to eq(
        {
          metric_name: :no_messages_received,
          metric_value: time_ago_in_words(created_at),
          in_violation: true
        })
      end

    end
    context "non-business hours" do
      let(:time_ago) { rand(45..180) }
      let(:created_at) { Time.now - time_ago.minutes }
      before do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,2,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
      end

      it "does not raise an alert" do
        expect(subject.metrics[:in_violation]).to be false
      end
    end

    context "detects hour range properly" do
      let(:time_ago) { rand(45..180) }
      let(:created_at) { Time.now - time_ago.minutes }
      it "does not trigger at 6am" do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,10,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
        expect(subject.metrics[:in_violation]).to be false
      end

      it "does trigger at 7am" do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,11,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
        expect(subject.metrics).to eq(
        {
          metric_name: :no_messages_received,
          metric_value: time_ago_in_words(created_at),
          in_violation: true
        })
      end

      it "does trigger at 7pm" do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,23,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
        expect(subject.metrics).to eq(
        {
          metric_name: :no_messages_received,
          metric_value: time_ago_in_words(created_at),
          in_violation: true
        })
      end

      it "does trigger at 8pm, crosses 23 --> 0 hour transition" do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,0,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
        expect(subject.metrics).to eq(
        {
          metric_name: :no_messages_received,
          metric_value: time_ago_in_words(created_at),
          in_violation: true
        })
      end

      it "does not trigger at 9pm" do
        allow(Time).to receive(:now).and_return Time.new(2016,7,9,1,0,0)
        allow(Message).to receive(:last).and_return(double(Message, {created_at: created_at }))
        expect(subject.metrics[:in_violation]).to be false
      end
    end
  end
end
