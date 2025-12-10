# frozen_string_literal: true

# HTTP client for making requests to backend microservices
# Uses Faraday with retry middleware and circuit breaker integration
#
# @example Making a GET request
#   response = HttpClient.get(:users, "/api/users/1")
#   if response.success?
#     user = response.body
#   end
#
# @example Making a POST request with body
#   response = HttpClient.post(:appointments, "/api/appointments", {
#     patient_id: 1,
#     doctor_id: 2,
#     scheduled_at: Time.current
#   })
#
class HttpClient
  # Custom errors
  class ServiceUnavailable < StandardError; end
  class CircuitOpen < StandardError; end
  class RequestTimeout < StandardError; end
  class ClientError < StandardError; end
  class ServerError < StandardError; end

  # Response wrapper for consistent interface
  class Response
    attr_reader :status, :body, :headers

    def initialize(status:, body:, headers:)
      @status = status
      @body = body
      @headers = headers
    end

    def success?
      status.between?(200, 299)
    end

    def redirect?
      status.between?(300, 399)
    end

    def client_error?
      status.between?(400, 499)
    end

    def server_error?
      status.between?(500, 599)
    end
  end

  # Default configuration
  DEFAULT_TIMEOUT = 10
  DEFAULT_OPEN_TIMEOUT = 5
  DEFAULT_MAX_RETRIES = 3
  RETRY_STATUSES = [ 408, 429, 500, 502, 503, 504 ].freeze
  RETRY_EXCEPTIONS = [
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Errno::ECONNREFUSED,
    Errno::ETIMEDOUT
  ].freeze

  class << self
    # Performs a GET request
    #
    # @param service [Symbol] service name from ServiceRegistry
    # @param path [String] request path
    # @param params [Hash] query parameters
    # @param headers [Hash] additional headers
    # @return [Response] the response wrapper
    def get(service, path, params: {}, headers: {})
      request(:get, service, path, params: params, headers: headers)
    end

    # Performs a POST request
    #
    # @param service [Symbol] service name from ServiceRegistry
    # @param path [String] request path
    # @param body [Hash] request body
    # @param headers [Hash] additional headers
    # @return [Response] the response wrapper
    def post(service, path, body = {}, headers: {})
      request(:post, service, path, body: body, headers: headers)
    end

    # Performs a PUT request
    #
    # @param service [Symbol] service name from ServiceRegistry
    # @param path [String] request path
    # @param body [Hash] request body
    # @param headers [Hash] additional headers
    # @return [Response] the response wrapper
    def put(service, path, body = {}, headers: {})
      request(:put, service, path, body: body, headers: headers)
    end

    # Performs a PATCH request
    #
    # @param service [Symbol] service name from ServiceRegistry
    # @param path [String] request path
    # @param body [Hash] request body
    # @param headers [Hash] additional headers
    # @return [Response] the response wrapper
    def patch(service, path, body = {}, headers: {})
      request(:patch, service, path, body: body, headers: headers)
    end

    # Performs a DELETE request
    #
    # @param service [Symbol] service name from ServiceRegistry
    # @param path [String] request path
    # @param headers [Hash] additional headers
    # @return [Response] the response wrapper
    def delete(service, path, headers: {})
      request(:delete, service, path, headers: headers)
    end

    # Performs a health check on a service
    #
    # @param service [Symbol] service name from ServiceRegistry
    # @return [Hash] health status with response time
    def health_check(service)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      health_path = ServiceRegistry.health_path_for(service)

      response = get(service, health_path)
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      {
        status: response.success? ? "ok" : "error",
        response_time_ms: ((end_time - start_time) * 1000).round(2),
        http_status: response.status
      }
    rescue StandardError => e
      {
        status: "error",
        error: e.message,
        http_status: nil
      }
    end

    private

    def request(method, service, path, body: nil, params: {}, headers: {})
      # Check circuit breaker
      unless ServiceRegistry.allow_request?(service)
        raise CircuitOpen, "Circuit breaker is open for service: #{service}"
      end

      base_url = ServiceRegistry.url_for(service)
      connection = build_connection(base_url)

      # Merge default headers
      request_headers = default_headers.merge(headers)

      response = connection.public_send(method) do |req|
        req.url path
        req.headers.merge!(request_headers)
        req.params = params.to_h if params.present?
        req.body = body.to_json if body
      end

      # Record success with circuit breaker
      ServiceRegistry.record_success(service)

      Response.new(
        status: response.status,
        body: parse_body(response.body),
        headers: response.headers.to_h
      )
    rescue Faraday::TimeoutError => e
      ServiceRegistry.record_failure(service)
      raise RequestTimeout, "Request to #{service} timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      ServiceRegistry.record_failure(service)
      raise ServiceUnavailable, "Cannot connect to #{service}: #{e.message}"
    rescue ServiceRegistry::ServiceNotFound
      raise
    rescue StandardError => e
      ServiceRegistry.record_failure(service)
      Rails.logger.error("HTTP Client error for #{service}: #{e.class} - #{e.message}")
      raise ServiceUnavailable, "Service #{service} unavailable: #{e.message}"
    end

    def build_connection(base_url)
      Faraday.new(url: base_url) do |conn|
        # Request middleware
        conn.request :json

        # Response middleware
        conn.response :json, content_type: /\bjson$/

        # Retry middleware with exponential backoff
        conn.request :retry, {
          max: max_retries,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: RETRY_STATUSES,
          exceptions: RETRY_EXCEPTIONS,
          retry_block: ->(env, opts, retries, exc) {
            Rails.logger.warn("Retrying request to #{env.url} (attempt #{retries + 1}): #{exc&.message}")
          }
        }

        # Timeout configuration
        conn.options.timeout = timeout
        conn.options.open_timeout = open_timeout

        # Adapter
        conn.adapter Faraday.default_adapter
      end
    end

    def default_headers
      headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => "MediConnect-API-Gateway/1.0",
        "X-Internal-Service" => "api-gateway"
      }

      # Add request ID for distributed tracing if available
      if Thread.current[:request_id]
        headers["X-Request-ID"] = Thread.current[:request_id]
      end

      # Add forwarded user ID if available
      if Thread.current[:current_user_id]
        headers["X-User-ID"] = Thread.current[:current_user_id].to_s
      end

      headers
    end

    def parse_body(body)
      return {} if body.nil? || body.empty?
      return body if body.is_a?(Hash) || body.is_a?(Array)

      JSON.parse(body)
    rescue JSON::ParserError
      { raw: body }
    end

    def timeout
      ENV.fetch("HTTP_CLIENT_TIMEOUT", DEFAULT_TIMEOUT).to_i
    end

    def open_timeout
      ENV.fetch("HTTP_CLIENT_OPEN_TIMEOUT", DEFAULT_OPEN_TIMEOUT).to_i
    end

    def max_retries
      ENV.fetch("HTTP_CLIENT_MAX_RETRIES", DEFAULT_MAX_RETRIES).to_i
    end
  end
end
