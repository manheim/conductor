class RemoveFullTextIndexFromMessages < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table messages drop index `body_idx`, drop index `headers_idx`
    SQL
  end

  def down
    execute <<-SQL
      alter table messages
        add FULLTEXT KEY `body_idx` (`body`);
    SQL
    execute <<-SQL
      alter table messages
        add FULLTEXT KEY `headers_idx` (`headers`);
    SQL
  end
end
