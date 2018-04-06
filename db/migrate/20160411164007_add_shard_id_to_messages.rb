class AddShardIdToMessages < ActiveRecord::Migration
  def change
    #unless column_exists? :messages, :shard_id
      #add_column :messages, :shard_id, :integer
    #end
    unless column_exists? :messages, :shard_id
      execute <<-SQL
        alter table messages
          add column `shard_id` varchar(190) DEFAULT '0',
          add column `succeeded_at` datetime DEFAULT NULL,
          add column `processed_count` int(11) DEFAULT '0',
          add column `processed_at` datetime DEFAULT NULL,
          add column `last_failed_at` datetime DEFAULT NULL,
          add column `last_failed_message` text COLLATE utf8mb4_unicode_ci,
          add column `response_code` int(11) DEFAULT NULL,
          add column `response_body` text COLLATE utf8mb4_unicode_ci,
          add column `needs_sending` tinyint(1) DEFAULT '0',
          add index `index_messages_on_needs_sending` (`needs_sending`),
          add index `index_messages_on_shard_id` (`shard_id`);
      SQL
    end
  end
end
