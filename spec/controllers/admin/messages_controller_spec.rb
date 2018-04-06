require 'rails_helper'

RSpec.describe MessagesController, type: :request do
  admin_auth_header = Base64::encode64("#{Settings.basic_auth_user}:#{Settings.basic_auth_password}")

  readonly_auth_header = Base64::encode64("#{Settings.readonly_username}:#{Settings.readonly_password}")

  describe "any user" do
    context "authentication" do
      it 'returns a 401 if no auth given' do
        get '/admin'
        expect(response.code).to eql "401"
      end
    end

    [readonly_auth_header, admin_auth_header].each do |header|
      let(:headers) {
        {
          "Authorization" => "Basic #{header}",
        }
      }

      context "#{header} user" do
        context "multiple pages worth of messages" do
          let(:body1) { "body1 #{rand(99999999999)}" }
          let(:body2) { "body2 #{rand(99999999999)}" }

          before do
            page_size = 100

            page_size.times do
              create(:message, body: body1)
            end

            page_size.times do
              create(:message, body: body2)
            end
          end

          context "using use_master parameter" do
            it "reads from the master by default" do
              expect(Octopus).to receive(:using).with(:replica).and_call_original
              get "/admin/messages", {}, headers
            end
            it "reads from the replica when use_master is provided" do
              expect(Octopus).to receive(:using).with(:master).and_call_original
              get "/admin/messages", {use_master: true}, headers
            end
          end

          it "renders most recently received messages" do
            get "/admin/messages", {}, headers
            expect(response.code).to eq "200"
            expect(response.body).to_not include body1
            expect(response.body).to include body2
          end

          it "respects a limit parameter" do
            get "/admin/messages?limit=2", {}, headers
            expect(response.code).to eq "200"
            expect(response.body.scan(/(?=#{body2})/).count).to eq 2
          end

          context "view is most_failing" do
            it "render most failing messages" do
              failed_body_1 = "some failed body 1"
              failed_body_2 = "some failed body 2"
              create(:failed_message, body: failed_body_1)
              create(:failed_message, body: failed_body_2)

              get "/admin/messages?view=most_failing", {}, headers

              expect(response.body).to include failed_body_1
              expect(response.body).to include failed_body_2
              expect(response.body).to_not include body1
              expect(response.body).to_not include body2
            end

            it "respects a limit parameter" do
              failed_body_1 = "some failed body 1"
              failed_body_2 = "some failed body 2"
              create(:failed_message, body: failed_body_1, processed_count: 2)
              create(:failed_message, body: failed_body_2, processed_count: 1)

              get "/admin/messages?view=most_failing&limit=1", {}, headers

              expect(response.body).to include failed_body_1
              expect(response.body).to_not include failed_body_2
            end
          end
        end

        context "search" do
          let(:body1) { "body1 #{rand(99999999999)}" }
          let(:body2) { "body2 #{rand(99999999999)}" }
          let(:header1) { "header1 #{rand(99999999999)}" }
          let(:header2) { "header2 #{rand(99999999999)}" }

          before do
            1.times do
              create(:message, body: body1, headers: header1)
            end

            2.times do
              create(:message, body: body2, headers: header2)
            end
          end

          it "filters by body" do
            get "/admin/messages", {search: body2}, headers
            expect(response.code).to eq "200"
            expect(response.body).to include body2
            expect(response.body).to include header2

            expect(response.body).to_not include body1
            expect(response.body).to_not include header1
          end

          it "succeeds with no results" do
            get "/admin/messages", {search: "asdfasdfalsdjk"}, headers
            expect(response.code).to eq "200"
            expect(response.body).to_not include body2
            expect(response.body).to_not include header2

            expect(response.body).to_not include body1
            expect(response.body).to_not include header1
          end
        end
      end
    end
  end

  describe "admin" do
    let(:headers) {
      {
        "Authorization" => "Basic #{admin_auth_header}",
      }
    }

    describe "#edit" do
      let(:message) do
        create(:message, body: "body", headers: "headers")
      end

      it "renders 200" do
        get "/admin/messages/#{message.id}/edit", {}, headers
        expect(response.code).to eq "200"
      end
    end

    describe "#new" do
      it "renders 200" do
        get "/admin/messages/new", {}, headers
        expect(response.code).to eq "200"
      end
    end

    describe "delete" do
      let(:message) do
        create(:message, body: "body", headers: "headers")
      end

      it "deletes the message" do
        delete "/admin/messages/#{message.id}", {}, headers
        expect(Message.where(id: message.id).first).to be nil
        expect(response.code).to eq "302"
      end
    end

    describe "update" do
      let(:message) do
        create(:message, body: "body", headers: "headers")
      end

      it "responds with 401" do
        put "/admin/messages/#{message.id}", {message: {body: "123"}}, headers
        expect(message.reload.body).to eq "123"
        expect(response.code).to eq "302"
      end
    end

    describe "create" do
      it "responds with 401" do
        expect {
          post "/admin/messages", {message: {body: "123"}}, headers
        }.to change { Message.count }.by 1
        expect(response.code).to eq "302"
      end
    end
  end

  describe "read-only user" do
    let(:headers) {
      {
        "Authorization" => "Basic #{readonly_auth_header}",
      }
    }

    describe "#index" do
      it "responds with 200" do
        get "/admin/messages", {}, headers
        expect(response.code).to eq "200"
      end

    end

    describe "#edit" do
      let(:message) do
        create(:message, body: "body", headers: "headers")
      end

      it "redirects to index" do
        get "/admin/messages/#{message.id}/edit", {}, headers
        expect(response).to redirect_to('/admin/messages')
        expect(flash[:error]).to eq "You are not authorized to perform this action"
      end
    end

    describe "#new" do
      it "redirects to index" do
        get "/admin/messages/new", {}, headers
        expect(response).to redirect_to('/admin/messages')
        expect(flash[:error]).to eq "You are not authorized to perform this action"
      end
    end

    describe "delete" do
      let(:message) do
        create(:message, body: "body", headers: "headers")
      end

      it "responds with 302" do
        delete "/admin/messages/#{message.id}", {}, headers
        expect(Message.find(message.id)).to eq message
        expect(response).to redirect_to('/admin/messages')
        expect(flash[:error]).to eq "You are not authorized to perform this action"
      end
    end

    describe "update" do
      let(:message) do
        create(:message, body: "body", headers: "headers")
      end
      it "responds with 401" do
        put "/admin/messages/#{message.id}", {message: {body: "123"}}, headers
        expect(message.reload.body).to_not eq "123"
        expect(response.code).to eq "401"
      end
    end

    describe "create" do
      it "responds with 401" do
        expect {
          post "/admin/messages", {message: {body: "123"}}, headers
        }.to_not change { Message.count }
        expect(response.code).to eq "401"
      end
    end
  end
end
