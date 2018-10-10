require 'rails_helper'
require 'webmock/rspec'

RSpec.describe CleanupWorker, type: :request do
  describe "#work" do
    after do
      Message.connection.reset!
    end

    let!(:old_created_messages) do
      (1..10).to_a.map do |i|
        create(:message, created_at: 10.minutes.ago, needs_sending: false)
      end
    end

    let!(:old_unsent_messages) do
      (1..10).to_a.map do |i|
        create(:message, created_at: 10.minutes.ago, needs_sending: true)
      end
    end
    let!(:not_old_messages) do
      (1..20).to_a.map do |i|
        create(:message, created_at: 5.minutes.ago, needs_sending: false)
      end
    end

    subject(:worker) do
      CleanupWorker.new(batch_size: 1, retention_period: 7.minutes.seconds)
    end

    it "deletes the old messages" do
      expect{subject.work}.to change{Message.count}.by(-10)
      expect(Message.all.map(&:id)).to match_array(not_old_messages.map(&:id) + old_unsent_messages.map(&:id))
    end

    it "deletes the old search_texts" do
      expect{subject.work}.to change{SearchText.count}.by(-10)
      expect(SearchText.all.map(&:id)).to match_array(not_old_messages.map(&:search_text).map(&:id) + old_unsent_messages.map(&:search_text).map(&:id))
    end

    it "deletes the old alternate_search_texts" do
      expect{subject.work}.to change{AlternateSearchText.count}.by(-10)
      expect(AlternateSearchText.all.map(&:id)).to match_array(not_old_messages.map(&:alternate_search_text).map(&:id) + old_unsent_messages.map(&:alternate_search_text).map(&:id))
    end

    it "respects batch size" do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/Deleted 1 messages/).exactly(10).times
      subject.work
    end

    it "respects the advisory lock" do
      thread = Thread.new do
        result = Message.with_advisory_lock_result(CleanupWorker.lock_name) do
          sleep 1
        end
        expect(result.lock_was_acquired?).to be true
      end

      sleep 0.5

      expect(Message).not_to receive(:where)
      worker.work

      thread.join
    end

    context "truncating old search text tables" do
      subject(:worker) do
        CleanupWorker.new(batch_size: 1, retention_period: 20.minutes.seconds)
      end

      context "when an error occurs" do
        it "does catch the error" do
          change_created_at SearchText.first, 22.minutes.ago
          change_created_at AlternateSearchText.first, 21.minutes.ago
          expect(ActiveRecord::Base.connection).to receive(:execute).with(/truncate/i).and_raise "BOOM"
          subject.work
        end
      end

      context "when another thread has the advisory lock" do
        it "does not attempt to truncate the search text" do
          change_created_at SearchText.first, 22.minutes.ago
          change_created_at AlternateSearchText.first, 21.minutes.ago
          thread = Thread.new do
            result = Message.with_advisory_lock_result(CleanupWorker.lock_name) do
              sleep 1
            end
            expect(result.lock_was_acquired?).to be true
          end
          sleep 0.5
          subject.work
          thread.join
          expect(SearchText.count).to be > 1
          expect(AlternateSearchText.count).to be > 1
        end
      end

      context "when both have data greater than retention period" do
        context "when search_texts is older" do
          it "truncates the search_texts" do
            change_created_at SearchText.first, 22.minutes.ago
            change_created_at AlternateSearchText.first, 21.minutes.ago
            subject.work
            expect(SearchText.count).to eq 0
          end
        end

        context "when alternate_search_texts is older" do
          it "truncates the alternate_search_texts" do
            change_created_at SearchText.first, 21.minutes.ago
            change_created_at AlternateSearchText.first, 22.minutes.ago
            subject.work
            expect(AlternateSearchText.count).to eq 0
          end
        end
      end

      context "when only one table has data greater than the retention period" do
        context "alternate_search_texts is older" do
          it "does not truncate any table" do
            change_created_at SearchText.first, 19.minutes.ago
            change_created_at AlternateSearchText.first, 22.minutes.ago
            subject.work
            expect(AlternateSearchText.count).to be > 0
            expect(SearchText.count).to be > 0
          end
        end

        context "search_texts is older" do
          it "does not truncate any table" do
            change_created_at SearchText.first, 22.minutes.ago
            change_created_at AlternateSearchText.first, 19.minutes.ago
            subject.work
            expect(AlternateSearchText.count).to be > 0
            expect(SearchText.count).to be > 0
          end
        end
      end

      context "when search texts is already empty" do
        subject(:worker) do
          CleanupWorker.new(batch_size: 1, retention_period: 7.minutes.seconds)
        end

        it "does not truncate" do
          SearchText.delete_all

          AlternateSearchText.first.update! created_at: 19.minutes.ago
          subject.work
          expect(SearchText.count).to eq 0
          expect(AlternateSearchText.count).to eq Message.count
        end

        it "cleans up messages" do
          SearchText.delete_all

          AlternateSearchText.first.update! created_at: 19.minutes.ago

          expect{subject.work}.to change{Message.count}.by(-10)
          expect(Message.all.map(&:id)).to match_array(not_old_messages.map(&:id) + old_unsent_messages.map(&:id))
        end
      end

      context "when alternate search text is already empty" do
        subject(:worker) do
          CleanupWorker.new(batch_size: 1, retention_period: 7.minutes.seconds)
        end

        it "does not truncate" do
          AlternateSearchText.delete_all

          SearchText.first.update! created_at: 19.minutes.ago
          subject.work
          expect(AlternateSearchText.count).to eq 0
          expect(SearchText.count).to eq Message.count
        end

        it "cleans up messages" do
          AlternateSearchText.delete_all

          SearchText.first.update! created_at: 19.minutes.ago

          expect{subject.work}.to change{Message.count}.by(-10)
          expect(Message.all.map(&:id)).to match_array(not_old_messages.map(&:id) + old_unsent_messages.map(&:id))
        end
      end
    end

    context "when errors occur" do
      context "error when finding messages" do
        it "logs when a standard error happens and doesn't reraise" do
          expect(Rails.logger).to receive(:error)
          expect(Message).to receive(:where).and_raise "BOOM"
          expect {
            subject.work
          }.to_not raise_error
        end

        it "logs when an exception happens and reraises" do
          expect(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error)
          expect(Message).to receive(:where).and_raise Exception.new("This is an exception")
          expect {
            subject.work
          }.to raise_error("This is an exception")
        end

      end
      context "error when getting advisory lock" do
        it "logs when a standard error happens and doesn't reraise" do
          expect(Rails.logger).to receive(:error)
          expect(Message).to receive(:advisory_lock_exists?).and_raise "BOOM"
          expect {
            subject.work
          }.to_not raise_error
        end

        it "logs when an exception happens and reraises" do
          expect(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error)
          expect(Message).to receive(:advisory_lock_exists?).and_raise Exception.new("This is an exception")
          expect {
            subject.work
          }.to raise_error("This is an exception")
        end
      end

      context "error when deleting messages" do
        it "logs when a standard error happens and doesn't reraise" do
          expect(Rails.logger).to receive(:error)
          allow_any_instance_of(Message::ActiveRecord_Relation).to receive(:delete_all).and_raise "BOOM"
          expect {
            subject.work
          }.to_not raise_error
        end

        it "does not delete the search_texts" do
          allow_any_instance_of(Message::ActiveRecord_Relation).to receive(:delete_all).and_raise "BOOM"
          expect {
            subject.work
          }.to change{ SearchText.count }.by 0
        end

        it "does not delete the alternate search_texts" do
          allow_any_instance_of(Message::ActiveRecord_Relation).to receive(:delete_all).and_raise "BOOM"
          expect {
            subject.work
          }.to change{ AlternateSearchText.count }.by 0
        end

        it "does not delete the messages" do
          allow_any_instance_of(SearchText::ActiveRecord_Relation).to receive(:delete_all).and_raise "BOOM"
          expect {
            subject.work
          }.to change{ Message.count }.by 0
        end

        it "does not delete the messages" do
          allow_any_instance_of(AlternateSearchText::ActiveRecord_Relation).to receive(:delete_all).and_raise "BOOM"
          expect {
            subject.work
          }.to change{ Message.count }.by 0
        end

        it "logs when an exception happens and reraises" do
          expect(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error)
          allow_any_instance_of(Message::ActiveRecord_Relation).to receive(:delete_all).and_raise Exception.new("This is an exception")
          expect {
            subject.work
          }.to raise_error("This is an exception")
        end
      end
    end
  end
end


def change_created_at obj, time
  # search record and it's message end up w/ _exact_ same time
  obj.update!(created_at: time)
  obj.message.update!(created_at: time)
end
