class AddProcessedCountToMessages < ActiveRecord::Migration
  def change
    unless column_exists? :messages, :processed_count
      add_column :messages, :processed_count, :integer
    end
  end
end
