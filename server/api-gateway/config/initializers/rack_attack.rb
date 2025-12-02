# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and request throttling
# Protects the API from abuse and DDoS attacks
#
# Rate limits:
# - Login attempts: 5 per minute per IP
# - API requests (unauthenticated): 100 per minute per IP
# - API requests (authenticated): 1000 per minute per user
#
class Rack::Attack
  # Use Redis as the cache store for distributed rate limiting
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    namespace: "rack_attack"
  )

  ### Safelist Rules ###

  # Allow all requests from localhost in development
  safelist("allow-localhost") do |req|
    Rails.env.development? && (req.ip == "127.0.0.1" || req.ip == "::1")
  end

  # Always allow health check endpoints
  safelist("allow-health-checks") do |req|
    req.path == "/health" || req.path == "/up" || req.path == "/health/services"
  end

  ### Throttle Rules ###

  # Throttle login attempts by IP address
  # Prevents brute force attacks on authentication
  throttle("logins/ip", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email (prevent credential stuffing)
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      # Normalize the email
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind # Important: rewind for downstream processing
        body["email"]&.to_s&.downcase&.strip
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Throttle password reset requests
  throttle("password-reset/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/api/v1/auth/password/reset" && req.post?
      req.ip
    end
  end

  # Throttle refresh token requests
  throttle("refresh/ip", limit: 10, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/refresh" && req.post?
      req.ip
    end
  end

  # Throttle unauthenticated API requests by IP
  # Default: 100 requests per minute
  throttle("api/ip", limit: proc { rate_limit_unauthenticated }, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && !authenticated_request?(req)
      req.ip
    end
  end

  # Throttle authenticated API requests by user ID
  # Default: 1000 requests per minute
  throttle("api/user", limit: proc { rate_limit_authenticated }, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      user_id = extract_user_id_from_token(req)
      user_id if user_id.present?
    end
  end

  # Block suspicious requests (SQL injection patterns)
  blocklist("block-sql-injection") do |req|
    # Check query string and path for SQL injection patterns
    dangerous = /(\b(union|select|insert|update|delete|drop|truncate)\b.*\b(from|into|set|table)\b)/i

    req.query_string&.match?(dangerous) || req.path&.match?(dangerous)
  end

  # Block requests with invalid characters in path
  blocklist("block-bad-paths") do |req|
    req.path.include?("..") || req.path.include?("\x00")
  end

  ### Custom Response ###

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    # Calculate retry time
    retry_after = match_data[:period] - (now % match_data[:period])

    headers = {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after.to_s,
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => (now + retry_after).to_s
    }

    body = {
      status: 429,
      error: "too_many_requests",
      message: "Rate limit exceeded. Please retry after #{retry_after} seconds.",
      retry_after: retry_after,
      request_id: request.env["action_dispatch.request_id"] || Thread.current[:request_id]
    }.to_json

    [429, headers, [body]]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |request|
    headers = { "Content-Type" => "application/json" }

    body = {
      status: 403,
      error: "forbidden",
      message: "Request blocked",
      request_id: request.env["action_dispatch.request_id"] || Thread.current[:request_id]
    }.to_json

    [403, headers, [body]]
  end

  ### Logging ###

  # Log throttled requests
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      {
        event: "rate_limit_exceeded",
        ip: req.ip,
        path: req.path,
        method: req.request_method,
        matched: req.env["rack.attack.matched"],
        discriminator: req.env["rack.attack.match_discriminator"],
        request_id: req.env["action_dispatch.request_id"]
      }.to_json
    )
  end

  # Log blocked requests
  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      {
        event: "request_blocked",
        ip: req.ip,
        path: req.path,
        method: req.request_method,
        matched: req.env["rack.attack.matched"],
        request_id: req.env["action_dispatch.request_id"]
      }.to_json
    )
  end

  ### Helper Methods ###

  class << self
    def rate_limit_unauthenticated
      ENV.fetch("RATE_LIMIT_REQUESTS_PER_MINUTE", 100).to_i
    end

    def rate_limit_authenticated
      ENV.fetch("RATE_LIMIT_AUTHENTICATED_REQUESTS_PER_MINUTE", 1000).to_i
    end

    def authenticated_request?(req)
      req.env["HTTP_AUTHORIZATION"].present?
    end

    def extract_user_id_from_token(req)
      auth_header = req.env["HTTP_AUTHORIZATION"]
      return nil if auth_header.blank?

      token = auth_header.split(" ").last
      return nil if token.blank?

      begin
        payload = JsonWebToken.decode(token)
        payload[:user_id]
      rescue StandardError
        nil
      end
    end
  end
end
