# frozen_string_literal: true

class Schedule < ApplicationRecord
  # Associations
  belongs_to :doctor

  # Enums
  enum :day_of_week, {
    sunday: 0,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6
  }

  # Validations
  validates :doctor, presence: true
  validates :day_of_week, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :slot_duration_minutes, presence: true, numericality: { greater_than: 0 }
  validate :end_time_after_start_time

  # Scopes
  scope :active_schedules, -> { where(active: true) }
  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :for_doctor, ->(doctor_id) { where(doctor_id: doctor_id) }

  # Instance methods
  def duration_hours
    ((end_time - start_time) / 3600).round(2)
  end

  def total_slots
    (duration_hours * 60 / slot_duration_minutes).floor
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
