# frozen_string_literal: true

require "net/http"
require "json"

class HttpClient
  class ServiceUnavailableError < StandardError; end
  class CircuitOpenError < StandardError; end

  CIRCUIT_BREAKER_THRESHOLD = 5
  CIRCUIT_BREAKER_TIMEOUT = 60 # seconds

  class << self
    def get(url, headers: {}, timeout: 5)
      request(:get, url, headers: headers, timeout: timeout)
    end

    def post(url, body:, headers: {}, timeout: 5)
      request(:post, url, body: body, headers: headers, timeout: timeout)
    end

    def put(url, body:, headers: {}, timeout: 5)
      request(:put, url, body: body, headers: headers, timeout: timeout)
    end

    def delete(url, headers: {}, timeout: 5)
      request(:delete, url, headers: headers, timeout: timeout)
    end

    private

    def request(method, url, body: nil, headers: {}, timeout: 5)
      check_circuit_breaker!(url)

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout
      http.read_timeout = timeout

      request = build_request(method, uri, body, headers)
      response = http.request(request)

      handle_response(response, url)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      record_failure(url)
      Rails.logger.error("HTTP request failed: #{e.message}")
      raise ServiceUnavailableError, "Service unavailable: #{e.message}"
    rescue StandardError => e
      record_failure(url)
      Rails.logger.error("Unexpected error in HTTP request: #{e.message}")
      raise
    end

    def build_request(method, uri, body, headers)
      request_class = case method
                      when :get then Net::HTTP::Get
                      when :post then Net::HTTP::Post
                      when :put then Net::HTTP::Put
                      when :delete then Net::HTTP::Delete
                      end

      request = request_class.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      headers.each { |key, value| request[key] = value }

      request.body = body.to_json if body && [:post, :put].include?(method)
      request
    end

    def handle_response(response, url)
      case response.code.to_i
      when 200..299
        reset_circuit_breaker(url)
        JSON.parse(response.body) if response.body.present?
      when 400..499
        Rails.logger.warn("Client error: #{response.code} - #{response.body}")
        { error: "Client error", status: response.code.to_i, message: response.body }
      when 500..599
        record_failure(url)
        Rails.logger.error("Server error: #{response.code} - #{response.body}")
        raise ServiceUnavailableError, "Server error: #{response.code}"
      else
        Rails.logger.warn("Unexpected response code: #{response.code}")
        { error: "Unexpected response", status: response.code.to_i }
      end
    end

    def check_circuit_breaker!(url)
      circuit_key = circuit_breaker_key(url)
      failure_count = Rails.cache.read("#{circuit_key}:failures") || 0
      last_failure_time = Rails.cache.read("#{circuit_key}:last_failure")

      if failure_count >= CIRCUIT_BREAKER_THRESHOLD
        if last_failure_time && (Time.current - last_failure_time) < CIRCUIT_BREAKER_TIMEOUT
          Rails.logger.warn("Circuit breaker open for #{url}")
          raise CircuitOpenError, "Circuit breaker is open for #{url}"
        else
          # Reset circuit breaker after timeout
          reset_circuit_breaker(url)
        end
      end
    end

    def record_failure(url)
      circuit_key = circuit_breaker_key(url)
      failure_count = Rails.cache.read("#{circuit_key}:failures") || 0
      Rails.cache.write("#{circuit_key}:failures", failure_count + 1, expires_in: CIRCUIT_BREAKER_TIMEOUT)
      Rails.cache.write("#{circuit_key}:last_failure", Time.current, expires_in: CIRCUIT_BREAKER_TIMEOUT)
    end

    def reset_circuit_breaker(url)
      circuit_key = circuit_breaker_key(url)
      Rails.cache.delete("#{circuit_key}:failures")
      Rails.cache.delete("#{circuit_key}:last_failure")
    end

    def circuit_breaker_key(url)
      uri = URI.parse(url)
      "circuit_breaker:#{uri.host}:#{uri.port}"
    end
  end
end
