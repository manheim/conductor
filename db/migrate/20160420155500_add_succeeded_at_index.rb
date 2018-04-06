class AddSucceededAtIndex < ActiveRecord::Migration
  def up
    add_index :messages, :succeeded_at
  end

  def down
    remove_index :messages, :succeeded_at
  end
end

