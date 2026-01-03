# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPublisher do
  before(:each) do
    # Reset the memoized connection before each test to prevent leaks
    EventPublisher.instance_variable_set(:@rabbit_connection, nil)
    allow(Rails.logger).to receive(:info)
  end

  describe ".publish" do
    context "in production environment" do
      before(:each) do
        # Recreate Bunny mocks for each test to prevent instance double leaks
        connection_instance = instance_double(Bunny::Session)
        channel_instance = instance_double(Bunny::Channel)
        exchange_instance = instance_double(Bunny::Exchange)

        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(Bunny).to receive(:new).and_return(connection_instance)
        allow(connection_instance).to receive(:start).and_return(connection_instance)
        allow(connection_instance).to receive(:create_channel).and_return(channel_instance)
        allow(channel_instance).to receive(:topic).and_return(exchange_instance)
        allow(channel_instance).to receive(:close)
        allow(exchange_instance).to receive(:publish)

        # Store references for test assertions
        @connection_mock = connection_instance
        @channel_mock = channel_instance
        @exchange_mock = exchange_instance
      end

      it "publishes event to RabbitMQ" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@exchange_mock).to have_received(:publish).with(
          anything,
          hash_including(
            routing_key: "doctor.created",
            persistent: true,
            content_type: "application/json"
          )
        )
      end

      it "includes event_type in message" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@exchange_mock).to have_received(:publish) do |message, _options|
          parsed = JSON.parse(message)
          expect(parsed["event_type"]).to eq("doctor.created")
        end
      end

      it "includes payload in message" do
        EventPublisher.publish("doctor.created", { doctor_id: "123", name: "Dr. Smith" })

        expect(@exchange_mock).to have_received(:publish) do |message, _options|
          parsed = JSON.parse(message)
          expect(parsed["payload"]["doctor_id"]).to eq("123")
          expect(parsed["payload"]["name"]).to eq("Dr. Smith")
        end
      end

      it "includes service name in message" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@exchange_mock).to have_received(:publish) do |message, _options|
          parsed = JSON.parse(message)
          expect(parsed["service"]).to eq("doctors-service")
        end
      end

      it "includes timestamp in message" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@exchange_mock).to have_received(:publish) do |message, _options|
          parsed = JSON.parse(message)
          expect(parsed["timestamp"]).to be_present
          expect { Time.parse(parsed["timestamp"]) }.not_to raise_error
        end
      end

      it "includes request_id from Current" do
        Current.request_id = "request-123"

        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@exchange_mock).to have_received(:publish) do |message, _options|
          parsed = JSON.parse(message)
          expect(parsed["request_id"]).to eq("request-123")
        end

        Current.request_id = nil
      end

      it "logs the published event" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(Rails.logger).to have_received(:info).with(/Published event: doctor.created/)
      end

      it "closes the channel after publishing" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@channel_mock).to have_received(:close)
      end

      it "uses durable topic exchange" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@channel_mock).to have_received(:topic).with("mediconnect.events", durable: true)
      end
    end

    context "in development environment" do
      before(:each) do
        connection_instance = instance_double(Bunny::Session)
        channel_instance = instance_double(Bunny::Channel)
        exchange_instance = instance_double(Bunny::Exchange)

        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
        allow(Bunny).to receive(:new).and_return(connection_instance)
        allow(connection_instance).to receive(:start).and_return(connection_instance)
        allow(connection_instance).to receive(:create_channel).and_return(channel_instance)
        allow(channel_instance).to receive(:topic).and_return(exchange_instance)
        allow(channel_instance).to receive(:close)
        allow(exchange_instance).to receive(:publish)

        @exchange_mock = exchange_instance
      end

      it "publishes events" do
        EventPublisher.publish("doctor.created", { doctor_id: "123" })

        expect(@exchange_mock).to have_received(:publish)
      end
    end

    context "in test environment" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
      end

      it "does not publish events" do
        expect(Bunny).not_to receive(:new)

        EventPublisher.publish("doctor.created", { doctor_id: "123" })
      end
    end

    context "when channel close raises an error" do
      before(:each) do
        connection_instance = instance_double(Bunny::Session)
        channel_instance = instance_double(Bunny::Channel)
        exchange_instance = instance_double(Bunny::Exchange)

        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(Bunny).to receive(:new).and_return(connection_instance)
        allow(connection_instance).to receive(:start).and_return(connection_instance)
        allow(connection_instance).to receive(:create_channel).and_return(channel_instance)
        allow(channel_instance).to receive(:topic).and_return(exchange_instance)
        allow(channel_instance).to receive(:close).and_raise(StandardError.new("Close failed"))
        allow(exchange_instance).to receive(:publish)

        @channel_mock = channel_instance
      end

      it "still ensures channel close is attempted" do
        expect { EventPublisher.publish("doctor.created", { doctor_id: "123" }) }
          .to raise_error(StandardError, "Close failed")

        expect(@channel_mock).to have_received(:close)
      end
    end

    context "with nil channel" do
      before(:each) do
        connection_instance = instance_double(Bunny::Session)

        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(Bunny).to receive(:new).and_return(connection_instance)
        allow(connection_instance).to receive(:start).and_return(connection_instance)
        allow(connection_instance).to receive(:create_channel).and_return(nil)
      end

      it "handles nil channel gracefully in ensure block" do
        expect { EventPublisher.publish("doctor.created", { doctor_id: "123" }) }
          .to raise_error(NoMethodError)
      end
    end
  end

  describe "RabbitMQ connection configuration" do
    context "with default RABBITMQ_URL" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(ENV).to receive(:fetch).with("RABBITMQ_URL", anything).and_return("amqp://guest:guest@localhost:5672")
      end

      it "uses default connection URL" do
        connection_instance = instance_double(Bunny::Session)
        channel_instance = instance_double(Bunny::Channel)
        exchange_instance = instance_double(Bunny::Exchange)

        expect(Bunny).to receive(:new).with(
          "amqp://guest:guest@localhost:5672",
          hash_including(
            automatically_recover: true,
            network_recovery_interval: 5,
            recovery_attempts: 10
          )
        ).and_return(connection_instance)

        allow(connection_instance).to receive(:start).and_return(connection_instance)
        allow(connection_instance).to receive(:create_channel).and_return(channel_instance)
        allow(channel_instance).to receive(:topic).and_return(exchange_instance)
        allow(channel_instance).to receive(:close)
        allow(exchange_instance).to receive(:publish)

        EventPublisher.publish("doctor.created", { doctor_id: "123" })
      end
    end
  end
end