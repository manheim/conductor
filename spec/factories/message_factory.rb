
one_minute_ago = Time.now - 1.minute

FactoryGirl.define do
  factory :message do
    created_at one_minute_ago
    updated_at one_minute_ago
    #processed_at nil
    #succeeded_at nil
    body ''
    headers '{}'
    shard_id { Random.rand(1..1024) }
    #processed_count 0
    #last_failed_at nil
    #last_failed_message nil
    #response_code
    #response_body
    needs_sending true

    after(:build) do |message|
      message.search_text = SearchText.new(message: message, text: message.body)
      message.alternate_search_text = AlternateSearchText.new(message: message, text: message.body)
    end
  end

  factory :sent_message, class: Message, parent: :message do
    succeeded_at one_minute_ago
    processed_at one_minute_ago
    processed_count 1
    response_code 200
    response_body ''
    needs_sending false
  end

  factory :failed_message, class: Message, parent: :message do
    last_failed_at one_minute_ago
    last_failed_message 'failz'
    processed_at one_minute_ago
    processed_count { Random.rand(1..100) }
    response_code 500
    response_body ''
    needs_sending true
  end

  factory :failed_message_no_retry, class: Message, parent: :message do
    last_failed_at one_minute_ago
    last_failed_message 'failz'
    processed_at one_minute_ago
    processed_count { Random.rand(1..100) }
    response_code 500
    response_body ''
    needs_sending false
  end
end

# "bad" messages (aka have been processed many times and still have error)
# "good" messages, aka already sent
# "unprocessed" messages

# created_at
# processed_count
