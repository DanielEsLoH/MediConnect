# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventConsumer do
  let(:user) { create(:user) }
  let(:channel) { instance_double(Bunny::Channel) }
  let(:delivery_info) { instance_double("DeliveryInfo", delivery_tag: "tag-123") }

  before do
    allow(channel).to receive(:ack)
    allow(channel).to receive(:nack)
  end

  describe "SUBSCRIBED_EVENTS" do
    it "includes appointment.created" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.created")
    end

    it "includes appointment.completed" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.completed")
    end

    it "includes appointment.cancelled" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.cancelled")
    end

    it "includes payment.completed" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("payment.completed")
    end

    it "is frozen" do
      expect(described_class::SUBSCRIBED_EVENTS).to be_frozen
    end
  end

  describe ".handle_event" do
    describe "appointment.created event" do
      let(:event_payload) do
        {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-123",
            "doctor_id" => "doc-456",
            "scheduled_at" => Time.current.iso8601
          }
        }.to_json
      end

      it "acknowledges the message on success" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs user activity for appointment creation" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\[USER_ACTIVITY\].*created appointment/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs the received event" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Received event: appointment.created/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs statistics update" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Updated statistics for user.*appointment_created/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    describe "appointment.completed event" do
      let(:event_payload) do
        {
          "event_type" => "appointment.completed",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-123",
            "doctor_id" => "doc-456",
            "completed_at" => Time.current.iso8601
          }
        }.to_json
      end

      it "acknowledges the message on success" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs user activity for appointment completion" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\[USER_ACTIVITY\].*completed appointment/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    describe "appointment.cancelled event" do
      let(:event_payload) do
        {
          "event_type" => "appointment.cancelled",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-123",
            "cancelled_at" => Time.current.iso8601,
            "reason" => "Patient request"
          }
        }.to_json
      end

      it "acknowledges the message on success" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs user activity for appointment cancellation" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\[USER_ACTIVITY\].*cancelled appointment/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    describe "payment.completed event" do
      let(:event_payload) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "user_id" => user.id,
            "amount" => 150.00,
            "payment_id" => "pay-789",
            "appointment_id" => "apt-123"
          }
        }.to_json
      end

      it "acknowledges the message on success" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs user activity for payment completion" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\[USER_ACTIVITY\].*completed payment/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "formats currency amount in activity log" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\$150\.00/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    describe "unknown event type" do
      let(:event_payload) do
        {
          "event_type" => "unknown.event",
          "payload" => {
            "user_id" => user.id,
            "data" => "test"
          }
        }.to_json
      end

      it "acknowledges the message" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "logs the received event" do
        expect(Rails.logger).to receive(:info).with(/Received event: unknown.event/)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end
  end

  describe "Error Handling" do
    describe "invalid JSON payload" do
      let(:invalid_json) { "not valid json {" }

      it "rejects and requeues the message" do
        expect(channel).to receive(:nack).with("tag-123", false, true)

        described_class.handle_event(delivery_info, invalid_json, channel)
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(/Error handling event/).at_least(:once)

        described_class.handle_event(delivery_info, invalid_json, channel)
      end

      it "logs the backtrace" do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).at_least(:twice)

        described_class.handle_event(delivery_info, invalid_json, channel)
      end
    end

    describe "empty payload" do
      let(:empty_json) { "{}" }

      it "handles empty payload without raising" do
        expect { described_class.handle_event(delivery_info, empty_json, channel) }.not_to raise_error
      end
    end

    describe "user not found" do
      let(:event_payload) do
        {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => "non-existent-uuid",
            "appointment_id" => "apt-123"
          }
        }.to_json
      end

      it "logs warning when user is not found" do
        expect(Rails.logger).to receive(:warn).with(/User not found/)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "acknowledges the message even when user not found" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    describe "missing user_id in payload" do
      let(:event_payload) do
        {
          "event_type" => "appointment.created",
          "payload" => {
            "appointment_id" => "apt-123"
          }
        }.to_json
      end

      it "handles missing user_id gracefully" do
        expect { described_class.handle_event(delivery_info, event_payload, channel) }.not_to raise_error
      end

      it "acknowledges the message" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    describe "nil user_id in payload" do
      let(:event_payload) do
        {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => nil,
            "appointment_id" => "apt-123"
          }
        }.to_json
      end

      it "handles nil user_id gracefully" do
        expect { described_class.handle_event(delivery_info, event_payload, channel) }.not_to raise_error
      end
    end

    describe "database error during user lookup" do
      let(:event_payload) do
        {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-123"
          }
        }.to_json
      end

      before do
        allow(User).to receive(:find_by).and_raise(ActiveRecord::ConnectionNotEstablished.new("Connection lost"))
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(/Failed to update user statistics/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "acknowledges the message despite error" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end
  end

  describe "currency formatting" do
    context "with payment.completed event" do
      let(:event_payload) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "user_id" => user.id,
            "amount" => 99.5,
            "payment_id" => "pay-123"
          }
        }.to_json
      end

      it "formats amount with two decimal places" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\$99\.50/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    context "with string amount" do
      let(:event_payload) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "user_id" => user.id,
            "amount" => "75.25",
            "payment_id" => "pay-123"
          }
        }.to_json
      end

      it "handles string amounts" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\$75\.25/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end

    context "with zero amount" do
      let(:event_payload) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "user_id" => user.id,
            "amount" => 0,
            "payment_id" => "pay-123"
          }
        }.to_json
      end

      it "handles zero amounts" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\$0\.00/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end
  end

  describe "activity logging" do
    context "with appointment events" do
      it "includes user ID in activity message" do
        event_payload = {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-123"
          }
        }.to_json

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/User #{user.id}/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "includes appointment ID in activity message" do
        event_payload = {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-999"
          }
        }.to_json

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/apt-999/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end

      it "includes timestamp in activity log" do
        event_payload = {
          "event_type" => "appointment.created",
          "payload" => {
            "user_id" => user.id,
            "appointment_id" => "apt-123"
          }
        }.to_json

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/\[USER_ACTIVITY\].*at \d{4}-\d{2}-\d{2}/).at_least(:once)

        described_class.handle_event(delivery_info, event_payload, channel)
      end
    end
  end
end
