class AddIndexOnNeedsSendingAndShardId < ActiveRecord::Migration
  def up
    add_index :messages, [:needs_sending, :shard_id], name: 'index_on_needs_sending_and_shard_id'
  end

  def down
    remove_index :messages, name: 'index_on_needs_sending_and_shard_id'
  end
end
