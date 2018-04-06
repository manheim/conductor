require 'rails_helper'

RSpec.describe ApplicationController, :type => :controller do
  describe "bad response" do
    controller do

      def index
        render text: "hello", status: 400
      end
    end

    it "captures the response for logging" do
      payload = {}
      get :index
      subject.send(:append_info_to_payload, payload)
      expect(payload[:response]).to eq "hello"
    end

  end

  describe "good response" do
    controller do

      def index
        render text: "hello"
      end
    end

    it "captures nothing on GET" do
      payload = {}
      get :index
      subject.send(:append_info_to_payload, payload)
      expect(payload[:response]).to be nil
    end

    it "captures the headers for logging, ignoring sensitive headers" do
      payload = {}
      request.headers["Auth"] = "some secret" #this will become HTTP_AUTH in the request
      request.headers["X-Mashery-Oauth-User-Context"] = "user context"
      post :index, {some_body: "YO"}.to_json
      subject.send(:append_info_to_payload, payload)
      expect(payload[:headers]).to eq({"HTTP_HOST"=>"test.host",
                                       "HTTP_USER_AGENT"=>"Rails Testing",
                                       "HTTP_X_MASHERY_OAUTH_USER_CONTEXT"=>"user context"})
    end

  end
end
