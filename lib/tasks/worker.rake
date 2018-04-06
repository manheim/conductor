namespace :workers do
  desc "Start the background worker"
  task :start => :environment do
    Rails.application.eager_load!

    ThreadedWorker.register_ttin_handler

    options = {}
    options.merge!({ producer_name: ENV['CONDUCTOR_PRODUCER_NAME'] }) if ENV['CONDUCTOR_PRODUCER_NAME']
    options.merge!({ connection: ThreadedWorker.basic_auth_connection }) if Settings.use_destination_basic_auth

    ThreadedWorker.new(options).start
  end
end
