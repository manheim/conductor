class ChangeShardIdDefaultValue < ActiveRecord::Migration
  def change
    change_column_default(:messages, :shard_id, 0)
  end
end
