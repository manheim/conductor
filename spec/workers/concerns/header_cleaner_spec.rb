require 'rails_helper'

class FakeWorker
  include Concerns::HeaderCleaner
end

RSpec.describe FakeWorker do
  describe "#auth_cleaner" do
    it "removes Authorization information from input" do
      test_input = {"Accept-encoding"=>"gzip;q=1.0",
                    "Authorization"=>"ohhey",
                    "Conductor-enabled-tag"=>"true"}
      cleaned_output = FakeWorker.new.auth_cleaner(test_input)
      expect(cleaned_output).to eq( {"Accept-encoding"=>"gzip;q=1.0",
                                     "Conductor-enabled-tag"=>"true"})
    end
    it "removes Authorization information from nested input" do
      test_input = {"Accept-encoding"=>"gzip;q=1.0",
                    "next_level" => {"Authorization"=>"ohhey",
                                     "something" => "else"},
                    "Conductor-enabled-tag"=>"true"}
      cleaned_output = FakeWorker.new.auth_cleaner(test_input)
      expect(cleaned_output).to eq( {"Accept-encoding"=>"gzip;q=1.0",
                                     "next_level" => {"something" => "else"},
                                     "Conductor-enabled-tag"=>"true"})
    end
    it "ignores case" do
      test_input = {"Accept-encoding"=>"gzip;q=1.0",
                    "next_level" => {"authorIzAtion"=>"ohhey",
                                     "something" => "else"},
                    "Conductor-enabled-tag"=>"true"}
      cleaned_output = FakeWorker.new.auth_cleaner(test_input)
      expect(cleaned_output).to eq( {"Accept-encoding"=>"gzip;q=1.0",
                                     "next_level" => {"something" => "else"},
                                     "Conductor-enabled-tag"=>"true"})
    end

    it "strips embedded faraday request objects" do
      test_input = {"Accept-encoding"=>"gzip;q=1.0",
                    "Response" => Faraday::Response.new }
      cleaned_output = FakeWorker.new.auth_cleaner(test_input)
      expect(cleaned_output).to eq( {"Accept-encoding"=>"gzip;q=1.0"} )
    end
  end
end

