# frozen_string_literal: true

class EventConsumer
  SUBSCRIBED_EVENTS = [
    "payment.completed"
  ].freeze

  class << self
    def start
      return unless Rails.env.production? || Rails.env.development?

      Thread.new do
        connection = rabbit_connection
        channel = connection.create_channel
        channel.prefetch(10) # Process 10 messages at a time

        exchange = channel.topic("mediconnect.events", durable: true)
        queue = channel.queue("appointments_service.events", durable: true)

        # Bind queue to subscribed events
        SUBSCRIBED_EVENTS.each do |event_type|
          queue.bind(exchange, routing_key: event_type)
          Rails.logger.info("Bound to event: #{event_type}")
        end

        Rails.logger.info("EventConsumer started, waiting for events...")

        # Subscribe to queue
        queue.subscribe(block: false, manual_ack: true) do |delivery_info, _properties, body|
          handle_event(delivery_info, body, channel)
        end
      rescue StandardError => e
        Rails.logger.error("EventConsumer error: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        sleep 5
        retry
      end
    end

    def handle_event(delivery_info, body, channel)
      event = JSON.parse(body)
      event_type = event["event_type"]
      payload = event["payload"]

      Rails.logger.info("Received event: #{event_type} - #{payload.inspect}")

      case event_type
      when "payment.completed"
        handle_payment_completed(payload)
      end

      # Acknowledge message
      channel.ack(delivery_info.delivery_tag)
    rescue StandardError => e
      Rails.logger.error("Error handling event #{event_type}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      # Reject and requeue message
      channel.nack(delivery_info.delivery_tag, false, true)
    end

    private

    def handle_payment_completed(payload)
      appointment_id = payload["appointment_id"]

      return unless appointment_id.present?

      appointment = Appointment.find_by(id: appointment_id)

      unless appointment
        Rails.logger.warn("Appointment not found for payment: #{appointment_id}")
        return
      end

      # Idempotency check: only confirm if currently pending
      unless appointment.pending?
        Rails.logger.info("Appointment #{appointment_id} already in status '#{appointment.status}', skipping confirmation")
        return
      end

      if appointment.confirm!
        Rails.logger.info("Confirmed appointment #{appointment_id} after payment completion")
      else
        Rails.logger.error("Failed to confirm appointment #{appointment_id}")
      end
    end

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
