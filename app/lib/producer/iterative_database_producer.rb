#
# This Producer is best when the number of shards in the database is very large.
# For instance, if there were ever hundreds of thousands or millions of shards
# that needs processing, this producer can handle that, but with the tradeoff that
# it may be unpredictable as to what shards get worked on next.
#
module Producer
  class IterativeDatabaseProducer
    include Logging

    def initialize(input_queue, settings)
      @input_queue = input_queue
      @iterative_producer_batch_size = settings[:iterative_producer_batch_size]
    end

    def produce_work
      newest_message = Message.where(needs_sending: true).select(:id).last

      query = if newest_message
                Message.where(needs_sending: true)
                       .where("id <= #{newest_message.id}")
              else
                Message.where(needs_sending: true)
              end

      query.select(:id, :shard_id).find_in_batches(batch_size: @iterative_producer_batch_size) do |messages|
        shards = messages.map(&:shard_id).uniq
        debug("Found #{shards.size} to produce")
        shards.each do |s|
          debug("Enqueuing shard #{s}")
          @input_queue << s
        end
      end
    end
  end
end
