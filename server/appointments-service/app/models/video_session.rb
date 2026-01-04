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
  before_validation :setup_livekit_room, on: :create, unless: :room_name?

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

  # Generate a LiveKit token for a specific participant
  def generate_participant_token(user_id:, user_name:, is_owner: false)
    livekit_service.generate_token(
      room_name: room_name,
      user_id: user_id,
      user_name: user_name,
      is_owner: is_owner
    )
  end

  # Get token for patient
  def patient_token
    return nil unless appointment.present?

    generate_participant_token(
      user_id: appointment.user_id,
      user_name: patient_display_name,
      is_owner: false
    )
  end

  # Get token for doctor
  def doctor_token
    return nil unless appointment.present?

    generate_participant_token(
      user_id: appointment.doctor_id,
      user_name: doctor_display_name,
      is_owner: true
    )
  end

  # URL for patient to join (includes token)
  def patient_url
    return nil unless session_url.present?

    "#{session_url}?token=#{patient_token}"
  end

  # URL for doctor to join (includes token)
  def doctor_url
    return nil unless session_url.present?

    "#{session_url}?token=#{doctor_token}"
  end

  # Get the LiveKit WebSocket URL for clients
  def livekit_websocket_url
    livekit_service.websocket_url
  end

  # Connection info for frontend clients
  def connection_info(user_id:, user_name:, is_doctor: false)
    {
      room_name: room_name,
      token: generate_participant_token(
        user_id: user_id,
        user_name: user_name,
        is_owner: is_doctor
      ),
      websocket_url: livekit_websocket_url,
      session_url: session_url
    }
  end

  private

  def setup_livekit_room
    self.provider = "livekit"
    self.room_name = livekit_service.create_room(appointment_id)
    self.session_url = build_session_url
  rescue LiveKitService::Error => e
    Rails.logger.error("[VideoSession] Failed to create LiveKit room: #{e.message}")
    errors.add(:base, "Failed to create video room: #{e.message}")
    throw(:abort)
  end

  def build_session_url
    base_url = ENV.fetch("LIVEKIT_FRONTEND_URL", "http://localhost:5173/video")
    "#{base_url}/#{room_name}"
  end

  def calculate_duration
    return 0 unless started_at.present?

    ((Time.current - started_at) / 60).round
  end

  def livekit_service
    @livekit_service ||= LiveKitService.new
  end

  def patient_display_name
    "Patient"
  end

  def doctor_display_name
    "Doctor"
  end
end
