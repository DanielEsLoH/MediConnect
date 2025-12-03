# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/3"),
    network_timeout: 5
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/3"),
    network_timeout: 5
  }
end

# Schedule recurring jobs
if Sidekiq.server?
  require "sidekiq-scheduler"

  Sidekiq.configure_server do |config|
    config.on(:startup) do
      # Check for expired pending appointments every 10 minutes
      Sidekiq::Cron::Job.create(
        name: "Expire pending appointments",
        cron: "*/10 * * * *", # Every 10 minutes
        class: "ExpiredPendingAppointmentJob"
      )
    end
  end
end
