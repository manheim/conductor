require 'rails_helper'

RSpec.describe MessageSearcher do
  let(:options) do
    {
      max_full_text_search_results: 10,
      search_term: "abc123"
    }
  end

  before do
    allow(Settings).to receive(:search_text_ignore_words).and_return ""
  end

  subject do
    MessageSearcher.new(options)
  end

  context "no messages" do
    let!(:messages) { [] }
  end

  context "some messages that match" do
    let!(:messages_without_search_texts) do
      [
        Message.create(body: "abc123"),
        Message.create(body: "abc123"),
        Message.create(body: "abc123"),
        Message.create(body: "abc123"),
        Message.create(body: "abc123"),
      ]
    end

    let!(:messages) do
      [
        create(:message, body: "abc123"),
        create(:message, body: "aaaaaaaaaa"),
        create(:message, body: "asdf abc123 asdf"),
        create(:message, body: "bbbbbbbbbb"),
        create(:message, body: "asdf abc123 asdf"),
        create(:message, body: "cccccccccc"),
        create(:message, body: "abc123"),
      ]
    end

    let(:matching_message_id_set) { [messages[0].id, messages[2].id, messages[4].id, messages[6].id] }

    it "returns message id's based on the matching search terms" do
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end

    context "more matches than the limit" do
      let(:options) do
        {
          max_full_text_search_results: 2,
          search_term: "abc123"
        }
      end

      it "limits the results" do
        result = subject.message_ids
        expect(result.size).to eq 2
        expect(result & matching_message_id_set).to eq result
      end
    end
  end

  context "searching for hrefs" do
    let(:href) { "http://foobar.com/abc-asd1-231-2333" }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: href
      }
    end

    let!(:messages) do
      [
        create(:message, body: href),
        create(:message, body: "abc-asd1-231-2333"),
        create(:message, body: "http://foobar.com/"),
        create(:message, body: "#{href}?query=param"),
        create(:message, body: "And here is an href: #{href}?query=param"),
      ]
    end

    let(:matching_message_id_set) { [messages[0].id, messages[3].id, messages[4].id] }

    it "finds messages when searching by an href" do
      allow(Settings).to receive(:search_text_ignore_words).and_return "com"
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end
  end

  context "searching for exact words" do
    let(:search_term) { "word1 word2" }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: search_term
      }
    end

    let!(:messages) do
      [
        create(:message, body: "word1"),
        create(:message, body: "word2"),
        create(:message, body: "word1 word2"),
        create(:message, body: "word2 word1"),
        create(:message, body: "no words"),
      ]
    end

    let(:matching_message_id_set) { [messages[2].id, messages[3].id] }

    it "finds messages when searching by an href" do
      allow(Settings).to receive(:search_text_ignore_words).and_return "com"
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end
  end

  context "ignores words below the minimum search term length" do
    let(:search_term) { "its a word to me" }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: search_term
      }
    end

    let!(:messages) do
      [
        create(:message, body: "its a word to me"),
        create(:message, body: "its word"),
        create(:message, body: "its some other word"),
        create(:message, body: "word"),
        create(:message, body: "its"),
        create(:message, body: "a to me"),
        create(:message, body: "a"),
        create(:message, body: "to"),
        create(:message, body: "me"),
      ]
    end

    let(:matching_message_id_set) { [messages[0].id, messages[1].id, messages[2].id] }

    it "finds messages when searching by an href" do
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end

    context "when search text is empty" do
      it "finds messages when searching by an href" do
        SearchText.delete_all
        expect(subject.message_ids).to match_array(matching_message_id_set)
      end
    end

    context "when alternate search text is empty" do
      it "finds messages when searching by an href" do
        AlternateSearchText.delete_all
        expect(subject.message_ids).to match_array(matching_message_id_set)
      end
    end
  end

  context "searching for hrefs" do
    let(:href) { "http://foobar.com/abc-asd1-231-2333" }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: href
      }
    end

    let!(:messages) do
      [
        create(:message, body: href),
        create(:message, body: "abc-asd1-231-2333"),
        create(:message, body: "http://foobar.com/"),
        create(:message, body: "#{href}?query=param"),
        create(:message, body: "And here is an href: #{href}?query=param"),
      ]
    end

    let(:matching_message_id_set) { [messages[0].id, messages[3].id, messages[4].id] }

    it "finds messages when searching by an href" do
      allow(Settings).to receive(:search_text_ignore_words).and_return "com"
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end
  end

  context "searching for exact words" do
    let(:search_term) { "word1 word2" }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: search_term
      }
    end

    let!(:messages) do
      [
        create(:message, body: "word1"),
        create(:message, body: "word2"),
        create(:message, body: "word1 word2"),
        create(:message, body: "word2 word1"),
        create(:message, body: "no words"),
      ]
    end

    let(:matching_message_id_set) { [messages[2].id, messages[3].id] }

    it "finds messages when searching by an href" do
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end
  end

  context "ignores words below the minimum search term length" do
    let(:search_term) { "its a word to me" }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: search_term
      }
    end

    let!(:messages) do
      [
        create(:message, body: "its a word to me"),
        create(:message, body: "its word"),
        create(:message, body: "its some other word"),
        create(:message, body: "word"),
        create(:message, body: "its"),
        create(:message, body: "a to me"),
        create(:message, body: "a"),
        create(:message, body: "to"),
        create(:message, body: "me"),
      ]
    end

    let(:matching_message_id_set) { [messages[0].id, messages[1].id, messages[2].id] }

    it "finds messages when searching by an href" do
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end
  end

  context 'respects the boolean operators as provided by user in search term' do
    let(:search_term) { '+foo -bar asdf*' }
    let(:options) do
      {
        max_full_text_search_results: 10,
        search_term: search_term
      }
    end
    let!(:messages) do
      [
        create(:message, body: "foobar"),
        create(:message, body: "foo"),
        create(:message, body: "foo asdf123"),
        create(:message, body: "foo asdf"),
        create(:message, body: "foo asd"),
        create(:message, body: "foo asdf123 123abc"),
        create(:message, body: "asdf123"),
        create(:message, body: "bar"),
        create(:message, body: "foo bar"),
        create(:message, body: "+bar"),
        create(:message, body: "-bar"),
        create(:message, body: "barfoo"),
        create(:message, body: "something_random"),
        create(:message, body: "foo bar asdf")
      ]
    end

    let(:matching_message_id_set) {
      [
        messages[2].id,
        messages[3].id,
        messages[5].id
      ]
    }

    it 'finds the matching messages' do
      expect(subject.message_ids).to match_array(matching_message_id_set)
    end
  end

  context "#parse_search_term" do
    subject do
      MessageSearcher.new(options)
    end

    it "parses url" do
      expect(subject.parse_search_term(
        "http://something.com/one-two-three"
      )).to eq(
        ["http", "something", "com", "one", "two", "three"]
      )
    end

    it "parses quote-wrapped url" do
      expect(subject.parse_search_term(
        "\"http://something.com/one-two-three\""
      )).to eq(
        ["http", "something", "com", "one", "two", "three"]
      )
    end

    it "handles mysql search term" do
      expect(subject.parse_search_term(
        "+one +two -three but-still-handles-this"
      )).to eq(
        ["+one", "+two", "-three", "but", "still", "handles", "this"]
      )
    end

    it "handles star search term" do
      expect(subject.parse_search_term(
        "+one +two -three four* but*still*handles*this five*"
      )).to eq(
        ["+one", "+two", "-three", "four*", "but", "still", "handles", "this", "five*"]
      )
    end

    it "ignores stopwords" do
      allow(Settings).to receive(:search_text_ignore_words).and_return "www,com,on,wo,o,how"
      expect(subject.parse_search_term(
        "one two www com how +www -com how*"
      )).to eq(
        ["one", "two"]
      )
    end
  end
end
