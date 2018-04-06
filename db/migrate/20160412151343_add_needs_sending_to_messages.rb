class AddNeedsSendingToMessages < ActiveRecord::Migration
  def up
    unless column_exists? :messages, :needs_sending
      add_column :messages, :needs_sending, :boolean, default: false
    end
    unless index_exists? :messages, :needs_sending
      add_index :messages, :needs_sending
    end
    unless index_exists? :messages, :shard_id
      add_index :messages, :shard_id
    end
  end

  def down
    remove_column :messages, :needs_sending
    remove_index :messages, :shard_id
  end
end
