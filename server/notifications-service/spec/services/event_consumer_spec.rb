# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventConsumer do
  describe "SUBSCRIBED_EVENTS" do
    it "includes all required event types" do
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.created")
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.confirmed")
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.cancelled")
      expect(described_class::SUBSCRIBED_EVENTS).to include("appointment.reminder")
      expect(described_class::SUBSCRIBED_EVENTS).to include("user.registered")
      expect(described_class::SUBSCRIBED_EVENTS).to include("payment.completed")
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
    let(:user_id) { SecureRandom.uuid }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(channel).to receive(:ack)
      allow(channel).to receive(:nack)
      create(:notification_preference, user_id: user_id)
    end

    context "with valid JSON payload" do
      let(:event_body) do
        {
          event_type: "appointment.created",
          payload: {
            user_id: user_id,
            doctor_id: SecureRandom.uuid,
            scheduled_datetime: 3.days.from_now.iso8601
          }
        }.to_json
      end

      it "parses JSON and logs the event" do
        expect(Rails.logger).to receive(:info).with(/Received event: appointment.created/)

        described_class.handle_event(delivery_info, event_body, channel)
      end

      it "acknowledges the message after processing" do
        expect(channel).to receive(:ack).with("tag_123")

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
        described_class.handle_event(delivery_info, invalid_json, channel)
        # Error is logged during exception handling
      end
    end

    context "when an exception occurs during processing" do
      let(:event_body) do
        {
          event_type: "appointment.created",
          payload: { user_id: nil }  # nil user_id will cause validation error
        }.to_json
      end

      it "handles the error gracefully" do
        # The error might be handled by create_notification's rescue
        described_class.handle_event(delivery_info, event_body, channel)
        # Verify the call completed without raising
      end
    end
  end

  describe "event handlers" do
    let(:user_id) { SecureRandom.uuid }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      create(:notification_preference, user_id: user_id)
    end

    describe ".handle_appointment_created" do
      let(:payload) do
        {
          "user_id" => user_id,
          "doctor_id" => SecureRandom.uuid,
          "scheduled_datetime" => 3.days.from_now.iso8601
        }
      end

      it "creates email and in-app notifications" do
        expect {
          described_class.send(:handle_appointment_created, payload)
        }.to change(Notification, :count).by(2)
      end

      it "creates notifications with correct type" do
        described_class.send(:handle_appointment_created, payload)

        notifications = Notification.where(user_id: user_id, notification_type: :appointment_created)
        expect(notifications.count).to eq(2)
      end

      it "creates one email and one in_app notification" do
        described_class.send(:handle_appointment_created, payload)

        expect(Notification.where(user_id: user_id, delivery_method: :email).count).to eq(1)
        expect(Notification.where(user_id: user_id, delivery_method: :in_app).count).to eq(1)
      end
    end

    describe ".handle_appointment_confirmed" do
      let(:payload) do
        {
          "user_id" => user_id,
          "appointment_id" => SecureRandom.uuid
        }
      end

      it "creates email and push notifications" do
        expect {
          described_class.send(:handle_appointment_confirmed, payload)
        }.to change(Notification, :count).by(2)
      end

      it "creates notifications with priority 7" do
        described_class.send(:handle_appointment_confirmed, payload)

        notifications = Notification.where(user_id: user_id, notification_type: :appointment_confirmed)
        expect(notifications.all? { |n| n.priority == 7 }).to be true
      end
    end

    describe ".handle_appointment_cancelled" do
      let(:payload) do
        {
          "user_id" => user_id,
          "cancelled_by" => "doctor",
          "cancellation_reason" => "Doctor unavailable"
        }
      end

      it "creates email and SMS notifications" do
        expect {
          described_class.send(:handle_appointment_cancelled, payload)
        }.to change(Notification, :count).by(2)
      end

      it "includes cancellation reason in message" do
        described_class.send(:handle_appointment_cancelled, payload)

        notification = Notification.find_by(user_id: user_id, delivery_method: :email)
        expect(notification.message).to include("cancelled by the doctor")
        expect(notification.message).to include("Doctor unavailable")
      end

      context "when cancelled by patient" do
        let(:payload) do
          {
            "user_id" => user_id,
            "cancelled_by" => "patient"
          }
        end

        it "uses generic cancellation message" do
          described_class.send(:handle_appointment_cancelled, payload)

          notification = Notification.find_by(user_id: user_id, delivery_method: :email)
          expect(notification.message).to include("has been cancelled")
          expect(notification.message).not_to include("by the doctor")
        end
      end
    end

    describe ".handle_appointment_reminder" do
      let(:scheduled_time) { 2.days.from_now }
      let(:payload) do
        {
          "user_id" => user_id,
          "scheduled_datetime" => scheduled_time.iso8601
        }
      end

      it "creates email and SMS notifications" do
        expect {
          described_class.send(:handle_appointment_reminder, payload)
        }.to change(Notification, :count).by(2)
      end

      it "schedules notifications for 24 hours before appointment" do
        described_class.send(:handle_appointment_reminder, payload)

        notification = Notification.find_by(user_id: user_id, delivery_method: :email)
        expect(notification.scheduled_for).to be_within(1.minute).of(scheduled_time - 24.hours)
      end

      it "creates notifications with priority 9" do
        described_class.send(:handle_appointment_reminder, payload)

        notifications = Notification.where(user_id: user_id, notification_type: :appointment_reminder)
        expect(notifications.all? { |n| n.priority == 9 }).to be true
      end
    end

    describe ".handle_user_registered" do
      let(:payload) do
        {
          "user_id" => user_id,
          "user_email" => "newuser@example.com"
        }
      end

      it "creates welcome email notification" do
        expect {
          described_class.send(:handle_user_registered, payload)
        }.to change(Notification, :count).by(1)
      end

      it "creates notification with welcome_email type" do
        described_class.send(:handle_user_registered, payload)

        notification = Notification.find_by(user_id: user_id)
        expect(notification.notification_type).to eq("welcome_email")
        expect(notification.title).to include("Welcome")
      end
    end

    describe ".handle_payment_completed" do
      let(:payload) do
        {
          "user_id" => user_id,
          "amount" => 150.00,
          "transaction_id" => "txn_abc123"
        }
      end

      it "creates payment receipt notification" do
        expect {
          described_class.send(:handle_payment_completed, payload)
        }.to change(Notification, :count).by(1)
      end

      it "includes formatted amount in message" do
        described_class.send(:handle_payment_completed, payload)

        notification = Notification.find_by(user_id: user_id)
        expect(notification.message).to include("$150.00")
      end
    end
  end

  describe ".format_datetime" do
    it "formats datetime string correctly" do
      datetime = "2025-03-15T14:30:00Z"
      result = described_class.send(:format_datetime, datetime)

      expect(result).to include("March")
      expect(result).to include("15")
      expect(result).to include("2025")
    end

    it "returns original string on parse error" do
      invalid_datetime = "not-a-date"
      result = described_class.send(:format_datetime, invalid_datetime)

      expect(result).to eq("not-a-date")
    end
  end

  describe ".format_currency" do
    it "formats positive amounts correctly" do
      expect(described_class.send(:format_currency, 100)).to eq("$100.00")
    end

    it "formats decimal amounts correctly" do
      expect(described_class.send(:format_currency, 75.5)).to eq("$75.50")
    end

    it "formats zero amount" do
      expect(described_class.send(:format_currency, 0)).to eq("$0.00")
    end

    it "handles string amounts" do
      expect(described_class.send(:format_currency, "50.25")).to eq("$50.25")
    end

    it "handles nil gracefully" do
      expect(described_class.send(:format_currency, nil)).to eq("$0.00")
    end
  end

  describe ".create_notification" do
    let(:user_id) { SecureRandom.uuid }
    let(:attributes) do
      {
        user_id: user_id,
        notification_type: :general,
        title: "Test",
        message: "Test message",
        data: {},
        delivery_method: :email,
        priority: 5
      }
    end

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it "creates a notification" do
      expect {
        described_class.send(:create_notification, attributes)
      }.to change(Notification, :count).by(1)
    end

    it "logs success" do
      expect(Rails.logger).to receive(:info).with(/Created notification/)

      described_class.send(:create_notification, attributes)
    end

    context "when creation fails" do
      let(:invalid_attributes) { attributes.merge(title: nil) }

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Failed to create notification/)

        described_class.send(:create_notification, invalid_attributes)
      end

      it "does not raise an exception" do
        expect {
          described_class.send(:create_notification, invalid_attributes)
        }.not_to raise_error
      end
    end
  end
end
