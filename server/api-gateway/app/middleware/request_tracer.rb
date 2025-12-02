# frozen_string_literal: true

# Rack middleware for distributed request tracing
# Generates or forwards request IDs and logs request lifecycle
#
# Usage: Add to middleware stack in application.rb
#   config.middleware.use RequestTracer
#
class RequestTracer
  REQUEST_ID_HEADER = "X-Request-ID"
  CORRELATION_ID_HEADER = "X-Correlation-ID"

  def initialize(app)
    @app = app
  end

  def call(env)
    request_id = extract_or_generate_request_id(env)
    correlation_id = extract_correlation_id(env)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Store request ID in thread local for access throughout the request
    Thread.current[:request_id] = request_id
    Thread.current[:correlation_id] = correlation_id

    # Add request ID to Rack env for Rails access
    env["action_dispatch.request_id"] = request_id

    # Log request start
    log_request_start(env, request_id)

    # Process the request
    status, headers, response = @app.call(env)

    # Calculate duration
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration_ms = ((end_time - start_time) * 1000).round(2)

    # Add request ID to response headers
    headers[REQUEST_ID_HEADER] = request_id
    headers[CORRELATION_ID_HEADER] = correlation_id if correlation_id

    # Log request completion
    log_request_complete(env, request_id, status, duration_ms)

    [status, headers, response]
  ensure
    # Clean up thread locals
    Thread.current[:request_id] = nil
    Thread.current[:correlation_id] = nil
  end

  private

  # Extracts request ID from incoming header or generates a new one
  def extract_or_generate_request_id(env)
    # Check for incoming request ID (forwarded from load balancer, etc.)
    incoming_id = env["HTTP_X_REQUEST_ID"]

    if incoming_id.present? && valid_request_id?(incoming_id)
      incoming_id
    else
      generate_request_id
    end
  end

  # Extracts correlation ID for linking related requests
  def extract_correlation_id(env)
    env["HTTP_X_CORRELATION_ID"]
  end

  # Generates a unique request ID
  # Format: timestamp_ms-random_hex (for sortability and uniqueness)
  def generate_request_id
    timestamp = (Time.current.to_f * 1000).to_i.to_s(36)
    random = SecureRandom.hex(8)
    "#{timestamp}-#{random}"
  end

  # Validates incoming request ID format
  # Prevents injection of malicious content
  def valid_request_id?(id)
    return false if id.nil?
    return false if id.length > 64 # Reasonable max length

    # Allow alphanumeric, hyphens, and underscores
    id.match?(/\A[a-zA-Z0-9_-]+\z/)
  end

  def log_request_start(env, request_id)
    request = Rack::Request.new(env)

    Rails.logger.info(
      {
        event: "request_started",
        request_id: request_id,
        method: request.request_method,
        path: request.path,
        query_string: sanitize_query_string(request.query_string),
        remote_ip: extract_client_ip(env),
        user_agent: request.user_agent&.truncate(200)
      }.compact.to_json
    )
  end

  def log_request_complete(env, request_id, status, duration_ms)
    request = Rack::Request.new(env)

    log_level = status >= 500 ? :error : (status >= 400 ? :warn : :info)

    Rails.logger.public_send(
      log_level,
      {
        event: "request_completed",
        request_id: request_id,
        method: request.request_method,
        path: request.path,
        status: status,
        duration_ms: duration_ms,
        remote_ip: extract_client_ip(env)
      }.to_json
    )
  end

  # Sanitizes query string to remove sensitive parameters
  def sanitize_query_string(query_string)
    return nil if query_string.blank?

    sensitive_params = %w[password token api_key secret access_token refresh_token]

    params = Rack::Utils.parse_query(query_string)
    params.each do |key, _value|
      params[key] = "[FILTERED]" if sensitive_params.any? { |p| key.downcase.include?(p) }
    end

    Rack::Utils.build_query(params)
  end

  # Extracts client IP, considering proxy headers
  def extract_client_ip(env)
    # Check X-Forwarded-For first (from load balancers/proxies)
    forwarded_for = env["HTTP_X_FORWARDED_FOR"]
    if forwarded_for.present?
      # Take the first IP (original client)
      return forwarded_for.split(",").first.strip
    end

    # Check X-Real-IP
    real_ip = env["HTTP_X_REAL_IP"]
    return real_ip if real_ip.present?

    # Fall back to REMOTE_ADDR
    env["REMOTE_ADDR"]
  end
end
