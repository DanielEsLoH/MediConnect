# frozen_string_literal: true

# Concern for centralized error handling in controllers
# Rescues common exceptions and returns standardized JSON error responses
#
# @example Including in ApplicationController
#   class ApplicationController < ActionController::API
#     include ErrorHandler
#   end
#
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    # Stripe-specific errors (should be caught first)
    rescue_from Stripe::CardError, with: :handle_stripe_card_error
    rescue_from Stripe::RateLimitError, with: :handle_stripe_rate_limit
    rescue_from Stripe::InvalidRequestError, with: :handle_stripe_invalid_request
    rescue_from Stripe::AuthenticationError, with: :handle_stripe_authentication_error
    rescue_from Stripe::APIConnectionError, with: :handle_stripe_connection_error
    rescue_from Stripe::SignatureVerificationError, with: :handle_stripe_signature_error
    rescue_from Stripe::StripeError, with: :handle_stripe_generic_error

    # ActiveRecord errors
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

    # ActionController errors
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    # JSON parsing errors
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error
    rescue_from JSON::ParserError, with: :handle_parse_error

    # Generic fallback (should be last)
    rescue_from StandardError, with: :handle_standard_error
  end

  private

  # =============================================================================
  # STRIPE ERROR HANDLERS
  # =============================================================================

  # Handles card-related errors (declined, expired, etc.)
  def handle_stripe_card_error(exception)
    log_error(exception, level: :info)
    error = exception.error
    render_error(
      status: :payment_required,
      error: "card_error",
      message: error.message,
      details: {
        code: error.code,
        decline_code: error.decline_code,
        param: error.param
      }
    )
  end

  # Handles Stripe rate limiting
  def handle_stripe_rate_limit(exception)
    log_error(exception, level: :warn)
    render_error(
      status: :too_many_requests,
      error: "rate_limit_exceeded",
      message: "Too many requests to payment processor. Please try again later."
    )
  end

  # Handles invalid request parameters to Stripe
  def handle_stripe_invalid_request(exception)
    log_error(exception, level: :error)
    render_error(
      status: :bad_request,
      error: "invalid_request",
      message: "Invalid payment request: #{exception.message}"
    )
  end

  # Handles Stripe authentication/API key errors
  def handle_stripe_authentication_error(exception)
    log_error(exception, level: :error)
    render_error(
      status: :internal_server_error,
      error: "payment_configuration_error",
      message: "Payment processing is temporarily unavailable."
    )
  end

  # Handles network/connection errors to Stripe
  def handle_stripe_connection_error(exception)
    log_error(exception, level: :error)
    render_error(
      status: :service_unavailable,
      error: "payment_service_unavailable",
      message: "Unable to connect to payment processor. Please try again."
    )
  end

  # Handles webhook signature verification failures
  def handle_stripe_signature_error(exception)
    log_error(exception, level: :warn)
    render_error(
      status: :bad_request,
      error: "invalid_signature",
      message: "Invalid webhook signature."
    )
  end

  # Handles all other Stripe errors
  def handle_stripe_generic_error(exception)
    log_error(exception, level: :error)
    render_error(
      status: :internal_server_error,
      error: "payment_error",
      message: "An error occurred while processing your payment. Please try again."
    )
  end

  # =============================================================================
  # ACTIVERECORD ERROR HANDLERS
  # =============================================================================

  def handle_record_not_found(exception)
    log_error(exception, level: :info)
    resource = exception.model || "Resource"
    render_error(
      status: :not_found,
      error: "not_found",
      message: "#{resource} not found."
    )
  end

  def handle_record_invalid(exception)
    log_error(exception, level: :info)
    render_error(
      status: :unprocessable_entity,
      error: "validation_failed",
      message: "Validation failed.",
      details: exception.record&.errors&.full_messages
    )
  end

  def handle_record_not_unique(exception)
    log_error(exception, level: :info)
    render_error(
      status: :conflict,
      error: "duplicate_record",
      message: "A record with this data already exists."
    )
  end

  # =============================================================================
  # CONTROLLER ERROR HANDLERS
  # =============================================================================

  def handle_parameter_missing(exception)
    log_error(exception, level: :info)
    render_error(
      status: :bad_request,
      error: "parameter_missing",
      message: "Required parameter missing: #{exception.param}"
    )
  end

  def handle_parse_error(exception)
    log_error(exception, level: :warn)
    render_error(
      status: :bad_request,
      error: "invalid_json",
      message: "Request body contains invalid JSON."
    )
  end

  # =============================================================================
  # GENERIC ERROR HANDLER
  # =============================================================================

  def handle_standard_error(exception)
    log_error(exception, level: :error)

    # In production, don't expose internal error details
    if Rails.env.production?
      render_error(
        status: :internal_server_error,
        error: "internal_server_error",
        message: "An unexpected error occurred. Please try again later."
      )
    else
      render_error(
        status: :internal_server_error,
        error: "internal_server_error",
        message: exception.message,
        details: exception.backtrace&.first(10)
      )
    end
  end

  # =============================================================================
  # HELPER METHODS
  # =============================================================================

  # Renders a standardized error response
  #
  # @param status [Symbol] HTTP status code
  # @param error [String] Error code
  # @param message [String] Human-readable message
  # @param details [Object] Additional error details
  def render_error(status:, error:, message:, details: nil)
    response_body = {
      error: error,
      message: message,
      timestamp: Time.current.iso8601,
      request_id: request.request_id
    }

    response_body[:details] = details if details.present?

    render json: response_body, status: status
  end

  # Logs an error with appropriate level and context
  #
  # @param exception [Exception] The exception to log
  # @param level [Symbol] Log level (:info, :warn, :error)
  def log_error(exception, level: :error)
    log_data = {
      event: "error",
      error_class: exception.class.name,
      error_message: exception.message,
      request_id: request.request_id,
      path: request.path,
      method: request.method
    }

    # Add backtrace for error level
    log_data[:backtrace] = exception.backtrace&.first(5) if level == :error

    Rails.logger.public_send(level, log_data.to_json)
  end
end
