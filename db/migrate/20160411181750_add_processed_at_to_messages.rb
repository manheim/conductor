class AddProcessedAtToMessages < ActiveRecord::Migration
  def change
    unless column_exists? :messages, :processed_at
      add_column :messages, :processed_at, :timestamp
    end
  end
end
