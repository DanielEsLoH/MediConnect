# frozen_string_literal: true

class AvailabilityService
  def initialize(doctor)
    @doctor = doctor
  end

  def available_slots(date)
    day_of_week = date.wday
    schedules = @doctor.schedules.active_schedules.for_day(day_of_week)

    schedules.flat_map do |schedule|
      generate_time_slots(date, schedule)
    end.compact
  end

  def available_on_date?(date)
    available_slots(date).any?
  end

  def next_available_date(from_date = Date.today, limit_days = 30)
    (from_date..from_date + limit_days.days).find do |date|
      available_on_date?(date)
    end
  end

  private

  def generate_time_slots(date, schedule)
    slots = []
    current_time = combine_date_and_time(date, schedule.start_time)
    end_time = combine_date_and_time(date, schedule.end_time)

    while current_time < end_time
      slots << {
        start_time: current_time,
        end_time: current_time + schedule.slot_duration_minutes.minutes,
        duration_minutes: schedule.slot_duration_minutes
      }
      current_time += schedule.slot_duration_minutes.minutes
    end

    slots
  end

  def combine_date_and_time(date, time)
    Time.zone.local(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.min,
      time.sec
    )
  end
end
