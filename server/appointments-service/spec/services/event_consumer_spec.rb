# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventConsumer do
  describe "SUBSCRIBED_EVENTS constant" do
    it "includes payment.completed event" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("payment.completed")
    end

    it "is frozen" do
      expect(described_class::SUBSCRIBED_EVENTS).to be_frozen
    end
  end

  describe ".start" do
    context "in test environment" do
      it "does not start the consumer" do
        # Verify we're in test environment
        expect(Rails.env.test?).to be true

        # The start method should return nil and not start any threads
        result = described_class.start

        expect(result).to be_nil
      end
    end
  end

  describe ".handle_event" do
    let(:channel) { instance_double("Bunny::Channel") }
    let(:delivery_info) { instance_double("Bunny::DeliveryInfo", delivery_tag: "tag-123") }

    before do
      allow(channel).to receive(:ack)
      allow(channel).to receive(:nack)
    end

    context "with payment.completed event" do
      let!(:appointment) { create(:appointment, status: "pending") }
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => appointment.id,
            "amount" => 150.00,
            "payment_id" => SecureRandom.uuid
          }
        }.to_json
      end

      it "confirms the appointment" do
        described_class.handle_event(delivery_info, event_body, channel)

        appointment.reload
        expect(appointment.status).to eq("confirmed")
      end

      it "acknowledges the message" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "logs the event" do
        expect(Rails.logger).to receive(:info).with(/Received event: payment.completed/)
        allow(Rails.logger).to receive(:info) # Allow other logs

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when appointment is not found" do
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => SecureRandom.uuid
          }
        }.to_json
      end

      it "logs warning and acknowledges" do
        expect(Rails.logger).to receive(:warn).with(/Appointment not found/)
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when appointment_id is blank" do
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {}
        }.to_json
      end

      it "acknowledges without processing" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when appointment is already confirmed" do
      let!(:appointment) { create(:appointment, :confirmed) }
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => appointment.id
          }
        }.to_json
      end

      it "skips confirmation (idempotent)" do
        expect(Rails.logger).to receive(:info).with(/already in status/)
        allow(Rails.logger).to receive(:info) # Allow other logs

        described_class.handle_event(delivery_info, event_body, channel)

        appointment.reload
        expect(appointment.status).to eq("confirmed")
      end

      it "acknowledges the message" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when appointment is completed" do
      let!(:appointment) { create(:appointment, :completed) }
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => appointment.id
          }
        }.to_json
      end

      it "skips confirmation (idempotent)" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)

        appointment.reload
        expect(appointment.status).to eq("completed")
      end
    end

    context "when appointment is cancelled" do
      let!(:appointment) { create(:appointment, :cancelled) }
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => appointment.id
          }
        }.to_json
      end

      it "skips confirmation (idempotent)" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)

        appointment.reload
        expect(appointment.status).to eq("cancelled")
      end
    end

    context "with unknown event type" do
      let(:event_body) do
        {
          "event_type" => "unknown.event",
          "payload" => {}
        }.to_json
      end

      it "acknowledges without processing" do
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when JSON parsing fails" do
      let(:event_body) { "invalid json" }

      it "rejects and requeues the message" do
        expect(channel).to receive(:nack).with("tag-123", false, true)

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Error handling event/)
        expect(Rails.logger).to receive(:error).at_least(:once) # backtrace

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when confirmation fails" do
      let!(:appointment) { create(:appointment, status: "pending") }
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => appointment.id
          }
        }.to_json
      end

      before do
        allow_any_instance_of(Appointment).to receive(:confirm!).and_return(false)
      end

      it "logs error but acknowledges" do
        expect(Rails.logger).to receive(:error).with(/Failed to confirm/)
        expect(channel).to receive(:ack).with("tag-123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "when processing raises an error" do
      let!(:appointment) { create(:appointment, status: "pending") }
      let(:event_body) do
        {
          "event_type" => "payment.completed",
          "payload" => {
            "appointment_id" => appointment.id
          }
        }.to_json
      end

      before do
        allow(Appointment).to receive(:find_by).and_raise(StandardError.new("Database error"))
      end

      it "rejects and requeues the message" do
        expect(channel).to receive(:nack).with("tag-123", false, true)

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Error handling event/)
        expect(Rails.logger).to receive(:error).at_least(:once) # backtrace

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end
  end
end
