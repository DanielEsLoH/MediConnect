# frozen_string_literal: true

class EventConsumer
  SUBSCRIBED_EVENTS = [
    "appointment.created",
    "appointment.confirmed",
    "appointment.cancelled",
    "appointment.reminder",
    "user.registered",
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
        queue = channel.queue("notifications_service.events", durable: true)

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
      when "appointment.confirmed"
        handle_appointment_confirmed(payload)
      when "appointment.cancelled"
        handle_appointment_cancelled(payload)
      when "appointment.reminder"
        handle_appointment_reminder(payload)
      when "user.registered"
        handle_user_registered(payload)
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
      doctor_id = payload["doctor_id"]
      scheduled_datetime = payload["scheduled_datetime"]

      create_notification(
        user_id: user_id,
        notification_type: :appointment_created,
        title: "Appointment Scheduled",
        message: "Your appointment has been scheduled for #{format_datetime(scheduled_datetime)}",
        data: payload,
        delivery_method: :email,
        priority: 5
      )

      create_notification(
        user_id: user_id,
        notification_type: :appointment_created,
        title: "Appointment Scheduled",
        message: "Your appointment has been scheduled",
        data: payload,
        delivery_method: :in_app,
        priority: 5
      )
    end

    def handle_appointment_confirmed(payload)
      user_id = payload["user_id"]

      create_notification(
        user_id: user_id,
        notification_type: :appointment_confirmed,
        title: "Appointment Confirmed",
        message: "Your appointment has been confirmed by the doctor",
        data: payload,
        delivery_method: :email,
        priority: 7
      )

      create_notification(
        user_id: user_id,
        notification_type: :appointment_confirmed,
        title: "Appointment Confirmed",
        message: "Your appointment has been confirmed",
        data: payload,
        delivery_method: :push,
        priority: 7
      )
    end

    def handle_appointment_cancelled(payload)
      user_id = payload["user_id"]
      cancelled_by = payload["cancelled_by"]
      reason = payload["cancellation_reason"]

      message = if cancelled_by == "doctor"
                  "Your appointment has been cancelled by the doctor"
                else
                  "Your appointment has been cancelled"
                end
      message += ". Reason: #{reason}" if reason.present?

      create_notification(
        user_id: user_id,
        notification_type: :appointment_cancelled,
        title: "Appointment Cancelled",
        message: message,
        data: payload,
        delivery_method: :email,
        priority: 8
      )

      create_notification(
        user_id: user_id,
        notification_type: :appointment_cancelled,
        title: "Appointment Cancelled",
        message: message,
        data: payload,
        delivery_method: :sms,
        priority: 8
      )
    end

    def handle_appointment_reminder(payload)
      user_id = payload["user_id"]
      scheduled_datetime = payload["scheduled_datetime"]

      create_notification(
        user_id: user_id,
        notification_type: :appointment_reminder,
        title: "Appointment Reminder",
        message: "You have an appointment scheduled for #{format_datetime(scheduled_datetime)}",
        data: payload,
        delivery_method: :email,
        priority: 9,
        scheduled_for: Time.parse(scheduled_datetime) - 24.hours
      )

      create_notification(
        user_id: user_id,
        notification_type: :appointment_reminder,
        title: "Appointment Reminder",
        message: "You have an appointment in 24 hours",
        data: payload,
        delivery_method: :sms,
        priority: 9,
        scheduled_for: Time.parse(scheduled_datetime) - 24.hours
      )
    end

    def handle_user_registered(payload)
      user_id = payload["user_id"]

      create_notification(
        user_id: user_id,
        notification_type: :welcome_email,
        title: "Welcome to MediConnect",
        message: "Thank you for joining MediConnect. We're excited to have you!",
        data: payload,
        delivery_method: :email,
        priority: 5
      )
    end

    def handle_payment_completed(payload)
      user_id = payload["user_id"]
      amount = payload["amount"]

      create_notification(
        user_id: user_id,
        notification_type: :payment_received,
        title: "Payment Received",
        message: "We have received your payment of #{format_currency(amount)}",
        data: payload,
        delivery_method: :email,
        priority: 6
      )
    end

    def create_notification(attributes)
      Notification.create!(attributes)
      Rails.logger.info("Created notification: #{attributes[:notification_type]} for user #{attributes[:user_id]}")
    rescue StandardError => e
      Rails.logger.error("Failed to create notification: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    def format_datetime(datetime_str)
      Time.parse(datetime_str).strftime("%B %d, %Y at %I:%M %p")
    rescue StandardError
      datetime_str
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
