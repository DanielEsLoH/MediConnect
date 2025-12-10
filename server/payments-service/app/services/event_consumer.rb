# frozen_string_literal: true

class EventConsumer
  SUBSCRIBED_EVENTS = [
    "appointment.cancelled"
  ].freeze

  class << self
    def start
      return unless Rails.env.production? || Rails.env.development?

      Thread.new do
        connection = rabbit_connection
        channel = connection.create_channel
        channel.prefetch(10) # Process 10 messages at a time

        exchange = channel.topic("mediconnect.events", durable: true)
        queue = channel.queue("payments_service.events", durable: true)

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
      when "appointment.cancelled"
        handle_appointment_cancelled(payload)
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

    def handle_appointment_cancelled(payload)
      appointment_id = payload["appointment_id"]
      user_id = payload["user_id"]

      return unless appointment_id.present?

      # Find payment(s) associated with the cancelled appointment
      payment = Payment.for_appointment(appointment_id).first

      unless payment
        Rails.logger.info("No payment found for cancelled appointment #{appointment_id}")
        return
      end

      # Idempotency check: only refund completed payments
      unless payment.status_completed?
        Rails.logger.info(
          "Payment #{payment.id} for appointment #{appointment_id} " \
          "is not in 'completed' status (current: #{payment.status}), skipping refund"
        )
        return
      end

      # Process refund
      process_refund(payment, appointment_id)
    end

    def process_refund(payment, appointment_id)
      # In production, this would call Stripe API to process the actual refund
      # For now, we stub the Stripe call and update our local state
      Rails.logger.info(
        "[REFUND] Processing refund for payment #{payment.id}, " \
        "appointment #{appointment_id}, amount: #{format_currency(payment.amount)}"
      )

      # Stubbed Stripe refund call
      # In production: Stripe::Refund.create(charge: payment.stripe_charge_id)
      stripe_refund_successful = true # Stubbed success

      if stripe_refund_successful
        # Mark payment as refunded (this will trigger publish_payment_events callback)
        payment.mark_as_refunded!

        Rails.logger.info(
          "[REFUND] Successfully refunded payment #{payment.id} " \
          "for cancelled appointment #{appointment_id}"
        )
      else
        Rails.logger.error(
          "[REFUND] Failed to process Stripe refund for payment #{payment.id}"
        )
      end
    rescue StandardError => e
      Rails.logger.error("[REFUND] Error processing refund: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
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
