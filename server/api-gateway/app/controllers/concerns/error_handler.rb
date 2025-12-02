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
    # Order matters: more specific exceptions should be listed first

    # Custom application errors
    rescue_from JsonWebToken::ExpiredTokenError, with: :handle_token_expired
    rescue_from JsonWebToken::InvalidTokenError, with: :handle_invalid_token
    rescue_from JsonWebToken::TokenRevoked, with: :handle_token_revoked

    # Service communication errors
    rescue_from HttpClient::ServiceUnavailable, with: :handle_service_unavailable
    rescue_from HttpClient::CircuitOpen, with: :handle_circuit_open
    rescue_from HttpClient::RequestTimeout, with: :handle_request_timeout
    rescue_from ServiceRegistry::ServiceNotFound, with: :handle_service_not_found

    # ActiveRecord errors
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

    # ActionController errors
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters

    # JSON parsing errors
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error
    rescue_from JSON::ParserError, with: :handle_parse_error

    # Routing errors (when mounted)
    rescue_from ActionController::RoutingError, with: :handle_routing_error

    # Generic fallback (should be last)
    rescue_from StandardError, with: :handle_standard_error
  end

  private

  # Token errors
  def handle_token_expired(exception)
    log_error(exception, level: :info)
    render_error(
      status: :unauthorized,
      error: "token_expired",
      message: "Access token has expired. Please refresh your token."
    )
  end

  def handle_invalid_token(exception)
    log_error(exception, level: :warn)
    render_error(
      status: :unauthorized,
      error: "invalid_token",
      message: "Invalid authentication token."
    )
  end

  def handle_token_revoked(exception)
    log_error(exception, level: :info)
    render_error(
      status: :unauthorized,
      error: "token_revoked",
      message: "Token has been revoked. Please login again."
    )
  end

  # Service communication errors
  def handle_service_unavailable(exception)
    log_error(exception, level: :error)
    render_error(
      status: :service_unavailable,
      error: "service_unavailable",
      message: "A required service is currently unavailable. Please try again later."
    )
  end

  def handle_circuit_open(exception)
    log_error(exception, level: :warn)
    render_error(
      status: :service_unavailable,
      error: "service_circuit_open",
      message: "Service is temporarily unavailable due to high error rate. Please try again later."
    )
  end

  def handle_request_timeout(exception)
    log_error(exception, level: :error)
    render_error(
      status: :gateway_timeout,
      error: "request_timeout",
      message: "Request to downstream service timed out."
    )
  end

  def handle_service_not_found(exception)
    log_error(exception, level: :error)
    render_error(
      status: :internal_server_error,
      error: "service_not_found",
      message: "Requested service is not configured."
    )
  end

  # ActiveRecord errors
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

  # ActionController errors
  def handle_parameter_missing(exception)
    log_error(exception, level: :info)
    render_error(
      status: :bad_request,
      error: "parameter_missing",
      message: "Required parameter missing: #{exception.param}"
    )
  end

  def handle_unpermitted_parameters(exception)
    log_error(exception, level: :info)
    render_error(
      status: :bad_request,
      error: "unpermitted_parameters",
      message: "Unpermitted parameters: #{exception.params.join(', ')}"
    )
  end

  # Parse errors
  def handle_parse_error(exception)
    log_error(exception, level: :warn)
    render_error(
      status: :bad_request,
      error: "invalid_json",
      message: "Request body contains invalid JSON."
    )
  end

  # Routing errors
  def handle_routing_error(exception)
    log_error(exception, level: :info)
    render_error(
      status: :not_found,
      error: "route_not_found",
      message: "The requested endpoint does not exist."
    )
  end

  # Generic error handler (fallback)
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

  # Helper method to render error response
  def render_error(status:, error:, message:, details: nil)
    response_body = ErrorResponse.build(
      status: status,
      error: error,
      message: message,
      details: details,
      request_id: current_request_id
    )

    render json: response_body, status: status
  end

  # Helper method to log errors
  def log_error(exception, level: :error)
    log_data = {
      event: "error",
      error_class: exception.class.name,
      error_message: exception.message,
      request_id: current_request_id,
      path: request.path,
      method: request.method
    }

    # Add backtrace for error level
    if level == :error
      log_data[:backtrace] = exception.backtrace&.first(5)
    end

    Rails.logger.public_send(level, log_data.to_json)
  end

  # Get current request ID
  def current_request_id
    request.request_id || Thread.current[:request_id]
  end
end
