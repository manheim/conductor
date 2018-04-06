class RemoveNeedsSendingIndexFromMessages < ActiveRecord::Migration
  def up
    if index_exists?(:messages, :needs_sending)
      remove_index(:messages, :needs_sending)
    end
  end

  def down
    unless index_exists?(:messages, :needs_sending)
      add_index(:messages, :needs_sending)
    end
  end
end
