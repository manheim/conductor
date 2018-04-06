class MessageSerializer < ActiveModel::Serializer
  attributes :id, :shard_id, :body, :headers, :succeeded_at, :processed_at,
             :processed_count, :last_failed_at, :last_failed_message, :response_code,
             :response_body, :needs_sending, :created_at, :updated_at
end
