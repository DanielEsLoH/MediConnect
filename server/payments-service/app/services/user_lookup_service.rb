# frozen_string_literal: true

# Service for fetching user data from the Users Service
# Used by Payments Service to get user details for receipts and billing
#
# @example Fetch user for payment receipt
#   user = UserLookupService.find(user_id)
#   if user
#     receipt_email = user[:email]
#     customer_name = user[:full_name]
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
        cached = Rails.cache.read(cache_key(user_id))
        return cached.symbolize_keys if cached
      end

      response = HttpClient.get(:users, "/internal/users/#{user_id}")

      if response.success?
        user_data = response.dig("user")
        Rails.cache.write(cache_key(user_id), user_data, expires_in: CACHE_TTL) if cache && user_data
        user_data&.symbolize_keys
      elsif response.not_found?
        nil
      else
        Rails.logger.error("[UserLookupService] Failed to fetch user_id=#{user_id}")
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[UserLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Users service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Users service is unavailable"
    end

    # Find a user, raising error if not found
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
        nil
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Contact info fetch failed: #{e.message}")
      nil
    end

    # Check if a user exists
    #
    # @param user_id [String] UUID of the user
    # @return [Boolean] True if user exists
    def exists?(user_id)
      return false if user_id.blank?

      response = HttpClient.get(:users, "/internal/users/#{user_id}/exists")

      response.success? && response.dig("exists") == true
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout
      false
    end

    def clear_cache(user_id)
      Rails.cache.delete(cache_key(user_id))
    end

    private

    def cache_key(user_id)
      "#{CACHE_KEY_PREFIX}:#{user_id}"
    end
  end
end
