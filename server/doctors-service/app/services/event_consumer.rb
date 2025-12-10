# frozen_string_literal: true

class EventConsumer
  SUBSCRIBED_EVENTS = [
    "appointment.created",
    "appointment.completed",
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
        queue = channel.queue("doctors_service.events", durable: true)

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
      doctor_id = payload["doctor_id"]
      appointment_id = payload["appointment_id"]
      scheduled_datetime = payload["scheduled_datetime"]

      return unless doctor_id.present?

      doctor = Doctor.find_by(id: doctor_id)

      unless doctor
        Rails.logger.warn("Doctor not found: #{doctor_id}")
        return
      end

      # Log the appointment booking for the doctor
      Rails.logger.info(
        "[DOCTOR_SCHEDULE] Doctor #{doctor_id} (#{doctor.full_name}) " \
        "has new appointment #{appointment_id} scheduled for #{scheduled_datetime}"
      )

      # Track doctor performance metrics
      log_doctor_activity(doctor, :appointment_booked, payload)
    end

    def handle_appointment_completed(payload)
      doctor_id = payload["doctor_id"]
      appointment_id = payload["appointment_id"]

      return unless doctor_id.present?

      doctor = Doctor.find_by(id: doctor_id)

      unless doctor
        Rails.logger.warn("Doctor not found: #{doctor_id}")
        return
      end

      # Log the completed appointment
      Rails.logger.info(
        "[DOCTOR_SCHEDULE] Doctor #{doctor_id} (#{doctor.full_name}) " \
        "completed appointment #{appointment_id}"
      )

      # Track doctor performance metrics
      log_doctor_activity(doctor, :appointment_completed, payload)
    end

    def handle_appointment_cancelled(payload)
      doctor_id = payload["doctor_id"]
      appointment_id = payload["appointment_id"]
      cancelled_by = payload["cancelled_by"]

      return unless doctor_id.present?

      doctor = Doctor.find_by(id: doctor_id)

      unless doctor
        Rails.logger.warn("Doctor not found: #{doctor_id}")
        return
      end

      # Log the cancellation and freed time slot
      Rails.logger.info(
        "[DOCTOR_SCHEDULE] Doctor #{doctor_id} (#{doctor.full_name}) " \
        "appointment #{appointment_id} was cancelled by #{cancelled_by}. Time slot freed."
      )

      # Track doctor performance metrics
      log_doctor_activity(doctor, :appointment_cancelled, payload)
    end

    def log_doctor_activity(doctor, event_name, payload)
      activity_message = case event_name
      when :appointment_booked
                           "New appointment booked for doctor #{doctor.full_name}"
      when :appointment_completed
                           "Appointment completed by doctor #{doctor.full_name}"
      when :appointment_cancelled
                           cancelled_by = payload["cancelled_by"]
                           "Appointment cancelled (by #{cancelled_by}) - slot freed for doctor #{doctor.full_name}"
      else
                           "Doctor #{doctor.full_name} activity: #{event_name}"
      end

      Rails.logger.info("[DOCTOR_ACTIVITY] #{activity_message} at #{Time.current.iso8601}")
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
