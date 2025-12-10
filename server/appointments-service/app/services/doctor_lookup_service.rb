# frozen_string_literal: true

# Service for fetching doctor data from the Doctors Service
# Used by Appointments Service to validate doctors and check availability
#
# @example Validate doctor before booking
#   result = DoctorLookupService.validate_for_appointment(doctor_id, scheduled_at)
#   if result[:valid]
#     # proceed with booking
#   else
#     # show error: result[:reason]
#   end
#
# @example Fetch doctor details for appointment
#   doctor = DoctorLookupService.find(doctor_id)
#   if doctor
#     name = "Dr. #{doctor[:first_name]} #{doctor[:last_name]}"
#     specialty = doctor[:specialty][:name]
#   end
#
class DoctorLookupService
  class DoctorNotFound < StandardError; end
  class ServiceUnavailable < StandardError; end

  CACHE_TTL = ENV.fetch("DOCTOR_CACHE_TTL", 600).to_i.seconds
  CACHE_KEY_PREFIX = "doctor_lookup"

  class << self
    # Find a doctor by ID
    #
    # @param doctor_id [String] UUID of the doctor
    # @param cache [Boolean] Whether to use caching (default: true)
    # @return [Hash, nil] Doctor data or nil if not found
    def find(doctor_id, cache: true)
      return nil if doctor_id.blank?

      if cache
        cached = Rails.cache.read(cache_key(doctor_id))
        return cached.symbolize_keys if cached
      end

      response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}")

      if response.success?
        doctor_data = response.dig("doctor")
        Rails.cache.write(cache_key(doctor_id), doctor_data, expires_in: CACHE_TTL) if cache && doctor_data
        doctor_data&.symbolize_keys
      elsif response.not_found?
        nil
      else
        Rails.logger.error("[DoctorLookupService] Failed to fetch doctor_id=#{doctor_id}")
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[DoctorLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Doctors service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[DoctorLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Doctors service is unavailable"
    end

    # Find a doctor, raising error if not found
    #
    # @param doctor_id [String] UUID of the doctor
    # @return [Hash] Doctor data
    # @raise [DoctorNotFound] If doctor doesn't exist
    def find!(doctor_id)
      doctor = find(doctor_id)
      raise DoctorNotFound, "Doctor #{doctor_id} not found" unless doctor

      doctor
    end

    # Get contact information for a doctor
    #
    # @param doctor_id [String] UUID of the doctor
    # @return [Hash, nil] Contact info
    def contact_info(doctor_id)
      return nil if doctor_id.blank?

      response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}/contact_info")

      if response.success?
        response.body.symbolize_keys
      elsif response.not_found?
        nil
      else
        nil
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[DoctorLookupService] Contact info fetch failed: #{e.message}")
      nil
    end

    # Check if doctor exists and is accepting patients
    #
    # @param doctor_id [String] UUID of the doctor
    # @return [Hash] { exists: true/false, active: true/false, accepting_new_patients: true/false }
    def exists?(doctor_id)
      return { exists: false } if doctor_id.blank?

      response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}/exists")

      if response.success?
        response.body.symbolize_keys
      else
        { exists: false }
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout
      { exists: false, error: "service_unavailable" }
    end

    # Get doctor's availability for a specific date
    #
    # @param doctor_id [String] UUID of the doctor
    # @param date [Date, String] Date to check availability
    # @return [Hash] Availability info with available slots
    def availability(doctor_id, date:)
      return nil if doctor_id.blank?

      date_str = date.is_a?(Date) ? date.to_s : date

      response = HttpClient.get(
        :doctors,
        "/internal/doctors/#{doctor_id}/availability",
        params: { date: date_str }
      )

      if response.success?
        response.body.symbolize_keys
      else
        nil
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[DoctorLookupService] Availability check failed: #{e.message}")
      nil
    end

    # Validate if a doctor can accept an appointment at a given time
    # This is a critical check before booking
    #
    # @param doctor_id [String] UUID of the doctor
    # @param scheduled_at [Time, String] Proposed appointment datetime
    # @return [Hash] { valid: true/false, reason: "..." }
    def validate_for_appointment(doctor_id, scheduled_at)
      return { valid: false, reason: "Doctor ID is required" } if doctor_id.blank?
      return { valid: false, reason: "Scheduled time is required" } if scheduled_at.blank?

      scheduled_str = scheduled_at.is_a?(Time) ? scheduled_at.iso8601 : scheduled_at

      response = HttpClient.get(
        :doctors,
        "/internal/doctors/#{doctor_id}/validate_for_appointment",
        params: { scheduled_at: scheduled_str }
      )

      if response.success?
        response.body.symbolize_keys
      elsif response.not_found?
        { valid: false, reason: "Doctor not found" }
      else
        { valid: false, reason: "Unable to validate - service error" }
      end
    rescue HttpClient::CircuitOpen
      { valid: false, reason: "Doctors service is temporarily unavailable" }
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout
      { valid: false, reason: "Unable to validate doctor availability" }
    end

    def clear_cache(doctor_id)
      Rails.cache.delete(cache_key(doctor_id))
    end

    private

    def cache_key(doctor_id)
      "#{CACHE_KEY_PREFIX}:#{doctor_id}"
    end
  end
end
