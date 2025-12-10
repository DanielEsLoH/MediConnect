# frozen_string_literal: true

module Api
  module Internal
    class AuthenticationController < BaseController
      # POST /api/internal/authenticate
      # Verifies credentials and returns user data
      #
      # @param email [String] User email
      # @param password [String] User password
      # @return [JSON] User data (if valid) or 401 Unauthorized
      def authenticate
        email = params.require(:email)
        password = params.require(:password)

        user = User.find_by(email: email.downcase)

        if user&.authenticate(password)
          render json: user_response(user)
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      private

      def user_response(user)
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: user.email == "admin@mediconnect.com" ? "admin" : "user",
          # Add other fields required by API Gateway token generation
        }
      end
    end
  end
end
