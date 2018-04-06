require 'rails_helper'

RSpec.describe RuntimeSettingsApiController, type: :request do

  include AuthRequestHelper

  let!(:runtime_settings) { create(:runtime_settings) }
  let(:basic_auth_on) { false }

  let(:headers) do
    { "Content-type" => "application/json" }
  end

  before do
    allow(Settings).to receive(:basic_auth_enabled).and_return(basic_auth_on)
  end

  describe "#show" do

    it "returns a 200" do
      get "/runtime_settings"
      expect(response.code).to eq '200'
    end

    it "returns valid json" do
      get "/runtime_settings"
      expect(JSON.parse(response.body)).not_to eq nil
    end

    it "returns the runtime_settings" do
      get "/runtime_settings"
      expect(JSON.parse(response.body)).to eq({ "settings" => runtime_settings.settings })
    end

    context "auth is on" do
      let(:basic_auth_on) { true }

      context "correct creds are provided" do
        it "returns 200" do
          http_auth_as(Settings.basic_auth_user, Settings.basic_auth_password) do
            auth_get "/runtime_settings"
          end
          expect(response.code).to eq '200'
        end
      end

      context "no creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_get "/runtime_settings"
          end
          expect(response.code).to eq '401'
        end
      end

      context "incorrect creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_get "/runtime_settings"
          end
          expect(response.code).to eq '401'
        end
      end
    end
  end

  describe "#update" do

    context 'attempt to update updatable field w/ valid value' do
      it "responds with 204" do
        post "/runtime_settings", { settings: { worker_enabled: false } }.to_json, headers
        expect(response.code).to eq '204'
      end

      it "updates the settings" do
        post "/runtime_settings", { settings: { worker_enabled: false } }.to_json, headers
        runtime_settings.reload
        expect(runtime_settings.settings).to eq({ "worker_enabled" => false })
      end
    end

    context "request has non-hash update data" do
      let(:message_update_data) { [] }
      it "returns 400" do
        post "/runtime_settings", [].to_json, headers
        expect(response.code).to eq '400'
      end
    end

    context 'request has no settings' do
      it "returns 400" do
        post "/runtime_settings", '{}', headers
        expect(response.code).to eq '400'
      end
    end

    context 'request has non hash settings' do
      it "returns 400" do
        post "/runtime_settings", {settings: []}.to_json, headers
        expect(response.code).to eq '400'
      end
    end

    context "auth is on" do
      let(:basic_auth_on) { true }

      context "correct creds are provided" do
        it "returns 200" do
          http_auth_as(Settings.basic_auth_user, Settings.basic_auth_password) do
            auth_post "/runtime_settings", { settings: { worker_enabled: false } }.to_json, headers
          end
          expect(response.code).to eq '204'
        end
      end

      context "no creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/runtime_settings", { settings: { worker_enabled: false } }.to_json, headers
          end
          expect(response.code).to eq '401'
        end
      end

      context "incorrect creds are provided" do
        it "returns auth error" do
          http_auth_as('wrong', 'creds') do
            auth_post "/runtime_settings", { settings: { worker_enabled: false } }.to_json, headers
          end
          expect(response.code).to eq '401'
        end
      end

      context 'guest creds are provided' do
        it 'returns auth error' do
          http_auth_as(Settings.readonly_username, Settings.readonly_password) do
            auth_post "/runtime_settings", { settings: { worker_enabled: false } }.to_json, headers
          end
          expect(response.code).to eq '401'
        end
      end
    end
  end
end
