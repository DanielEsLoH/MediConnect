# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appointment, type: :model do
  describe "associations" do
    it { should have_one(:video_session).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:appointment) }

    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:doctor_id) }
    it { should validate_presence_of(:clinic_id) }
    it { should validate_presence_of(:appointment_date) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }
    # Note: duration_minutes is auto-calculated by calculate_duration callback
    # so we can't use shoulda-matchers for presence/numericality validations
    # Testing manually instead
    it { should validate_presence_of(:consultation_type) }
    it { should validate_presence_of(:status) }

    describe "duration_minutes validations" do
      it "is invalid when duration is less than 15 minutes" do
        # Create appointment with 10-minute duration
        appointment = build(:appointment, start_time: "10:00", end_time: "10:10")
        expect(appointment).not_to be_valid
        expect(appointment.errors[:duration_minutes]).to include("must be greater than or equal to 15")
      end

      it "is invalid when duration is more than 120 minutes" do
        # Create appointment with 150-minute duration
        appointment = build(:appointment, start_time: "10:00", end_time: "12:30")
        expect(appointment).not_to be_valid
        expect(appointment.errors[:duration_minutes]).to include("must be less than or equal to 120")
      end

      it "is valid with 30 minute duration" do
        appointment = build(:appointment, start_time: "10:00", end_time: "10:30")
        expect(appointment).to be_valid
      end

      it "is valid with exactly 15 minute duration" do
        appointment = build(:appointment, start_time: "10:00", end_time: "10:15")
        expect(appointment).to be_valid
      end

      it "is valid with exactly 120 minute duration" do
        appointment = build(:appointment, start_time: "10:00", end_time: "12:00")
        expect(appointment).to be_valid
      end
    end

    describe "appointment_date_cannot_be_in_past" do
      it "is invalid with a past date" do
        appointment = build(:appointment, appointment_date: 1.day.ago.to_date)
        expect(appointment).not_to be_valid
        expect(appointment.errors[:appointment_date]).to include("cannot be in the past")
      end

      it "is valid with today's date" do
        appointment = build(:appointment, appointment_date: Date.current)
        expect(appointment).to be_valid
      end

      it "is valid with a future date" do
        appointment = build(:appointment, appointment_date: 1.day.from_now.to_date)
        expect(appointment).to be_valid
      end
    end

    describe "start_time_before_end_time" do
      it "is invalid when start_time is after end_time" do
        appointment = build(:appointment, start_time: Time.parse("14:00"), end_time: Time.parse("13:00"))
        expect(appointment).not_to be_valid
        expect(appointment.errors[:start_time]).to include("must be before end time")
      end

      it "is invalid when start_time equals end_time" do
        appointment = build(:appointment, start_time: Time.parse("14:00"), end_time: Time.parse("14:00"))
        expect(appointment).not_to be_valid
      end

      it "is valid when start_time is before end_time" do
        appointment = build(:appointment, start_time: Time.parse("13:00"), end_time: Time.parse("14:00"))
        expect(appointment).to be_valid
      end
    end

    describe "no_overlapping_appointments" do
      let(:doctor_id) { SecureRandom.uuid }
      let(:appointment_date) { 1.week.from_now.to_date }

      before do
        create(:appointment,
               doctor_id: doctor_id,
               appointment_date: appointment_date,
               start_time: Time.parse("10:00"),
               end_time: Time.parse("11:00"),
               status: "confirmed")
      end

      it "is invalid when appointment overlaps" do
        overlapping_appointment = build(:appointment,
                                       doctor_id: doctor_id,
                                       appointment_date: appointment_date,
                                       start_time: Time.parse("10:30"),
                                       end_time: Time.parse("11:30"))
        expect(overlapping_appointment).not_to be_valid
        expect(overlapping_appointment.errors[:base]).to include("Doctor has an overlapping appointment at this time")
      end

      it "is valid when appointment is immediately after" do
        next_appointment = build(:appointment,
                                doctor_id: doctor_id,
                                appointment_date: appointment_date,
                                start_time: Time.parse("11:00"),
                                end_time: Time.parse("12:00"))
        expect(next_appointment).to be_valid
      end

      it "is valid when appointment is on a different date" do
        different_date_appointment = build(:appointment,
                                          doctor_id: doctor_id,
                                          appointment_date: appointment_date + 1.day,
                                          start_time: Time.parse("10:00"),
                                          end_time: Time.parse("11:00"))
        expect(different_date_appointment).to be_valid
      end

      it "is valid when overlapping appointment is cancelled" do
        # The existing confirmed appointment is already at 10:00-11:00 from the before block
        # Cancel that appointment, then create a new one that would have overlapped
        existing = Appointment.find_by(doctor_id: doctor_id, appointment_date: appointment_date)
        existing.update!(status: "cancelled", cancelled_at: Time.current, cancelled_by: "patient")

        # Now a new appointment in the same slot should be valid
        new_appointment = build(:appointment,
                               doctor_id: doctor_id,
                               appointment_date: appointment_date,
                               start_time: Time.parse("10:00"),
                               end_time: Time.parse("11:00"))
        expect(new_appointment).to be_valid
      end
    end
  end

  describe "enums" do
    it "defines consultation_type enum" do
      expect(Appointment.consultation_types.keys).to contain_exactly("in_person", "video", "phone")
    end

    it "defines status enum" do
      expect(Appointment.statuses.keys).to contain_exactly("pending", "confirmed", "in_progress", "completed", "cancelled", "no_show")
    end

    it "defines cancelled_by enum" do
      expect(Appointment.cancelled_bies.keys).to contain_exactly("patient", "doctor", "system")
    end
  end

  describe "scopes" do
    let!(:user_id) { SecureRandom.uuid }
    let!(:doctor_id) { SecureRandom.uuid }
    let!(:pending_appointment) { create(:appointment, user_id: user_id, status: "pending") }
    let!(:confirmed_appointment) { create(:appointment, :confirmed, doctor_id: doctor_id) }
    let!(:cancelled_appointment) { create(:appointment, :cancelled) }
    let!(:past_appointment) { create(:appointment, :past_appointment, :completed) }
    let!(:upcoming_appointment) { create(:appointment, :upcoming_appointment) }

    describe ".for_user" do
      it "returns appointments for specific user" do
        expect(Appointment.for_user(user_id)).to include(pending_appointment)
        expect(Appointment.for_user(user_id)).not_to include(confirmed_appointment)
      end
    end

    describe ".for_doctor" do
      it "returns appointments for specific doctor" do
        expect(Appointment.for_doctor(doctor_id)).to include(confirmed_appointment)
        expect(Appointment.for_doctor(doctor_id)).not_to include(pending_appointment)
      end
    end

    describe ".by_status" do
      it "returns appointments with specific status" do
        expect(Appointment.by_status("pending")).to include(pending_appointment)
        expect(Appointment.by_status("pending")).not_to include(confirmed_appointment)
      end
    end

    describe ".upcoming" do
      it "returns only upcoming non-cancelled appointments" do
        expect(Appointment.upcoming).to include(upcoming_appointment)
        expect(Appointment.upcoming).not_to include(past_appointment, cancelled_appointment)
      end
    end

    describe ".past" do
      it "returns past or completed appointments" do
        expect(Appointment.past).to include(past_appointment)
      end
    end

    describe ".expired_pending" do
      let!(:expired_pending) { create(:appointment, :expired_pending) }

      it "returns pending appointments created more than 30 minutes ago" do
        expect(Appointment.expired_pending).to include(expired_pending)
        expect(Appointment.expired_pending).not_to include(pending_appointment)
      end
    end
  end

  describe "callbacks" do
    describe "calculate_duration" do
      it "automatically calculates duration from start and end times" do
        appointment = create(:appointment,
                            start_time: Time.parse("10:00"),
                            end_time: Time.parse("11:30"))
        expect(appointment.duration_minutes).to eq(90)
      end
    end
  end

  describe "#scheduled_datetime" do
    let(:future_date) { 10.days.from_now.to_date }
    let(:appointment) do
      create(:appointment,
             appointment_date: future_date,
             start_time: "10:30:00",
             end_time: "11:00:00")
    end

    it "returns combined date and time" do
      scheduled = appointment.scheduled_datetime
      expect(scheduled.to_date).to eq(future_date)
      # Check that the time matches the start_time from the model
      expect(scheduled.hour).to eq(appointment.start_time.hour)
      expect(scheduled.min).to eq(appointment.start_time.min)
    end

    it "returns nil when appointment_date is nil" do
      appointment = build(:appointment, appointment_date: nil)
      expect(appointment.scheduled_datetime).to be_nil
    end

    it "returns nil when start_time is nil" do
      appointment = build(:appointment, start_time: nil)
      expect(appointment.scheduled_datetime).to be_nil
    end
  end

  describe "#can_be_cancelled?" do
    it "returns true for pending appointments" do
      appointment = create(:appointment, status: "pending")
      expect(appointment.can_be_cancelled?).to be true
    end

    it "returns true for confirmed appointments" do
      appointment = create(:appointment, :confirmed)
      expect(appointment.can_be_cancelled?).to be true
    end

    it "returns false for completed appointments" do
      appointment = create(:appointment, :completed)
      expect(appointment.can_be_cancelled?).to be false
    end

    it "returns false for cancelled appointments" do
      appointment = create(:appointment, :cancelled)
      expect(appointment.can_be_cancelled?).to be false
    end
  end

  describe "#confirm!" do
    it "confirms a pending appointment" do
      appointment = create(:appointment, status: "pending")
      expect(appointment.confirm!).to be true
      expect(appointment.reload.status).to eq("confirmed")
      expect(appointment.confirmed_at).to be_present
    end

    it "fails to confirm non-pending appointment" do
      appointment = create(:appointment, :completed)
      expect(appointment.confirm!).to be false
    end
  end

  describe "#cancel!" do
    it "cancels a pending appointment" do
      appointment = create(:appointment, status: "pending")
      result = appointment.cancel!(cancelled_by: "patient", reason: "Change of plans")

      expect(result).to be true
      expect(appointment.reload.status).to eq("cancelled")
      expect(appointment.cancelled_by).to eq("patient")
      expect(appointment.cancellation_reason).to eq("Change of plans")
      expect(appointment.cancelled_at).to be_present
    end

    it "fails to cancel completed appointment" do
      appointment = create(:appointment, :completed)
      expect(appointment.cancel!(cancelled_by: "patient")).to be false
    end
  end

  describe "#complete!" do
    it "completes an in_progress appointment with notes" do
      appointment = create(:appointment, :in_progress)
      result = appointment.complete!(
        notes: "Patient responded well to treatment",
        prescription: "Amoxicillin 500mg"
      )

      expect(result).to be true
      expect(appointment.reload.status).to eq("completed")
      expect(appointment.notes).to eq("Patient responded well to treatment")
      expect(appointment.prescription).to eq("Amoxicillin 500mg")
      expect(appointment.completed_at).to be_present
    end

    it "fails to complete pending appointment" do
      appointment = create(:appointment, status: "pending")
      expect(appointment.complete!).to be false
    end
  end

  describe "#within_cancellation_window?" do
    it "returns true when appointment is more than 24 hours away" do
      appointment = create(:appointment,
                          appointment_date: 2.days.from_now.to_date,
                          start_time: Time.parse("10:00"))
      expect(appointment.within_cancellation_window?).to be true
    end

    it "returns false when appointment is less than 24 hours away" do
      # Create an appointment for tomorrow at a time that's less than 24 hours from now
      # Use tomorrow's date with early morning time to ensure it's within 24 hours
      tomorrow = 1.day.from_now.to_date
      # Calculate a time that would be 12 hours from now
      target_time = (Time.current + 12.hours)
      appointment_time = target_time.strftime("%H:%M:%S")

      # We need to use the correct date based on whether the target time crosses midnight
      appointment_date = target_time.to_date

      appointment = build(:appointment,
                         appointment_date: appointment_date,
                         start_time: appointment_time)
      # Skip validation to allow creating appointment potentially for today
      appointment.save(validate: false)

      expect(appointment.within_cancellation_window?).to be false
    end
  end
end
