# frozen_string_literal: true

# Service for fetching user data from the Users Service
# Used by Appointments Service to validate users and fetch contact info
#
# @example Validate user exists before booking
#   if UserLookupService.exists?(user_id)
#     # proceed with booking
#   end
#
# @example Fetch user details for appointment confirmation
#   user = UserLookupService.find(user_id)
#   if user
#     email = user[:email]
#     name = user[:full_name]
#   end
#
class UserLookupService
  class UserNotFound < StandardError; end
  class ServiceUnavailable < StandardError; end

  CACHE_TTL = ENV.fetch("USER_CACHE_TTL", 300).to_i.seconds
  CACHE_KEY_PREFIX = "user_lookup"

  class << self
    # Find a user by ID
    #
    # @param user_id [String] UUID of the user
    # @param cache [Boolean] Whether to use caching (default: true)
    # @return [Hash, nil] User data or nil if not found
    def find(user_id, cache: true)
      return nil if user_id.blank?

      if cache
        cached_user = fetch_from_cache(user_id)
        return cached_user if cached_user
      end

      fetch_from_service(user_id, cache: cache)
    end

    # Find a user by ID, raising an error if not found
    #
    # @param user_id [String] UUID of the user
    # @return [Hash] User data
    # @raise [UserNotFound] If user doesn't exist
    def find!(user_id)
      user = find(user_id)
      raise UserNotFound, "User #{user_id} not found" unless user

      user
    end

    # Get contact information for a user
    #
    # @param user_id [String] UUID of the user
    # @return [Hash, nil] Contact info (email, phone, name)
    def contact_info(user_id)
      return nil if user_id.blank?

      response = HttpClient.get(:users, "/internal/users/#{user_id}/contact_info")

      if response.success?
        response.body.symbolize_keys
      elsif response.not_found?
        nil
      else
        Rails.logger.error(
          "[UserLookupService] Failed to fetch contact info user_id=#{user_id} " \
          "status=#{response.status}"
        )
        nil
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Service error: #{e.message}")
      nil
    end

    # Check if a user exists
    #
    # @param user_id [String] UUID of the user
    # @return [Boolean] True if user exists
    def exists?(user_id)
      return false if user_id.blank?

      response = HttpClient.get(:users, "/internal/users/#{user_id}/exists")

      if response.success?
        response.dig("exists") == true
      else
        false
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout
      # In case of service unavailability, we may want to fail open or closed
      # depending on business requirements. Failing closed (false) is safer.
      Rails.logger.warn("[UserLookupService] Service unavailable, user existence check failed")
      false
    end

    def clear_cache(user_id)
      Rails.cache.delete(cache_key(user_id))
    end

    private

    def fetch_from_service(user_id, cache: true)
      response = HttpClient.get(:users, "/internal/users/#{user_id}")

      if response.success?
        user_data = response.dig("user")
        store_in_cache(user_id, user_data) if cache && user_data
        user_data&.symbolize_keys
      elsif response.not_found?
        nil
      else
        Rails.logger.error(
          "[UserLookupService] Failed to fetch user user_id=#{user_id} status=#{response.status}"
        )
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[UserLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Users service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Users service is unavailable"
    end

    def fetch_from_cache(user_id)
      Rails.cache.read(cache_key(user_id))&.symbolize_keys
    end

    def store_in_cache(user_id, user_data)
      Rails.cache.write(cache_key(user_id), user_data, expires_in: CACHE_TTL)
    end

    def cache_key(user_id)
      "#{CACHE_KEY_PREFIX}:#{user_id}"
    end
  end
end
