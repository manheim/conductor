require 'rails_helper'

RSpec.describe MessagesApiController, type: :request do

  include AuthRequestHelper

  message_datetime_fields = Message.column_names.select { |col| col.end_with? '_at' }
  message_non_datetime_fields = Message.column_names.select { |col| !col.end_with? '_at' }
  updatable_fields = ['needs_sending']

  let(:message) { create(:message) }
  let(:basic_auth_on) { false }

  before do
    allow(Settings).to receive(:basic_auth_enabled).and_return(basic_auth_on)
    randomize_message_values
  end

  describe "find messages by criteria (#search)" do

    let(:range_start) { DateTime.new(2015, 1, 2, 1) }
    let(:range_end)   { DateTime.new(2015, rand(2..10), 1, 1) }

    let!(:in_range_messages) do
      rand(2..10).times { create(:message, created_at: rand(range_start..range_end)) }
    end
    let!(:out_range_messages) do
      rand(2..4).times { create(:message, created_at: range_start - 1) }
      rand(2..4).times { create(:message, created_at: range_end + 1) }
    end

    it "returns a 200" do
      get "/messages/search"
      expect(response.code).to eq '200'
    end

    it "returns valid json" do
      get "/messages/search"
      expect(JSON.parse(response.body)).not_to eq nil
    end

    it "lists items under item top level key" do
      get "/messages/search"
      data = JSON.parse(response.body)
      expect(data['items']).not_to eq nil
    end

    it "returns id data for all messages" do
      get "/messages/search"
      data = JSON.parse(response.body)
      expected_ids = Message.all.map(&:id)
      returned_ids = data['items'].map{ |d| d['id'] }
      expect(returned_ids).to eq expected_ids
    end

    it "returns only id data for all messages" do
      get "/messages/search"
      data = JSON.parse(response.body)
      data['items'].each do |d|
        expect(d.keys).to eq ['id']
      end
    end

    context "created_after specified" do
      it "returns an item for each message created after specified value" do
        get "/messages/search?created_after=#{range_start.iso8601}"
        data = JSON.parse(response.body)
        expected_ids = Message.where('created_at > ?', range_start).map(&:id)
        returned_ids = data['items'].map{ |d| d['id'] }
        expect(returned_ids).to eq expected_ids
      end
    end

    context "created_before specified" do
      it "returns an item for each message created before or equal to specified value" do
        get "/messages/search?created_before=#{range_end.iso8601}"
        data = JSON.parse(response.body)
        expected_ids = Message.where('created_at <= ?', range_end).map(&:id)
        returned_ids = data['items'].map{ |d| d['id'] }
        expect(returned_ids).to eq expected_ids
      end
    end

    context "created_before and created_after specified" do
      it "returns message data for each message within date range" do
        get "/messages/search?created_after=#{range_start.iso8601}&created_before=#{range_end.iso8601}"
        data = JSON.parse(response.body)
        expected_ids = Message.where('created_at > ? AND created_at <= ?', range_start, range_end).map(&:id)
        returned_ids = data['items'].map{ |d| d['id'] }
        expect(returned_ids).to eq expected_ids
      end
    end

    context "page size (limit) is smaller than the number of messages to be returned" do
      let(:page_size) { [1, Message.count - rand(10)].max }

      context "there are more than 25 messages and limit is not specified" do
        before do
          create_list(:message, 26)
        end
        it "returns 25 records" do
          get "/messages/search"
          data = JSON.parse(response.body)
          expect(data['items'].length).to eq 25
        end
      end

      context "limit is specified larger than 500 items" do
        before do
          create_list(:message, 501)
        end
        it "returns 500 items in page" do
          get "/messages/search?limit=700"
          data = JSON.parse(response.body)
          expect(data['items'].length).to eq 500
        end
      end

      it "returns the # of messages specified in limit param (page size)" do
        get "/messages/search?limit=#{page_size}"
        data = JSON.parse(response.body)
        expect(data['items'].length).to eq page_size
      end

      context "start is not specified" do
        it "returns first page" do
          get "/messages/search?limit=#{page_size}"
          data = JSON.parse(response.body)
          returned_ids = data['items'].map{ |d| d['id'] }
          first_page_ids = Message.first(page_size).map(&:id)
          expect(returned_ids).to eq first_page_ids
        end
      end

      context "start is specified" do
        it "returns the page after the start message specified" do
          start = Message.all.sample.id
          next_page_ids = Message.all[start..start+page_size-1].map(&:id)
          get "/messages/search?limit=#{page_size}&start=#{start}"
          data = JSON.parse(response.body)
          message_ids = data['items'].map{ |d| d['id'] }
          expect(message_ids).to eq next_page_ids
        end
      end

      context "text is specified" do
        it "returns the messages with search_text matching the text" do
          messages = [
            create(:message, body: '{"vin": "abc123"}'),
            create(:message, body: '{"vin": "abc123"}'),
          ]

          get "/messages/search?text=abc123"
          data = JSON.parse(response.body)
          message_ids = data['items'].map{ |d| d['id'] }
          expect(message_ids).to match_array messages.map(&:id)
        end
      end

      context "with_fields" do
        context "with_fields=all" do
          it "renders the whole message" do
            messages = [
              create(:message, body: '{"vin": "abc123"}'),
              create(:message, body: '{"vin": "abc123"}'),
            ]

            get "/messages/search?text=abc123&with_fields=all"
            data = JSON.parse(response.body)
            message_ids = data['items'].map{ |d| d['body'] }
            expect(message_ids).to match_array messages.map(&:body)
          end
        end

        context "with_fields=almostall" do
          it "does not render the whole message" do
            create(:message, body: '{"vin": "abc123"}')
            create(:message, body: '{"vin": "abc123"}')

            get "/messages/search?text=abc123&with_fields=almostall"
            data = JSON.parse(response.body)
            message_ids = data['items'].map{ |d| d['body'] }
            expect(message_ids).to match_array [nil, nil]
          end
        end
      end
    end

    context "auth is on" do
      let(:basic_auth_on) { true }

      context "correct creds are provided" do
        it "returns 200" do
          http_auth_as(Settings.basic_auth_user, Settings.basic_auth_password) do
            auth_get "/messages/search"
          end
          expect(response.code).to eq '200'
        end
      end

      context "no creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/messages/#{message.id}", { needs_sending: true }.to_json
          end
          expect(response.code).to eq '401'
        end
      end

      context "incorrect creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_get "/messages/search"
          end
          expect(response.code).to eq '401'
        end
      end
    end
  end

  describe "create message details in bulk (#bulk_create)" do
    let(:messages_json) do
      [
        {
          body: { someJson: "something1" }.to_json
        },
        {
          body: { someJson: "something2" }.to_json
        }
      ]
    end

    let(:missing_body_message_json) do
      [
        {
          body: { someJson: "something1" }.to_json
        },
        {
          not_body: { someJson: "something2" }.to_json
        }
      ]
    end

    let(:missing_hash_message_json) do
      [
        {
          body: { someJson: "something1" }.to_json
        },
        ""
      ]
    end

    let(:message) { nil }

    it "responds with a 201" do
      post "/messages/bulk_create", { items: messages_json }.to_json
      expect(response.code).to eq "201"
    end

    it "creates multiple messages" do
      expect {
        post "/messages/bulk_create", { items: messages_json }.to_json
      }.to change { Message.count }.by 2
      messages = Message.all
      expect(messages.first.body).to eq messages_json.first[:body]
      expect(messages.second.body).to eq messages_json.second[:body]
    end

    it "does not save any messages when a failure occurs" do
      expect(Message).to receive(:create).and_call_original
      expect(Message).to receive(:create).and_raise(StandardError.new("DB Fail"))
      expect {
        expect {
          post "/messages/bulk_create", { items: messages_json }.to_json
        }.to change { Message.count }.by 0
      }.to_not raise_error
      expect(response.code).to eq "503"
    end

    it "responds with a 400 when there is no items key" do
      post "/messages/bulk_create", { }.to_json
      expect(response.code).to eq "400"
    end

    it "responds with a 400 when the items is not an array" do
      post "/messages/bulk_create", { items: "" }.to_json
      expect(response.code).to eq "400"
    end

    it "responds with a 400 when any item is missing body key" do
        expect {
          post "/messages/bulk_create", { items: missing_body_message_json }.to_json
        }.to change { Message.count }.by 0
      expect(response.code).to eq "400"
    end

    it "responds with a 400 when any item not a hash" do
        expect {
          post "/messages/bulk_create", { items: missing_hash_message_json }.to_json
        }.to change { Message.count }.by 0
      expect(response.code).to eq "400"
    end
  end

  describe "update message details in bulk (#bulk_update)" do

    before do
      post "/messages/bulk_update", { items: message_ids, data: message_update_data }.to_json
    end

    let(:messages) { create_list :sent_message, rand(2..10) }
    let(:message_ids) { messages.map(&:id) }
    let(:message_update_data) { { } }

    context "request does not include any message identifiers to update" do
      let(:message_ids) { [] }
      it "returns 400" do
        expect(response.code).to eq '400'
      end
    end

    context "request includes message identifiers to update" do
      context "request includes valid update data" do
        let(:message_update_data) { { needs_sending: true }  }

        it "returns a 204 status code" do
          expect(response.code).to eq '204'
        end

        it "updates the records" do
          messages.each do |message|
            message.reload
            expect(message.needs_sending).to eq true
          end
        end

        context "one of the records can not be updated" do
          let(:message_ids) { messages.map(&:id) + ['fake_id'] }
          it "does not update any records" do
            messages.each do |message|
              message.reload
              expect(message.needs_sending).to eq false
            end
          end

          it "returns a 400" do
            expect(response.code).to eq '400'
          end
        end

        context "more than 1000 ids are submitted" do
          let(:messages) { create_list :sent_message, rand(1001..1100) }
          it "returns a 400" do
            expect(response.code).to eq '400'
          end
        end
      end

      context "requeset includes invalid update data" do
        let(:message_update_data) { { id: 1 } }
        it "returns 400" do
          expect(response.code).to eq '400'
        end
      end

      context "request has blank update data" do
        let(:message_update_data) { {} }
        it "returns 400" do
          expect(response.code).to eq '400'
        end
      end

      context "request has non-hash update data" do
        let(:message_update_data) { [] }
        it "returns 400" do
          expect(response.code).to eq '400'
        end
      end

      context "request does not include update data" do
        let(:message_update_data) { }
        it "returns 400" do
          expect(response.code).to eq '400'
        end
      end

      context 'request includes non-valid json' do
        it "returns 400" do
          post "/messages/bulk_update", '{ nonvalid-json'
        end
      end
    end

    context "auth is on" do
      let(:basic_auth_on) { true }
      let(:message_update_data) { { needs_sending: true }  }

      context "correct creds are provided" do
        it "returns 200" do
          http_auth_as(Settings.basic_auth_user, Settings.basic_auth_password) do
            auth_post "/messages/bulk_update", { items: message_ids, data: message_update_data }.to_json
          end
          expect(response.code).to eq '204'
        end
      end

      context "no creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/messages/bulk_update", { items: message_ids, data: message_update_data }.to_json
          end
          expect(response.code).to eq '401'
        end
      end

      context "incorrect creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/messages/bulk_update", { items: message_ids, data: message_update_data }.to_json
          end
          expect(response.code).to eq '401'
        end
      end

      context 'guest creds are provided' do
        it 'returns auth error' do
          http_auth_as(Settings.readonly_username, Settings.readonly_password) do
            auth_post "/messages/bulk_update", { items: message_ids, data: message_update_data }.to_json
          end
          expect(response.code).to eq '401'
        end
      end
    end
  end

  describe "update message details (#update)" do

    context 'attempt to update updatable field w/ valid value' do
      it "responds with 204" do
        post "/messages/#{message.id}", { needs_sending: true }.to_json
        expect(response.code).to eq '204'
      end

      it "responds with blank body" do
        post "/messages/#{message.id}", { needs_sending: true }.to_json
        expect(response.body).to eq ''
      end

      it "makes updates to the message" do
        message.reload
        new_value = !message.needs_sending
        post "/messages/#{message.id}", { needs_sending: new_value }.to_json
        message.reload
        expect(message.needs_sending).to eq new_value
      end

      it "can nil out value" do
        post "/messages/#{message.id}", { needs_sending: nil }.to_json
        message.reload
        expect(message.needs_sending).to eq nil
      end
    end

    context 'attempt to update non-existing message' do
      it "returns 400" do
        post "/messages/fake_id", { needs_sending: true }.to_json
        expect(response.code).to eq '404'
      end
    end

    context "request has non-hash update data" do
      let(:message_update_data) { [] }
      it "returns 400" do
        post "/messages/#{message.id}", [].to_json
        expect(response.code).to eq '400'
      end
    end

    context 'request includes non-valid json' do
      it "returns 400" do
        post "/messages/#{message.id}", '{ invalid json'
        expect(response.code).to eq '400'
      end
    end

    context 'attempt to update a field which is not updatable' do
      Message.column_names.each do |col_name|
        next if updatable_fields.include? col_name

        it "returns 400 when trying to update #{col_name}" do
          post "/messages/#{message.id}", { col_name => nil }.to_json
          expect(response.code).to eq '400'
        end

        it "does not update value when trying to set #{col_name}" do
          message.reload
          old_value = message.send col_name
          post "/messages/#{message.id}", { col_name => nil }.to_json
          message.reload
          expect(message.send(col_name)).to eq old_value
        end
      end
    end

    context "auth is on" do
      let(:basic_auth_on) { true }

      context "correct creds are provided" do
        it "returns 200" do
          http_auth_as(Settings.basic_auth_user, Settings.basic_auth_password) do
            auth_post "/messages/#{message.id}", { needs_sending: true }.to_json
          end
          expect(response.code).to eq '204'
        end
      end

      context "no creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/messages/#{message.id}", { needs_sending: true }.to_json
          end
          expect(response.code).to eq '401'
        end
      end

      context "incorrect creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/messages/#{message.id}", { needs_sending: true }.to_json
          end
          expect(response.code).to eq '401'
        end
      end

      context 'guest creds are provided' do
        it 'returns auth error' do
          http_auth_as(Settings.readonly_username, Settings.readonly_password) do
            auth_post "/messages/#{message.id}", { needs_sending: true }.to_json
          end
          expect(response.code).to eq '401'
        end
      end
    end
  end

  describe "retrieve message info by id (#show)" do

    context "message exists" do
      it "responds with 200" do
        get "/messages/#{message.id}"
        expect(response.code).to eq '200'
      end

      it "returns parsable json" do
        get "/messages/#{message.id}"
        expect(JSON.parse(response.body)).not_to eq nil
      end

      message_datetime_fields.each do |col|
        it "returns k/v for #{col} field in response as iso8601 strings" do
          get "/messages/#{message.id}"
          response_data = JSON.parse(response.body)
          value = message.send(col)
          value = value.iso8601(ActiveSupport::JSON::Encoding.time_precision) if value
          expect(response_data[col]).to eq value
        end
      end

      message_non_datetime_fields.each do |col|
        it "returns k/v for #{col} field in response" do
          get "/messages/#{message.id}"
          response_data = JSON.parse(response.body)
          expect(response_data[col]).to eq message.send(col)
        end
      end
    end

    context "message does not exist" do
      it "responds with 404" do
        get "/messages/fake_id"
        expect(response.code).to eq '404'
      end
    end

    context "auth is on" do
      let(:basic_auth_on) { true }

      context "correct creds are provided" do
        it "returns 200" do
          http_auth_as(Settings.basic_auth_user, Settings.basic_auth_password) do
            auth_get "/messages/#{message.id}"
          end
          expect(response.code).to eq '200'
        end
      end

      context "no creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_get "/messages/#{message.id}"
          end
          expect(response.code).to eq '401'
        end
      end

      context "incorrect creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_get "/messages/#{message.id}"
          end
          expect(response.code).to eq '401'
        end
      end
    end
  end
end


def randomize_message_values
  # set random values for message attributes
  return unless message
  Message.columns.each do |col|
    next if col.name == 'id'
    case col.cast_type.type
    when :integer
      message.send "#{col.name}=", rand(1..1000)
    when :text
      message.send "#{col.name}=", ('a'..'z').to_a.shuffle.join
    when :datetime
      message.send "#{col.name}=", DateTime.new(rand(2000..2020), rand(1..10), rand(1..10), rand(1.0..10.999))
    when :string
      message.send "#{col.name}=", ('a'..'z').to_a.shuffle.join
    when :boolean
      message.send "#{col.name}=", [true, false].sample
    else
      raise "can't find type"
    end
  end
  message.save
end
