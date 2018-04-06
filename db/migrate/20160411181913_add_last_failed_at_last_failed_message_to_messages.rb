class AddLastFailedAtLastFailedMessageToMessages < ActiveRecord::Migration
  def change
    unless column_exists? :messages, :last_failed_at
      add_column :messages, :last_failed_at, :timestamp
    end
    unless column_exists? :messages, :last_failed_message
      add_column :messages, :last_failed_message, :text
    end
  end
end
