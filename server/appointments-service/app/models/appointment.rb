# frozen_string_literal: true

class Appointment < ApplicationRecord
  # Enums
  enum :consultation_type, {
    in_person: "in_person",
    video: "video",
    phone: "phone"
  }, validate: true

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    in_progress: "in_progress",
    completed: "completed",
    cancelled: "cancelled",
    no_show: "no_show"
  }, validate: true

  enum :cancelled_by, {
    patient: "patient",
    doctor: "doctor",
    system: "system"
  }, prefix: :cancelled_by

  # Associations
  has_one :video_session, dependent: :destroy

  # Validations
  validates :user_id, presence: true
  validates :doctor_id, presence: true
  validates :clinic_id, presence: true
  validates :appointment_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than_or_equal_to: 15, less_than_or_equal_to: 120 }
  validates :consultation_type, presence: true
  validates :status, presence: true
  validates :consultation_fee, numericality: { greater_than: 0 }, allow_nil: true

  validate :appointment_date_cannot_be_in_past
  validate :start_time_before_end_time
  validate :validate_duration_matches_times
  validate :no_overlapping_appointments, on: :create

  # Callbacks
  before_validation :calculate_duration, if: -> { start_time.present? && end_time.present? }
  after_create :publish_appointment_created_event
  after_update :publish_appointment_updated_event, if: :saved_change_to_status?
  after_destroy :publish_appointment_deleted_event

  # Scopes
  scope :for_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :for_doctor, ->(doctor_id) { where(doctor_id: doctor_id) if doctor_id.present? }
  scope :for_clinic, ->(clinic_id) { where(clinic_id: clinic_id) if clinic_id.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_consultation_type, ->(type) { where(consultation_type: type) if type.present? }
  scope :upcoming, -> { where("appointment_date >= ?", Date.current).where.not(status: [:cancelled, :completed, :no_show]) }
  scope :past, -> { where("appointment_date < ?", Date.current).or(where(status: [:completed, :no_show])) }
  scope :on_date, ->(date) { where(appointment_date: date) if date.present? }
  scope :between_dates, lambda { |start_date, end_date|
    where(appointment_date: start_date..end_date) if start_date.present? && end_date.present?
  }
  scope :confirmed_or_completed, -> { where(status: [:confirmed, :in_progress, :completed]) }
  scope :cancellable, -> { where(status: [:pending, :confirmed]) }
  scope :expired_pending, -> { pending.where("created_at < ?", 30.minutes.ago) }
  scope :ordered_by_date, -> { order(appointment_date: :asc, start_time: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def scheduled_datetime
    return nil unless appointment_date.present? && start_time.present?

    Time.zone.local(
      appointment_date.year,
      appointment_date.month,
      appointment_date.day,
      start_time.hour,
      start_time.min,
      start_time.sec
    )
  end

  def end_datetime
    return nil unless appointment_date.present? && end_time.present?

    Time.zone.local(
      appointment_date.year,
      appointment_date.month,
      appointment_date.day,
      end_time.hour,
      end_time.min,
      end_time.sec
    )
  end

  def can_be_cancelled?
    cancellable_statuses = %w[pending confirmed]
    cancellable_statuses.include?(status)
  end

  def can_be_confirmed?
    status == "pending"
  end

  def can_be_completed?
    status == "in_progress" || (status == "confirmed" && scheduled_datetime <= Time.current)
  end

  def within_cancellation_window?
    return true unless scheduled_datetime

    hours_until_appointment = (scheduled_datetime - Time.current) / 3600
    hours_until_appointment >= 24
  end

  def confirm!
    return false unless can_be_confirmed?

    update(status: :confirmed, confirmed_at: Time.current)
  end

  def start!
    return false unless status == "confirmed"

    update(status: :in_progress)
  end

  def complete!(notes: nil, prescription: nil)
    return false unless can_be_completed?

    update(
      status: :completed,
      completed_at: Time.current,
      notes: notes,
      prescription: prescription
    )
  end

  def cancel!(cancelled_by:, reason: nil)
    return false unless can_be_cancelled?

    update(
      status: :cancelled,
      cancelled_at: Time.current,
      cancelled_by: cancelled_by,
      cancellation_reason: reason
    )
  end

  def mark_as_no_show!
    return false unless status == "confirmed" && scheduled_datetime < Time.current

    update(status: :no_show)
  end

  def as_json(options = {})
    super(options.merge(
      methods: [:scheduled_datetime, :end_datetime],
      except: [:metadata]
    ))
  end

  private

  def appointment_date_cannot_be_in_past
    return unless appointment_date.present?

    if appointment_date < Date.current
      errors.add(:appointment_date, "cannot be in the past")
    end
  end

  def start_time_before_end_time
    return unless start_time.present? && end_time.present?

    if start_time >= end_time
      errors.add(:start_time, "must be before end time")
    end
  end

  def calculate_duration
    return unless start_time.present? && end_time.present?

    start_datetime = Time.zone.parse(start_time.strftime("%H:%M:%S"))
    end_datetime = Time.zone.parse(end_time.strftime("%H:%M:%S"))
    self.duration_minutes = ((end_datetime - start_datetime) / 60).to_i
  end

  def validate_duration_matches_times
    return unless start_time.present? && end_time.present? && duration_minutes.present?

    calculated_duration = ((Time.zone.parse(end_time.strftime("%H:%M:%S")) -
                           Time.zone.parse(start_time.strftime("%H:%M:%S"))) / 60).to_i

    if calculated_duration != duration_minutes
      errors.add(:duration_minutes, "does not match start and end times")
    end
  end

  def no_overlapping_appointments
    return unless doctor_id.present? && appointment_date.present? &&
                  start_time.present? && end_time.present?

    overlapping = Appointment.where(doctor_id: doctor_id)
                             .where(appointment_date: appointment_date)
                             .where.not(status: [:cancelled, :no_show])
                             .where.not(id: id)
                             .where("(start_time::time, end_time::time) OVERLAPS (?::time, ?::time)", start_time, end_time)

    if overlapping.exists?
      errors.add(:base, "Doctor has an overlapping appointment at this time")
    end
  end

  def publish_appointment_created_event
    EventPublisher.publish("appointment.created", {
      appointment_id: id,
      user_id: user_id,
      doctor_id: doctor_id,
      clinic_id: clinic_id,
      scheduled_datetime: scheduled_datetime.iso8601,
      consultation_type: consultation_type,
      status: status,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish appointment.created event: #{e.message}")
  end

  def publish_appointment_updated_event
    event_type = case status
                 when "confirmed"
                   "appointment.confirmed"
                 when "cancelled"
                   "appointment.cancelled"
                 when "completed"
                   "appointment.completed"
                 when "no_show"
                   "appointment.no_show"
                 else
                   "appointment.updated"
                 end

    EventPublisher.publish(event_type, {
      appointment_id: id,
      user_id: user_id,
      doctor_id: doctor_id,
      status: status,
      cancelled_by: cancelled_by,
      cancellation_reason: cancellation_reason,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish #{event_type} event: #{e.message}")
  end

  def publish_appointment_deleted_event
    EventPublisher.publish("appointment.deleted", {
      appointment_id: id,
      user_id: user_id,
      doctor_id: doctor_id,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish appointment.deleted event: #{e.message}")
  end
end
