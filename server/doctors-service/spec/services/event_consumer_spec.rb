# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventConsumer do
  let(:doctor) { create(:doctor, first_name: "John", last_name: "Smith") }
  let(:channel_mock) { instance_double(Bunny::Channel) }
  let(:delivery_info) { instance_double("DeliveryInfo", delivery_tag: "tag-123") }

  before do
    allow(EventPublisher).to receive(:publish)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe "SUBSCRIBED_EVENTS" do
    it "includes appointment events" do
      expect(EventConsumer::SUBSCRIBED_EVENTS).to include(
        "appointment.created",
        "appointment.completed",
        "appointment.cancelled"
      )
    end

    it "is frozen" do
      expect(EventConsumer::SUBSCRIBED_EVENTS).to be_frozen
    end

    it "contains exactly three event types" do
      expect(EventConsumer::SUBSCRIBED_EVENTS.size).to eq(3)
    end
  end

  describe ".handle_event" do
    context "with appointment.created event" do
      let(:event_body) do
        {
          event_type: "appointment.created",
          payload: {
            doctor_id: doctor.id,
            appointment_id: "appointment-123",
            scheduled_datetime: Time.current.iso8601
          }
        }.to_json
      end

      it "processes the event and acknowledges" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:ack).with("tag-123")
      end

      it "logs the appointment booking" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/DOCTOR_SCHEDULE.*has new appointment/)
      end

      it "logs doctor activity" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/DOCTOR_ACTIVITY.*New appointment booked/)
      end

      it "logs the received event" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/Received event: appointment.created/)
      end

      context "when doctor is not found" do
        let(:event_body) do
          {
            event_type: "appointment.created",
            payload: {
              doctor_id: "nonexistent-uuid",
              appointment_id: "appointment-123"
            }
          }.to_json
        end

        it "logs a warning and acknowledges" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(Rails.logger).to have_received(:warn).with(/Doctor not found/)
          expect(channel_mock).to have_received(:ack)
        end
      end

      context "when doctor_id is blank" do
        let(:event_body) do
          {
            event_type: "appointment.created",
            payload: {
              doctor_id: nil,
              appointment_id: "appointment-123"
            }
          }.to_json
        end

        it "acknowledges without processing" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(channel_mock).to have_received(:ack)
        end
      end

      context "when doctor_id is empty string" do
        let(:event_body) do
          {
            event_type: "appointment.created",
            payload: {
              doctor_id: "",
              appointment_id: "appointment-123"
            }
          }.to_json
        end

        it "acknowledges without processing" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(channel_mock).to have_received(:ack)
          expect(Rails.logger).not_to have_received(:warn).with(/Doctor not found/)
        end
      end
    end

    context "with appointment.completed event" do
      let(:event_body) do
        {
          event_type: "appointment.completed",
          payload: {
            doctor_id: doctor.id,
            appointment_id: "appointment-123"
          }
        }.to_json
      end

      it "processes the event and acknowledges" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:ack).with("tag-123")
      end

      it "logs the completed appointment" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/DOCTOR_SCHEDULE.*completed appointment/)
      end

      it "logs doctor activity for completion" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/DOCTOR_ACTIVITY.*Appointment completed/)
      end

      context "when doctor is not found" do
        let(:event_body) do
          {
            event_type: "appointment.completed",
            payload: {
              doctor_id: "nonexistent-uuid",
              appointment_id: "appointment-123"
            }
          }.to_json
        end

        it "logs a warning" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(Rails.logger).to have_received(:warn).with(/Doctor not found/)
        end
      end

      context "when doctor_id is blank" do
        let(:event_body) do
          {
            event_type: "appointment.completed",
            payload: {
              doctor_id: nil,
              appointment_id: "appointment-123"
            }
          }.to_json
        end

        it "acknowledges without doctor lookup" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(channel_mock).to have_received(:ack)
          expect(Rails.logger).not_to have_received(:warn).with(/Doctor not found/)
        end
      end
    end

    context "with appointment.cancelled event" do
      let(:event_body) do
        {
          event_type: "appointment.cancelled",
          payload: {
            doctor_id: doctor.id,
            appointment_id: "appointment-123",
            cancelled_by: "patient"
          }
        }.to_json
      end

      it "processes the event and acknowledges" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:ack).with("tag-123")
      end

      it "logs the cancellation" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/DOCTOR_SCHEDULE.*was cancelled by patient/)
      end

      it "logs doctor activity for cancellation" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/DOCTOR_ACTIVITY.*Appointment cancelled.*patient/)
      end

      it "includes cancelled_by information" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/slot freed for doctor/)
      end

      context "when cancelled by doctor" do
        let(:event_body) do
          {
            event_type: "appointment.cancelled",
            payload: {
              doctor_id: doctor.id,
              appointment_id: "appointment-123",
              cancelled_by: "doctor"
            }
          }.to_json
        end

        it "logs who cancelled the appointment" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(Rails.logger).to have_received(:info).with(/cancelled by doctor/)
        end
      end

      context "when doctor is not found" do
        let(:event_body) do
          {
            event_type: "appointment.cancelled",
            payload: {
              doctor_id: "nonexistent-uuid",
              appointment_id: "appointment-123",
              cancelled_by: "patient"
            }
          }.to_json
        end

        it "logs a warning" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(Rails.logger).to have_received(:warn).with(/Doctor not found/)
        end
      end

      context "when doctor_id is blank" do
        let(:event_body) do
          {
            event_type: "appointment.cancelled",
            payload: {
              doctor_id: nil,
              appointment_id: "appointment-123",
              cancelled_by: "patient"
            }
          }.to_json
        end

        it "acknowledges without processing" do
          allow(channel_mock).to receive(:ack)

          EventConsumer.handle_event(delivery_info, event_body, channel_mock)

          expect(channel_mock).to have_received(:ack)
        end
      end
    end

    context "with unknown event type" do
      let(:event_body) do
        {
          event_type: "unknown.event",
          payload: { some: "data" }
        }.to_json
      end

      it "acknowledges the message without processing" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:ack)
      end

      it "logs the received event" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:info).with(/Received event: unknown.event/)
      end
    end

    context "when an error occurs during processing" do
      let(:event_body) do
        {
          event_type: "appointment.created",
          payload: {
            doctor_id: doctor.id,
            appointment_id: "appointment-123"
          }
        }.to_json
      end

      before do
        allow(Doctor).to receive(:find_by).and_raise(StandardError.new("Database error"))
      end

      it "logs the error" do
        allow(channel_mock).to receive(:nack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:error).with(/Error handling event/)
      end

      it "logs the error message" do
        allow(channel_mock).to receive(:nack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:error).with(/Database error/)
      end

      it "logs the backtrace" do
        allow(channel_mock).to receive(:nack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        # The second error log call is for the backtrace
        expect(Rails.logger).to have_received(:error).twice
      end

      it "rejects and requeues the message" do
        allow(channel_mock).to receive(:nack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:nack).with("tag-123", false, true)
      end
    end

    context "with malformed JSON" do
      let(:event_body) { "not valid json" }

      it "rejects the message" do
        allow(channel_mock).to receive(:nack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:nack)
      end

      it "logs the JSON parsing error" do
        allow(channel_mock).to receive(:nack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(Rails.logger).to have_received(:error).with(/Error handling event/)
      end
    end

    context "with empty JSON object" do
      let(:event_body) { "{}".to_s }

      it "acknowledges the message" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:ack)
      end
    end

    context "with missing payload" do
      let(:event_body) do
        { event_type: "appointment.created", payload: {} }.to_json
      end

      it "handles gracefully and acknowledges" do
        allow(channel_mock).to receive(:ack)

        EventConsumer.handle_event(delivery_info, event_body, channel_mock)

        expect(channel_mock).to have_received(:ack)
      end
    end
  end

  describe ".start" do
    context "in test environment" do
      it "does not start consumer in test environment" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))

        result = EventConsumer.start

        expect(result).to be_nil
      end
    end

    context "in production environment" do
      let(:connection_mock) { instance_double(Bunny::Session) }
      let(:exchange_mock) { instance_double(Bunny::Exchange) }
      let(:queue_mock) { instance_double(Bunny::Queue) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(Bunny).to receive(:new).and_return(connection_mock)
        allow(connection_mock).to receive(:start).and_return(connection_mock)
        allow(connection_mock).to receive(:create_channel).and_return(channel_mock)
        allow(channel_mock).to receive(:prefetch)
        allow(channel_mock).to receive(:topic).and_return(exchange_mock)
        allow(channel_mock).to receive(:queue).and_return(queue_mock)
        allow(queue_mock).to receive(:bind)
        allow(queue_mock).to receive(:subscribe)

        # Reset memoized connection
        EventConsumer.instance_variable_set(:@rabbit_connection, nil)
      end

      after do
        EventConsumer.instance_variable_set(:@rabbit_connection, nil)
      end

      it "starts a new thread" do
        thread = EventConsumer.start

        expect(thread).to be_a(Thread)
        thread.kill if thread&.alive?
      end

      it "creates a RabbitMQ connection" do
        thread = EventConsumer.start
        sleep 0.1 # Allow thread to start

        expect(Bunny).to have_received(:new).with(
          anything,
          hash_including(
            automatically_recover: true,
            network_recovery_interval: 5,
            recovery_attempts: 10
          )
        )

        thread.kill if thread&.alive?
      end

      it "creates a channel with prefetch" do
        thread = EventConsumer.start
        sleep 0.1

        expect(channel_mock).to have_received(:prefetch).with(10)
        thread.kill if thread&.alive?
      end

      it "sets up topic exchange" do
        thread = EventConsumer.start
        sleep 0.1

        expect(channel_mock).to have_received(:topic).with("mediconnect.events", durable: true)
        thread.kill if thread&.alive?
      end

      it "creates a durable queue" do
        thread = EventConsumer.start
        sleep 0.1

        expect(channel_mock).to have_received(:queue).with("doctors_service.events", durable: true)
        thread.kill if thread&.alive?
      end

      it "binds queue to all subscribed events" do
        thread = EventConsumer.start
        sleep 0.1

        EventConsumer::SUBSCRIBED_EVENTS.each do |event_type|
          expect(queue_mock).to have_received(:bind).with(exchange_mock, routing_key: event_type)
        end

        thread.kill if thread&.alive?
      end

      it "logs binding for each event" do
        thread = EventConsumer.start
        sleep 0.1

        EventConsumer::SUBSCRIBED_EVENTS.each do |event_type|
          expect(Rails.logger).to have_received(:info).with(/Bound to event: #{event_type}/)
        end

        thread.kill if thread&.alive?
      end

      it "logs consumer started message" do
        thread = EventConsumer.start
        sleep 0.1

        expect(Rails.logger).to have_received(:info).with(/EventConsumer started/)
        thread.kill if thread&.alive?
      end

      it "subscribes to the queue" do
        thread = EventConsumer.start
        sleep 0.1

        expect(queue_mock).to have_received(:subscribe).with(block: false, manual_ack: true)
        thread.kill if thread&.alive?
      end

      # Note: Connection failure and retry testing is challenging with threads
      # The retry behavior is covered by the error handling in handle_event
    end

    context "in development environment" do
      let(:connection_mock) { instance_double(Bunny::Session) }
      let(:exchange_mock) { instance_double(Bunny::Exchange) }
      let(:queue_mock) { instance_double(Bunny::Queue) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
        allow(Bunny).to receive(:new).and_return(connection_mock)
        allow(connection_mock).to receive(:start).and_return(connection_mock)
        allow(connection_mock).to receive(:create_channel).and_return(channel_mock)
        allow(channel_mock).to receive(:prefetch)
        allow(channel_mock).to receive(:topic).and_return(exchange_mock)
        allow(channel_mock).to receive(:queue).and_return(queue_mock)
        allow(queue_mock).to receive(:bind)
        allow(queue_mock).to receive(:subscribe)

        EventConsumer.instance_variable_set(:@rabbit_connection, nil)
      end

      after do
        EventConsumer.instance_variable_set(:@rabbit_connection, nil)
      end

      it "starts consumer in development" do
        thread = EventConsumer.start

        expect(thread).to be_a(Thread)
        thread.kill if thread&.alive?
      end
    end
  end

  describe "log_doctor_activity" do
    let(:event_body) do
      {
        event_type: "appointment.created",
        payload: {
          doctor_id: doctor.id,
          appointment_id: "appointment-123"
        }
      }.to_json
    end

    it "logs activity message with timestamp" do
      allow(channel_mock).to receive(:ack)

      EventConsumer.handle_event(delivery_info, event_body, channel_mock)

      expect(Rails.logger).to have_received(:info).with(/DOCTOR_ACTIVITY.*at \d{4}-\d{2}-\d{2}/)
    end

    it "includes doctor full name in activity log" do
      allow(channel_mock).to receive(:ack)

      EventConsumer.handle_event(delivery_info, event_body, channel_mock)

      expect(Rails.logger).to have_received(:info).with(/John Smith/).at_least(:once)
    end
  end

  describe "rabbit_connection configuration" do
    context "with custom RABBITMQ_URL" do
      let(:connection_mock) { instance_double(Bunny::Session) }
      let(:exchange_mock) { instance_double(Bunny::Exchange) }
      let(:queue_mock) { instance_double(Bunny::Queue) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(ENV).to receive(:fetch).with("RABBITMQ_URL", anything).and_return("amqp://custom:password@rabbitmq.example.com:5672")
        allow(Bunny).to receive(:new).and_return(connection_mock)
        allow(connection_mock).to receive(:start).and_return(connection_mock)
        allow(connection_mock).to receive(:create_channel).and_return(channel_mock)
        allow(channel_mock).to receive(:prefetch)
        allow(channel_mock).to receive(:topic).and_return(exchange_mock)
        allow(channel_mock).to receive(:queue).and_return(queue_mock)
        allow(queue_mock).to receive(:bind)
        allow(queue_mock).to receive(:subscribe)

        EventConsumer.instance_variable_set(:@rabbit_connection, nil)
      end

      after do
        EventConsumer.instance_variable_set(:@rabbit_connection, nil)
      end

      it "uses the custom URL" do
        thread = EventConsumer.start
        sleep 0.1

        expect(Bunny).to have_received(:new).with(
          "amqp://custom:password@rabbitmq.example.com:5672",
          anything
        )

        thread.kill if thread&.alive?
      end
    end
  end
end