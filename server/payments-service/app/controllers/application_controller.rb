# frozen_string_literal: true

# Base controller for the Payments Service API
# Includes authentication and error handling concerns
class ApplicationController < ActionController::API
  include Authenticatable
  include ErrorHandler

  # Set request ID for logging and tracing
  before_action :set_request_id

  private

  # Sets up request ID for distributed tracing
  # Uses forwarded ID from API Gateway or generates a new one
  def set_request_id
    Thread.current[:request_id] = request.headers["X-Request-ID"] || request.request_id
  end
end
