# frozen_string_literal: true

# Service for handling user authentication
# Acts as a proxy to the users-service for authentication operations
#
# @example Authenticating a user
#   result = AuthenticationService.login(email: 'user@example.com', password: 'secret')
#   if result.success?
#     result.tokens # => { access_token: '...', refresh_token: '...' }
#   end
#
class AuthenticationService
  # Result object for authentication operations
  class Result
    attr_reader :user, :tokens, :error, :status

    def initialize(success:, user: nil, tokens: nil, error: nil, status: :ok)
      @success = success
      @user = user
      @tokens = tokens
      @error = error
      @status = status
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  class << self
    # Authenticates a user with email and password
    # Proxies to users-service and generates JWT tokens on success
    #
    # @param email [String] user's email
    # @param password [String] user's password
    # @param request_id [String] optional request ID for tracing
    # @return [Result] authentication result with tokens or error
    def login(email:, password:, request_id: nil)
      # Validate input
      return invalid_credentials_result if email.blank? || password.blank?

      # Authenticate against users-service
      response = http_client.post(
        :users,
        "/api/internal/authenticate",
        { email: email, password: password },
        headers: { "X-Request-ID" => request_id }.compact
      )

      if response.success?
        user_data = response.body
        tokens = generate_tokens(user_data)

        Result.new(
          success: true,
          user: user_data,
          tokens: tokens
        )
      else
        handle_auth_error(response)
      end
    rescue HttpClient::ServiceUnavailable => e
      Result.new(
        success: false,
        error: "Authentication service unavailable",
        status: :service_unavailable
      )
    rescue HttpClient::CircuitOpen => e
      Result.new(
        success: false,
        error: "Authentication service temporarily unavailable",
        status: :service_unavailable
      )
    rescue StandardError => e
      Rails.logger.error("Authentication error: #{e.message}")
      Result.new(
        success: false,
        error: "Authentication failed",
        status: :internal_server_error
      )
    end

    # Refreshes an access token using a refresh token
    #
    # @param refresh_token [String] the refresh token
    # @return [Result] result with new tokens or error
    def refresh(refresh_token:)
      return invalid_token_result if refresh_token.blank?

      # Decode and validate refresh token
      payload = JsonWebToken.decode(refresh_token)

      # Verify it's a refresh token
      unless payload[:type]&.to_sym == :refresh
        return Result.new(
          success: false,
          error: "Invalid token type",
          status: :unauthorized
        )
      end

      # Fetch fresh user data from users-service
      user_data = fetch_user(payload[:user_id])
      return user_not_found_result unless user_data

      # Generate new tokens
      tokens = generate_tokens(user_data)

      # Optionally revoke old refresh token (sliding window)
      JsonWebToken.revoke(refresh_token) if ENV.fetch("REVOKE_ON_REFRESH", "true") == "true"

      Result.new(
        success: true,
        user: user_data,
        tokens: tokens
      )
    rescue JsonWebToken::ExpiredTokenError
      Result.new(
        success: false,
        error: "Refresh token has expired",
        status: :unauthorized
      )
    rescue JsonWebToken::InvalidTokenError => e
      Result.new(
        success: false,
        error: "Invalid refresh token",
        status: :unauthorized
      )
    rescue JsonWebToken::TokenRevoked
      Result.new(
        success: false,
        error: "Refresh token has been revoked",
        status: :unauthorized
      )
    end

    # Validates an access token and returns user info
    #
    # @param token [String] the access token
    # @return [Result] result with user data or error
    def validate(token:)
      return invalid_token_result if token.blank?

      payload = JsonWebToken.decode(token)

      # Verify it's an access token
      unless payload[:type]&.to_sym == :access
        return Result.new(
          success: false,
          error: "Invalid token type",
          status: :unauthorized
        )
      end

      Result.new(
        success: true,
        user: payload.slice(:user_id, :email, :role, :first_name, :last_name).to_h.symbolize_keys
      )
    rescue JsonWebToken::ExpiredTokenError
      Result.new(
        success: false,
        error: "Token has expired",
        status: :unauthorized
      )
    rescue JsonWebToken::InvalidTokenError
      Result.new(
        success: false,
        error: "Invalid token",
        status: :unauthorized
      )
    rescue JsonWebToken::TokenRevoked
      Result.new(
        success: false,
        error: "Token has been revoked",
        status: :unauthorized
      )
    end

    # Logs out a user by revoking their tokens
    #
    # @param access_token [String] the access token to revoke
    # @param refresh_token [String] optional refresh token to revoke
    # @return [Result] logout result
    def logout(access_token:, refresh_token: nil)
      revoked_access = JsonWebToken.revoke(access_token) if access_token.present?
      revoked_refresh = JsonWebToken.revoke(refresh_token) if refresh_token.present?

      Result.new(
        success: true,
        tokens: {
          access_token_revoked: revoked_access || false,
          refresh_token_revoked: revoked_refresh || false
        }
      )
    end

    # Fetches current user info from users-service
    #
    # @param user_id [Integer] the user's ID
    # @param request_id [String] optional request ID for tracing
    # @return [Hash, nil] user data or nil if not found
    def fetch_user(user_id, request_id: nil)
      response = http_client.get(
        :users,
        "/api/internal/users/#{user_id}",
        headers: { "X-Request-ID" => request_id }.compact
      )

      response.success? ? response.body : nil
    rescue StandardError => e
      Rails.logger.error("Failed to fetch user #{user_id}: #{e.message}")
      nil
    end

    private

    def http_client
      @http_client ||= HttpClient
    end

    def generate_tokens(user_data)
      # Build token payload
      token_payload = {
        user_id: user_data["id"] || user_data[:id],
        email: user_data["email"] || user_data[:email],
        role: user_data["role"] || user_data[:role],
        first_name: user_data["first_name"] || user_data[:first_name],
        last_name: user_data["last_name"] || user_data[:last_name]
      }.compact

      {
        access_token: JsonWebToken.encode(token_payload),
        refresh_token: JsonWebToken.encode_refresh_token(user_id: token_payload[:user_id]),
        token_type: "Bearer",
        expires_in: ENV.fetch("JWT_EXPIRATION", 86_400).to_i
      }
    end

    def handle_auth_error(response)
      case response.status
      when 401
        invalid_credentials_result
      when 404
        user_not_found_result
      when 422
        Result.new(
          success: false,
          error: response.body["error"] || "Validation failed",
          status: :unprocessable_entity
        )
      else
        Result.new(
          success: false,
          error: "Authentication failed",
          status: :internal_server_error
        )
      end
    end

    def invalid_credentials_result
      Result.new(
        success: false,
        error: "Invalid email or password",
        status: :unauthorized
      )
    end

    def invalid_token_result
      Result.new(
        success: false,
        error: "Token is required",
        status: :unauthorized
      )
    end

    def user_not_found_result
      Result.new(
        success: false,
        error: "User not found",
        status: :not_found
      )
    end
  end
end
