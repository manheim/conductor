require 'rails_helper'

RSpec.describe MessageCreator do
  let(:sample_shard_value) { rand(1..1024) }
  let(:request) do
    ActionDispatch::Request.new(Rack::MockRequest.env_for("http://example.com:8080/", {"HTTP_SAMPLE_SHARD_ID" => sample_shard_value, "REMOTE_ADDR" => "10.10.10.10"}))
  end

  let(:options) do
    {
      settings: {
        search_text_number_characters: 10,
        search_text_words: 'vin',
        search_text_extraction_direction: "bidirectional",
        shard_tag: 'Sample-Shard-Id'
      },
      params: {},
      request: request
    }
  end

  let(:creator) { MessageCreator.new options }

  it "creates the message" do
    allow(request).to receive(:body).and_return(StringIO.new("aaaaaaaaaa1234567890vin1234567890aaaaaaaaaaa"))
    expect {
      creator.create
    }.to change{ Message.count }.by 1
  end

  context "DISABLE_MESSAGE_SENDING" do

    let(:options) do
      {
        settings: {
          search_text_number_characters: 10,
          search_text_words: 'vin',
          search_text_extraction_direction: "bidirectional",
          shard_tag: 'Sample-Shard-Id',
          disable_message_sending: true,
          enable_tag: 'Conductor-Enabled-Tag'
        },
        params: {},
        request: request
      }
    end

    it "creates the message with needs_sending as false" do
      expect {
        creator.create
      }.to change{ Message.count }.by 1
      message = Message.last
      expect(message.needs_sending).to be false
    end
  end

  it 'uses the shard id' do
    creator.create
    expect(Message.last.shard_id).to eq sample_shard_value.to_s
  end

  context "search texts" do
    [
      ["search_text", SearchText],
      ["alternate_search_text", AlternateSearchText]
    ].each do |name, clazz|
      context name do
        it "creates the record" do
          expect {
            creator.create
          }.to change{ clazz.count }.by 1
        end

        it "populates the message_id" do
          creator.create
          expect(Message.last.public_send(name).message_id).to eq Message.last.id
        end

        it "populates the text" do
          allow(request).to receive(:body).and_return(StringIO.new("aaaaaaaaaa1234567890vin1234567890aaaaaaaaaaa"))
          creator.create
          expect(Message.last.public_send(name).text).to eq '1234567890vin1234567890'
        end

        it "removes whitespace when splitting the words" do
          options[:settings][:search_text_words] = "vin, dealer_number"
          allow(request).to receive(:body).and_return(StringIO.new("aaaaaaaaaa1234567890dealer_number1234567890aaaaaaaaaaa"))
          creator.create
          expect(Message.last.public_send(name).text).to eq '1234567890dealer_number1234567890'
        end
      end
    end
  end

  context 'autogeneration of shard id' do
    let(:options) do
      {
        settings: {
          search_text_number_characters: 10,
          search_text_words: 'vin',
          search_text_extraction_direction: "bidirectional",
          autogenerate_shard_id: 'true',
          autogenerate_shard_id_range: 16
        },
        params: {},
        request: request
      }
    end

    let(:creator) { MessageCreator.new options }

    it 'generates a shard id within the specified range' do
      shard_ids = []
      32.times do
        creator.create
        shard_ids.push(Message.last.shard_id.to_i)
      end

      expect(shard_ids).to all( be <= 16 )
    end
  end

  context 'an error during message creation' do
    it "does not create the message if there is an error creating the search text" do
      error = StandardError.new("BOOM")
      allow(SearchText).to receive(:create).and_raise(error)
      expect {
        creator.create
      }.to raise_error(error)
      expect(Message.count).to eq 0
    end

    it "raises a top level exception" do
      exception = Exception.new("STOP RUNNING")
      allow(SearchText).to receive(:create).and_raise(exception)
      expect {
        creator.create
      }.to raise_error(exception)
    end
  end
end
