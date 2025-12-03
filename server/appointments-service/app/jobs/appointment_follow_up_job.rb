# frozen_string_literal: true

class AppointmentFollowUpJob
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: :default

  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment

    # Only send follow-ups for completed appointments
    return unless appointment.status == "completed"

    # Check if appointment was completed recently (within 24-48 hours)
    return unless appointment.completed_at

    hours_since_completion = (Time.current - appointment.completed_at) / 3600
    return unless hours_since_completion.between?(24, 48)

    send_follow_up(appointment)

    Rails.logger.info("Sent follow-up for appointment #{appointment.id}")
  rescue StandardError => e
    Rails.logger.error("Failed to send follow-up for appointment #{appointment_id}: #{e.message}")
    raise
  end

  private

  def send_follow_up(appointment)
    # Publish event for notification service to pick up
    EventPublisher.publish("appointment.follow_up", {
      appointment_id: appointment.id,
      user_id: appointment.user_id,
      doctor_id: appointment.doctor_id,
      completed_at: appointment.completed_at.iso8601,
      has_prescription: appointment.prescription.present?,
      timestamp: Time.current.iso8601
    })
  end
end
