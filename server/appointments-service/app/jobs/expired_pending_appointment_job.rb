# frozen_string_literal: true

class ExpiredPendingAppointmentJob
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: :default

  EXPIRATION_MINUTES = 30

  def perform
    expired_appointments = Appointment.expired_pending

    expired_appointments.find_each do |appointment|
      cancel_expired_appointment(appointment)
    end

    Rails.logger.info("Processed #{expired_appointments.count} expired pending appointments")
  rescue StandardError => e
    Rails.logger.error("Failed to process expired pending appointments: #{e.message}")
    raise
  end

  private

  def cancel_expired_appointment(appointment)
    result = AppointmentCancellationService.new(
      appointment,
      cancelled_by: "system",
      reason: "Appointment automatically cancelled after #{EXPIRATION_MINUTES} minutes without confirmation"
    ).call

    if result[:success]
      Rails.logger.info("Auto-cancelled expired appointment #{appointment.id}")
    else
      Rails.logger.error("Failed to auto-cancel appointment #{appointment.id}: #{result[:errors]}")
    end
  end
end
