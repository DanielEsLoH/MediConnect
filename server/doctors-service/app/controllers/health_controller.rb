# frozen_string_literal: true

class HealthController < ApplicationController
  # GET /health
  # Returns detailed health status including database and Redis connectivity
  def show
    health_status = {
      status: "ok",
      service: "doctors-service",
      timestamp: Time.current.iso8601,
      version: ENV.fetch("APP_VERSION", "1.0.0"),
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

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok", response_time_ms: measure_time { ActiveRecord::Base.connection.execute("SELECT 1") } }
  rescue StandardError => e
    { status: "error", error: e.message }
  end

  def check_redis
    redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/2")
    redis = Redis.new(url: redis_url)
    redis.ping
    { status: "ok", response_time_ms: measure_time { redis.ping } }
  rescue StandardError => e
    { status: "error", error: e.message }
  end

  def measure_time
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ((end_time - start_time) * 1000).round(2)
  end
end
