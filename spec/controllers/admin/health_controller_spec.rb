require 'rails_helper'

RSpec.describe Admin::HealthController, type: :request do
  describe "#index" do
    let(:auth_header) {
      Base64::encode64("#{Settings.basic_auth_user}:#{Settings.basic_auth_password}")
    }

    let(:headers) {
      {
        "Authorization" => "Basic #{auth_header}",
      }
    }

    context "authentication" do
      it 'returns a 401 if no auth given' do
        get '/admin'
        expect(response.code).to eql "401"
      end
    end

    context "index" do

      before do
        create(:message, needs_sending: true, processed_count: 10)
      end

      it "renders health page link for most failing messages" do
        get "/admin/health", {}, headers
        expect(response.code).to eq "200"
        expect(response.body).to include "Number of failing messages: 1"
        expect(response.body).to include "See most failing messages"
      end

      context "database parameter" do
        it "renders health page using master data" do
          expect(Octopus).to receive(:using).with(:master).and_call_original
          get "/admin/health", {use_master: "true"}, headers
          expect(response.code).to eq "200"
        end

        it "renders health page using replica data by default" do
          expect(Octopus).to receive(:using).with(:replica).and_call_original
          get "/admin/health", {}, headers
          expect(response.code).to eq "200"
        end
      end
    end

    context "stats" do

      before do
        create(:message, needs_sending: true, processed_count: 10)
      end

      it "renders json" do
        get "/admin/stats", {}, headers
        expect(response.code).to eq "200"
        json = JSON.parse(response.body)
        expect(json["healthy"]).to be true
        expect(json["processing_rate"]).to eq 0
        expect(json["health"]).to match_array(
          [
            {
              "metric_name"=>"shards_blocked_over_threshold",
              "metric_value"=>0, "in_violation"=>false
            }, {
              "metric_name"=>"too_many_unsent_messages",
              "metric_value"=>1,
              "in_violation"=>false
            }, {
              "metric_name"=>"oldest_message_older_than_threshold",
              "metric_value"=>"",
              "in_violation"=>false
            }, {
              "metric_name"=>"no_messages_received",
              "metric_value"=>/minute/,
              "in_violation"=>false
            }
          ]
        )
      end

      context "database parameter" do
        it "renders health page using master data" do
          expect(Octopus).to receive(:using).with(:master).and_call_original
          get "/admin/stats", {use_master: "true"}, headers
          expect(response.code).to eq "200"
        end

        it "renders health page using replica data by default" do
          expect(Octopus).to receive(:using).with(:replica).and_call_original
          get "/admin/stats", {}, headers
          expect(response.code).to eq "200"
        end
      end
    end
  end
end
