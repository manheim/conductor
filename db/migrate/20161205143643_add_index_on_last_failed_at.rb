class AddIndexOnLastFailedAt < ActiveRecord::Migration
  def up
    unless index_exists? :messages, :last_failed_at
      add_index :messages, :last_failed_at
    end
  end

  def down
    remove_index :messages, :last_failed_at
  end
end

