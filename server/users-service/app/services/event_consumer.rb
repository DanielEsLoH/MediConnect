# frozen_string_literal: true

class EventConsumer
  SUBSCRIBED_EVENTS = [
    "appointment.created",
    "appointment.completed",
    "appointment.cancelled",
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
        queue = channel.queue("users_service.events", durable: true)

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
      when "appointment.created"
        handle_appointment_created(payload)
      when "appointment.completed"
        handle_appointment_completed(payload)
      when "appointment.cancelled"
        handle_appointment_cancelled(payload)
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

    def handle_appointment_created(payload)
      user_id = payload["user_id"]
      update_user_statistics(user_id, :appointment_created, payload)
    end

    def handle_appointment_completed(payload)
      user_id = payload["user_id"]
      update_user_statistics(user_id, :appointment_completed, payload)
    end

    def handle_appointment_cancelled(payload)
      user_id = payload["user_id"]
      update_user_statistics(user_id, :appointment_cancelled, payload)
    end

    def handle_payment_completed(payload)
      user_id = payload["user_id"]
      amount = payload["amount"]
      update_user_statistics(user_id, :payment_completed, payload.merge("amount" => amount))
    end

    def update_user_statistics(user_id, event_name, payload)
      return unless user_id.present?

      user = User.find_by(id: user_id)

      unless user
        Rails.logger.warn("User not found: #{user_id}")
        return
      end

      # Log the user activity event
      log_user_activity(user, event_name, payload)

      Rails.logger.info("Updated statistics for user #{user_id} - event: #{event_name}")
    rescue StandardError => e
      Rails.logger.error("Failed to update user statistics: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    def log_user_activity(user, event_name, payload)
      activity_message = case event_name
      when :appointment_created
                           "User #{user.id} created appointment #{payload['appointment_id']}"
      when :appointment_completed
                           "User #{user.id} completed appointment #{payload['appointment_id']}"
      when :appointment_cancelled
                           "User #{user.id} cancelled appointment #{payload['appointment_id']}"
      when :payment_completed
                           amount = payload["amount"]
                           "User #{user.id} completed payment of #{format_currency(amount)}"
      else
                           "User #{user.id} activity: #{event_name}"
      end

      Rails.logger.info("[USER_ACTIVITY] #{activity_message} at #{Time.current.iso8601}")
    end

    def format_currency(amount)
      "$#{format('%.2f', amount.to_f)}"
    rescue StandardError
      amount.to_s
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
