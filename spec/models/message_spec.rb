require 'rails_helper'

RSpec.describe Message, type: :model do
  describe "timestamps" do
    it "has microsecond precision" do
      Message.create! body: "asdf", headers: "asdf"
      message = Message.first
      created_at = message.created_at.to_f.to_s
      updated_at = message.updated_at.to_f.to_s
      expect(created_at).to_not match(/^\d+\.0$/)
      expect(updated_at).to_not match(/^\d+\.0$/)
    end
  end
end
