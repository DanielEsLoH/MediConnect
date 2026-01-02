# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppointmentFollowUpJob do
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

    context "when appointment is not completed" do
      let!(:appointment) { create(:appointment, :confirmed) }

      it "returns early without sending follow-up" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment is pending" do
      let!(:appointment) { create(:appointment, status: "pending") }

      it "returns early without sending follow-up" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment has no completed_at timestamp" do
      let!(:appointment) do
        apt = create(:appointment, status: "completed")
        apt.update_column(:completed_at, nil)
        apt
      end

      it "returns early without sending follow-up" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment was completed within 24-48 hour window" do
      let!(:appointment) do
        apt = create(:appointment, :completed)
        apt.update_column(:completed_at, 30.hours.ago)
        apt
      end

      before do
        allow(EventPublisher).to receive(:publish)
      end

      it "sends follow-up event" do
        expect(EventPublisher).to receive(:publish).with(
          "appointment.follow_up",
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
          "appointment.follow_up",
          hash_including(
            :appointment_id,
            :user_id,
            :doctor_id,
            :completed_at,
            :has_prescription,
            :timestamp
          )
        )

        subject.perform(appointment.id)
      end

      it "logs success" do
        expect(Rails.logger).to receive(:info).with(/Sent follow-up for appointment/)

        subject.perform(appointment.id)
      end
    end

    context "when appointment has prescription" do
      let!(:appointment) do
        apt = create(:appointment, :completed, :with_prescription)
        apt.update_column(:completed_at, 30.hours.ago)
        apt
      end

      before do
        allow(EventPublisher).to receive(:publish)
      end

      it "sets has_prescription to true in event" do
        expect(EventPublisher).to receive(:publish).with(
          "appointment.follow_up",
          hash_including(has_prescription: true)
        )

        subject.perform(appointment.id)
      end
    end

    context "when appointment has no prescription" do
      let!(:appointment) do
        apt = create(:appointment, :completed)
        apt.update_columns(completed_at: 30.hours.ago, prescription: nil)
        apt
      end

      before do
        allow(EventPublisher).to receive(:publish)
      end

      it "sets has_prescription to false in event" do
        expect(EventPublisher).to receive(:publish).with(
          "appointment.follow_up",
          hash_including(has_prescription: false)
        )

        subject.perform(appointment.id)
      end
    end

    context "when appointment was completed too recently (less than 24 hours)" do
      let!(:appointment) do
        apt = create(:appointment, :completed)
        apt.update_column(:completed_at, 12.hours.ago)
        apt
      end

      it "returns early without sending follow-up" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when appointment was completed too long ago (more than 48 hours)" do
      let!(:appointment) do
        apt = create(:appointment, :completed)
        apt.update_column(:completed_at, 60.hours.ago)
        apt
      end

      it "returns early without sending follow-up" do
        expect(EventPublisher).not_to receive(:publish)

        subject.perform(appointment.id)
      end
    end

    context "when EventPublisher raises an error" do
      let!(:appointment) do
        apt = create(:appointment, :completed)
        apt.update_column(:completed_at, 30.hours.ago)
        apt
      end

      before do
        allow(EventPublisher).to receive(:publish).and_raise(StandardError.new("Publish failed"))
      end

      it "logs error and re-raises" do
        expect(Rails.logger).to receive(:error).with(/Failed to send follow-up/)

        expect { subject.perform(appointment.id) }.to raise_error(StandardError, "Publish failed")
      end
    end
  end
end