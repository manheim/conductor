require 'rails_helper'

RSpec.describe RetryCalculator do
  let(:message) { create(:message, last_failed_at: last_failed_at, processed_count: processed_count) }
  let(:now) { Time.now }
  let(:last_failed_at) { 5.minutes.ago }
  let(:max_failure_delay) { nil }
  let(:max_exponent_value) { 300 }

  subject do
    RetryCalculator.new(
      failure_delay: failure_delay,
      failure_exponent_base: failure_exponent_base,
      max_failure_delay: max_failure_delay,
      max_exponent_value: max_exponent_value,
    )
  end

  context "no exponential backoff configured" do
    let(:failure_delay) { rand(1..99) }
    let(:failure_exponent_base) { 1 }
    let(:processed_count) { 51 }

    it "returns the next time to retry as last_failed plus retry delay" do
      retry_at = subject.next_retry(message)
      expect(retry_at).to eq(last_failed_at + failure_delay)
    end
  end

  context "exponential backoff configured as zero" do
    let(:failure_delay) { rand(1..99) }
    let(:failure_exponent_base) { 0 }
    let(:processed_count) { 51 }

    it "returns the next time to retry as last_failed plus retry delay" do
      retry_at = subject.next_retry(message)
      expect(retry_at).to eq(last_failed_at + failure_delay)
    end
  end

  context "exponential backoff configured" do
    let(:failure_delay) { rand(1..99) }
    let(:failure_exponent_base) { 2 }

    context "no failures" do
      let(:last_failed_at) { nil }
      let(:processed_count) { 0 }

      it "returns the current time" do
        Timecop.freeze(now) do
          retry_at = subject.next_retry(message)
          expect(retry_at).to eq(now)
        end
      end
    end

    context "1 failure" do
      let(:processed_count) { 1 }

      it "returns the next time to retry as last_failed plus retry delay" do
        retry_at = subject.next_retry(message)
        expect(retry_at).to eq(last_failed_at + failure_delay)
      end
    end

    context "2 failures" do
      let(:failure_delay) { 10 }
      let(:processed_count) { 2 }

      it "returns the next time to retry exponentally" do
        retry_at = subject.next_retry(message)
        expect(retry_at).to eq(last_failed_at + 20)
      end
    end

    context "3 failures" do
      let(:failure_delay) { 10 }
      let(:processed_count) { 3 }

      it "returns the next time to retry exponentally" do
        retry_at = subject.next_retry(message)
        expect(retry_at).to eq(last_failed_at + 40)
      end
    end

    context "4 failures" do
      let(:failure_delay) { 10 }
      let(:processed_count) { 4 }

      it "returns the next time to retry exponentally" do
        retry_at = subject.next_retry(message)
        expect(retry_at).to eq(last_failed_at + 80)
      end
    end

    context "10000 failures" do
      let(:failure_delay) { 10 }
      let(:processed_count) { 10000 }
      let(:failure_exponent_base) { 2 }

      it "limits the exponential calculation" do
        retry_at = subject.next_retry(message)
        expect(retry_at).to eq(
          last_failed_at + failure_delay * (
            failure_exponent_base ** (max_exponent_value - 1)
          )
        )
      end
    end

    context "with a max_failure_delay configured" do
      let(:failure_delay) { 10 }
      let(:processed_count) { 4 }
      let(:max_failure_delay) { 75 }

      it "returns the next time to retry exponentally" do
        retry_at = subject.next_retry(message)
        expect(retry_at).to eq(last_failed_at + 75)
      end
    end
  end
end
