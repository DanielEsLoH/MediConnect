# frozen_string_literal: true

# Service for fetching appointment data from the Appointments Service
# Used by Payments Service to validate appointments and get payment amounts
#
# @example Fetch appointment payment info
#   apt = AppointmentLookupService.payment_info(appointment_id)
#   if apt
#     amount = apt[:consultation_fee]
#     user_id = apt[:user_id]
#   end
#
class AppointmentLookupService
  class AppointmentNotFound < StandardError; end
  class ServiceUnavailable < StandardError; end

  CACHE_TTL = ENV.fetch("APPOINTMENT_CACHE_TTL", 300).to_i.seconds
  CACHE_KEY_PREFIX = "appointment_lookup"

  class << self
    # Find an appointment by ID
    #
    # @param appointment_id [String] UUID of the appointment
    # @param cache [Boolean] Whether to use caching (default: true)
    # @return [Hash, nil] Appointment data or nil if not found
    def find(appointment_id, cache: true)
      return nil if appointment_id.blank?

      if cache
        cached = Rails.cache.read(cache_key(appointment_id))
        return cached.symbolize_keys if cached
      end

      response = HttpClient.get(:appointments, "/internal/appointments/#{appointment_id}")

      if response.success?
        apt_data = response.dig("appointment")
        Rails.cache.write(cache_key(appointment_id), apt_data, expires_in: CACHE_TTL) if cache && apt_data
        apt_data&.symbolize_keys
      elsif response.not_found?
        nil
      else
        Rails.logger.error("[AppointmentLookupService] Failed to fetch appointment_id=#{appointment_id}")
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[AppointmentLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Appointments service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[AppointmentLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Appointments service is unavailable"
    end

    # Find an appointment, raising error if not found
    def find!(appointment_id)
      appointment = find(appointment_id)
      raise AppointmentNotFound, "Appointment #{appointment_id} not found" unless appointment

      appointment
    end

    # Get payment-specific info for an appointment
    # This is optimized for payment processing needs
    #
    # @param appointment_id [String] UUID of the appointment
    # @return [Hash, nil] Payment-related appointment data
    def payment_info(appointment_id)
      return nil if appointment_id.blank?

      response = HttpClient.get(:appointments, "/internal/appointments/#{appointment_id}/payment_info")

      if response.success?
        response.body.symbolize_keys
      elsif response.not_found?
        nil
      else
        Rails.logger.error(
          "[AppointmentLookupService] Failed to fetch payment_info appointment_id=#{appointment_id}"
        )
        nil
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[AppointmentLookupService] Payment info fetch failed: #{e.message}")
      nil
    end

    # Check if an appointment exists
    #
    # @param appointment_id [String] UUID of the appointment
    # @return [Hash] { exists: true/false, status: "...", user_id: "..." }
    def exists?(appointment_id)
      return { exists: false } if appointment_id.blank?

      response = HttpClient.get(:appointments, "/internal/appointments/#{appointment_id}/exists")

      if response.success?
        response.body.symbolize_keys
      else
        { exists: false }
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout
      { exists: false, error: "service_unavailable" }
    end

    # Get appointments for a user (for payment history/association)
    #
    # @param user_id [String] UUID of the user
    # @param status [String, nil] Optional status filter
    # @return [Array<Hash>] Array of appointments
    def for_user(user_id, status: nil)
      return [] if user_id.blank?

      params = {}
      params[:status] = status if status.present?

      response = HttpClient.get(
        :appointments,
        "/internal/appointments/by_user/#{user_id}",
        params: params
      )

      if response.success?
        appointments = response.dig("appointments") || []
        appointments.map(&:symbolize_keys)
      else
        []
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[AppointmentLookupService] User appointments fetch failed: #{e.message}")
      []
    end

    def clear_cache(appointment_id)
      Rails.cache.delete(cache_key(appointment_id))
    end

    private

    def cache_key(appointment_id)
      "#{CACHE_KEY_PREFIX}:#{appointment_id}"
    end
  end
end