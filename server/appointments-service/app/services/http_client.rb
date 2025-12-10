# frozen_string_literal: true

# Production-grade HTTP client for service-to-service communication
# Features:
#   - Circuit breaker integration via ServiceRegistry
#   - Automatic retry with exponential backoff
#   - Request/response logging with correlation IDs
#   - JWT token propagation for authenticated calls
#   - Configurable timeouts
#   - Thread-safe implementation
#
# @example Basic GET request
#   response = HttpClient.get(:users, "/internal/users/#{user_id}")
#   if response.success?
#     user = response.body
#   end
#
# @example Validate doctor availability
#   response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}/availability",
#     params: { date: appointment_date.to_s }
#   )
#
class HttpClient
  class ServiceUnavailable < StandardError; end
  class CircuitOpen < StandardError; end
  class RequestTimeout < StandardError; end
  class ClientError < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end
  class ServerError < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end

  class Response
    attr_reader :status, :body, :headers, :duration_ms

    def initialize(status:, body:, headers:, duration_ms: 0)
      @status = status
      @body = body
      @headers = headers
      @duration_ms = duration_ms
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

    def not_found?
      status == 404
    end

    def unauthorized?
      status == 401
    end

    def forbidden?
      status == 403
    end

    def unprocessable?
      status == 422
    end

    def dig(*path)
      return body if path.empty?
      return nil unless body.is_a?(Hash)

      body.dig(*path.map(&:to_s))
    end
  end

  DEFAULT_TIMEOUT = ENV.fetch("HTTP_CLIENT_TIMEOUT", 10).to_i
  DEFAULT_OPEN_TIMEOUT = ENV.fetch("HTTP_CLIENT_OPEN_TIMEOUT", 5).to_i
  DEFAULT_MAX_RETRIES = ENV.fetch("HTTP_CLIENT_MAX_RETRIES", 3).to_i
  DEFAULT_RETRY_INTERVAL = ENV.fetch("HTTP_CLIENT_RETRY_INTERVAL", 0.5).to_f

  RETRY_STATUSES = [408, 429, 500, 502, 503, 504].freeze
  RETRY_EXCEPTIONS = [
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Errno::ECONNREFUSED,
    Errno::ETIMEDOUT,
    Errno::ECONNRESET
  ].freeze

  class << self
    def get(service, path, params: {}, headers: {}, timeout: nil)
      request(:get, service, path, params: params, headers: headers, timeout: timeout)
    end

    def post(service, path, body = {}, headers: {}, timeout: nil)
      request(:post, service, path, body: body, headers: headers, timeout: timeout)
    end

    def put(service, path, body = {}, headers: {}, timeout: nil)
      request(:put, service, path, body: body, headers: headers, timeout: timeout)
    end

    def patch(service, path, body = {}, headers: {}, timeout: nil)
      request(:patch, service, path, body: body, headers: headers, timeout: timeout)
    end

    def delete(service, path, headers: {}, timeout: nil)
      request(:delete, service, path, headers: headers, timeout: timeout)
    end

    def health_check(service)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      health_path = ServiceRegistry.health_path_for(service)

      response = get(service, health_path)
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      {
        service: service,
        status: response.success? ? "healthy" : "unhealthy",
        response_time_ms: ((end_time - start_time) * 1000).round(2),
        http_status: response.status,
        circuit_state: ServiceRegistry.circuit_state(service)
      }
    rescue CircuitOpen
      {
        service: service,
        status: "circuit_open",
        response_time_ms: nil,
        http_status: nil,
        circuit_state: :open
      }
    rescue StandardError => e
      {
        service: service,
        status: "error",
        error: e.message,
        http_status: nil,
        circuit_state: ServiceRegistry.circuit_state(service)
      }
    end

    def health_check_all
      ServiceRegistry.service_names.each_with_object({}) do |service, results|
        results[service] = health_check(service)
      end
    end

    private

    def request(method, service, path, body: nil, params: {}, headers: {}, timeout: nil)
      unless ServiceRegistry.allow_request?(service)
        raise CircuitOpen, "Circuit breaker is open for service: #{service}"
      end

      base_url = ServiceRegistry.url_for(service)
      connection = build_connection(base_url, timeout: timeout)
      request_headers = build_headers(headers)
      request_id = request_headers["X-Request-ID"]

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      log_request(service, method, path, request_id)

      response = connection.public_send(method) do |req|
        req.url path
        req.headers.merge!(request_headers)
        req.params = params if params.any?
        req.body = body.to_json if body
      end

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration_ms = ((end_time - start_time) * 1000).round(2)

      ServiceRegistry.record_success(service)

      log_response(service, method, path, response.status, duration_ms, request_id)

      Response.new(
        status: response.status,
        body: parse_body(response.body),
        headers: response.headers.to_h,
        duration_ms: duration_ms
      )
    rescue Faraday::TimeoutError => e
      ServiceRegistry.record_failure(service)
      log_error(service, method, path, "Timeout", request_id)
      raise RequestTimeout, "Request to #{service}#{path} timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      ServiceRegistry.record_failure(service)
      log_error(service, method, path, "Connection failed", request_id)
      raise ServiceUnavailable, "Cannot connect to #{service}: #{e.message}"
    rescue ServiceRegistry::ServiceNotFound
      raise
    rescue StandardError => e
      ServiceRegistry.record_failure(service)
      log_error(service, method, path, e.message, request_id)
      raise ServiceUnavailable, "Service #{service} unavailable: #{e.message}"
    end

    def build_connection(base_url, timeout: nil)
      request_timeout = timeout || DEFAULT_TIMEOUT

      Faraday.new(url: base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/

        conn.request :retry, {
          max: DEFAULT_MAX_RETRIES,
          interval: DEFAULT_RETRY_INTERVAL,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: RETRY_STATUSES,
          exceptions: RETRY_EXCEPTIONS,
          retry_block: ->(env, _opts, retries, exc) {
            Rails.logger.warn(
              "[HttpClient] Retry #{retries}/#{DEFAULT_MAX_RETRIES} for #{env.method.upcase} #{env.url}: #{exc&.message}"
            )
          }
        }

        conn.options.timeout = request_timeout
        conn.options.open_timeout = DEFAULT_OPEN_TIMEOUT
        conn.adapter Faraday.default_adapter
      end
    end

    def build_headers(custom_headers)
      headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => "MediConnect-AppointmentsService/1.0"
      }

      request_id = Thread.current[:request_id] || SecureRandom.uuid
      headers["X-Request-ID"] = request_id

      if Thread.current[:correlation_id]
        headers["X-Correlation-ID"] = Thread.current[:correlation_id]
      end

      if Thread.current[:auth_token]
        headers["Authorization"] = "Bearer #{Thread.current[:auth_token]}"
      end

      if Thread.current[:current_user_id]
        headers["X-User-ID"] = Thread.current[:current_user_id].to_s
      end

      headers["X-Internal-Service"] = "appointments-service"
      headers["X-Service-Version"] = "1.0"

      headers.merge(custom_headers)
    end

    def parse_body(body)
      return {} if body.nil?
      return {} if body.is_a?(String) && body.empty?
      return body if body.is_a?(Hash) || body.is_a?(Array)

      JSON.parse(body)
    rescue JSON::ParserError
      { raw: body }
    end

    def log_request(service, method, path, request_id)
      Rails.logger.info(
        "[HttpClient] Request: #{method.to_s.upcase} #{service}#{path} [request_id=#{request_id}]"
      )
    end

    def log_response(service, method, path, status, duration_ms, request_id)
      log_level = status >= 400 ? :warn : :info
      Rails.logger.public_send(
        log_level,
        "[HttpClient] Response: #{method.to_s.upcase} #{service}#{path} status=#{status} duration=#{duration_ms}ms [request_id=#{request_id}]"
      )
    end

    def log_error(service, method, path, error, request_id)
      Rails.logger.error(
        "[HttpClient] Error: #{method.to_s.upcase} #{service}#{path} error=#{error} [request_id=#{request_id}]"
      )
    end
  end
end
