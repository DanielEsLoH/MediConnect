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
# @example Getting health endpoint
#   ServiceRegistry.health_endpoint(:notifications)
#   # => "http://notifications-service:3004/health"
#
class ServiceRegistry
  class ServiceNotFound < StandardError; end
  class CircuitOpen < StandardError; end

  # Circuit breaker states
  CIRCUIT_CLOSED = :closed      # Normal operation - requests allowed
  CIRCUIT_OPEN = :open          # Failing - requests blocked
  CIRCUIT_HALF_OPEN = :half_open # Testing recovery - limited requests allowed

  # Circuit breaker configuration (can be overridden via environment variables)
  FAILURE_THRESHOLD = ENV.fetch("CIRCUIT_FAILURE_THRESHOLD", 5).to_i
  SUCCESS_THRESHOLD = ENV.fetch("CIRCUIT_SUCCESS_THRESHOLD", 2).to_i
  OPEN_TIMEOUT = ENV.fetch("CIRCUIT_OPEN_TIMEOUT", 30).to_i.seconds
  FAILURE_WINDOW = ENV.fetch("CIRCUIT_FAILURE_WINDOW", 60).to_i.seconds

  # Service configuration with environment-based URLs
  # Each service has:
  #   - env_key: Environment variable for production URL override
  #   - default_url: Docker Compose service name (development default)
  #   - health_path: Health check endpoint path
  #   - internal_path_prefix: Prefix for internal API endpoints
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
    # Returns the base URL for a given service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [String] the service base URL
    # @raise [ServiceNotFound] if service is not registered
    #
    # @example
    #   ServiceRegistry.url_for(:doctors)
    #   # => "http://doctors-service:3002"
    def url_for(service_name)
      service = find_service(service_name)
      ENV.fetch(service[:env_key], service[:default_url])
    end

    # Returns the full health check endpoint URL for a service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [String] the full health check URL
    #
    # @example
    #   ServiceRegistry.health_endpoint(:doctors)
    #   # => "http://doctors-service:3002/health"
    def health_endpoint(service_name)
      "#{url_for(service_name)}#{health_path_for(service_name)}"
    end

    # Returns health check path for a service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [String] the health check path
    def health_path_for(service_name)
      service = find_service(service_name)
      service[:health_path]
    end

    # Returns the internal API path prefix for a service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [String] the internal API path prefix
    def internal_path_prefix(service_name)
      service = find_service(service_name)
      service[:internal_path_prefix]
    end

    # Returns all registered services with their URLs
    #
    # @return [Hash] service names mapped to their configuration
    def all_services
      SERVICES.transform_values do |config|
        {
          url: ENV.fetch(config[:env_key], config[:default_url]),
          health_path: config[:health_path]
        }
      end
    end

    # Lists all registered service names
    #
    # @return [Array<Symbol>] array of service names
    def service_names
      SERVICES.keys
    end

    # Checks if a service is registered
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [Boolean] true if service exists in registry
    def registered?(service_name)
      SERVICES.key?(service_name.to_sym)
    end

    # Checks if a service is healthy (circuit breaker is not open)
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [Boolean] true if service is available for requests
    def healthy?(service_name)
      circuit_state(service_name) != CIRCUIT_OPEN
    end

    # Checks if the circuit allows a request through
    # Implements the circuit breaker state machine
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [Boolean] true if request is allowed
    def allow_request?(service_name)
      state = circuit_state(service_name)

      case state
      when CIRCUIT_CLOSED
        true
      when CIRCUIT_HALF_OPEN
        # Allow test request in half-open state
        true
      when CIRCUIT_OPEN
        if circuit_open_timeout_elapsed?(service_name)
          transition_to_half_open(service_name)
          true
        else
          false
        end
      else
        # Default to allowing requests if state is unknown
        true
      end
    end

    # Records a successful request to a service
    # Used by HttpClient after successful responses
    #
    # @param service_name [Symbol, String] the service identifier
    def record_success(service_name)
      return unless redis_available?

      state = circuit_state(service_name)

      case state
      when CIRCUIT_HALF_OPEN
        increment_success_count(service_name)
        if success_count(service_name) >= SUCCESS_THRESHOLD
          transition_to_closed(service_name)
          Rails.logger.info("[ServiceRegistry] Circuit CLOSED for #{service_name} after #{SUCCESS_THRESHOLD} successes")
        end
      when CIRCUIT_CLOSED
        # Reset failure count on success to prevent false positives
        reset_failure_count(service_name)
      end
    end

    # Records a failed request to a service
    # Used by HttpClient after failed requests
    #
    # @param service_name [Symbol, String] the service identifier
    def record_failure(service_name)
      return unless redis_available?

      state = circuit_state(service_name)

      case state
      when CIRCUIT_CLOSED
        increment_failure_count(service_name)
        if failure_count(service_name) >= FAILURE_THRESHOLD
          transition_to_open(service_name)
          Rails.logger.warn("[ServiceRegistry] Circuit OPENED for #{service_name} after #{FAILURE_THRESHOLD} failures")
        end
      when CIRCUIT_HALF_OPEN
        # Any failure in half-open state immediately opens the circuit
        transition_to_open(service_name)
        Rails.logger.warn("[ServiceRegistry] Circuit re-OPENED for #{service_name} after failure in half-open state")
      end
    end

    # Returns current circuit state for a service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [Symbol] :closed, :open, or :half_open
    def circuit_state(service_name)
      return CIRCUIT_CLOSED unless redis_available?

      state = redis.get(circuit_state_key(service_name))
      state&.to_sym || CIRCUIT_CLOSED
    end

    # Returns circuit breaker status for all services
    # Useful for monitoring dashboards
    #
    # @return [Hash] service names mapped to circuit status
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

    # Resets circuit breaker for a specific service
    # Use for manual recovery or testing
    #
    # @param service_name [Symbol, String] the service identifier
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

    # Resets all circuit breakers
    # Use with caution - typically for testing or full system recovery
    def reset_all_circuits
      SERVICES.keys.each { |service| reset_circuit(service) }
    end

    # Check if Redis is available for circuit breaker state
    #
    # @return [Boolean] true if Redis is connected
    def redis_available?
      redis.ping == "PONG"
    rescue StandardError => e
      Rails.logger.warn("[ServiceRegistry] Redis unavailable: #{e.message}")
      false
    end

    private

    def find_service(service_name)
      name = service_name.to_sym
      SERVICES[name] || raise(ServiceNotFound, "Service '#{service_name}' not found in registry. Available: #{SERVICES.keys.join(', ')}")
    end

    def service_key(service_name)
      service_name.to_s.downcase
    end

    # Redis keys for circuit breaker state
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

    # State transitions
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

    # Counter operations
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
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    end
  end
end
