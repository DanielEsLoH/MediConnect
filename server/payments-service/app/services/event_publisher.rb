# frozen_string_literal: true

# EventPublisher handles publishing domain events to RabbitMQ
# for inter-service communication in the MediConnect microservices architecture.
#
# Events are published to a topic exchange, allowing other services
# to subscribe to specific event types (e.g., payment.completed, payment.failed).
#
# @example Publishing a payment completed event
#   EventPublisher.publish('payment.completed', {
#     payment_id: '123',
#     user_id: '456',
#     amount: 99.99
#   })
#
class EventPublisher
  class << self
    # Publishes an event to the message queue
    #
    # @param event_type [String] The type of event (e.g., 'payment.completed')
    # @param payload [Hash] The event payload data
    # @return [void]
    def publish(event_type, payload)
      # Skip publishing in test environment unless explicitly enabled
      return if Rails.env.test? && !ENV["ENABLE_EVENT_PUBLISHING"]

      connection = rabbit_connection
      channel = connection.create_channel
      exchange = channel.topic("mediconnect.events", durable: true)

      message = build_message(event_type, payload)

      exchange.publish(
        message,
        routing_key: event_type,
        persistent: true,
        content_type: "application/json"
      )

      Rails.logger.info(
        event: "event_published",
        event_type: event_type,
        payload: payload.except(:sensitive_data)
      )
    rescue StandardError => e
      # Log the error but don't raise - event publishing failures
      # should not break the main application flow
      Rails.logger.error(
        event: "event_publish_failed",
        event_type: event_type,
        error: e.message,
        backtrace: e.backtrace&.first(5)
      )
    ensure
      channel&.close
    end

    private

    # Builds the message envelope with metadata
    #
    # @param event_type [String] The type of event
    # @param payload [Hash] The event payload
    # @return [String] JSON-encoded message
    def build_message(event_type, payload)
      {
        event_type: event_type,
        payload: payload,
        service: "payments-service",
        timestamp: Time.current.iso8601,
        request_id: Thread.current[:request_id],
        version: "1.0"
      }.to_json
    end

    # Creates or returns an existing RabbitMQ connection
    # Uses connection pooling via the class instance variable
    #
    # @return [Bunny::Session] The RabbitMQ connection
    def rabbit_connection
      @rabbit_connection ||= begin
        conn = Bunny.new(
          ENV.fetch("RABBITMQ_URL", "amqp://guest:guest@localhost:5672"),
          automatically_recover: true,
          network_recovery_interval: 5,
          recovery_attempts: 10
        )
        conn.start
        conn
      end
    end
  end
end
