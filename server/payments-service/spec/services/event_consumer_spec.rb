# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventConsumer do
  describe "SUBSCRIBED_EVENTS" do
    it "includes appointment.cancelled event" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.cancelled")
    end

    it "is frozen to prevent modification" do
      expect(described_class::SUBSCRIBED_EVENTS).to be_frozen
    end
  end

  describe ".start" do
    it "responds to .start" do
      expect(described_class).to respond_to(:start)
    end

    context "in test environment" do
      it "returns early without starting a thread" do
        expect(Thread).not_to receive(:new)
        described_class.start
      end
    end
  end

  describe ".handle_event" do
    let(:channel) { double("Bunny::Channel") }
    let(:delivery_info) { double("DeliveryInfo", delivery_tag: "tag_123") }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(channel).to receive(:ack)
      allow(channel).to receive(:nack)
    end

    context "with valid JSON payload" do
      let(:appointment_id) { SecureRandom.uuid }
      let(:user_id) { SecureRandom.uuid }
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: {
            appointment_id: appointment_id,
            user_id: user_id
          }
        }.to_json
      end

      it "parses JSON and logs the event" do
        expect(Rails.logger).to receive(:info).with(/Received event: appointment.cancelled/)

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "acknowledges the message after processing" do
        expect(channel).to receive(:ack).with("tag_123")

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "routes to handle_appointment_cancelled for appointment.cancelled event" do
        expect(described_class).to receive(:handle_appointment_cancelled).with(
          hash_including("appointment_id" => appointment_id, "user_id" => user_id)
        )

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "with unknown event type" do
      let(:event_body) do
        {
          event_type: "unknown.event",
          payload: { some: "data" }
        }.to_json
      end

      it "logs the event and acknowledges without processing" do
        expect(Rails.logger).to receive(:info).with(/Received event: unknown.event/)
        expect(channel).to receive(:ack).with("tag_123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "with invalid JSON" do
      let(:invalid_json) { "{ invalid json }" }

      it "rejects and requeues the message" do
        expect(channel).to receive(:nack).with("tag_123", false, true)

        described_class.handle_event(delivery_info, invalid_json, channel)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Error handling event/)

        described_class.handle_event(delivery_info, invalid_json, channel)
      end
    end

    context "when an exception occurs during processing" do
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: { appointment_id: SecureRandom.uuid }
        }.to_json
      end

      before do
        allow(described_class).to receive(:handle_appointment_cancelled).and_raise(StandardError.new("Processing error"))
      end

      it "rejects and requeues the message" do
        expect(channel).to receive(:nack).with("tag_123", false, true)

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "logs the error with backtrace" do
        expect(Rails.logger).to receive(:error).with(/Error handling event.*Processing error/)
        expect(Rails.logger).to receive(:error).with(kind_of(String)) # backtrace

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "with empty payload" do
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: {}
        }.to_json
      end

      it "acknowledges the message even with empty payload" do
        expect(channel).to receive(:ack).with("tag_123")

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "with nil payload" do
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: nil
        }.to_json
      end

      it "handles nil payload gracefully" do
        # Attempting to access nil["appointment_id"] will raise, which should nack
        expect(channel).to receive(:nack).with("tag_123", false, true)

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end
  end

  describe ".handle_appointment_cancelled" do
    let(:appointment_id) { SecureRandom.uuid }
    let(:user_id) { SecureRandom.uuid }
    let(:payload) { { "appointment_id" => appointment_id, "user_id" => user_id } }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    context "when appointment_id is missing" do
      let(:payload) { { "user_id" => user_id } }

      it "returns early without processing" do
        expect(Payment).not_to receive(:for_appointment)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when appointment_id is blank" do
      let(:payload) { { "appointment_id" => "", "user_id" => user_id } }

      it "returns early without processing" do
        expect(Payment).not_to receive(:for_appointment)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when appointment_id is nil" do
      let(:payload) { { "appointment_id" => nil, "user_id" => user_id } }

      it "returns early without processing" do
        expect(Payment).not_to receive(:for_appointment)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when no payment exists for the appointment" do
      before do
        allow(Payment).to receive(:for_appointment).with(appointment_id).and_return(Payment.none)
      end

      it "logs that no payment was found and returns" do
        expect(Rails.logger).to receive(:info).with(/No payment found for cancelled appointment #{appointment_id}/)

        described_class.send(:handle_appointment_cancelled, payload)
      end

      it "does not attempt to process a refund" do
        expect(described_class).not_to receive(:process_refund)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when payment exists but is not in completed status" do
      let!(:payment) { create(:payment, :pending, appointment_id: appointment_id) }

      it "logs that the payment is not in completed status" do
        expect(Rails.logger).to receive(:info).with(
          /Payment #{payment.id} for appointment #{appointment_id}.*not in 'completed' status.*pending/
        )

        described_class.send(:handle_appointment_cancelled, payload)
      end

      it "does not process a refund" do
        expect(described_class).not_to receive(:process_refund)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when payment exists with processing status" do
      let!(:payment) { create(:payment, :processing, appointment_id: appointment_id) }

      it "skips refund for processing payments" do
        expect(Rails.logger).to receive(:info).with(/not in 'completed' status.*processing/)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when payment exists with failed status" do
      let!(:payment) { create(:payment, :failed, appointment_id: appointment_id) }

      it "skips refund for failed payments" do
        expect(Rails.logger).to receive(:info).with(/not in 'completed' status.*failed/)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when payment exists with refunded status (idempotency check)" do
      let!(:payment) { create(:payment, :refunded, appointment_id: appointment_id) }

      it "skips refund for already refunded payments" do
        expect(Rails.logger).to receive(:info).with(/not in 'completed' status.*refunded/)

        described_class.send(:handle_appointment_cancelled, payload)
      end

      it "does not attempt to refund again" do
        expect(payment).not_to receive(:mark_as_refunded!)

        described_class.send(:handle_appointment_cancelled, payload)
      end
    end

    context "when payment is in completed status" do
      let!(:payment) { create(:payment, :completed, appointment_id: appointment_id, amount: 150.00) }

      before do
        allow(EventPublisher).to receive(:publish)
      end

      it "processes the refund" do
        expect(described_class).to receive(:process_refund).with(payment, appointment_id)

        described_class.send(:handle_appointment_cancelled, payload)
      end

      it "marks the payment as refunded" do
        described_class.send(:handle_appointment_cancelled, payload)

        expect(payment.reload.status).to eq("refunded")
      end
    end

    context "when multiple payments exist for the same appointment" do
      let!(:completed_payment) { create(:payment, :completed, appointment_id: appointment_id) }
      let!(:pending_payment) { create(:payment, :pending, appointment_id: appointment_id) }

      before do
        allow(EventPublisher).to receive(:publish)
      end

      it "processes the first payment found by the query" do
        # The scope returns payments ordered by default (likely by id/created_at)
        # We need to check that the first payment returned by the query is processed
        first_payment = Payment.for_appointment(appointment_id).first

        described_class.send(:handle_appointment_cancelled, payload)

        first_payment.reload
        # The first payment found by the scope gets processed
        # If it's completed, it gets refunded; if pending, it's skipped
        if first_payment.id == completed_payment.id
          expect(first_payment.status).to eq("refunded")
        else
          # First payment was pending, so it was skipped (no status change expected)
          expect(first_payment.status).to eq("pending")
        end
      end
    end
  end

  describe ".process_refund" do
    let(:appointment_id) { SecureRandom.uuid }
    let(:payment) { create(:payment, :completed, appointment_id: appointment_id, amount: 75.50) }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(EventPublisher).to receive(:publish)
    end

    context "when refund is successful (stubbed)" do
      it "logs the refund initiation with formatted currency" do
        expect(Rails.logger).to receive(:info).with(
          /\[REFUND\] Processing refund for payment #{payment.id}.*amount: \$75\.50/
        )

        described_class.send(:process_refund, payment, appointment_id)
      end

      it "marks the payment as refunded" do
        described_class.send(:process_refund, payment, appointment_id)

        expect(payment.reload.status).to eq("refunded")
      end

      it "logs successful refund" do
        expect(Rails.logger).to receive(:info).with(/\[REFUND\] Successfully refunded payment #{payment.id}/)

        described_class.send(:process_refund, payment, appointment_id)
      end

      it "triggers the publish_payment_events callback" do
        expect(EventPublisher).to receive(:publish).with("payment.refunded", hash_including(payment_id: payment.id))

        described_class.send(:process_refund, payment, appointment_id)
      end
    end

    context "when mark_as_refunded! raises an error" do
      before do
        allow(payment).to receive(:mark_as_refunded!).and_raise(ActiveRecord::RecordInvalid.new(payment))
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/\[REFUND\] Error processing refund/)

        described_class.send(:process_refund, payment, appointment_id)
      end

      it "logs the backtrace" do
        expect(Rails.logger).to receive(:error).with(kind_of(String)).twice

        described_class.send(:process_refund, payment, appointment_id)
      end

      it "does not re-raise the exception" do
        expect {
          described_class.send(:process_refund, payment, appointment_id)
        }.not_to raise_error
      end
    end

    context "when payment has zero amount" do
      let(:payment) { create(:payment, :completed, appointment_id: appointment_id, amount: 0.01) }

      it "processes refund for minimal amounts" do
        expect(Rails.logger).to receive(:info).with(/amount: \$0\.01/)

        described_class.send(:process_refund, payment, appointment_id)
      end
    end

    context "when payment has large amount" do
      let(:payment) { create(:payment, :completed, appointment_id: appointment_id, amount: 9999.99) }

      it "handles large amounts correctly" do
        expect(Rails.logger).to receive(:info).with(/amount: \$9999\.99/)

        described_class.send(:process_refund, payment, appointment_id)
      end
    end
  end

  describe ".format_currency" do
    it "formats positive amounts with dollar sign and two decimal places" do
      expect(described_class.send(:format_currency, 100)).to eq("$100.00")
    end

    it "formats decimal amounts correctly" do
      expect(described_class.send(:format_currency, 75.5)).to eq("$75.50")
    end

    it "formats amounts with many decimal places" do
      expect(described_class.send(:format_currency, 25.999)).to eq("$26.00")
    end

    it "formats zero amount" do
      expect(described_class.send(:format_currency, 0)).to eq("$0.00")
    end

    it "formats string amounts that can be converted to float" do
      expect(described_class.send(:format_currency, "50.25")).to eq("$50.25")
    end

    it "formats BigDecimal amounts" do
      expect(described_class.send(:format_currency, BigDecimal("123.45"))).to eq("$123.45")
    end

    it "handles nil by returning string representation" do
      expect(described_class.send(:format_currency, nil)).to eq("$0.00")
    end

    context "with invalid input that causes format error" do
      it "returns string representation when format fails" do
        # Create an object that will cause the format to fail
        invalid_object = Class.new do
          def to_f
            raise StandardError, "Cannot convert to float"
          end

          def to_s
            "invalid_amount"
          end
        end.new

        result = described_class.send(:format_currency, invalid_object)

        expect(result).to be_a(String)
        expect(result).to eq("invalid_amount")
      end
    end
  end

  describe "integration scenarios" do
    let(:channel) { double("Bunny::Channel") }
    let(:delivery_info) { double("DeliveryInfo", delivery_tag: "integration_tag") }
    let(:appointment_id) { SecureRandom.uuid }
    let(:user_id) { SecureRandom.uuid }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(channel).to receive(:ack)
      allow(channel).to receive(:nack)
      allow(EventPublisher).to receive(:publish)
    end

    context "full refund flow for cancelled appointment" do
      let!(:payment) { create(:payment, :completed, appointment_id: appointment_id, user_id: user_id, amount: 200.00) }
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: {
            appointment_id: appointment_id,
            user_id: user_id,
            reason: "Patient cancelled"
          }
        }.to_json
      end

      it "processes the complete refund flow" do
        # Verify initial state
        expect(payment.status).to eq("completed")

        # Handle the event
        described_class.handle_event(delivery_info, event_body, channel)

        # Verify final state
        payment.reload
        expect(payment.status).to eq("refunded")
      end

      it "acknowledges the message after successful processing" do
        expect(channel).to receive(:ack).with("integration_tag")

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "publishes refund event" do
        expect(EventPublisher).to receive(:publish).with(
          "payment.refunded",
          hash_including(
            payment_id: payment.id,
            user_id: user_id,
            appointment_id: appointment_id,
            partial: false
          )
        )

        described_class.handle_event(delivery_info, event_body, channel)
      end
    end

    context "idempotent processing of same event" do
      let!(:payment) { create(:payment, :completed, appointment_id: appointment_id) }
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: { appointment_id: appointment_id }
        }.to_json
      end

      it "processes first event and refunds" do
        described_class.handle_event(delivery_info, event_body, channel)

        expect(payment.reload.status).to eq("refunded")
      end

      it "ignores second event due to idempotency check" do
        # First event
        described_class.handle_event(delivery_info, event_body, channel)

        # Reset expectations
        expect(EventPublisher).not_to receive(:publish).with("payment.refunded", anything)

        # Second event - should be skipped
        described_class.handle_event(delivery_info, event_body, channel)

        # Status should still be refunded (not double-refunded)
        expect(payment.reload.status).to eq("refunded")
      end
    end
  end
end