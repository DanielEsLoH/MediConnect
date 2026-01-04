# frozen_string_literal: true

# Service for fetching appointment data from the Appointments Service
# Provides a clean interface for notification services to get appointment details
#
# @example Fetch appointment details for reminder
#   apt = AppointmentLookupService.find(appointment_id)
#   if apt
#     scheduled_time = apt[:scheduled_datetime]
#     doctor_id = apt[:doctor_id]
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
        cached_appointment = fetch_from_cache(appointment_id)
        return cached_appointment if cached_appointment
      end

      fetch_from_service(appointment_id, cache: cache)
    end

    # Find an appointment by ID, raising an error if not found
    #
    # @param appointment_id [String] UUID of the appointment
    # @return [Hash] Appointment data
    # @raise [AppointmentNotFound] If appointment doesn't exist
    def find!(appointment_id)
      appointment = find(appointment_id)
      raise AppointmentNotFound, "Appointment #{appointment_id} not found" unless appointment

      appointment
    end

    # Get appointments for a specific user
    #
    # @param user_id [String] UUID of the user
    # @param status [String, nil] Optional status filter
    # @param from_date [String, nil] Optional start date filter
    # @return [Array<Hash>] Array of appointments
    def for_user(user_id, status: nil, from_date: nil)
      return [] if user_id.blank?

      params = {}
      params[:status] = status if status.present?
      params[:from_date] = from_date if from_date.present?

      response = HttpClient.get(
        :appointments,
        "/internal/appointments/by_user/#{user_id}",
        params: params
      )

      if response.success?
        appointments = response.dig("appointments") || []
        appointments.map(&:symbolize_keys)
      else
        log_error("Failed to fetch user appointments", user_id, response)
        []
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[AppointmentLookupService] Service error: #{e.message}")
      []
    end

    # Get appointments for a specific doctor
    #
    # @param doctor_id [String] UUID of the doctor
    # @param status [String, nil] Optional status filter
    # @param date [String, nil] Optional date filter
    # @return [Array<Hash>] Array of appointments
    def for_doctor(doctor_id, status: nil, date: nil)
      return [] if doctor_id.blank?

      params = {}
      params[:status] = status if status.present?
      params[:date] = date if date.present?

      response = HttpClient.get(
        :appointments,
        "/internal/appointments/by_doctor/#{doctor_id}",
        params: params
      )

      if response.success?
        appointments = response.dig("appointments") || []
        appointments.map(&:symbolize_keys)
      else
        log_error("Failed to fetch doctor appointments", doctor_id, response)
        []
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[AppointmentLookupService] Service error: #{e.message}")
      []
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

    def clear_cache(appointment_id)
      Rails.cache.delete(cache_key(appointment_id))
    end

    private

    def fetch_from_service(appointment_id, cache: true)
      response = HttpClient.get(:appointments, "/internal/appointments/#{appointment_id}")

      if response.success?
        appointment_data = response.dig("appointment")
        store_in_cache(appointment_id, appointment_data) if cache && appointment_data
        appointment_data&.symbolize_keys
      elsif response.not_found?
        nil
      else
        log_error("Failed to fetch appointment", appointment_id, response)
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[AppointmentLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Appointments service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[AppointmentLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Appointments service is unavailable: #{e.message}"
    end

    def fetch_from_cache(appointment_id)
      cached = Rails.cache.read(cache_key(appointment_id))
      return nil unless cached

      cached.symbolize_keys
    end

    def store_in_cache(appointment_id, appointment_data)
      Rails.cache.write(cache_key(appointment_id), appointment_data, expires_in: CACHE_TTL)
    end

    def cache_key(appointment_id)
      "#{CACHE_KEY_PREFIX}:#{appointment_id}"
    end

    def log_error(message, id, response)
      Rails.logger.error(
        "[AppointmentLookupService] #{message} id=#{id} " \
        "status=#{response.status} body=#{response.body.inspect}"
      )
    end
  end
end
