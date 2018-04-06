class AddSucceededAtToMessages < ActiveRecord::Migration
  def change
    unless column_exists? :messages, :succeeded_at
      add_column :messages, :succeeded_at, :timestamp
    end
  end
end
