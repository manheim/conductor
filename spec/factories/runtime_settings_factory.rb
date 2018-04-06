FactoryGirl.define do
  factory :runtime_settings do
    settings({"workers_enabled" => true})
    one_minute_ago = 1.minute.ago
    created_at one_minute_ago
    updated_at one_minute_ago
  end
end
