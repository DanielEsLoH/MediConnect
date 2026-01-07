# frozen_string_literal: true

require "rails_helper"

RSpec.describe Schedule, type: :model do
  describe "associations" do
    it { should belong_to(:doctor) }
  end

  describe "validations" do
    subject { build(:schedule) }

    it { should validate_presence_of(:doctor) }
    it { should validate_presence_of(:day_of_week) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }
    it { should validate_presence_of(:slot_duration_minutes) }
    it { should validate_numericality_of(:slot_duration_minutes).is_greater_than(0) }

    describe "end_time_after_start_time validation" do
      it "is valid when end_time is after start_time" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("17:00")
        )
        expect(schedule).to be_valid
      end

      it "is invalid when end_time equals start_time" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("09:00")
        )
        expect(schedule).not_to be_valid
        expect(schedule.errors[:end_time]).to include("must be after start time")
      end

      it "is invalid when end_time is before start_time" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("17:00"),
          end_time: Time.zone.parse("09:00")
        )
        expect(schedule).not_to be_valid
        expect(schedule.errors[:end_time]).to include("must be after start time")
      end

      it "skips validation when start_time is nil" do
        schedule = build(:schedule, start_time: nil, end_time: Time.zone.parse("17:00"))
        schedule.valid?
        expect(schedule.errors[:end_time]).not_to include("must be after start time")
      end

      it "skips validation when end_time is nil" do
        schedule = build(:schedule, start_time: Time.zone.parse("09:00"), end_time: nil)
        schedule.valid?
        expect(schedule.errors[:end_time]).not_to include("must be after start time")
      end
    end
  end

  describe "enums" do
    describe "day_of_week" do
      it "defines all days of the week" do
        expect(Schedule.day_of_weeks).to eq({
          "sunday" => 0,
          "monday" => 1,
          "tuesday" => 2,
          "wednesday" => 3,
          "thursday" => 4,
          "friday" => 5,
          "saturday" => 6
        })
      end

      it "allows setting day_of_week by name" do
        schedule = build(:schedule, day_of_week: :monday)
        expect(schedule.monday?).to be true
        expect(schedule.day_of_week).to eq("monday")
      end

      it "allows setting day_of_week by integer" do
        schedule = build(:schedule, day_of_week: 0)
        expect(schedule.sunday?).to be true
      end
    end
  end

  describe "scopes" do
    describe ".active_schedules" do
      it "returns only active schedules" do
        active = create(:schedule, active: true)
        create(:schedule, :inactive)

        expect(Schedule.active_schedules).to eq([ active ])
      end
    end

    describe ".for_day" do
      let!(:monday_schedule) { create(:schedule, day_of_week: :monday) }
      let!(:tuesday_schedule) { create(:schedule, day_of_week: :tuesday) }

      it "filters by day of week" do
        expect(Schedule.for_day(:monday)).to eq([ monday_schedule ])
        expect(Schedule.for_day(1)).to eq([ monday_schedule ])
      end
    end

    describe ".for_doctor" do
      let(:doctor1) { create(:doctor) }
      let(:doctor2) { create(:doctor) }
      let!(:schedule1) { create(:schedule, doctor: doctor1) }
      let!(:schedule2) { create(:schedule, doctor: doctor2) }

      it "filters by doctor" do
        expect(Schedule.for_doctor(doctor1.id)).to eq([ schedule1 ])
      end
    end
  end

  describe "instance methods" do
    describe "#duration_hours" do
      it "calculates correct duration" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("17:00")
        )

        expect(schedule.duration_hours).to eq(8.0)
      end

      it "handles fractional hours" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:30")
        )

        expect(schedule.duration_hours).to eq(1.5)
      end
    end

    describe "#total_slots" do
      it "calculates total slots for 30-minute duration" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("11:00"),
          slot_duration_minutes: 30
        )

        expect(schedule.total_slots).to eq(4)
      end

      it "calculates total slots for 15-minute duration" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("10:00"),
          slot_duration_minutes: 15
        )

        expect(schedule.total_slots).to eq(4)
      end

      it "floors when duration does not divide evenly" do
        schedule = build(:schedule,
          start_time: Time.zone.parse("09:00"),
          end_time: Time.zone.parse("09:45"),
          slot_duration_minutes: 30
        )

        # 45 minutes / 30 = 1.5, floored to 1
        expect(schedule.total_slots).to eq(1)
      end
    end
  end

  describe "factory" do
    it "has valid factory" do
      expect(build(:schedule)).to be_valid
    end

    it "has valid inactive trait" do
      schedule = build(:schedule, :inactive)
      expect(schedule).to be_valid
      expect(schedule.active).to be false
    end

    it "has valid morning trait" do
      schedule = build(:schedule, :morning)
      expect(schedule).to be_valid
      expect(schedule.start_time.strftime("%H:%M")).to eq("08:00")
      expect(schedule.end_time.strftime("%H:%M")).to eq("12:00")
    end

    it "has valid afternoon trait" do
      schedule = build(:schedule, :afternoon)
      expect(schedule).to be_valid
      expect(schedule.start_time.strftime("%H:%M")).to eq("13:00")
      expect(schedule.end_time.strftime("%H:%M")).to eq("17:00")
    end
  end
end
