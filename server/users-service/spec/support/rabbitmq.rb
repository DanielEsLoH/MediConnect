# frozen_string_literal: true

# RabbitMQ/Bunny test configuration
# Stubs all RabbitMQ connections and EventPublisher calls in tests
# to prevent actual message queue connections
#
# NOTE: EventPublisher already guards against test environment with:
#   return unless Rails.env.production? || Rails.env.development?
# So no actual RabbitMQ connections are made in tests by default.
#
# The stubs below are for:
# 1. Extra safety in case code changes
# 2. Specs that explicitly test EventPublisher behavior (they set up their own mocks)

RSpec.configure do |config|
  # Stub EventPublisher.publish for all specs EXCEPT those in event_publisher_spec.rb
  # The event_publisher_spec needs to test the actual behavior with its own mocks
  config.before(:each) do |example|
    # Skip stubbing for EventPublisher spec - it sets up its own mocks
    unless example.metadata[:file_path]&.include?("event_publisher_spec")
      allow(EventPublisher).to receive(:publish).and_return(true)
    end
  end
end

# Helper module for event publishing assertions
module EventPublisherHelpers
  # Expect an event to be published with specific attributes
  def expect_event_published(event_type, payload_matcher = anything)
    expect(EventPublisher).to receive(:publish)
      .with(event_type, payload_matcher)
  end

  # Expect no events to be published
  def expect_no_events_published
    expect(EventPublisher).not_to receive(:publish)
  end

  # Stub event publishing and capture published events
  def capture_published_events
    events = []
    allow(EventPublisher).to receive(:publish) do |event_type, payload|
      events << { event_type: event_type, payload: payload }
      true
    end
    events
  end
end

RSpec.configure do |config|
  config.include EventPublisherHelpers
end

# Stub Bunny for specs that don't set up their own Bunny mocks
# EventPublisher spec sets up its own Bunny mocks, so we skip it
RSpec.configure do |config|
  config.before(:each) do |example|
    # Skip for EventPublisher spec which sets up its own Bunny mocks
    unless example.metadata[:file_path]&.include?("event_publisher_spec")
      # Create a mock Bunny connection that doesn't actually connect
      mock_channel = instance_double(Bunny::Channel)
      mock_exchange = instance_double(Bunny::Exchange)
      mock_connection = instance_double(Bunny::Session)

      allow(mock_connection).to receive(:start).and_return(mock_connection)
      allow(mock_connection).to receive(:create_channel).and_return(mock_channel)
      allow(mock_connection).to receive(:close).and_return(true)
      allow(mock_connection).to receive(:open?).and_return(true)

      allow(mock_channel).to receive(:topic).and_return(mock_exchange)
      allow(mock_channel).to receive(:close).and_return(true)
      allow(mock_channel).to receive(:open?).and_return(true)

      allow(mock_exchange).to receive(:publish).and_return(true)

      allow(Bunny).to receive(:new).and_return(mock_connection)
    end
  end
end
