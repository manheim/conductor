class ChangeTimestampsToBeMicrosecondPrecision < ActiveRecord::Migration
  def up
    change_column(:messages, :succeeded_at, "datetime(6) DEFAULT NULL")
    change_column(:messages, :processed_at, "datetime(6) DEFAULT NULL")
    change_column(:messages, :last_failed_at, "datetime(6) DEFAULT NULL")
  end

  def down
    change_column(:messages, :succeeded_at, "datetime DEFAULT NULL")
    change_column(:messages, :processed_at, "datetime DEFAULT NULL")
    change_column(:messages, :last_failed_at, "datetime DEFAULT NULL")
  end
end
