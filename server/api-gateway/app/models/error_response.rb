# frozen_string_literal: true

# Standardized error response builder for API responses
# Provides consistent error format across all endpoints
#
# @example Building an error response
#   ErrorResponse.build(
#     status: :not_found,
#     error: "user_not_found",
#     message: "User with ID 123 not found"
#   )
#   # => {
#   #   status: 404,
#   #   error: "user_not_found",
#   #   message: "User with ID 123 not found",
#   #   request_id: "abc123",
#   #   timestamp: "2024-01-15T10:30:00Z"
#   # }
#
class ErrorResponse
  # HTTP status code mapping
  STATUS_CODES = {
    bad_request: 400,
    unauthorized: 401,
    forbidden: 403,
    not_found: 404,
    method_not_allowed: 405,
    conflict: 409,
    gone: 410,
    unprocessable_entity: 422,
    too_many_requests: 429,
    internal_server_error: 500,
    not_implemented: 501,
    bad_gateway: 502,
    service_unavailable: 503,
    gateway_timeout: 504
  }.freeze

  class << self
    # Builds a standardized error response hash
    #
    # @param status [Symbol, Integer] HTTP status code
    # @param error [String] error identifier (snake_case)
    # @param message [String] human-readable error message
    # @param details [Array, Hash, nil] additional error details
    # @param request_id [String, nil] request ID for tracing
    # @return [Hash] the error response hash
    def build(status:, error:, message:, details: nil, request_id: nil)
      response = {
        status: normalize_status(status),
        error: error,
        message: message,
        request_id: request_id || Thread.current[:request_id],
        timestamp: Time.current.iso8601
      }

      response[:details] = details if details.present?

      response
    end

    # Convenience methods for common errors

    def bad_request(message, request_id: nil, details: nil)
      build(
        status: :bad_request,
        error: "bad_request",
        message: message,
        details: details,
        request_id: request_id
      )
    end

    def unauthorized(message = "Unauthorized", request_id: nil)
      build(
        status: :unauthorized,
        error: "unauthorized",
        message: message,
        request_id: request_id
      )
    end

    def forbidden(message = "Forbidden", request_id: nil)
      build(
        status: :forbidden,
        error: "forbidden",
        message: message,
        request_id: request_id
      )
    end

    def not_found(message = "Resource not found", request_id: nil)
      build(
        status: :not_found,
        error: "not_found",
        message: message,
        request_id: request_id
      )
    end

    def conflict(message, request_id: nil)
      build(
        status: :conflict,
        error: "conflict",
        message: message,
        request_id: request_id
      )
    end

    def unprocessable_entity(message, details: nil, request_id: nil)
      build(
        status: :unprocessable_entity,
        error: "unprocessable_entity",
        message: message,
        details: details,
        request_id: request_id
      )
    end

    def too_many_requests(message = "Rate limit exceeded", retry_after: nil, request_id: nil)
      response = build(
        status: :too_many_requests,
        error: "too_many_requests",
        message: message,
        request_id: request_id
      )

      response[:retry_after] = retry_after if retry_after.present?

      response
    end

    def internal_server_error(message = "Internal server error", request_id: nil)
      build(
        status: :internal_server_error,
        error: "internal_server_error",
        message: message,
        request_id: request_id
      )
    end

    def service_unavailable(message = "Service temporarily unavailable", request_id: nil)
      build(
        status: :service_unavailable,
        error: "service_unavailable",
        message: message,
        request_id: request_id
      )
    end

    def gateway_timeout(message = "Gateway timeout", request_id: nil)
      build(
        status: :gateway_timeout,
        error: "gateway_timeout",
        message: message,
        request_id: request_id
      )
    end

    # Build error response from exception
    #
    # @param exception [Exception] the exception to convert
    # @param request_id [String, nil] request ID for tracing
    # @return [Hash] the error response hash
    def from_exception(exception, request_id: nil)
      case exception
      when ActiveRecord::RecordNotFound
        not_found("#{exception.model || 'Resource'} not found", request_id: request_id)
      when ActiveRecord::RecordInvalid
        unprocessable_entity(
          "Validation failed",
          details: exception.record&.errors&.full_messages,
          request_id: request_id
        )
      when ActionController::ParameterMissing
        bad_request("Required parameter missing: #{exception.param}", request_id: request_id)
      else
        internal_server_error(request_id: request_id)
      end
    end

    private

    def normalize_status(status)
      case status
      when Symbol
        STATUS_CODES[status] || 500
      when Integer
        status
      else
        500
      end
    end
  end
end
