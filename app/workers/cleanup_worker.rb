class CleanupWorker
  include Concerns::Workers

  attr_accessor :retention_period, :batch_size

  def self.lock_name
    "#{Rails.env}_cleanup_messages"
  end

  def initialize(options = {})
    self.retention_period = options[:retention_period] || Settings.retention_period
    self.batch_size = options[:batch_size] || Settings.deletion_batch_size
  end

  def work
    with_thread_error_handling("cleanup_old_messages", false) do
      info "Database cleaner worker running"
      with_worker_lock(CleanupWorker.lock_name) do
        work_without_error_handling
      end
    end
  end

  def work_without_error_handling
    truncate_oldest_search_texts

    loop do
      ids = Message.where(
        "created_at < ? AND succeeded_at is not NULL", retention_period.seconds.ago
      ).limit(batch_size).pluck(:id).flatten


      if ids.empty?
        info "Done cleaning."
        break
      end

      Message.transaction do
        Message.where(id: ids).delete_all
        SearchText.where(message_id: ids).delete_all
        AlternateSearchText.where(message_id: ids).delete_all
      end

      info "Deleted #{ids.size} messages from the database."
    end
  end

  def truncate_oldest_search_texts
    info "Starting truncate search texts"
    first_search_text_created = SearchText.first.try(:created_at)
    first_alternate_search_text_created = AlternateSearchText.first.try(:created_at)
    info "Truncate search records found, oldest search_texts record: #{first_search_text_created}, oldest alternate_search_texts record: #{first_alternate_search_text_created}"

    unless first_search_text_created && first_alternate_search_text_created
      info "Not truncating search text tables. One table is empty."
      return
    end

    if first_search_text_created < retention_period.seconds.ago && first_alternate_search_text_created < retention_period.seconds.ago
      if first_search_text_created < first_alternate_search_text_created
        info "Truncating search text table: search_texts"
        ActiveRecord::Base.connection.execute("TRUNCATE search_texts")
      else
        info "Truncating search text table: alternate_search_texts"
        ActiveRecord::Base.connection.execute("TRUNCATE alternate_search_texts")
      end
    else
      info "Not Truncating search neither table older than retention period"
    end
  end
end
