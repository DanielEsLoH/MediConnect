# frozen_string_literal: true

module Api
  module V1
    # Controller for authentication endpoints
    # Handles login, logout, token refresh, and user info retrieval
    class AuthController < Api::BaseController
      # Skip authentication for login and refresh endpoints
      skip_before_action :set_request_context, only: [:login]
      before_action :authenticate_request!, only: [:logout, :me]

      # POST /api/v1/auth/login
      # Authenticates user and returns JWT tokens
      #
      # @param [String] email User's email address
      # @param [String] password User's password
      # @return [JSON] { user: {...}, tokens: { access_token, refresh_token, ... } }
      def login
        result = AuthenticationService.login(
          email: login_params[:email],
          password: login_params[:password],
          request_id: request_id
        )

        if result.success?
          render json: {
            message: "Login successful",
            user: sanitize_user_data(result.user),
            tokens: result.tokens
          }, status: :ok
        else
          render json: ErrorResponse.build(
            status: result.status,
            error: "authentication_failed",
            message: result.error,
            request_id: request_id
          ), status: result.status
        end
      end

      # POST /api/v1/auth/refresh
      # Refreshes access token using refresh token
      #
      # @param [String] refresh_token The refresh token
      # @return [JSON] { tokens: { access_token, refresh_token, ... } }
      def refresh
        result = AuthenticationService.refresh(
          refresh_token: refresh_params[:refresh_token]
        )

        if result.success?
          render json: {
            message: "Token refreshed successfully",
            tokens: result.tokens
          }, status: :ok
        else
          render json: ErrorResponse.build(
            status: result.status,
            error: "token_refresh_failed",
            message: result.error,
            request_id: request_id
          ), status: result.status
        end
      end

      # POST /api/v1/auth/logout
      # Invalidates current tokens
      #
      # @return [JSON] { message: "Logged out successfully" }
      def logout
        access_token = extract_access_token
        refresh_token = logout_params[:refresh_token]

        result = AuthenticationService.logout(
          access_token: access_token,
          refresh_token: refresh_token
        )

        render json: {
          message: "Logged out successfully",
          tokens_revoked: result.tokens
        }, status: :ok
      end

      # GET /api/v1/auth/me
      # Returns current user information
      #
      # @return [JSON] { user: {...} }
      def me
        # Fetch fresh user data from users-service
        user_data = AuthenticationService.fetch_user(current_user_id, request_id: request_id)

        if user_data
          render json: {
            user: sanitize_user_data(user_data)
          }, status: :ok
        else
          render json: ErrorResponse.not_found(
            "User not found",
            request_id: request_id
          ), status: :not_found
        end
      end

      # POST /api/v1/auth/password/reset
      # Requests a password reset email
      def request_password_reset
        proxy_request(
          service: :users,
          path: "/api/internal/password/reset",
          method: :post,
          body: password_reset_params.to_h
        )
      end

      # PUT /api/v1/auth/password/reset
      # Resets password with token
      def reset_password
        proxy_request(
          service: :users,
          path: "/api/internal/password/reset",
          method: :put,
          body: password_reset_confirm_params.to_h
        )
      end

      private

      def login_params
        params.permit(:email, :password)
      end

      def refresh_params
        params.permit(:refresh_token)
      end

      def logout_params
        params.permit(:refresh_token)
      end

      def password_reset_params
        params.permit(:email)
      end

      def password_reset_confirm_params
        params.permit(:token, :password, :password_confirmation)
      end

      def extract_access_token
        header = request.headers["Authorization"]
        return nil if header.blank?

        header.split(" ").last
      end

      # Removes sensitive fields from user data
      def sanitize_user_data(user)
        return nil if user.nil?

        # Convert to hash with string keys if needed
        user_hash = user.is_a?(Hash) ? user.stringify_keys : user.to_h.stringify_keys

        # Remove sensitive fields
        user_hash.except(
          "password_digest",
          "password_hash",
          "encrypted_password",
          "reset_password_token",
          "confirmation_token"
        )
      end
    end
  end
end
