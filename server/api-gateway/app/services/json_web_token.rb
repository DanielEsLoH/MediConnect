# frozen_string_literal: true

# Service for encoding and decoding JSON Web Tokens (JWT)
# Handles both access tokens (short-lived) and refresh tokens (long-lived)
#
# @example Encoding an access token
#   token = JsonWebToken.encode(user_id: 123, email: 'user@example.com')
#
# @example Decoding a token
#   payload = JsonWebToken.decode(token)
#   # => { user_id: 123, email: 'user@example.com', exp: ..., iat: ..., jti: ... }
#
class JsonWebToken
  class ExpiredTokenError < StandardError; end
  class InvalidTokenError < StandardError; end
  class TokenRevoked < StandardError; end

  # Default expiration times
  ACCESS_TOKEN_EXPIRATION = 24.hours
  REFRESH_TOKEN_EXPIRATION = 7.days

  class << self
    # Encodes a payload into a JWT access token
    #
    # @param payload [Hash] the data to encode
    # @param expiration [ActiveSupport::Duration] token expiration time
    # @return [String] the encoded JWT
    def encode(payload, expiration: access_token_expiration)
      payload = payload.dup
      payload[:exp] = expiration.from_now.to_i
      payload[:iat] = Time.current.to_i
      payload[:jti] = SecureRandom.uuid # Unique token identifier for revocation
      payload[:type] = :access

      JWT.encode(payload, secret_key, algorithm)
    end

    # Encodes a payload into a JWT refresh token (longer expiration)
    #
    # @param payload [Hash] the data to encode (typically just user_id)
    # @return [String] the encoded refresh token
    def encode_refresh_token(payload)
      payload = payload.dup
      payload[:exp] = refresh_token_expiration.from_now.to_i
      payload[:iat] = Time.current.to_i
      payload[:jti] = SecureRandom.uuid
      payload[:type] = :refresh

      JWT.encode(payload, secret_key, algorithm)
    end

    # Decodes a JWT and returns the payload
    #
    # @param token [String] the JWT to decode
    # @return [HashWithIndifferentAccess] the decoded payload
    # @raise [ExpiredTokenError] if the token has expired
    # @raise [InvalidTokenError] if the token is invalid
    # @raise [TokenRevoked] if the token has been revoked
    def decode(token)
      decoded = JWT.decode(token, secret_key, true, decode_options)
      payload = decoded.first.with_indifferent_access

      # Check if token has been revoked
      raise TokenRevoked, "Token has been revoked" if token_revoked?(payload[:jti])

      # Validate payload structure
      validate_payload!(payload)

      payload
    rescue JWT::ExpiredSignature
      raise ExpiredTokenError, "Token has expired"
    rescue JWT::DecodeError => e
      raise InvalidTokenError, "Invalid token: #{e.message}"
    end

    # Validates a token without raising exceptions
    #
    # @param token [String] the JWT to validate
    # @return [Boolean] true if valid, false otherwise
    def valid?(token)
      decode(token)
      true
    rescue ExpiredTokenError, InvalidTokenError, TokenRevoked
      false
    end

    # Revokes a token by adding its JTI to the blacklist
    #
    # @param token [String] the JWT to revoke
    # @return [Boolean] true if revoked successfully
    def revoke(token)
      payload = decode(token)
      add_to_blacklist(payload[:jti], payload[:exp])
      true
    rescue ExpiredTokenError, InvalidTokenError
      # Token is already invalid, no need to revoke
      false
    end

    # Revokes a token by its JTI (useful when you only have the JTI)
    #
    # @param jti [String] the token's unique identifier
    # @param exp [Integer] the token's expiration timestamp
    # @return [Boolean] true if added to blacklist
    def revoke_by_jti(jti, exp = nil)
      exp ||= refresh_token_expiration.from_now.to_i
      add_to_blacklist(jti, exp)
      true
    end

    # Checks if an access token is about to expire (within threshold)
    #
    # @param token [String] the JWT to check
    # @param threshold [ActiveSupport::Duration] time threshold for "about to expire"
    # @return [Boolean] true if token expires within threshold
    def expiring_soon?(token, threshold: 5.minutes)
      payload = decode(token)
      Time.at(payload[:exp]) < threshold.from_now
    rescue ExpiredTokenError, InvalidTokenError
      true
    end

    private

    def secret_key
      @secret_key ||= ENV.fetch("JWT_SECRET") do
        Rails.application.credentials.dig(:jwt, :secret_key) ||
          raise("JWT_SECRET must be set in environment or credentials")
      end
    end

    def algorithm
      "HS256"
    end

    def access_token_expiration
      seconds = ENV.fetch("JWT_EXPIRATION", ACCESS_TOKEN_EXPIRATION.to_i).to_i
      seconds.seconds
    end

    def refresh_token_expiration
      seconds = ENV.fetch("JWT_REFRESH_EXPIRATION", REFRESH_TOKEN_EXPIRATION.to_i).to_i
      seconds.seconds
    end

    def decode_options
      {
        algorithm: algorithm,
        verify_expiration: true,
        verify_iat: true
      }
    end

    def validate_payload!(payload)
      required_fields = %i[exp iat jti type]
      missing_fields = required_fields - payload.keys.map(&:to_sym)

      if missing_fields.any?
        raise InvalidTokenError, "Missing required fields: #{missing_fields.join(', ')}"
      end
    end

    # Token blacklist using Redis
    # Keys are prefixed and set to expire when the token would have expired
    def token_revoked?(jti)
      return false if jti.blank?
      return false unless redis_available?

      redis.exists?("jwt:revoked:#{jti}")
    end

    def add_to_blacklist(jti, exp)
      return unless redis_available?

      # Calculate TTL based on token expiration
      ttl = [ exp - Time.current.to_i, 0 ].max

      # Store in Redis with expiration (no need to keep blacklist entries forever)
      redis.setex("jwt:revoked:#{jti}", ttl + 60, "1")
    end

    def redis_available?
      redis.ping == "PONG"
    rescue StandardError
      Rails.logger.warn("Redis unavailable for token blacklist")
      false
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end
  end
end
