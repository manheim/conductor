require 'rails_helper'
require 'webmock/rspec'

# concerns: getting monitor like work done under lock
# behavior: refreshes pages

RSpec.describe MonitoringWorker, type: :request do
  describe "#work" do

    after do
      Message.connection.reset!
    end

    subject do
      MonitoringWorker.new(pager_attendant, metrics_broadcaster, 0.1)
    end

    let(:pager_attendant) { double(PagerAttendant, :"refresh_pages!" => nil) }
    let(:metrics_broadcaster) { double(MetricsBroadcaster, :"broadcast!" => nil) }
    let(:metrics) { [{ a: 1 }] }
    let(:healthy) { [true, false].sample }

    before do
      allow_any_instance_of(HealthWatcher).to receive(:health_status)
                                              .and_return(metrics)
      allow(HealthWatcher).to receive(:is_healthy?).and_return healthy
    end

    it 'refreshes pages, passing metrics' do
      expect(pager_attendant).to receive(:refresh_pages!).with(metrics)
      subject.work
    end

    it 'broadcasts metrics, passing metrics and health' do
      expect(metrics_broadcaster).to receive(:broadcast!).with(metrics, healthy)
      subject.work
    end

    it "respects the advisory lock" do
      thread = Thread.new do
        result = Message.with_advisory_lock_result(MonitoringWorker.lock_name) do
          sleep 1
        end
        expect(result.lock_was_acquired?).to be true
      end

      sleep 0.5

      expect(pager_attendant).not_to receive(:refresh_pages!)

      subject.work

      thread.join
    end

    it "respects the advisory lock if a thread gets past the first check" do
      worker1 = MonitoringWorker.new(pager_attendant, metrics_broadcaster, 1)
      worker2 = MonitoringWorker.new(pager_attendant, metrics_broadcaster, 1)

      allow(Message).to receive(:advisory_lock_exists?).and_return false

      expect(pager_attendant).to receive(:refresh_pages!).once
      expect(pager_attendant).to receive(:refresh_pages!).never

      thread1 = Thread.new do
        worker1.work
      end

      sleep 0.5

      thread2 = Thread.new do
        worker2.work
      end

      thread1.join
      thread2.join
    end

  end
end
