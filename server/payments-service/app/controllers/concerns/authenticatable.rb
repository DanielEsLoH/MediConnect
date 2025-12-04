# frozen_string_literal: true

# Concern for handling JWT-based authentication in controllers
# This is adapted for the payments microservice to validate tokens
# passed from the API Gateway.
#
# In the microservices architecture, the API Gateway handles primary
# authentication and forwards validated user information in headers.
#
# @example Requiring authentication for all actions
#   class Api::V1::PaymentsController < ApplicationController
#     include Authenticatable
#     before_action :authenticate_request
#   end
#
module Authenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user_id, :current_user_role
  end

  # Authenticates the request using JWT token or forwarded headers
  # In production, the API Gateway validates the token and forwards user info
  # For direct access (dev/test), validates the JWT token directly
  #
  # @return [void]
  # @raise Renders 401 Unauthorized if authentication fails
  def authenticate_request
    # First, check for forwarded headers from API Gateway
    if forwarded_user_headers?
      authenticate_from_headers
    else
      # Direct access - validate JWT token
      authenticate_from_token
    end
  end

  # Checks if the current user is an admin
  #
  # @return [Boolean] true if user has admin role
  def current_user_admin?
    current_user_role == "admin"
  end

  # Checks if the current user is a doctor
  #
  # @return [Boolean] true if user has doctor role
  def current_user_doctor?
    current_user_role == "doctor"
  end

  # Checks if the current user is a patient
  #
  # @return [Boolean] true if user has patient role
  def current_user_patient?
    current_user_role == "patient"
  end

  private

  # Checks if request contains forwarded user headers from API Gateway
  #
  # @return [Boolean] true if forwarded headers are present
  def forwarded_user_headers?
    request.headers["X-User-ID"].present?
  end

  # Authenticates using forwarded headers from API Gateway
  # The API Gateway validates the JWT and forwards user info
  #
  # @return [void]
  def authenticate_from_headers
    @current_user_id = request.headers["X-User-ID"]
    @current_user_role = request.headers["X-User-Role"] || "patient"

    if @current_user_id.blank?
      render_unauthorized("User identification required")
    end
  end

  # Authenticates using JWT token directly
  # Used for direct API access without going through the gateway
  #
  # @return [void]
  def authenticate_from_token
    token = extract_token_from_header

    if token.blank?
      render_unauthorized("Authorization token is required")
      return
    end

    payload = decode_token(token)

    if payload
      @current_user_id = payload["user_id"] || payload["sub"]
      @current_user_role = payload["role"] || "patient"
    else
      render_unauthorized("Invalid or expired token")
    end
  end

  # Extracts JWT from Authorization header
  # Supports "Bearer <token>" format
  #
  # @return [String, nil] the extracted token or nil
  def extract_token_from_header
    header = request.headers["Authorization"]
    return nil if header.blank?

    if header.start_with?("Bearer ")
      header.split(" ").last
    else
      header
    end
  end

  # Decodes and validates a JWT token
  #
  # @param token [String] The JWT token to decode
  # @return [Hash, nil] The decoded payload or nil if invalid
  def decode_token(token)
    secret_key = ENV.fetch("JWT_SECRET_KEY", "development-secret-key")

    decoded = JWT.decode(
      token,
      secret_key,
      true,
      {
        algorithm: "HS256",
        verify_expiration: true
      }
    )

    decoded.first
  rescue JWT::ExpiredSignature
    Rails.logger.info(event: "token_expired")
    nil
  rescue JWT::DecodeError => e
    Rails.logger.warn(event: "token_decode_error", error: e.message)
    nil
  end

  # Renders a 401 Unauthorized response
  #
  # @param message [String] the error message
  def render_unauthorized(message = "Unauthorized")
    render json: {
      error: "unauthorized",
      message: message,
      timestamp: Time.current.iso8601
    }, status: :unauthorized
  end

  # Renders a 403 Forbidden response
  #
  # @param message [String] the error message
  def render_forbidden(message = "Forbidden")
    render json: {
      error: "forbidden",
      message: message,
      timestamp: Time.current.iso8601
    }, status: :forbidden
  end
end
