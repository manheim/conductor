require 'rails_helper'

RSpec.describe UtilitiesController, type: :controller do
  describe "#configuration" do
    let(:tmpdir) { Dir.mktmpdir }

    let!(:file) do
      File.open(File.join(tmpdir, "version.txt"), "w+") do |f|
        f.write "42\n"
      end
    end

    before { ENV['RAILS_RELATIVE_URL_ROOT'] = tmpdir }

    after do 
      ENV.delete 'RAILS_RELATIVE_URL_ROOT' 
      FileUtils.rm_rf(tmpdir)
    end

    it "returns the build information" do
      get :configuration
      expect(response.code).to eq "200"
      json = JSON.parse(response.body)
      expect(json).to eq(
        "buildNumber" => "42"
      )
    end
  end

  describe "#elb_health_check" do
    it "responds with 200" do
      get :elb_health_check
      expect(response.code).to eq "200"
    end
  end

  describe "#root" do
    it "responds with available routes" do
      get :root
      expect(response.code).to eq "200"
    end
  end
end
