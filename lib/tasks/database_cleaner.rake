namespace :database_cleaner do
  desc "Start the database cleaner background worker"
  task :start => :environment do
    Rails.application.eager_load!

    log "Database cleaner background worker started"
    scheduler = Rufus::Scheduler.new
    cleanup_worker = CleanupWorker.new
    cron_schedule = Settings.cleanup_cron_job_schedule
    log "Configured to cleanup records according to schedule #{cron_schedule}"

    job = scheduler.repeat cron_schedule do
      cleanup_worker.work
    end

    log "Rufus job scheduled: #{job.inspect}"

    scheduler.join
  end

  def log(message)
    Rails.logger.info message
  end
end
