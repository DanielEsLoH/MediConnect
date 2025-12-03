# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppointmentCancellationService do
  let(:appointment) { create(:appointment, :confirmed, :upcoming_appointment) }

  describe "#call" do
    context "with valid cancellation" do
      it "cancels appointment successfully" do
        service = described_class.new(appointment, cancelled_by: "patient", reason: "Personal reasons")
        result = service.call

        expect(result[:success]).to be true
        expect(appointment.reload.status).to eq("cancelled")
        expect(appointment.cancelled_by).to eq("patient")
        expect(appointment.cancellation_reason).to eq("Personal reasons")
      end

      it "returns success message" do
        service = described_class.new(appointment, cancelled_by: "patient")
        result = service.call

        expect(result[:message]).to eq("Appointment cancelled successfully")
      end
    end

    context "when cancelled by doctor" do
      it "cancels appointment" do
        service = described_class.new(appointment, cancelled_by: "doctor", reason: "Emergency")
        result = service.call

        expect(result[:success]).to be true
        expect(appointment.reload.cancelled_by).to eq("doctor")
      end
    end

    context "when cancelled by system" do
      it "cancels appointment" do
        service = described_class.new(appointment, cancelled_by: "system", reason: "Auto-cancelled")
        result = service.call

        expect(result[:success]).to be true
        expect(appointment.reload.cancelled_by).to eq("system")
      end
    end

    context "when appointment cannot be cancelled" do
      let(:completed_appointment) { create(:appointment, :completed) }

      it "returns error" do
        service = described_class.new(completed_appointment, cancelled_by: "patient")
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Appointment cannot be cancelled in its current status: completed")
      end
    end

    context "with invalid cancelled_by value" do
      it "returns error" do
        service = described_class.new(appointment, cancelled_by: "invalid")
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Invalid cancelled_by value. Must be one of: patient, doctor, system")
      end
    end

    context "when within 24-hour cancellation window" do
      let(:near_appointment) do
        create(:appointment,
               :confirmed,
               appointment_date: Date.current,
               start_time: (Time.current + 20.hours).strftime("%H:%M:%S"),
               end_time: (Time.current + 20.5.hours).strftime("%H:%M:%S"))
      end

      it "still cancels but returns warning" do
        service = described_class.new(near_appointment, cancelled_by: "patient")
        result = service.call

        expect(result[:success]).to be true
        expect(result[:warning]).to be_present
        expect(result[:warning]).to include("within 24 hours")
      end
    end

    context "when appointment is already cancelled" do
      let(:cancelled_appointment) { create(:appointment, :cancelled) }

      it "returns error" do
        service = described_class.new(cancelled_appointment, cancelled_by: "patient")
        result = service.call

        expect(result[:success]).to be false
      end
    end
  end
end
