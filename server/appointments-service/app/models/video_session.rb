# frozen_string_literal: true

class VideoSession < ApplicationRecord
  # Enums
  enum :status, {
    created: "created",
    active: "active",
    ended: "ended",
    failed: "failed"
  }, validate: true

  # Associations
  belongs_to :appointment

  # Validations
  validates :appointment_id, presence: true, uniqueness: true
  validates :room_name, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :status, presence: true

  # Callbacks
  before_validation :generate_room_name, on: :create, unless: :room_name?
  before_validation :generate_session_url, on: :create, unless: :session_url?

  # Scopes
  scope :active_sessions, -> { where(status: :active) }
  scope :ended_sessions, -> { where(status: :ended) }
  scope :for_appointment, ->(appointment_id) { where(appointment_id: appointment_id) if appointment_id.present? }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def start!
    return false unless status == "created"

    update(status: :active, started_at: Time.current)
  end

  def end!
    return false unless status == "active"

    duration = calculate_duration
    update(
      status: :ended,
      ended_at: Time.current,
      duration_minutes: duration
    )
  end

  def fail!
    update(status: :failed)
  end

  def active?
    status == "active"
  end

  def session_duration
    return nil unless started_at.present? && ended_at.present?

    ((ended_at - started_at) / 60).round
  end

  def patient_url
    return nil unless session_url.present?

    "#{session_url}?role=patient&token=#{generate_token(appointment.user_id, 'patient')}"
  end

  def doctor_url
    return nil unless session_url.present?

    "#{session_url}?role=doctor&token=#{generate_token(appointment.doctor_id, 'doctor')}"
  end

  private

  def generate_room_name
    self.room_name = "mediconnect-#{appointment_id}-#{SecureRandom.hex(4)}"
  end

  def generate_session_url
    # Stub implementation - in production, this would integrate with Daily.co or Twilio
    # For now, generate a placeholder URL
    self.session_url = "https://mediconnect.daily.co/#{room_name}"
  end

  def calculate_duration
    return 0 unless started_at.present?

    ((Time.current - started_at) / 60).round
  end

  def generate_token(user_id, role)
    # Stub implementation - in production, this would generate a JWT token for video session
    # For now, generate a simple token
    payload = {
      user_id: user_id,
      role: role,
      room_name: room_name,
      exp: 4.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
end
