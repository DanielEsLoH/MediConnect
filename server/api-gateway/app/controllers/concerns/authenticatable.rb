# frozen_string_literal: true

# Concern for handling JWT-based authentication in controllers
# Include this in controllers that require authentication
#
# @example Requiring authentication for all actions
#   class Api::V1::UsersController < ApplicationController
#     include Authenticatable
#     before_action :authenticate_request!
#   end
#
# @example Requiring authentication for specific actions
#   class Api::V1::DoctorsController < ApplicationController
#     include Authenticatable
#     before_action :authenticate_request!, only: [:create, :update, :destroy]
#   end
#
module Authenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user_id, :current_user, :current_token_payload
  end

  # Authenticates the request and sets current user information
  # Returns 401 Unauthorized if authentication fails
  #
  # @raise [UnauthorizedError] if token is missing or invalid
  def authenticate_request!
    token = extract_token_from_header

    if token.blank?
      render_unauthorized("Authorization token is required")
      return
    end

    result = AuthenticationService.validate(token: token)

    if result.success?
      @current_token_payload = result.user
      @current_user_id = result.user[:user_id]
      @current_user = result.user
    else
      render_unauthorized(result.error)
    end
  end

  # Optional authentication - sets current user if token is valid
  # Does not return 401 if token is missing
  def authenticate_request
    token = extract_token_from_header
    return if token.blank?

    result = AuthenticationService.validate(token: token)

    if result.success?
      @current_token_payload = result.user
      @current_user_id = result.user[:user_id]
      @current_user = result.user
    end
  end

  # Checks if the current request is authenticated
  #
  # @return [Boolean] true if user is authenticated
  def authenticated?
    current_user_id.present?
  end

  # Helper to check if current user has a specific role
  #
  # @param role [Symbol, String] the role to check
  # @return [Boolean] true if user has the role
  def current_user_has_role?(role)
    return false unless authenticated?

    current_user[:role]&.to_s == role.to_s
  end

  # Ensures user has admin role
  def require_admin!
    return if current_user_has_role?(:admin)

    render_forbidden("Admin access required")
  end

  # Ensures user has doctor role
  def require_doctor!
    return if current_user_has_role?(:doctor) || current_user_has_role?(:admin)

    render_forbidden("Doctor access required")
  end

  private

  # Extracts JWT from Authorization header
  # Supports "Bearer <token>" format
  #
  # @return [String, nil] the extracted token or nil
  def extract_token_from_header
    header = request.headers["Authorization"]
    return nil if header.blank?

    # Support both "Bearer token" and just "token" formats
    if header.start_with?("Bearer ")
      header.split(" ").last
    else
      header
    end
  end

  # Renders a 401 Unauthorized response
  #
  # @param message [String] the error message
  def render_unauthorized(message = "Unauthorized")
    render json: ErrorResponse.unauthorized(message, request_id: request_id),
           status: :unauthorized
  end

  # Renders a 403 Forbidden response
  #
  # @param message [String] the error message
  def render_forbidden(message = "Forbidden")
    render json: ErrorResponse.forbidden(message, request_id: request_id),
           status: :forbidden
  end

  # Gets the current request ID for tracing
  #
  # @return [String] the request ID
  def request_id
    request.headers["X-Request-ID"] || request.request_id
  end
end
