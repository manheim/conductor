require 'rails_helper'

require 'webmock/rspec'

RSpec.describe ThreadedWorker, type: :model do
  let(:failure_delay) { 3 }
  let(:failure_exponent_base) { 1 }
  let(:max_failure_delay) { 75 }
  subject { described_class.new({failure_delay: failure_delay, failure_exponent_base: failure_exponent_base, max_failure_delay: max_failure_delay }) }

  let(:needs_sending_decision) { true }

  before :each do
    allow(Settings).to receive(:workers_enabled).and_return true
    allow(Settings).to receive(:max_number_of_retries).and_return 3
    ActiveRecord::Base.clear_all_connections!
  end

  context "create_consumers" do
    let(:producer_name) { 'Producer::UnprocessedShardsProducer' }
    subject { described_class.new({producer_name: producer_name}) }

    it "removes dead threads and starts new threads" do
      subject.create_consumers
      expect(subject.consumers.size).to eq subject.thread_count
      expect(subject.consumers.all? { |t| t.alive? }).to be true

      subject.consumers.first.kill
      sleep 1
      expect(subject.consumers.first.alive?).to be false

      subject.create_consumers
      expect(subject.consumers.size).to eq subject.thread_count
      expect(subject.consumers.all? { |t| t.alive? }).to be true
    end
  end

  context "custom producers" do
    let(:producer_name) { 'Producer::UnprocessedShardsProducer' }
    subject { described_class.new({producer_name: producer_name}) }
    it "loads the given producer" do
      expect(subject.producer.class).to eq Producer::UnprocessedShardsProducer
    end
  end

  context "default producer" do
    it "uses iterative database producer by default" do
      expect(subject.producer.class).to eq Producer::IterativeDatabaseProducer
    end
  end

  ['Producer::UnprocessedShardsProducer', 'Producer::IterativeDatabaseProducer'].each do |producer|
    describe "#process_work with #{producer}" do
      let(:producer_name) { producer }
      subject { described_class.new({producer_name: producer_name}) }

      context "with one message, many shards" do
        let!(:messages) do
          (1..10).to_a.map do |i|
            create(:message, body: i, shard_id: i, needs_sending: true)
          end
        end

        def expect_processed
          stubs = (1..10).to_a.map do |i|
            stub_request(:post, /scaffolding\/messages/).
                with(body: i.to_s)
          end

          Timeout::timeout(3) do
            subject.start
          end rescue nil

          stubs.each do |stub|
            expect(stub).to have_been_requested
          end
        end

        def expect_not_processed
          stubs = (1..10).to_a.map do |i|
            stub_request(:post, /scaffolding\/messages/).
                with(body: i.to_s)
          end

          Timeout::timeout(3) do
            subject.start
          end rescue nil

          stubs.each do |stub|
            expect(stub).to_not have_been_requested
          end
        end


        it "processes each message only once" do
          expect_processed
        end

        context "database connection is closed" do
          it "automatically reestablishes database connections" do
            Message.connection.execute("set session wait_timeout=1,net_read_timeout=1,net_write_timeout=1;")
            sleep 1.1
            begin
              expect_processed
            ensure
              ActiveRecord::Base.clear_active_connections!
            end
          end
        end

        context "workers_enabled is false" do
          context "via RuntimeSettings" do
            it "does not process the messages" do
              RuntimeSettings.update_settings workers_enabled: false
              expect_not_processed
            end
          end

          context "via Settings" do
            it "does not process the messages" do
              allow(Settings).to receive(:workers_enabled).and_return false
              expect_not_processed
            end

            it "only calls the settings once per message times" do
              # only 3 calls because of sleep times
              expect(Settings).to receive(:workers_enabled).exactly(3).times.and_return false
              expect_not_processed
            end
          end
        end
      end

      context "many messages, two shards" do
        let!(:messages) do
          (1..10).to_a.map do |i|
            create(:message, body: i, shard_id: i % 2, needs_sending: true)
          end
        end

        let!(:stubs) do
          (1..10).to_a.map do |i|
            stub_request(:post, /scaffolding\/messages/).
              with(body: i.to_s).
              to_return(:body => "#{i} ack" )
          end
        end

        it "processes all messages" do
          Timeout::timeout(10) do
            subject.process_work
          end

          stubs.each do |stub|
            expect(stub).to have_been_requested
          end

          expect(Message.where(processed_count: 0).count).to eq 0
        end

        it "messages in order" do
          subject.process_without_looping
          subject.wait_for_processing

          shard1 = Message.where(processed_count: 1, shard_id: 0).order(:id).to_a
          shard1_by_process = Message.where(processed_count: 1, shard_id: 0).order([:succeeded_at]).to_a

          shard2 = Message.where(processed_count: 1, shard_id: 1).order(:id).to_a
          shard2_by_process = Message.where(processed_count: 1, shard_id: 1).order([:succeeded_at]).to_a

          expect(shard1).to eq shard1_by_process
          expect(shard2).to eq shard2_by_process
        end
      end
    end
  end

  context "#call_endpoint" do
    it "builds the path and query" do
      i = 1
      allow(Settings).to receive(:endpoint_path).and_return "/pathz"
      allow(Settings).to receive(:endpoint_query).and_return "api_key=foo"
      message = create(:message, body: i, shard_id: i, headers: {foo: "bar"}.to_json, needs_sending: true)
      expected_stub = stub_request(:post, /pathz\?api_key=foo/).
          with(body: i.to_s, headers: {foo: "bar"})
      subject.call_endpoint(message)
      expect(expected_stub).to have_been_requested
    end

    it "does not assign the query parameter if not configured" do
      i = 1
      allow(Settings).to receive(:endpoint_path).and_return "/pathz"
      allow(Settings).to receive(:endpoint_query).and_return ""
      message = create(:message, body: i, shard_id: i, headers: {foo: "bar"}.to_json, needs_sending: true)

      expect(subject.connection).to receive(:post) do |url, body, headers|
        expect(url).to match(/pathz$/)
        expect(url).to_not match(/pathz\?/)
      end

      subject.call_endpoint(message)
    end

    it "send the headers" do
      i = 1
      message = create(:message, body: i, shard_id: i, headers: {foo: "bar"}.to_json, needs_sending: true)
      expected_stub = stub_request(:post, /scaffolding\/messages/).
          with(body: i.to_s, headers: {foo: "bar"})
      subject.call_endpoint(message)
      expect(expected_stub).to have_been_requested
    end

    it "does not send a host header" do
      message = create(:message, body: 1, shard_id: 1, headers: {foo: "bar", Host: "something.com"}.to_json, needs_sending: true)
      expected_stub = stub_request(:post, /scaffolding\/messages/).
          with { |request| request.headers["Host"].nil? }
      subject.call_endpoint(message)
      expect(expected_stub).to have_been_requested
    end

    context "custom faraday connection with basic auth" do
      let(:connection) do
        ThreadedWorker.basic_auth_connection
      end

      let(:basic_auth) do
        Base64.encode64("#{Settings.destination_auth_username}:#{Settings.destination_auth_password}")
              .gsub("\n", "")
      end

      subject { described_class.new({connection: connection, failure_delay: failure_delay}) }

      it "sends an authorization header" do
        message = create(:message, body: 1, shard_id: 1, headers: {foo: "bar"}.to_json, needs_sending: true)
        expected_stub = stub_request(:post, /scaffolding\/messages/).
            with(headers: {"Authorization" => "Basic #{basic_auth}"})
        subject.call_endpoint(message)
        expect(expected_stub).to have_been_requested
      end

      it "overwrites existing Authorization header" do
        message = create(:message, body: 1, shard_id: 1, headers: {Authorization: "whatisthis"}.to_json, needs_sending: true)
        expected_stub = stub_request(:post, /scaffolding\/messages/).
            with(headers: {"Authorization" => "Basic #{basic_auth}"})
        subject.call_endpoint(message)
        expect(expected_stub).to have_been_requested
      end
    end
  end

  context "with errors" do
    let!(:messages) do
      (1..2).to_a.map do |i|
        create(:message, body: i, shard_id: i, needs_sending: true)
      end
    end

    # Technically, this terminates with a different exception
    # But, we log it, so, we should still be able to figure it out
    it "terminates with an exception" do
      stub_request(:post, /scaffolding\/messages/).
          with(body: 1.to_s).
          to_return(:body => "1 ack")
      stub_request(:post, /scaffolding\/messages/).
          with(body: 2.to_s).
          to_raise(Exception)

      expect(Rails.logger).to receive(:error).at_least(1)

      expect {
        Timeout::timeout(3) do
          subject.start
        end
      }.to raise_error(Exception)
    end

    it "does not terminate when a standard error occurs fetching the message" do
      stub_request(:post, /scaffolding\/messages/).
          with(body: 1.to_s).
          to_return(:body => "1 ack")
      stub_request(:post, /scaffolding\/messages/).
          with(body: 2.to_s).
          to_return(:body => "2 ack")
      allow(Message).to receive(:where).with(needs_sending: true) do
        RSpec::Mocks.space.proxy_for(Message).reset
        raise "BOOM"
      end

      Timeout::timeout(3) do
        subject.start
      end rescue nil

      message1 = Message.where(shard_id: 1).first
      message2 = Message.where(shard_id: 2).first

      expect(message1.succeeded_at).to_not be nil
      expect(message2.succeeded_at).to_not be nil
    end

    it "does not consider non 2xx a success" do
      stub_request(:post, /scaffolding\/messages/).
          with(body: 1.to_s).
          to_return(:body => "1 ack")
      stub_request(:post, /scaffolding\/messages/).
          with(body: 2.to_s).
          to_return(:body => "no bueno", status: 400)

      subject.process_without_looping
      subject.wait_for_processing

      message1 = Message.where(shard_id: 1).first
      message2 = Message.where(shard_id: 2).first

      expect(message1.succeeded_at).to_not be nil
      expect(message2.succeeded_at).to be nil
      expect(message2.last_failed_at).to_not be nil
      expect(message2.response_code).to eq 400
      expect(message2.response_body).to eq "no bueno"
    end

    context "single message" do
      let!(:messages) do
        create(:message, body: 1, shard_id: 1, needs_sending: true)
      end

      subject do
        described_class.new({
          thread_count: 1,
          failure_delay: failure_delay,
          failure_exponent_base: failure_exponent_base,
          max_failure_delay: max_failure_delay
        })
      end

      it "it skips work when failures occur until failure_delay has passed" do
        stub_request(:post, /scaffolding\/messages/).
            with(body: 1.to_s).
            to_return({:body => "no bueno", status: 504},
                      {:body => "si bueno", status: 200})

        subject.process_without_looping
        subject.wait_for_processing

        message1 = Message.where(shard_id: 1).first
        expect(message1.response_code).to eq 504
        expect(message1.response_body).to eq "no bueno"
        expect(message1.succeeded_at).to be nil

        sleep 1

        subject.produce_work
        subject.wait_for_processing

        message1 = Message.where(shard_id: 1).first
        expect(message1.succeeded_at).to be nil
        expect(message1.response_code).to eq 504
        expect(message1.response_body).to eq "no bueno"

        sleep failure_delay

        subject.produce_work
        subject.wait_for_processing

        message1 = Message.where(shard_id: 1).first
        expect(message1.succeeded_at).to_not be nil
        expect(message1.response_code).to eq 200
        expect(message1.response_body).to eq "si bueno"
        expect(message1.succeeded_at - message1.last_failed_at).to be >= failure_delay
      end

      it "it skips work when errors occur until failure_delay has passed" do
        stub_request(:post, /scaffolding\/messages/).
            with(body: 1.to_s).
            to_raise(StandardError).
            to_return({:body => "si bueno", status: 200})

        subject.process_without_looping
        subject.wait_for_processing

        message1 = Message.where(shard_id: 1).first
        expect(message1.last_failed_at).to_not be nil

        sleep 1

        subject.produce_work
        subject.wait_for_processing

        message1 = Message.where(shard_id: 1).first
        expect(message1.succeeded_at).to be nil
        expect(message1.last_failed_at).to_not be nil

        sleep failure_delay

        subject.produce_work
        subject.wait_for_processing

        message1 = Message.where(shard_id: 1).first
        expect(message1.succeeded_at).to_not be nil
        expect(message1.response_code).to eq 200
        expect(message1.response_body).to eq "si bueno"
        expect(message1.succeeded_at - message1.last_failed_at).to be >= failure_delay
      end

      context "exponential backoff is configured" do
        let(:failure_exponent_base) { 2 }

        it "it skips work when errors occur until failure_delay has passed" do
          stub_request(:post, /scaffolding\/messages/).
              with(body: 1.to_s).
              to_raise(StandardError).
              to_raise(StandardError).
              to_return({:body => "si bueno", status: 200})

          subject.process_without_looping
          subject.wait_for_processing

          message1 = Message.where(shard_id: 1).first

          Timeout.timeout(90) do
            begin
              subject.produce_work
              subject.wait_for_processing
            end while message1.reload.succeeded_at.nil?
          end rescue nil

          expect(message1.succeeded_at).to_not be nil
          expect(message1.response_code).to eq 200
          expect(message1.response_body).to eq "si bueno"
          expect(message1.succeeded_at - message1.last_failed_at).to be >= failure_delay * 2
        end
      end

      context "exponential backoff and max failure delay are configured" do
        let(:failure_exponent_base) { 2 }
        let(:max_failure_delay) { 5 }

        it "it skips work when errors occur until failure_delay has passed" do
          stub_request(:post, /scaffolding\/messages/).
              with(body: 1.to_s).
              to_raise(StandardError).
              to_raise(StandardError).
              to_return({:body => "si bueno", status: 200})

          subject.process_without_looping
          subject.wait_for_processing

          message1 = Message.where(shard_id: 1).first

          Timeout.timeout(10) do
            begin
              subject.produce_work
              subject.wait_for_processing
            end while message1.reload.succeeded_at.nil?
          end rescue nil

          expect(message1.succeeded_at).to_not be nil
          expect(message1.response_code).to eq 200
          expect(message1.response_body).to eq "si bueno"
          expect(message1.succeeded_at - message1.last_failed_at).to be < failure_delay * 2
          expect(message1.succeeded_at - message1.last_failed_at).to be >= 5
        end
      end

      context 'when processed_count exceeds the max retries' do
        let!(:messages) do
          [create(:message, body: 1, shard_id: 1, needs_sending: true, processed_count: 4)]
        end
        it 'sets the need sending to false ' do
          stub_request(:post, /scaffolding\/messages/).
              to_return(
                  :status => 401)
          subject.process_without_looping
          subject.wait_for_processing
          sleep 1
          message1 = Message.where(shard_id: 1).first

          expect(message1.needs_sending?).to be false
        end
      end

      context 'when processed_count is less than the max retries' do
        let!(:messages) do
          [create(:message, body: 1, shard_id: 1, needs_sending: true, processed_count: 1)]
        end
        it 'sets the need sending to true ' do
          stub_request(:post, /scaffolding\/messages/).
              to_return(
                  :status => 401)
          subject.process_without_looping
          subject.wait_for_processing
          sleep 1
          message1 = Message.where(shard_id: 1).first
          expect(message1.needs_sending?).to be true
        end
      end
      context 'on error when processed_count is less than the max retries' do
        let!(:messages) do
          [create(:message, body: 1, shard_id: 1, needs_sending: true, processed_count: 1)]
        end
        it 'sets the need sending to true on error if processed count is less then the max retry' do
          stub_request(:post, /scaffolding\/messages/).
              to_raise(Exception)
          subject.process_without_looping
          subject.wait_for_processing
          sleep 1
          message1 = Message.where(shard_id: 1).first
          expect(message1.needs_sending?).to be true
        end
      end

      context 'on error when processed_count is less than the max retries' do
        let!(:messages) do
          [create(:message, body: 1, shard_id: 1, needs_sending: true, processed_count: 4)]
        end
        it 'sets the need sending to true on error if processed count is less then the max retry' do
          stub_request(:post, /scaffolding\/messages/).
              to_raise(Exception)
          subject.process_without_looping
          subject.wait_for_processing
          sleep 1
          message1 = Message.where(shard_id: 1).first
          expect(message1.needs_sending?).to be false
        end
      end
    end
  end

  context 'on success' do
    let!(:messages) do
      [create(:message, body: 1, shard_id: 1, needs_sending: true)]
    end
    it 'sets the need sending to false on success' do
      stub_request(:post, /scaffolding\/messages/).
          to_return(
              :status => 200)
      subject.process_without_looping
      subject.wait_for_processing
      sleep 1
      message1 = Message.where(shard_id: 1).first

      expect(message1.needs_sending?).to be false
    end
  end


end
