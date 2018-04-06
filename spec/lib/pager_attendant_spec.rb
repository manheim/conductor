require 'rails_helper'
require 'webmock/rspec'


# concerns: paging out metric data to the humans
# behaviors: given metrics, open, close, or update pages (via pager duty)

RSpec.describe PagerAttendant, type: :request do

  describe "update pager duty alerts (#refresh_pages!)" do

    let(:service_key) { 'mykey' }
    let(:pagerduty) { instance_double(Pagerduty, service_key: service_key) }
    let(:incident) { instance_double(PagerdutyIncident) }
    let(:metrics) { [] }

    before do
      allow(Pagerduty).to receive(:new).and_return(pagerduty)
      allow(pagerduty).to receive(:get_incident).and_return incident
      allow(incident).to receive(:acknowledge)
      allow(incident).to receive(:resolve)
      allow(Settings).to receive(:new_relic_app_name).and_return 'Test Conductor'
      allow(Settings).to receive(:conductor_health_page_url).and_return 'http://conductor.com/health'
      allow(Rails.logger).to receive(:info)
    end

    after do
      Message.connection.reset!
    end

    subject do
      described_class.new()
    end

    context "system is healthy" do
      let(:metrics) do
        [
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: 10,
            in_violation: false
          },
          {
            metric_name: :too_many_unsent_messages,
            metric_value: 10000,
            in_violation: false
          },
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: '0 minutes',
            in_violation: false
          },
          {
            metric_name: :no_messages_received,
            metric_value: 10,
            in_violation: false
          }
        ]
      end

      it "does not attempt to alert even if system is unhealthy" do
        expect(pagerduty).to_not receive(:trigger)
        subject.refresh_pages!(metrics)
      end

      it "logs a message each time the worker starts" do
        expect(Rails.logger).to receive(:info).with(/#{described_class}.*Running/)
        subject.refresh_pages!(metrics)
      end

      it "logs a message when there are no alerts to trigger" do
        expect(Rails.logger).to receive(:info).with(/System healthy/)
        subject.refresh_pages!(metrics)
      end

      it "acknowledges and resolves any open alerts when no problems exist" do
        expect(pagerduty).to receive(:get_incident).and_return incident
        expect(incident).to receive(:acknowledge)
        expect(incident).to receive(:resolve)
        subject.refresh_pages!(metrics)
      end
    end

    context "system is unhealthy and pd application name is NOT set" do
      let(:metrics) do
        [
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: 10,
            in_violation: true
          },
          {
            metric_name: :too_many_unsent_messages,
            metric_value: 10000,
            in_violation: true
          },
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: '0 minutes',
            in_violation: false
          },
          {
            metric_name: :no_messages_received,
            metric_value: 10,
            in_violation: false
          }
        ]
      end

      it "includes app name as part of the alert" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(client: 'Test Conductor'))
        subject.refresh_pages!(metrics)
      end

      it "includes health page url in the alert" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(client_url: 'http://conductor.com/health'))
        subject.refresh_pages!(metrics)
      end

      it "includes incident key as part of the alert" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(incident_key: 'Test Conductor Alert'))
        subject.refresh_pages!(metrics)
      end

      it "includes details containing the raw event type and metric value" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(:details=>[{:metric_name=>:shards_blocked_over_threshold, :metric_value=>10, :in_violation=>true}, {:metric_name=>:too_many_unsent_messages, :metric_value=>10000, :in_violation=>true}, {:metric_name=>:oldest_message_older_than_threshold, :metric_value=>"0 minutes", :in_violation=>false}, {:metric_name=>:no_messages_received, :metric_value=>10, :in_violation=>false}]))
        subject.refresh_pages!(metrics)
      end

      it "logs a detailed message when tiggering an alert" do
        #this message contains only metrics in violation
        expect(Rails.logger).to receive(:warn).with(/Triggering alert.*Test Conductor.*blocked shards.*10.*unsent messages.*10000/)
        #this message contains all metrics
        expect(Rails.logger).to receive(:warn).with(/Full system health status.*shards_blocked_over_threshold.*10.*too_many_unsent_messages.*10000.*oldest_message_older_than_threshold.*no_messages_received/)
        allow(pagerduty).to receive(:trigger)
        subject.refresh_pages!(metrics)
      end

      context "queue depth over threshold" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 10000,
              in_violation: true
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: false
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "Number of unsent messages exceeds alert threshold, current queue depth: 10000",
            any_args)

          subject.refresh_pages!(metrics)
        end
      end

      context "oldest message too old" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '3 days ago',
              in_violation: true
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: false
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "An unsent message has exceeded age threshold, age of message: 3 days ago",
            any_args)

          subject.refresh_pages!(metrics)
        end
      end

      context "blocked shards over threshold" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 2,
              in_violation: true
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: false
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "Number of blocked shards exceed threshold, current number: 2",
            any_args)

          subject.refresh_pages!(metrics)
        end
      end

      context "no messages received lately" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: true
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "No messages received in last 10 minutes",
            any_args)

          subject.refresh_pages!(metrics)
        end

      end

      context "health check fails with unknown status" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :blah,
              metric_value: -1,
              in_violation: true
            }
          ]
        end

        it "raises alert to pagerduty with status code and data set" do
          expect(pagerduty).to receive(:trigger).with(
            "Unknown health status: blah, metric value: -1",
            any_args)
          subject.refresh_pages!(metrics)
        end
      end

      context "error when trigger" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :blah,
              metric_value: -1,
              in_violation: true
            }
          ]
        end

        it "logs when a standard error happens and doesn't reraise" do
          expect(Rails.logger).to receive(:error)
          expect(pagerduty).to receive(:trigger).and_raise "BOOM"
          expect {
            subject.refresh_pages!(metrics)
          }.to_not raise_error
        end

        it "logs when an exception happens and reraises" do
          expect(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error)
          expect(pagerduty).to receive(:trigger).and_raise Exception.new("This is an exception")
          expect { subject.refresh_pages!(metrics) }.to raise_error("This is an exception")
        end
      end
    end

    context "system is unhealthy and pd application name is set" do
      before do
        allow(Settings).to receive(:pagerduty_application_name).and_return('Test Conductor')
      end
      let(:metrics) do
        [
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: 10,
            in_violation: true
          },
          {
            metric_name: :too_many_unsent_messages,
            metric_value: 10000,
            in_violation: true
          },
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: '0 minutes',
            in_violation: false
          },
          {
            metric_name: :no_messages_received,
            metric_value: 10,
            in_violation: false
          }
        ]
      end

      it "includes app name as part of the alert" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(client: 'Test Conductor'))
        subject.refresh_pages!(metrics)
      end

      it "includes health page url in the alert" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(client_url: 'http://conductor.com/health'))
        subject.refresh_pages!(metrics)
      end

      it "includes incident key as part of the alert" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(incident_key: 'Test Conductor Alert'))
        subject.refresh_pages!(metrics)
      end

      it "includes details containing the raw event type and metric value" do
        expect(pagerduty).to receive(:trigger).with(anything, hash_including(:details=>[{:metric_name=>:shards_blocked_over_threshold, :metric_value=>10, :in_violation=>true}, {:metric_name=>:too_many_unsent_messages, :metric_value=>10000, :in_violation=>true}, {:metric_name=>:oldest_message_older_than_threshold, :metric_value=>"0 minutes", :in_violation=>false}, {:metric_name=>:no_messages_received, :metric_value=>10, :in_violation=>false}]))
        subject.refresh_pages!(metrics)
      end

      it "logs a detailed message when tiggering an alert" do
        #this message contains only metrics in violation
        expect(Rails.logger).to receive(:warn).with(/Triggering alert.*Test Conductor.*blocked shards.*10.*unsent messages.*10000/)
        #this message contains all metrics
        expect(Rails.logger).to receive(:warn).with(/Full system health status.*shards_blocked_over_threshold.*10.*too_many_unsent_messages.*10000.*oldest_message_older_than_threshold.*no_messages_received/)
        allow(pagerduty).to receive(:trigger)
        subject.refresh_pages!(metrics)
      end

      context "queue depth over threshold" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 10000,
              in_violation: true
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: false
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "Test Conductor: Number of unsent messages exceeds alert threshold, current queue depth: 10000",
            any_args)

          subject.refresh_pages!(metrics)
        end
      end

      context "oldest message too old" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '3 days ago',
              in_violation: true
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: false
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "Test Conductor: An unsent message has exceeded age threshold, age of message: 3 days ago",
            any_args)

          subject.refresh_pages!(metrics)
        end
      end

      context "blocked shards over threshold" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 2,
              in_violation: true
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: false
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "Test Conductor: Number of blocked shards exceed threshold, current number: 2",
            any_args)

          subject.refresh_pages!(metrics)
        end
      end

      context "no messages received lately" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 10,
              in_violation: true
            }
          ]
        end

        it "raises alert to pagerduty" do
          expect(pagerduty).to receive(:trigger).with(
            "Test Conductor: No messages received in last 10 minutes",
            any_args)

          subject.refresh_pages!(metrics)
        end

      end

      context "health check fails with unknown status" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :blah,
              metric_value: -1,
              in_violation: true
            }
          ]
        end

        it "raises alert to pagerduty with status code and data set" do
          expect(pagerduty).to receive(:trigger).with(
            "Test Conductor: Unknown health status: blah, metric value: -1",
            any_args)
          subject.refresh_pages!(metrics)
        end
      end

      context "error when trigger" do
        let(:metrics) do
          [
            {
              metric_name: :shards_blocked_over_threshold,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :too_many_unsent_messages,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :oldest_message_older_than_threshold,
              metric_value: '0 minutes ago',
              in_violation: false
            },
            {
              metric_name: :no_messages_received,
              metric_value: 0,
              in_violation: false
            },
            {
              metric_name: :blah,
              metric_value: -1,
              in_violation: true
            }
          ]
        end

        it "logs when a standard error happens and doesn't reraise" do
          expect(Rails.logger).to receive(:error)
          expect(pagerduty).to receive(:trigger).and_raise "BOOM"
          expect {
            subject.refresh_pages!(metrics)
          }.to_not raise_error
        end

        it "logs when an exception happens and reraises" do
          expect(Rails.logger).to receive(:error)
          expect(Rails.logger).to receive(:error)
          expect(pagerduty).to receive(:trigger).and_raise Exception.new("This is an exception")
          expect { subject.refresh_pages!(metrics) }.to raise_error("This is an exception")
        end
      end
    end

    context "no pd service key set" do
      let(:service_key) { nil }
      let(:health_watcher) { instance_double(HealthWatcher) }
      let(:metrics) do
        [
          {
            metric_name: :shards_blocked_over_threshold,
            metric_value: 0,
            in_violation: false
          },
          {
            metric_name: :too_many_unsent_messages,
            metric_value: 0,
            in_violation: false
          },
          {
            metric_name: :oldest_message_older_than_threshold,
            metric_value: '0 minutes ago',
            in_violation: false
          },
          {
            metric_name: :no_messages_received,
            metric_value: 0,
            in_violation: false
          },
          {
            metric_name: :too_spoopy_4_mez,
            metric_value: 2,
            in_violation: true
          }
        ]
      end

      it "does not attempt to alert even if system is unhealthy" do
        expect(pagerduty).to_not receive(:trigger)
        subject.refresh_pages!(metrics)
      end

      context "ensure watcher not called" do
        before do
          allow(health_watcher).to receive(:health_status).and_raise("spooooOOOOOoooky")
        end

        it "does not attempt to check system health needlessly" do
          expect {subject.refresh_pages!(metrics)}.to_not raise_error
        end

        it "logs a message when deciding not to check metrics" do
          expect(Rails.logger).to receive(:info).with(/No service key/)
          subject.refresh_pages!(metrics)
        end
      end
    end
  end



end
