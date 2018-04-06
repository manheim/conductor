class MonitoringWorker
  include Concerns::Workers

  def self.lock_name
    "#{Rails.env}_monitor_health"
  end

  def initialize pager_attendant, metric_broadcaster, pause_amount = 5
    @pager_attendant = pager_attendant
    @metric_broadcaster = metric_broadcaster
    @pause_amount = pause_amount
  end

  def work
    with_thread_error_handling(self.class.lock_name, false) do
      with_worker_lock(MonitoringWorker.lock_name) do
        info "Running"
        metrics = HealthWatcher.new.health_status
        healthy = HealthWatcher.is_healthy? metrics
        @pager_attendant.refresh_pages! metrics
        @metric_broadcaster.broadcast! metrics, healthy
        sleep @pause_amount
      end
    end
  end

end
