class ChangeProcessedCountDefaultValue < ActiveRecord::Migration
  def change
    change_column_default(:messages, :processed_count, 0)
  end
end
