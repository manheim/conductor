require 'rails_helper'

RSpec.describe NeedsSendingDecider do
  let(:options) do
    {
      settings: {
        search_text_number_characters: 10,
        search_text_words: 'vin',
        search_text_extraction_direction: "bidirectional",
        shard_tag: 'Sample-Shard-Id'
      },
      body: "",
      http_headers: {},
    }
  end

  subject(:needs_sending_decider) do
    NeedsSendingDecider.new options
  end

  describe "#needs_sending?" do

    context "when disable_message_sending setting is true" do
      before { options[:settings][:disable_message_sending] = true }

      it "returns false" do
        expect(subject.needs_sending?).to be false
      end
    end

    context "when disable_message_sending setting is false" do
      before { options[:settings][:disable_message_sending] = false }

      it "returns true" do
        expect(subject.needs_sending?).to be true
      end
    end

    context "when enable_tag in settings matches a header" do
      before { options[:settings][:enable_tag] = "SOME-TAG" }

      context "with a value of false" do
        before { options[:http_headers]["Some-tag"] = "false" }

        it "returns true" do
          expect(subject.needs_sending?).to be false
        end
      end

      context "with a value of true" do
        before { options[:http_headers]["Some-tag"] = "true" }

        it "returns true" do
          expect(subject.needs_sending?).to be true
        end
      end

      context "without a value" do
        before { options[:http_headers].delete("Some-tag") }

        it "returns true" do
          expect(subject.needs_sending?).to be true
        end
      end
    end

    context "with inbound_message_filter configured in settings" do
      before do
        options[:settings][:inbound_message_filter] = "(foo == 'bar.foobar' && baz == 'qux') || !(starts_with(foo, 'bar.'))"
      end

      context "configured as an empty string" do
        before do
          options[:settings][:inbound_message_filter] = ""
          options[:body] = "{}"
        end

        it "does not call JMESPATH and returns true" do
          expect(JMESPath).to_not receive(:search)
          expect(subject.needs_sending?).to be true
        end
      end

      context "with matching message on left side of expression" do
        before do
          options[:body] = { foo: "bar.foobar", baz: "qux" }.to_json
        end

        it "returns true" do
          expect(subject.needs_sending?).to be true
        end
      end

      context "with matching message on right side of expression" do
        before do
          options[:body] = { foo: "notbar.foobar", baz: "qux" }.to_json
        end

        it "returns true" do
          expect(subject.needs_sending?).to be true
        end
      end

      context "with non-matching message" do
        before do
          options[:body] = { foo: "bar.notfoobar", baz: "qux" }.to_json
        end

        it "returns false" do
          expect(subject.needs_sending?).to be false
        end
      end

      context "with non-matching message that doesn't have some keys" do
        before do
          options[:body] = { "cat": "dog"}.to_json
        end

        context "encounters an error" do
          it "returns false" do
            expect(subject.needs_sending?).to be false
          end
        end

        context "does not encounter an error" do
          before do
            options[:settings][:inbound_message_filter] = "(foo == 'bar.foobar' && baz == 'qux') || foo == null || !(starts_with(foo, 'bar.'))"
          end

          it "returns true" do
            expect(subject.needs_sending?).to be true
          end
        end
      end
    end

  end
end
