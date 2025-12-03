# frozen_string_literal: true

class EventPublisher
  class << self
    def publish(event_type, payload)
      return unless Rails.env.production? || Rails.env.development?

      connection = rabbit_connection
      channel = connection.create_channel
      exchange = channel.topic("mediconnect.events", durable: true)

      message = {
        event_type: event_type,
        payload: payload,
        service: "appointments-service",
        timestamp: Time.current.iso8601,
        request_id: Current.request_id
      }.to_json

      exchange.publish(
        message,
        routing_key: event_type,
        persistent: true,
        content_type: "application/json"
      )

      Rails.logger.info("Published event: #{event_type} - #{payload.inspect}")
    ensure
      channel&.close
    end

    private

    def rabbit_connection
      @rabbit_connection ||= Bunny.new(
        ENV.fetch("RABBITMQ_URL", "amqp://guest:guest@localhost:5672"),
        automatically_recover: true,
        network_recovery_interval: 5,
        recovery_attempts: 10
      ).tap(&:start)
    end
  end
end
