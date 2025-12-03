# frozen_string_literal: true

class AppointmentReminderJob
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: :default

  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment

    # Only send reminders for confirmed appointments
    return unless appointment.status == "confirmed"

    # Check if appointment is within 24 hours
    hours_until = (appointment.scheduled_datetime - Time.current) / 3600
    return unless hours_until.between?(23, 25) # 24 hours ± 1 hour window

    send_reminder(appointment)

    Rails.logger.info("Sent reminder for appointment #{appointment.id}")
  rescue StandardError => e
    Rails.logger.error("Failed to send reminder for appointment #{appointment_id}: #{e.message}")
    raise
  end

  private

  def send_reminder(appointment)
    # Publish event for notification service to pick up
    EventPublisher.publish("appointment.reminder", {
      appointment_id: appointment.id,
      user_id: appointment.user_id,
      doctor_id: appointment.doctor_id,
      scheduled_datetime: appointment.scheduled_datetime.iso8601,
      consultation_type: appointment.consultation_type,
      clinic_id: appointment.clinic_id,
      timestamp: Time.current.iso8601
    })
  end
end
