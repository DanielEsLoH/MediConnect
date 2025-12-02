# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPublisher do
  describe ".publish" do
    let(:connection) { instance_double(Bunny::Session) }
    let(:channel) { instance_double(Bunny::Channel) }
    let(:exchange) { instance_double(Bunny::Exchange) }

    before do
      allow(Bunny).to receive(:new).and_return(connection)
      allow(connection).to receive(:start).and_return(connection)
      allow(connection).to receive(:create_channel).and_return(channel)
      allow(channel).to receive(:topic).and_return(exchange)
      allow(channel).to receive(:close)
      allow(exchange).to receive(:publish)
    end

    it "publishes message to RabbitMQ exchange" do
      described_class.publish("test.event", { data: "test" })

      expect(exchange).to have_received(:publish).with(
        a_string_including('"event_type":"test.event"'),
        hash_including(
          routing_key: "test.event",
          persistent: true,
          content_type: "application/json"
        )
      )
    end

    it "includes service name in payload" do
      described_class.publish("test.event", { data: "test" })

      expect(exchange).to have_received(:publish).with(
        a_string_including('"service":"users-service"'),
        anything
      )
    end

    it "includes timestamp in payload" do
      described_class.publish("test.event", { data: "test" })

      expect(exchange).to have_received(:publish).with(
        a_string_including('"timestamp"'),
        anything
      )
    end

    it "closes channel after publishing" do
      described_class.publish("test.event", { data: "test" })

      expect(channel).to have_received(:close)
    end

    context "in test environment" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
      end

      it "does not publish events" do
        described_class.publish("test.event", { data: "test" })

        expect(exchange).not_to have_received(:publish)
      end
    end
  end
end
