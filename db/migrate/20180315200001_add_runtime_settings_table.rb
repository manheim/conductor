class AddRuntimeSettingsTable < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE `runtime_settings` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `settings` mediumtext COLLATE utf8mb4_unicode_ci,
        `created_at` datetime(6) NOT NULL,
        `updated_at` datetime(6) NOT NULL,
        PRIMARY KEY (`id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    SQL
  end

  def down
    drop_table :runtime_settings
  end
end
