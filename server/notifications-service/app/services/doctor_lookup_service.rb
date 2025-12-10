# frozen_string_literal: true

# Service for fetching doctor data from the Doctors Service
# Provides a clean interface for notification services to get doctor info
#
# @example Fetch doctor contact info
#   doctor = DoctorLookupService.find(doctor_id)
#   if doctor
#     name = "Dr. #{doctor[:first_name]} #{doctor[:last_name]}"
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
        cached_doctor = fetch_from_cache(doctor_id)
        return cached_doctor if cached_doctor
      end

      fetch_from_service(doctor_id, cache: cache)
    end

    # Find a doctor by ID, raising an error if not found
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
    # @return [Hash, nil] Contact info (email, phone, name, clinic)
    def contact_info(doctor_id)
      return nil if doctor_id.blank?

      response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}/contact_info")

      if response.success?
        response.body.symbolize_keys
      elsif response.not_found?
        nil
      else
        log_error("Failed to fetch contact info", doctor_id, response)
        nil
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[DoctorLookupService] Service error: #{e.message}")
      nil
    end

    # Batch fetch multiple doctors
    #
    # @param doctor_ids [Array<String>] Array of doctor UUIDs
    # @return [Hash<String, Hash>] Map of doctor_id => doctor_data
    def find_many(doctor_ids)
      return {} if doctor_ids.blank?

      doctor_ids = doctor_ids.uniq.compact

      response = HttpClient.post(:doctors, "/internal/doctors/batch", { doctor_ids: doctor_ids })

      if response.success?
        doctors = response.dig("doctors") || []
        doctors.index_by { |d| d["id"] }
      else
        log_error("Failed to batch fetch doctors", doctor_ids.join(","), response)
        {}
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[DoctorLookupService] Failed to batch fetch doctors: #{e.message}")
      {}
    end

    # Check if a doctor exists and is accepting patients
    #
    # @param doctor_id [String] UUID of the doctor
    # @return [Hash] { exists: true/false, accepting_new_patients: true/false }
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

    def clear_cache(doctor_id)
      Rails.cache.delete(cache_key(doctor_id))
    end

    private

    def fetch_from_service(doctor_id, cache: true)
      response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}")

      if response.success?
        doctor_data = response.dig("doctor")
        store_in_cache(doctor_id, doctor_data) if cache && doctor_data
        doctor_data&.symbolize_keys
      elsif response.not_found?
        nil
      else
        log_error("Failed to fetch doctor", doctor_id, response)
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[DoctorLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Doctors service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[DoctorLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Doctors service is unavailable: #{e.message}"
    end

    def fetch_from_cache(doctor_id)
      cached = Rails.cache.read(cache_key(doctor_id))
      return nil unless cached

      Rails.logger.debug("[DoctorLookupService] Cache hit for doctor #{doctor_id}")
      cached.symbolize_keys
    end

    def store_in_cache(doctor_id, doctor_data)
      Rails.cache.write(cache_key(doctor_id), doctor_data, expires_in: CACHE_TTL)
    end

    def cache_key(doctor_id)
      "#{CACHE_KEY_PREFIX}:#{doctor_id}"
    end

    def log_error(message, doctor_id, response)
      Rails.logger.error(
        "[DoctorLookupService] #{message} doctor_id=#{doctor_id} " \
        "status=#{response.status} body=#{response.body.inspect}"
      )
    end
  end
end
