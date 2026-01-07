# frozen_string_literal: true

module ApplicationCable
  # Base WebSocket connection class
  # Handles JWT authentication for incoming connections
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id

    def connect
      self.current_user_id = find_verified_user
    end

    private

    def find_verified_user
      token = extract_token
      return reject_unauthorized_connection unless token

      payload = decode_token(token)
      return reject_unauthorized_connection unless payload

      payload["sub"] || payload["user_id"]
    rescue StandardError => e
      Rails.logger.error "[WebSocket] Authentication error: #{e.message}"
      reject_unauthorized_connection
    end

    def extract_token
      # Token can be passed as query parameter
      request.params[:token]
    end

    def decode_token(token)
      secret = ENV.fetch("JWT_SECRET", "development_secret")
      decoded = JWT.decode(token, secret, true, algorithm: "HS256")
      decoded.first
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn "[WebSocket] Invalid token: #{e.message}"
      nil
    end
  end
end