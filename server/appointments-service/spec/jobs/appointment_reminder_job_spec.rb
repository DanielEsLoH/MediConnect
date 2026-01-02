# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppointmentReminderJob do
  describe "sidekiq_options" do
    it "retries 3 times" do
      expect(described_class.sidekiq_options["retry"]).to eq(3)
    end

    it "uses default queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:default)
    end
  end

  describe "#perform" do
    context "when appointment does not exist" do
      it "returns early without error" do
        expect { subject.perform(SecureRandom.uuid) }.not_to raise_error
      end

      it "does not publish event" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(SecureRandom.uuid)
      end
    end

    context "when appointment is not confirmed" do
      let!(:appointment) { create(:appointment, status: "pending") }

      it "returns early without sending reminder" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment is cancelled" do
      let!(:appointment) { create(:appointment, :cancelled) }

      it "returns early without sending reminder" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment is within 24 hour window" do
      let!(:appointment) do
        # Create appointment scheduled 24 hours from now
        current_time = Time.current
        apt = build(:appointment, :confirmed,
          appointment_date: Date.current + 1.day,
          start_time: current_time.strftime("%H:%M:%S"),
          end_time: (current_time + 30.minutes).strftime("%H:%M:%S"),
          duration_minutes: 30
        )
        # Ensure we're within the 23-25 hour window
        apt.save!
        apt
      end

      before do
        # Freeze time to make the appointment exactly 24 hours away
        allow(Time).to receive(:current).and_return(appointment.scheduled_datetime - 24.hours)
        allow(EventPublisher).to receive(:publish)
      end

      it "sends reminder event" do
        expect(EventPublisher).to receive(:publish).with(
          "appointment.reminder",
          hash_including(
            appointment_id: appointment.id,
            user_id: appointment.user_id,
            doctor_id: appointment.doctor_id
          )
        )

        subject.perform(appointment.id)
      end

      it "includes required fields in event" do
        expect(EventPublisher).to receive(:publish).with(
          "appointment.reminder",
          hash_including(
            :appointment_id,
            :user_id,
            :doctor_id,
            :scheduled_datetime,
            :consultation_type,
            :clinic_id,
            :timestamp
          )
        )

        subject.perform(appointment.id)
      end

      it "logs success" do
        expect(Rails.logger).to receive(:info).with(/Sent reminder for appointment/)

        subject.perform(appointment.id)
      end
    end

    context "when appointment is too far away (more than 25 hours)" do
      let!(:appointment) do
        create(:appointment, :confirmed,
          appointment_date: Date.current + 3.days,
          start_time: Time.parse("10:00:00")
        )
      end

      it "returns early without sending reminder" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment is too close (less than 23 hours)" do
      let!(:appointment) do
        # Create confirmed appointment in the past for testing
        apt = build(:appointment, :confirmed,
          appointment_date: Date.current,
          start_time: (Time.current + 1.hour).strftime("%H:%M:%S")
        )
        apt.save(validate: false)
        apt
      end

      it "returns early without sending reminder" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when EventPublisher raises an error" do
      let!(:appointment) do
        current_time = Time.current
        apt = build(:appointment, :confirmed,
          appointment_date: Date.current + 1.day,
          start_time: current_time.strftime("%H:%M:%S"),
          end_time: (current_time + 30.minutes).strftime("%H:%M:%S"),
          duration_minutes: 30
        )
        apt.save!
        apt
      end

      before do
        allow(Time).to receive(:current).and_return(appointment.scheduled_datetime - 24.hours)
        allow(EventPublisher).to receive(:publish).and_raise(StandardError.new("Publish failed"))
      end

      it "logs error and re-raises" do
        expect(Rails.logger).to receive(:error).with(/Failed to send reminder/)

        expect { subject.perform(appointment.id) }.to raise_error(StandardError, "Publish failed")
      end
    end
  end
end