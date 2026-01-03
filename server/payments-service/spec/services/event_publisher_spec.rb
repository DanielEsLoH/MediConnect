# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPublisher do
  describe ".publish" do
    let(:event_type) { "payment.completed" }
    let(:payload) { { payment_id: "123", user_id: "456", amount: 99.99 } }

    context "in test environment without ENABLE_EVENT_PUBLISHING" do
      before do
        ENV.delete("ENABLE_EVENT_PUBLISHING")
      end

      it "skips publishing and returns early" do
        expect(described_class).not_to receive(:rabbit_connection)

        described_class.publish(event_type, payload)
      end

      it "does not create a channel or exchange" do
        connection = instance_double(Bunny::Session)
        allow(described_class).to receive(:rabbit_connection).and_return(connection)

        expect(connection).not_to receive(:create_channel)

        described_class.publish(event_type, payload)
      end
    end

    context "with ENABLE_EVENT_PUBLISHING enabled" do
      let(:connection) { instance_double(Bunny::Session) }
      let(:channel) { instance_double(Bunny::Channel) }
      let(:exchange) { instance_double(Bunny::Exchange) }

      before do
        ENV["ENABLE_EVENT_PUBLISHING"] = "true"

        allow(described_class).to receive(:rabbit_connection).and_return(connection)
        allow(connection).to receive(:create_channel).and_return(channel)
        allow(channel).to receive(:topic).with("mediconnect.events", durable: true).and_return(exchange)
        allow(channel).to receive(:close)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end

      after do
        ENV.delete("ENABLE_EVENT_PUBLISHING")
      end

      it "creates a channel from the connection" do
        allow(exchange).to receive(:publish)

        expect(connection).to receive(:create_channel).and_return(channel)

        described_class.publish(event_type, payload)
      end

      it "creates a topic exchange named mediconnect.events" do
        allow(exchange).to receive(:publish)

        expect(channel).to receive(:topic).with("mediconnect.events", durable: true).and_return(exchange)

        described_class.publish(event_type, payload)
      end

      it "publishes the message to the exchange with correct routing key" do
        expect(exchange).to receive(:publish) do |message, options|
          expect(options[:routing_key]).to eq(event_type)
          expect(options[:persistent]).to be true
          expect(options[:content_type]).to eq("application/json")
        end

        described_class.publish(event_type, payload)
      end

      it "includes event metadata in the published message" do
        published_message = nil

        allow(exchange).to receive(:publish) do |message, _options|
          published_message = JSON.parse(message)
        end

        described_class.publish(event_type, payload)

        expect(published_message).to include(
          "event_type" => event_type,
          "payload" => payload.stringify_keys,
          "service" => "payments-service",
          "version" => "1.0"
        )
        expect(published_message["timestamp"]).to be_present
      end

      it "includes request_id from Thread.current in the message" do
        Thread.current[:request_id] = "req_12345"
        published_message = nil

        allow(exchange).to receive(:publish) do |message, _options|
          published_message = JSON.parse(message)
        end

        described_class.publish(event_type, payload)

        expect(published_message["request_id"]).to eq("req_12345")

        Thread.current[:request_id] = nil
      end

      it "logs successful event publication" do
        allow(exchange).to receive(:publish)

        expect(Rails.logger).to receive(:info).with(
          hash_including(
            event: "event_published",
            event_type: event_type
          )
        )

        described_class.publish(event_type, payload)
      end

      it "excludes sensitive_data from logged payload" do
        sensitive_payload = payload.merge(sensitive_data: "secret_token_123")

        allow(exchange).to receive(:publish)

        expect(Rails.logger).to receive(:info) do |log_entry|
          expect(log_entry[:payload]).not_to have_key(:sensitive_data)
        end

        described_class.publish(event_type, sensitive_payload)
      end

      it "closes the channel after publishing" do
        allow(exchange).to receive(:publish)

        expect(channel).to receive(:close)

        described_class.publish(event_type, payload)
      end

      context "when an error occurs during publishing" do
        before do
          allow(exchange).to receive(:publish).and_raise(StandardError.new("RabbitMQ connection lost"))
        end

        it "logs the error without raising" do
          expect(Rails.logger).to receive(:error).with(
            hash_including(
              event: "event_publish_failed",
              event_type: event_type,
              error: "RabbitMQ connection lost"
            )
          )

          expect {
            described_class.publish(event_type, payload)
          }.not_to raise_error
        end

        it "includes backtrace in the error log" do
          expect(Rails.logger).to receive(:error) do |log_entry|
            expect(log_entry[:backtrace]).to be_present
            expect(log_entry[:backtrace]).to be_a(Array)
          end

          described_class.publish(event_type, payload)
        end

        it "still attempts to close the channel" do
          expect(channel).to receive(:close)

          described_class.publish(event_type, payload)
        end
      end

      context "when channel is nil" do
        it "does not raise error when closing" do
          allow(connection).to receive(:create_channel).and_raise(StandardError.new("Connection failed"))

          expect {
            described_class.publish(event_type, payload)
          }.not_to raise_error
        end
      end
    end
  end

  describe ".rabbit_connection (private)" do
    before do
      # Clear the memoized connection before each test
      described_class.instance_variable_set(:@rabbit_connection, nil)
    end

    after do
      # Clean up after tests
      described_class.instance_variable_set(:@rabbit_connection, nil)
    end

    context "when creating a new connection" do
      it "uses RABBITMQ_URL from environment if present" do
        ENV["RABBITMQ_URL"] = "amqp://custom:password@rabbitmq.example.com:5672"

        expect(Bunny).to receive(:new).with(
          "amqp://custom:password@rabbitmq.example.com:5672",
          hash_including(
            automatically_recover: true,
            network_recovery_interval: 5,
            recovery_attempts: 10
          )
        ).and_return(instance_double(Bunny::Session, start: true))

        described_class.send(:rabbit_connection)

        ENV.delete("RABBITMQ_URL")
      end

      it "uses default localhost URL when RABBITMQ_URL is not set" do
        ENV.delete("RABBITMQ_URL")

        expect(Bunny).to receive(:new).with(
          "amqp://guest:guest@localhost:5672",
          hash_including(automatically_recover: true)
        ).and_return(instance_double(Bunny::Session, start: true))

        described_class.send(:rabbit_connection)
      end

      it "starts the connection before returning" do
        connection = instance_double(Bunny::Session)
        allow(Bunny).to receive(:new).and_return(connection)

        expect(connection).to receive(:start)

        described_class.send(:rabbit_connection)
      end

      it "memoizes the connection for subsequent calls" do
        connection = instance_double(Bunny::Session)
        allow(Bunny).to receive(:new).and_return(connection)
        allow(connection).to receive(:start)

        # First call should create new connection
        first_result = described_class.send(:rabbit_connection)

        # Second call should return the same connection
        second_result = described_class.send(:rabbit_connection)

        expect(first_result).to eq(second_result)
        expect(Bunny).to have_received(:new).once
      end
    end
  end
end
