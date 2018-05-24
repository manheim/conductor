class ThreadedWorker
  include Concerns::Workers
  include Concerns::HeaderCleaner

  LOCK_NAME_PREFIX = "message-"

  ALLOWED_OPTIONS = [
    :thread_count,
    :sleep_delay,
    :failure_delay,
    :failure_exponent_base,
    :max_failure_delay,
    :max_exponent_value,
  ]

  attr_accessor(*ALLOWED_OPTIONS)
  attr_accessor :input_queue, :completed_work, :thread_pool, :consumers, :producer, :connection

  def self.register_ttin_handler
    trap 'TTIN' do
      output = ""
      output += "-"*80
      Thread.list.each do |thread|
        output += "\n"
        output += "Thread TID-#{thread.object_id.to_s(36)}"
        output += "\n"
        output += thread.backtrace.join("\n")
        output += "\n"
        output += "-"*80
      end
      puts output
    end
  end

  def self.basic_auth_connection
    Faraday.new do |faraday|
      faraday.use BasicAuthMiddleware
      faraday.adapter Faraday.default_adapter
    end
  end

  def default_connection
    Faraday.new
  end

  def initialize(options = {})
    self.thread_count = options[:thread_count] || Settings.threaded_worker_thread_count
    self.sleep_delay = options[:sleep_delay] || Settings.threaded_worker_sleep_delay
    self.failure_delay = options[:failure_delay] || Settings.threaded_worker_failure_delay
    self.failure_exponent_base = options[:failure_exponent_base] || Settings.threaded_worker_failure_exponent_base
    self.max_failure_delay = options[:max_failure_delay] || Settings.threaded_worker_max_failure_delay
    self.max_exponent_value = options[:max_exponent_value] || Settings.threaded_worker_max_exponent_value
    self.input_queue = SizedQueue.new(thread_count)
    self.connection = options[:connection] || default_connection
    self.producer = load_producer(options[:producer_name], input_queue)
    self.consumers = []
  end

  def load_producer producer_name, input_queue
    producer_class = Producer::IterativeDatabaseProducer unless producer_name
    producer_class ||= producer_name.constantize
    info "Loaded producer #{producer_class}"
    producer_class.new(input_queue, {
      threaded_worker_failure_delay: Settings.threaded_worker_failure_delay,
      threaded_worker_failure_exponent_base: Settings.threaded_worker_failure_exponent_base,
      threaded_worker_no_work_delay: Settings.threaded_worker_no_work_delay,
      threaded_worker_max_exponent_value: Settings.threaded_worker_max_exponent_value
    })
  end

  def start
    while(true) do
      process_work
      sleep(sleep_delay)
    end
  end

  def create_consumers
    living_consumers = consumers.count { |c| c.alive? }
    return if living_consumers == thread_count

    difference = thread_count - living_consumers

    if consumers.size > 0
      info "Some dead consumers detected! Reaping and restoring #{difference} consumers."
      self.consumers.reject! { |thread| !thread.alive? }
    end

    info "Creating #{difference} consumers"

    difference.times do
      self.consumers << Thread.new do
        consume_work
      end
    end

    info "Created consumers"
  end

  def consume_work
    while(true) do
      shard_id = input_queue.pop
      debug "Got shard in consumer: #{shard_id}"
      with_thread_error_handling("process_shard", true) do
        process_shard(shard_id)
      end
    end
  end

  def process_work
    with_thread_error_handling("produce_work", true) do
      while(Message.where(needs_sending: true).count > 0)
        if RuntimeSettings::Config.workers_enabled
          process_without_looping
        else
          return
        end
      end
    end
  end

  def produce_work
    producer.produce_work
  end

  def process_without_looping
    create_consumers
    produce_work
  end

  def wait_for_processing
    while(!input_queue.empty?)
      sleep(0.1)
    end
  end

  def process_shard(shard_id)
    debug "About to get advisory lock on #{shard_id}"

    if Message.advisory_lock_exists?("#{LOCK_NAME_PREFIX}#{shard_id}")
      debug "Advisory lock detected on #{shard_id}. Skipping..."
      return
    end

    Message.with_advisory_lock("#{LOCK_NAME_PREFIX}#{shard_id}", 0) do
      do_work_inside_lock(shard_id)
    end
  end

  add_method_tracer :process_shard, 'Custom/ThreadedWorker/process_shard'

  def do_work_inside_lock(shard_id)
    from = "#{Message.quoted_table_name} USE INDEX(index_on_needs_sending_and_shard_id)"
    message_id = Message.from(from).
      where(shard_id: shard_id, needs_sending: true).
      order(id: :asc).limit(1).all.pluck(:id).first

    message = Message.where(id: message_id).first

    if !message.present?
      debug "Could not find message as expected for shard: #{shard_id}"
      return
    end

    next_retry = RetryCalculator.new(
      failure_delay: failure_delay,
      failure_exponent_base: failure_exponent_base,
      max_failure_delay: max_failure_delay,
      max_exponent_value: max_exponent_value
    ).next_retry(message)

    if message.last_failed_at && Time.now < next_retry
      info "Skipping processing of message #{message.id} since next retry time is #{next_retry}"
      return
    end

    begin
      clean_headers = auth_cleaner(JSON.parse(message.headers))
      log "Processing message: id: #{message.id}, headers: #{clean_headers}"
      response = call_endpoint(message)
      log "Got response: #{auth_cleaner(response.to_hash)}"
      if response.status.to_s.first == "2"
        update_success(message, response)
      else
        update_failure(message, response)
      end
    rescue StandardError => e
      update_error(message, e)
    rescue Exception => e
      update_error(message, e)
      raise e
    end
  end

  add_method_tracer :do_work_inside_lock, 'Custom/ThreadedWorker/do_work_inside_lock'

  def update_error(message, error)
    error "A Network related error has occurred: #{([error.message] + error.backtrace).join("\n")}"
    sending_decider = SendingDecider.new message
    message.update_attributes(
      processed_count: message.processed_count + 1,
      processed_at: Time.now,
      last_failed_at: Time.now,
      last_failed_message: ([error.message] + error.backtrace).join("\n"),
      needs_sending: sending_decider.needs_sending?
    )
  end

  def update_failure(message, response)
    sending_decider = SendingDecider.new message
    message.update_attributes(
      processed_count: message.processed_count + 1,
      processed_at: Time.now,
      last_failed_at: Time.now,
      response_code: response.status,
      response_body: response.body,
      needs_sending: sending_decider.needs_sending?
    )
  end

  def update_success(message, response)
    sending_decider = SendingDecider.new message
    sending_decider.send_succeeded
    message.update_attributes(
      processed_count: message.processed_count + 1,
      processed_at: Time.now,
      succeeded_at: Time.now,
      response_code: response.status,
      response_body: response.body,
      needs_sending: sending_decider.needs_sending?
    )
  end

  def call_endpoint(message)
    connection.post(endpoint_url, message.body, convert_headers(message))
  end

  add_method_tracer :call_endpoint, 'Custom/ThreadedWorker/call_endpoint'

  def convert_headers(message)
    if message.headers
      headers = JSON.parse(message.headers)
      headers.delete("Host")
      headers
    else
      {}
    end
  end

  def endpoint_url
    url = URI(Settings.endpoint_hostname)
    url.path = Settings.endpoint_path
    if Settings.endpoint_query.present?
      url.query = Settings.endpoint_query
    end
    url.to_s
  end
end
