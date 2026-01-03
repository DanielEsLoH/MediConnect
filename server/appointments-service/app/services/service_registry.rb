# frozen_string_literal: true

# Service Registry for managing microservice URLs and health status
# Implements the Circuit Breaker pattern to handle service failures gracefully
#
# Thread-safe implementation using Redis for distributed state management.
# Circuit breaker prevents cascade failures when downstream services are unhealthy.
#
# @example Getting a service URL
#   ServiceRegistry.url_for(:doctors)
#   # => "http://doctors-service:3002"
#
# @example Checking if service is healthy
#   ServiceRegistry.healthy?(:doctors)
#   # => true
#
# @example Test mode (bypasses Redis)
#   ServiceRegistry.test_mode = true
#   ServiceRegistry.test_circuit_state = :open  # Simulate open circuit
#
class ServiceRegistry
  class ServiceNotFound < StandardError; end
  class CircuitOpen < StandardError; end

  CIRCUIT_CLOSED = :closed
  CIRCUIT_OPEN = :open
  CIRCUIT_HALF_OPEN = :half_open

  # Test mode configuration - allows tests to bypass Redis entirely
  class << self
    attr_accessor :test_mode, :test_circuit_state, :test_allow_requests

    def reset_test_mode!
      @test_mode = false
      @test_circuit_state = CIRCUIT_CLOSED
      @test_allow_requests = true
      @redis = nil
    end
  end

  # Initialize test mode settings
  @test_mode = false
  @test_circuit_state = CIRCUIT_CLOSED
  @test_allow_requests = true

  FAILURE_THRESHOLD = ENV.fetch("CIRCUIT_FAILURE_THRESHOLD", 5).to_i
  SUCCESS_THRESHOLD = ENV.fetch("CIRCUIT_SUCCESS_THRESHOLD", 2).to_i
  OPEN_TIMEOUT = ENV.fetch("CIRCUIT_OPEN_TIMEOUT", 30).to_i.seconds
  FAILURE_WINDOW = ENV.fetch("CIRCUIT_FAILURE_WINDOW", 60).to_i.seconds

  SERVICES = {
    users: {
      env_key: "USERS_SERVICE_URL",
      default_url: "http://users-service:3001",
      health_path: "/health",
      internal_path_prefix: "/internal"
    },
    doctors: {
      env_key: "DOCTORS_SERVICE_URL",
      default_url: "http://doctors-service:3002",
      health_path: "/health",
      internal_path_prefix: "/internal"
    },
    appointments: {
      env_key: "APPOINTMENTS_SERVICE_URL",
      default_url: "http://appointments-service:3003",
      health_path: "/health",
      internal_path_prefix: "/internal"
    },
    notifications: {
      env_key: "NOTIFICATIONS_SERVICE_URL",
      default_url: "http://notifications-service:3004",
      health_path: "/health",
      internal_path_prefix: "/internal"
    },
    payments: {
      env_key: "PAYMENTS_SERVICE_URL",
      default_url: "http://payments-service:3005",
      health_path: "/health",
      internal_path_prefix: "/internal"
    }
  }.freeze

  class << self
    def url_for(service_name)
      service = find_service(service_name)
      ENV.fetch(service[:env_key], service[:default_url])
    end

    def health_endpoint(service_name)
      "#{url_for(service_name)}#{health_path_for(service_name)}"
    end

    def health_path_for(service_name)
      service = find_service(service_name)
      service[:health_path]
    end

    def internal_path_prefix(service_name)
      service = find_service(service_name)
      service[:internal_path_prefix]
    end

    def all_services
      SERVICES.transform_values do |config|
        {
          url: ENV.fetch(config[:env_key], config[:default_url]),
          health_path: config[:health_path]
        }
      end
    end

    def service_names
      SERVICES.keys
    end

    def registered?(service_name)
      SERVICES.key?(service_name.to_sym)
    end

    def healthy?(service_name)
      circuit_state(service_name) != CIRCUIT_OPEN
    end

    def allow_request?(service_name)
      # In test mode, use the test configuration
      return @test_allow_requests if @test_mode

      state = circuit_state(service_name)

      case state
      when CIRCUIT_CLOSED
        true
      when CIRCUIT_HALF_OPEN
        true
      when CIRCUIT_OPEN
        if circuit_open_timeout_elapsed?(service_name)
          transition_to_half_open(service_name)
          true
        else
          false
        end
      else
        true
      end
    end

    def record_success(service_name)
      # In test mode, skip Redis operations
      return if @test_mode
      return unless redis_available?

      state = circuit_state(service_name)

      case state
      when CIRCUIT_HALF_OPEN
        increment_success_count(service_name)
        if success_count(service_name) >= SUCCESS_THRESHOLD
          transition_to_closed(service_name)
          Rails.logger.info("[ServiceRegistry] Circuit CLOSED for #{service_name}")
        end
      when CIRCUIT_CLOSED
        reset_failure_count(service_name)
      end
    end

    def record_failure(service_name)
      # In test mode, skip Redis operations
      return if @test_mode
      return unless redis_available?

      state = circuit_state(service_name)

      case state
      when CIRCUIT_CLOSED
        increment_failure_count(service_name)
        if failure_count(service_name) >= FAILURE_THRESHOLD
          transition_to_open(service_name)
          Rails.logger.warn("[ServiceRegistry] Circuit OPENED for #{service_name}")
        end
      when CIRCUIT_HALF_OPEN
        transition_to_open(service_name)
        Rails.logger.warn("[ServiceRegistry] Circuit re-OPENED for #{service_name}")
      end
    end

    def circuit_state(service_name)
      # In test mode, return the test circuit state
      return @test_circuit_state if @test_mode
      return CIRCUIT_CLOSED unless redis_available?

      state = redis.get(circuit_state_key(service_name))
      state&.to_sym || CIRCUIT_CLOSED
    end

    def circuit_status
      SERVICES.keys.each_with_object({}) do |service_name, status|
        status[service_name] = {
          state: circuit_state(service_name),
          failures: failure_count(service_name),
          successes: success_count(service_name),
          healthy: healthy?(service_name),
          url: url_for(service_name)
        }
      end
    end

    def reset_circuit(service_name)
      return unless redis_available?

      redis.multi do |multi|
        multi.del(circuit_state_key(service_name))
        multi.del(failure_count_key(service_name))
        multi.del(success_count_key(service_name))
        multi.del(circuit_opened_at_key(service_name))
      end

      Rails.logger.info("[ServiceRegistry] Circuit reset for #{service_name}")
    end

    def reset_all_circuits
      SERVICES.keys.each { |service| reset_circuit(service) }
    end

    def redis_available?
      redis.ping == "PONG"
    rescue StandardError => e
      Rails.logger.warn("[ServiceRegistry] Redis unavailable: #{e.message}")
      false
    end

    private

    def find_service(service_name)
      name = service_name.to_sym
      SERVICES[name] || raise(ServiceNotFound, "Service '#{service_name}' not found in registry")
    end

    def service_key(service_name)
      service_name.to_s.downcase
    end

    def circuit_state_key(service_name)
      "circuit:#{service_key(service_name)}:state"
    end

    def failure_count_key(service_name)
      "circuit:#{service_key(service_name)}:failures"
    end

    def success_count_key(service_name)
      "circuit:#{service_key(service_name)}:successes"
    end

    def circuit_opened_at_key(service_name)
      "circuit:#{service_key(service_name)}:opened_at"
    end

    def transition_to_open(service_name)
      redis.multi do |multi|
        multi.set(circuit_state_key(service_name), CIRCUIT_OPEN.to_s)
        multi.set(circuit_opened_at_key(service_name), Time.current.to_i.to_s)
        multi.del(success_count_key(service_name))
      end
    end

    def transition_to_half_open(service_name)
      Rails.logger.info("[ServiceRegistry] Circuit HALF-OPEN for #{service_name}")

      redis.multi do |multi|
        multi.set(circuit_state_key(service_name), CIRCUIT_HALF_OPEN.to_s)
        multi.del(success_count_key(service_name))
      end
    end

    def transition_to_closed(service_name)
      redis.multi do |multi|
        multi.del(circuit_state_key(service_name))
        multi.del(failure_count_key(service_name))
        multi.del(success_count_key(service_name))
        multi.del(circuit_opened_at_key(service_name))
      end
    end

    def failure_count(service_name)
      return 0 unless redis_available?
      redis.get(failure_count_key(service_name)).to_i
    end

    def success_count(service_name)
      return 0 unless redis_available?
      redis.get(success_count_key(service_name)).to_i
    end

    def increment_failure_count(service_name)
      key = failure_count_key(service_name)
      redis.multi do |multi|
        multi.incr(key)
        multi.expire(key, FAILURE_WINDOW.to_i)
      end
    end

    def increment_success_count(service_name)
      redis.incr(success_count_key(service_name))
    end

    def reset_failure_count(service_name)
      redis.del(failure_count_key(service_name))
    end

    def circuit_open_timeout_elapsed?(service_name)
      opened_at = redis.get(circuit_opened_at_key(service_name))
      return true if opened_at.nil?

      Time.at(opened_at.to_i) + OPEN_TIMEOUT < Time.current
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/3"))
    end
  end
end
