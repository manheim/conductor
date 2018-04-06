class Message < ActiveRecord::Base
  has_one :search_text
  has_one :alternate_search_text
end
