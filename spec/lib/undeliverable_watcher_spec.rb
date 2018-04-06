require 'rails_helper'

# behavior: reports what the failure percentage of messges is
# concerns: the failure of msg delivery

RSpec.describe UndeliverableWatcher do

  before { Timecop.freeze }
  after { Timecop.return }

  let(:within_window) { DateTime.now - subject.window_size + 30.seconds }
  let(:outside_window) { DateTime.now - subject.window_size - 30.seconds }
  let(:configured_threshold) { 50 }

  before do
    allow(Settings).to receive(:undeliverable_percent_health_threshold).and_return(configured_threshold)
  end

  describe 'knowing if watcher is active (#active)' do
    context 'threshold not set' do
      let(:configured_threshold) { nil }
      it 'is not active' do
        expect(subject.active?).to eq false
      end
    end

    context 'threshold is set' do
      let(:configured_threshold) { rand(1..10) }
      it 'is not active' do
        expect(subject.active?).to eq true
      end
    end
  end

  describe 'getting metrics (#metrics)' do

    context 'failure percent is above threshold' do
      it 'returns a metric block' do
        metric = subject.metrics
        expect(metric).to have_key(:metric_name)
        expect(metric).to have_key(:metric_value)
        expect(metric).to have_key(:in_violation)
      end

      it 'populates name with undeliverable_message_percentage' do
        expect(subject.metrics[:metric_name]).to eq :undeliverable_message_percentage
      end

      it 'populates the metric value the failure percentage' do
        expect(subject.metrics[:metric_value]).to eq(subject.undeliverable_percent)
      end

      context 'failure percent is greater than or eq to configured threshold' do
        before do
          # all failure
          create_list(:failed_message_no_retry, 10, created_at: within_window,
                                                    updated_at: within_window,
                                                    last_failed_at: within_window,
                                                    processed_at: within_window)
        end
        it 'is in violation' do
          expect(subject.metrics[:in_violation]).to eq true
        end
      end

      context 'failure percent is less than greater than configured threshold' do
        it 'is not in violation' do
          expect(subject.metrics[:in_violation]).to eq false
        end
      end
    end
  end

  describe 'descerning percentage of messages which fail to be delivered is (#fail_percent)' do
    context 'no messages exist' do
      it 'has failure percentage of zero' do
        expect(subject.undeliverable_percent).to eq(0)
      end
    end

    context 'messages exist within window, all have been sent successfully' do
      before do
        create_list(:sent_message, rand(10), created_at: within_window,
                                             updated_at: within_window,
                                             processed_at: within_window,
                                             succeeded_at: within_window)
      end
      it 'has failure percent of zero' do
        expect(subject.undeliverable_percent).to eq(0)
      end
    end

    context 'messages exist only within window, some have failed and are not being retried' do
      let(:num_success) { rand(2..50) }
      let(:num_fail) { rand(2..50) }
      let(:total_messages) { num_success + num_fail }
      let(:undeliverable_percentage) {  (num_fail.to_f / total_messages) * 100 }
      before do
        create_list(:sent_message, num_success, created_at: within_window,
                                                updated_at: within_window,
                                                processed_at: within_window,
                                                succeeded_at: within_window)
        create_list(:failed_message_no_retry, num_fail, created_at: within_window,
                                                        updated_at: within_window,
                                                        last_failed_at: within_window,
                                                        processed_at: within_window)
      end
      it 'has failure percentage eq to total / fail within window' do
        expect(subject.undeliverable_percent).to eq undeliverable_percentage
      end
    end

    context 'messages exist in and outside of window, successes and failures' do
      let(:num_success) { rand(2..50) }
      let(:num_fail) { rand(2..50) }
      let(:num_success_outside_window) { rand(2..50) }
      let(:num_fail_outside_window) { rand(2..50) }
      let(:total_messages) { num_success + num_fail }
      let(:undeliverable_percentage) {  (num_fail.to_f / total_messages) * 100 }
      before do
        create_list(:sent_message, num_success, created_at: within_window,
                                                updated_at: within_window,
                                                processed_at: within_window,
                                                succeeded_at: within_window)
        create_list(:failed_message_no_retry, num_fail, created_at: within_window,
                                                        updated_at: within_window,
                                                        last_failed_at: within_window,
                                                        processed_at: within_window)
        create_list(:sent_message, num_success_outside_window, created_at: outside_window,
                                                               updated_at: outside_window,
                                                               processed_at: outside_window,
                                                               succeeded_at: outside_window)
        create_list(:failed_message_no_retry, num_fail_outside_window, created_at: outside_window,
                                                                       updated_at: outside_window,
                                                                       last_failed_at: outside_window,
                                                                       processed_at: outside_window)
      end
      it 'does not take in to acct messages outside window' do
        expect(subject.undeliverable_percent).to eq undeliverable_percentage
      end
    end
  end
end
