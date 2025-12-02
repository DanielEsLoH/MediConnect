# frozen_string_literal: true

# Service Registry for managing microservice URLs and health status
# Implements the Circuit Breaker pattern to handle service failures gracefully
#
# @example Getting a service URL
#   ServiceRegistry.url_for(:users)
#   # => "http://users-service:3001"
#
# @example Checking service health
#   ServiceRegistry.healthy?(:users)
#   # => true
#
class ServiceRegistry
  class ServiceNotFound < StandardError; end
  class CircuitOpen < StandardError; end

  # Circuit breaker states
  CIRCUIT_CLOSED = :closed    # Normal operation
  CIRCUIT_OPEN = :open        # Failing, reject requests
  CIRCUIT_HALF_OPEN = :half_open # Testing if service recovered

  # Circuit breaker configuration
  FAILURE_THRESHOLD = 5       # Number of failures before opening circuit
  SUCCESS_THRESHOLD = 2       # Number of successes before closing circuit
  OPEN_TIMEOUT = 30.seconds   # Time to wait before trying again
  FAILURE_WINDOW = 60.seconds # Window for counting failures

  # Service configuration
  SERVICES = {
    users: {
      env_key: "USERS_SERVICE_URL",
      default_url: "http://users-service:3001",
      health_path: "/health"
    },
    doctors: {
      env_key: "DOCTORS_SERVICE_URL",
      default_url: "http://doctors-service:3002",
      health_path: "/health"
    },
    appointments: {
      env_key: "APPOINTMENTS_SERVICE_URL",
      default_url: "http://appointments-service:3003",
      health_path: "/health"
    },
    notifications: {
      env_key: "NOTIFICATIONS_SERVICE_URL",
      default_url: "http://notifications-service:3004",
      health_path: "/health"
    },
    payments: {
      env_key: "PAYMENTS_SERVICE_URL",
      default_url: "http://payments-service:3005",
      health_path: "/health"
    }
  }.freeze

  class << self
    # Returns the URL for a given service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [String] the service URL
    # @raise [ServiceNotFound] if service is not registered
    def url_for(service_name)
      service = find_service(service_name)
      ENV.fetch(service[:env_key], service[:default_url])
    end

    # Returns all registered services with their URLs
    #
    # @return [Hash] service names mapped to their URLs
    def all_services
      SERVICES.transform_values do |config|
        ENV.fetch(config[:env_key], config[:default_url])
      end
    end

    # Returns health check path for a service
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [String] the health check path
    def health_path_for(service_name)
      service = find_service(service_name)
      service[:health_path]
    end

    # Checks if a service is healthy (circuit breaker is closed)
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [Boolean] true if service is available
    def healthy?(service_name)
      circuit_state(service_name) != CIRCUIT_OPEN
    end

    # Checks if the circuit allows a request through
    #
    # @param service_name [Symbol, String] the service identifier
    # @return [Boolean] true if request is allowed
    # @raise [CircuitOpen] if circuit is open and not ready for testing
    def allow_request?(service_name)
      state = circuit_state(service_name)

      case state
      when CIRCUIT_CLOSED
        true
      when CIRCUIT_HALF_OPEN
        # Allow one test request
        true
      when CIRCUIT_OPEN
        if circuit_open_timeout_elapsed?(service_name)
          transition_to_half_open(service_name)
          true
        else
          false
        end
      end
    end

    # Records a successful request to a service
    #
    # @param service_name [Symbol, String] the service identifier
    def record_success(service_name)
      key = service_key(service_name)
      state = circuit_state(service_name)

      case state
      when CIRCUIT_HALF_OPEN
        increment_success_count(service_name)
        if success_count(service_name) >= SUCCESS_THRESHOLD
          transition_to_closed(service_name)
        end
      when CIRCUIT_CLOSED
        # Reset failure count on success
        reset_failure_count(service_name)
      end
    end

    # Records a failed request to a service
    #
    # @param service_name [Symbol, String] the service identifier
    def record_failure(service_name)
      state = circuit_state(service_name)

      case state
      when CIRCUIT_CLOSED
        increment_failure_count(service_name)
        if failure_count(service_name) >= FAILURE_THRESHOLD
          transition_to_open(service_name)
        end
      when CIRCUIT_HALF_OPEN
        # Any failure in half-open state opens the circuit again
        transition_to_open(service_name)
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
    #
    # @return [Hash] service names mapped to circuit status
    def circuit_status
      SERVICES.keys.each_with_object({}) do |service_name, status|
        status[service_name] = {
          state: circuit_state(service_name),
          failures: failure_count(service_name),
          successes: success_count(service_name),
          healthy: healthy?(service_name)
        }
      end
    end

    # Resets circuit breaker for a service (for testing/admin purposes)
    #
    # @param service_name [Symbol, String] the service identifier
    def reset_circuit(service_name)
      return unless redis_available?

      redis.del(circuit_state_key(service_name))
      redis.del(failure_count_key(service_name))
      redis.del(success_count_key(service_name))
      redis.del(circuit_opened_at_key(service_name))
    end

    # Resets all circuit breakers
    def reset_all_circuits
      SERVICES.keys.each { |service| reset_circuit(service) }
    end

    private

    def find_service(service_name)
      name = service_name.to_sym
      SERVICES[name] || raise(ServiceNotFound, "Service '#{service_name}' not found in registry")
    end

    def service_key(service_name)
      service_name.to_s.downcase
    end

    # Circuit state keys
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
      return unless redis_available?

      Rails.logger.warn("Circuit breaker OPENED for service: #{service_name}")

      redis.multi do |multi|
        multi.set(circuit_state_key(service_name), CIRCUIT_OPEN.to_s)
        multi.set(circuit_opened_at_key(service_name), Time.current.to_i.to_s)
        multi.del(success_count_key(service_name))
      end
    end

    def transition_to_half_open(service_name)
      return unless redis_available?

      Rails.logger.info("Circuit breaker HALF-OPEN for service: #{service_name}")

      redis.multi do |multi|
        multi.set(circuit_state_key(service_name), CIRCUIT_HALF_OPEN.to_s)
        multi.del(success_count_key(service_name))
      end
    end

    def transition_to_closed(service_name)
      return unless redis_available?

      Rails.logger.info("Circuit breaker CLOSED for service: #{service_name}")

      redis.multi do |multi|
        multi.del(circuit_state_key(service_name))
        multi.del(failure_count_key(service_name))
        multi.del(success_count_key(service_name))
        multi.del(circuit_opened_at_key(service_name))
      end
    end

    # Counters
    def failure_count(service_name)
      return 0 unless redis_available?

      redis.get(failure_count_key(service_name)).to_i
    end

    def success_count(service_name)
      return 0 unless redis_available?

      redis.get(success_count_key(service_name)).to_i
    end

    def increment_failure_count(service_name)
      return unless redis_available?

      key = failure_count_key(service_name)
      redis.multi do |multi|
        multi.incr(key)
        multi.expire(key, FAILURE_WINDOW.to_i)
      end
    end

    def increment_success_count(service_name)
      return unless redis_available?

      redis.incr(success_count_key(service_name))
    end

    def reset_failure_count(service_name)
      return unless redis_available?

      redis.del(failure_count_key(service_name))
    end

    def circuit_open_timeout_elapsed?(service_name)
      return true unless redis_available?

      opened_at = redis.get(circuit_opened_at_key(service_name))
      return true if opened_at.nil?

      Time.at(opened_at.to_i) + OPEN_TIMEOUT < Time.current
    end

    def redis_available?
      redis.ping == "PONG"
    rescue StandardError
      Rails.logger.warn("Redis unavailable for circuit breaker")
      false
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end
  end
end
