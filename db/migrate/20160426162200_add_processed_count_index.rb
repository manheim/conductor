class AddProcessedCountIndex < ActiveRecord::Migration
  def up
    add_index :messages, :processed_count
  end

  def down
    remove_index :messages, :processed_count
  end
end


