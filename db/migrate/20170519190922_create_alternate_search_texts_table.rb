class CreateAlternateSearchTextsTable < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE `alternate_search_texts` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `message_id` int(11) NOT NULL,
        `text` longtext COLLATE utf8mb4_unicode_ci,
        `created_at` datetime(6) NOT NULL,
        `updated_at` datetime(6) NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE INDEX (`message_id`),
        FULLTEXT KEY `text_idx` (`text`)
      ) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=COMPRESSED;
    SQL
  end

  def down
    drop_table :alternate_search_texts
  end
end
