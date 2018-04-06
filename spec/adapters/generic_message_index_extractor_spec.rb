require 'rails_helper'

RSpec.describe GenericMessageIndexExtractor, type: :model do

  let(:body) { "stuff abcd1234567890vin1234567890abcd stuff" }

  let(:headers) { {"HeaderKey" => "123vin123"}.to_json }

  let(:message) do
    create(:message,
      body: body,
      headers: headers,
      shard_id: rand(1..999),
      needs_sending: true
    )
  end

  let(:words) { ["vin"] }

  let(:number_of_characters) { 10 }

  let(:extraction_direction) { "bidirectional" }

  subject do
    GenericMessageIndexExtractor.new(
      number_of_characters: number_of_characters,
      words: words,
      message: message,
      extraction_direction: extraction_direction
    )
  end

  context "empty message" do
    let(:body) { "" }
    let(:headers) { "" }
    it "returns empty string when nothing when nothing matches" do
      expect(subject.extract).to eq("")
    end
  end

  context "nil message" do
    let(:body) { nil }
    let(:words) { [""] }
    it "returns empty string when nothing when nothing matches" do
      expect(subject.extract).to eq("")
    end
  end

  context "nothing matches" do
    let(:headers) { {"HeaderKey" => "123vin123"}.to_json }
    let(:words) { ['foobar'] }
    it "returns empty string when nothing" do
      expect(subject.extract).to eq("")
    end
  end

  context "single match in both body and header" do
    let(:body) { "stuff abcd1234567890vin1234567890abcd stuff" }

    it "pulls the specified characters before and after a word match in a message" do
      expect(subject.extract).to eq("1234567890vin1234567890 rKey\":\"123vin123\"}")
    end
  end

  context "regular expression characters" do
    let(:body) { "stuff abcd1234567890vin(1234567890abcd stuff" }
    let(:words) { ["vin("] }

    it "pulls the specified characters after a word match in a message" do
      expect(subject.extract).to eq("1234567890vin(1234567890")
    end
  end

  context "single match with angle brackets in word" do
    let(:words) { ["<vin>"] }
    let(:headers) { "" }
    let(:body) { "stuff abcd1234567890<vin>1234567890abcd stuff" }

    it "pulls the specified characters before and after a word match in a message" do
      expect(subject.extract).to eq("1234567890<vin>1234567890")
    end
  end

  context "single match with quotes" do
    let(:words) { ['"vin"'] }
    let(:headers) { "" }
    let(:body) { 'stuff abcd1234567890"vin"1234567890abcd stuff' }

    it "pulls the specified characters before and after a word match in a message" do
      expect(subject.extract).to eq('1234567890"vin"1234567890')
    end
  end

  context "multiple matches in body" do
    let(:body) { "stuff abcd1234567890vin1234567890abcd 1234abcdefghijvinabcdefghij1234 stuff" }
    let(:headers) { {"HeaderKey" => "123vin123"}.to_json }

    it "pulls the specified characters before and after multiple word matches in a message" do
      expect(subject.extract).to eq("1234567890vin1234567890 abcdefghijvinabcdefghij rKey\":\"123vin123\"}")
    end
  end

  context "with multiple words" do
    let(:body) { "abc abc 9b9 9g9 aaa cbc 1b1" }
    let(:words) { ["b", "vin"] }
    let(:number_of_characters) { 1 }

    it "pulls the many words that match" do
      expect(subject.extract).to eq("abc abc 9b9 cbc 1b1 3vin1")
    end
  end

  context "with multiple words" do
    let(:body) { "stuff abcd1234567890vin1234567890abcd abcdefghij1234 stuff" }
    let(:words) { ["vin", "stuff"] }
    let(:headers) { "" }

    it "pulls the specified characters before and after multiple word matches" do
      expect(subject.extract).to eq("1234567890vin1234567890 stuff abcd12345 fghij1234 stuff")
    end
  end

  context "some words do not match" do
    let(:body) { "stuff abcd1234567890vin1234567890abcd 1234abcdefghijvinabcdefghij1234 stuff" }
    let(:words) { ["foobar", "vin", "foobaz"] }
    let(:headers) { "" }

    it "pulls the specified characters before and after multiple word matches with multiple words" do
     expect(subject.extract).to eq("1234567890vin1234567890 abcdefghijvinabcdefghij")
    end
  end

  context "extracting forward" do
    context "single match" do
      let(:extraction_direction) { "forwards" }
      let(:headers) { "" }

      it "pulls the specified characters after a word match in a message" do
        expect(subject.extract).to eq("vin1234567890")
      end

      context "regular expression characters" do
        let(:body) { "stuff abcd1234567890vin(1234567890abcd stuff" }
        let(:words) { ["vin("] }

        it "pulls the specified characters after a word match in a message" do
          expect(subject.extract).to eq("vin(1234567890")
        end
      end
    end
  end

  context "extracting backwards" do
    context "single match" do
      let(:extraction_direction) { "backwards" }
      let(:headers) { "" }

      it "pulls the specified characters before and after a word match in a message" do
        expect(subject.extract).to eq("1234567890vin")
      end

      context "regular expression characters" do
        let(:body) { "stuff abcd1234567890vin(1234567890abcd stuff" }
        let(:words) { ["vin("] }

        it "pulls the specified characters after a word match in a message" do
          expect(subject.extract).to eq("1234567890vin(")
        end
      end
    end
  end

  context "bad arguments" do
    let(:extraction_direction) { "to the right" }
    let(:headers) { "" }

    it "raises an error" do
      expect{subject.extract}.to raise_error(ArgumentError)
    end
  end
end
