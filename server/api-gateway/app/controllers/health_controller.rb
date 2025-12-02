# frozen_string_literal: true

class HealthController < ApplicationController
  # Skip any authentication or error handling for health checks
  # These endpoints need to be as lightweight and reliable as possible

  # GET /health
  # Returns detailed health status including database and Redis connectivity
  def show
    health_status = {
      status: "ok",
      service: "api-gateway",
      timestamp: Time.current.iso8601,
      version: ENV.fetch("APP_VERSION", "1.0.0"),
      environment: Rails.env,
      checks: {}
    }

    # Check database connectivity
    health_status[:checks][:database] = check_database

    # Check Redis connectivity
    health_status[:checks][:redis] = check_redis

    # Determine overall status
    all_healthy = health_status[:checks].values.all? { |check| check[:status] == "ok" }
    health_status[:status] = all_healthy ? "ok" : "degraded"

    status_code = all_healthy ? :ok : :service_unavailable
    render json: health_status, status: status_code
  end

  # GET /health/services
  # Returns health status of all downstream microservices
  def services
    health_status = {
      status: "ok",
      service: "api-gateway",
      timestamp: Time.current.iso8601,
      downstream_services: {}
    }

    # Check each registered service
    service_checks = check_downstream_services
    health_status[:downstream_services] = service_checks

    # Include circuit breaker status
    health_status[:circuit_breakers] = ServiceRegistry.circuit_status

    # Calculate summary
    healthy_count = service_checks.values.count { |s| s[:status] == "ok" }
    total_count = service_checks.size

    health_status[:summary] = {
      total_services: total_count,
      healthy_services: healthy_count,
      unhealthy_services: total_count - healthy_count
    }

    # Determine overall status
    # "ok" if all services healthy
    # "degraded" if some services unhealthy
    # "critical" if no services healthy
    health_status[:status] = if healthy_count == total_count
                               "ok"
                             elsif healthy_count > 0
                               "degraded"
                             else
                               "critical"
                             end

    status_code = case health_status[:status]
                  when "ok" then :ok
                  when "degraded" then :ok # Still return 200 for degraded
                  else :service_unavailable
                  end

    render json: health_status, status: status_code
  end

  private

  def check_database
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveRecord::Base.connection.execute("SELECT 1")
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    {
      status: "ok",
      response_time_ms: ((end_time - start_time) * 1000).round(2)
    }
  rescue StandardError => e
    {
      status: "error",
      error: e.message
    }
  end

  def check_redis
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
    redis = Redis.new(url: redis_url)
    redis.ping
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    {
      status: "ok",
      response_time_ms: ((end_time - start_time) * 1000).round(2)
    }
  rescue StandardError => e
    {
      status: "error",
      error: e.message
    }
  end

  def check_downstream_services
    services = ServiceRegistry.all_services
    results = {}

    # Check services in parallel using threads
    threads = services.map do |service_name, url|
      Thread.new do
        [service_name, check_service(service_name, url)]
      end
    end

    # Collect results
    threads.each do |thread|
      service_name, result = thread.value
      results[service_name] = result
    end

    results
  end

  def check_service(service_name, url)
    result = {
      url: url,
      circuit_state: ServiceRegistry.circuit_state(service_name).to_s
    }

    # Skip actual health check if circuit is open
    unless ServiceRegistry.allow_request?(service_name)
      result[:status] = "circuit_open"
      result[:error] = "Circuit breaker is open"
      return result
    end

    # Perform health check
    health_data = HttpClient.health_check(service_name)
    result.merge!(health_data)
    result
  rescue HttpClient::CircuitOpen
    result[:status] = "circuit_open"
    result[:error] = "Circuit breaker is open"
    result
  rescue StandardError => e
    result[:status] = "error"
    result[:error] = e.message
    result
  end

  def measure_time
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ((end_time - start_time) * 1000).round(2)
  end
end
