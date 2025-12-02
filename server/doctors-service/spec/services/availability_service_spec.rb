# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvailabilityService do
  let(:doctor) { create(:doctor) }
  let(:service) { described_class.new(doctor) }

  describe "#available_slots" do
    context "when doctor has schedules" do
      let!(:schedule) do
        create(:schedule,
               doctor: doctor,
               day_of_week: Date.today.wday,
               start_time: Time.zone.parse("09:00"),
               end_time: Time.zone.parse("11:00"),
               slot_duration_minutes: 30)
      end

      it "returns available time slots for the date" do
        slots = service.available_slots(Date.today)

        expect(slots).not_to be_empty
        expect(slots.first).to have_key(:start_time)
        expect(slots.first).to have_key(:end_time)
        expect(slots.first).to have_key(:duration_minutes)
      end

      it "generates correct number of slots" do
        slots = service.available_slots(Date.today)
        # 2 hours / 30 minutes = 4 slots
        expect(slots.size).to eq(4)
      end
    end

    context "when doctor has no schedules for the date" do
      it "returns empty array" do
        slots = service.available_slots(Date.today)
        expect(slots).to be_empty
      end
    end
  end

  describe "#available_on_date?" do
    it "returns true when slots are available" do
      create(:schedule, doctor: doctor, day_of_week: Date.today.wday)
      expect(service.available_on_date?(Date.today)).to be true
    end

    it "returns false when no slots are available" do
      expect(service.available_on_date?(Date.today)).to be false
    end
  end

  describe "#next_available_date" do
    it "finds the next available date" do
      tomorrow = Date.tomorrow
      create(:schedule, doctor: doctor, day_of_week: tomorrow.wday)

      next_date = service.next_available_date(Date.today)
      expect(next_date).to eq(tomorrow)
    end

    it "returns nil if no available dates within limit" do
      next_date = service.next_available_date(Date.today, limit_days: 7)
      expect(next_date).to be_nil
    end
  end
end
