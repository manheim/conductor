class ChangeShardIdToString < ActiveRecord::Migration
  def change
    unless column_exists?(:messages, :shard_id, :string, limit: 190)
      change_column(:messages, :shard_id, :string, limit: 190)
    end
  end
end
