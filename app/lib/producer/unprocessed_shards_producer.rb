#
# This Producer is best when the number of shards in the database is not very large.
# If there only going to be thousands and perhaps tens of thousands of shards that need
# to be worked in the database, this producer is optimized to focus on more recent shards
# that need work while skipping shards that are currently being processed. It also skips
# shards that cannot be processed yet because they failed and have not exceeded the configured
# failure delay yet.
#
module Producer
  class UnprocessedShardsProducer
    include Logging

    def self.produce_work input_queue, delay_between_processing, failure_delay = Settings.threaded_worker_failure_delay
      shards = shards_past_failure_delay(failure_delay) & shards_not_being_worked_on

      if shards.empty?
        debug "All shards are processing. Producer is going to sleep for #{delay_between_processing} seconds."
        sleep delay_between_processing
      else
        shards.each do | shard |
          input_queue << shard
        end
      end
    end

    def self.shards_not_being_worked_on
      Message.connection.execute(
        "select distinct(shard_id) from (
          select shard_id, IS_FREE_LOCK(
            CONCAT('#{ThreadedWorker::LOCK_NAME_PREFIX}', COALESCE(shard_id,''))
          ) as is_free
          from messages
          where needs_sending = true) iq
         where is_free = true"
      ).to_a.flatten
    end

    def self.shards_past_failure_delay(failure_delay)
      Message.connection.execute(
        "select shard_id from messages
         where needs_sending = true and
         id in (
           select min(id) from messages
           where needs_sending = true
           group by shard_id
         )
         and (TIMESTAMPDIFF(SECOND, last_failed_at, now()) > #{failure_delay} or last_failed_at is null)
         order by last_failed_at
        "
      ).to_a.flatten
    end
  end
end
