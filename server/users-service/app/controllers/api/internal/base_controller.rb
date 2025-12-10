# frozen_string_literal: true

module Api
  module Internal
    # Base controller for internal service-to-service API endpoints
  # These endpoints are called by other microservices, not external clients
  #
  # Security:
  #   - Validates X-Internal-Service header to ensure request is from another service
  #   - No JWT authentication required (service-to-service trust)
  #   - Should be protected at network level (only accessible within Docker network)
  #
  # Usage:
  #   All internal controllers should inherit from this class
  #
  class BaseController < ActionController::API
    include ActionController::MimeResponds

    before_action :verify_internal_request
    before_action :set_request_context

    # Handle common errors
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActionController::ParameterMissing, with: :parameter_missing

    private

    # Verify the request is coming from an internal service
    # In production, this should be combined with network-level security
    def verify_internal_request
      internal_service = request.headers["X-Internal-Service"]

      unless internal_service.present?
        Rails.logger.warn(
          "[Internal API] Request rejected - missing X-Internal-Service header " \
          "[ip=#{request.remote_ip}] [path=#{request.path}]"
        )
        render json: { error: "Unauthorized - internal service header required" }, status: :unauthorized
        return
      end

      Rails.logger.info(
        "[Internal API] Request from #{internal_service} " \
        "[request_id=#{request.headers['X-Request-ID']}] [path=#{request.path}]"
      )
    end

    # Set request context for logging and correlation
    def set_request_context
      Thread.current[:request_id] = request.headers["X-Request-ID"] || SecureRandom.uuid
      Thread.current[:correlation_id] = request.headers["X-Correlation-ID"]
      Thread.current[:calling_service] = request.headers["X-Internal-Service"]
    end

    def record_not_found(exception)
      Rails.logger.info("[Internal API] Record not found: #{exception.message}")
      render json: { error: "Record not found", details: exception.message }, status: :not_found
    end

    def parameter_missing(exception)
      Rails.logger.warn("[Internal API] Parameter missing: #{exception.message}")
      render json: { error: "Parameter missing", details: exception.message }, status: :bad_request
    end
  end
end
end
