class CreateMessages < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE `messages` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `body` longtext COLLATE utf8mb4_unicode_ci,
        `headers` longtext COLLATE utf8mb4_unicode_ci,
        `created_at` datetime(6) NOT NULL,
        `updated_at` datetime(6) NOT NULL,
        PRIMARY KEY (`id`),
        FULLTEXT KEY `body_idx` (`body`),
        FULLTEXT KEY `headers_idx` (`headers`)
      ) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED;
    SQL
  end

  def down
    drop_table :messages
  end
end
