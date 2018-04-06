namespace :monitoring do
  desc "Start the background worker"
  task :start => :environment do
    Rails.application.eager_load!

    log "Monitoring enabled"
    scheduler = Rufus::Scheduler.new
    pager_attendant = PagerAttendant.new
    datadog_adapter = DatadogAdapter.new
    metrics_broadcaster = MetricsBroadcaster.new datadog_adapter
    monitoring_worker = MonitoringWorker.new pager_attendant, metrics_broadcaster, Settings.monitoring_worker_pause_amount
    cron_schedule = Settings.monitoring_cron_job_schedule
    log "Configured to monitor application according to schedule #{cron_schedule}. Using pause amount of #{Settings.monitoring_worker_pause_amount}."

    job = scheduler.repeat cron_schedule do
      monitoring_worker.work
    end

    log "Rufus job scheduled: #{job.inspect}"

    scheduler.join
  end

  def log(message)
    Rails.logger.info message
  end
end
