class AddResponseCodeResponseBodyToMessages < ActiveRecord::Migration
  def change
    unless column_exists? :messages, :response_code
      add_column :messages, :response_code, :integer
    end
    unless column_exists? :messages, :response_body
      add_column :messages, :response_body, :text
    end
  end
end
