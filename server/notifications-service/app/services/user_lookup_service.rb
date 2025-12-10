# frozen_string_literal: true

# Service for fetching user data from the Users Service
# Provides a clean interface for notification services to get user contact info
#
# @example Fetch user contact info
#   user = UserLookupService.find(user_id)
#   if user
#     email = user[:email]
#     phone = user[:phone_number]
#   end
#
# @example Fetch with caching
#   user = UserLookupService.find(user_id, cache: true)
#
class UserLookupService
  class UserNotFound < StandardError; end
  class ServiceUnavailable < StandardError; end

  # Cache TTL for user data (5 minutes)
  CACHE_TTL = ENV.fetch("USER_CACHE_TTL", 300).to_i.seconds
  CACHE_KEY_PREFIX = "user_lookup"

  class << self
    # Find a user by ID
    #
    # @param user_id [String] UUID of the user
    # @param cache [Boolean] Whether to use caching (default: true)
    # @return [Hash, nil] User data or nil if not found
    # @raise [ServiceUnavailable] If Users Service is unavailable
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
    # @raise [ServiceUnavailable] If Users Service is unavailable
    def find!(user_id)
      user = find(user_id)
      raise UserNotFound, "User #{user_id} not found" unless user

      user
    end

    # Get contact information for a user (optimized endpoint)
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
        log_error("Failed to fetch contact info", user_id, response)
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[UserLookupService] Circuit open for users service: #{e.message}")
      nil
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Users service unavailable: #{e.message}")
      nil
    end

    # Batch fetch multiple users
    #
    # @param user_ids [Array<String>] Array of user UUIDs
    # @return [Hash<String, Hash>] Map of user_id => user_data
    def find_many(user_ids)
      return {} if user_ids.blank?

      user_ids = user_ids.uniq.compact

      response = HttpClient.post(:users, "/internal/users/batch", { user_ids: user_ids })

      if response.success?
        users = response.dig("users") || []
        users.index_by { |u| u["id"] }
      else
        log_error("Failed to batch fetch users", user_ids.join(","), response)
        {}
      end
    rescue HttpClient::CircuitOpen, HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Failed to batch fetch users: #{e.message}")
      {}
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
      false
    end

    # Clear cached user data
    #
    # @param user_id [String] UUID of the user
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
        Rails.logger.info("[UserLookupService] User #{user_id} not found")
        nil
      else
        log_error("Failed to fetch user", user_id, response)
        nil
      end
    rescue HttpClient::CircuitOpen => e
      Rails.logger.warn("[UserLookupService] Circuit open: #{e.message}")
      raise ServiceUnavailable, "Users service circuit is open"
    rescue HttpClient::ServiceUnavailable, HttpClient::RequestTimeout => e
      Rails.logger.error("[UserLookupService] Service unavailable: #{e.message}")
      raise ServiceUnavailable, "Users service is unavailable: #{e.message}"
    end

    def fetch_from_cache(user_id)
      cached = Rails.cache.read(cache_key(user_id))
      return nil unless cached

      Rails.logger.debug("[UserLookupService] Cache hit for user #{user_id}")
      cached.symbolize_keys
    end

    def store_in_cache(user_id, user_data)
      Rails.cache.write(cache_key(user_id), user_data, expires_in: CACHE_TTL)
      Rails.logger.debug("[UserLookupService] Cached user #{user_id}")
    end

    def cache_key(user_id)
      "#{CACHE_KEY_PREFIX}:#{user_id}"
    end

    def log_error(message, user_id, response)
      Rails.logger.error(
        "[UserLookupService] #{message} user_id=#{user_id} " \
        "status=#{response.status} body=#{response.body.inspect}"
      )
    end
  end
end
