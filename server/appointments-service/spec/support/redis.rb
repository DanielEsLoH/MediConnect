# frozen_string_literal: true

require "mock_redis"

RSpec.configure do |config|
  config.before(:each) do
    # Create a fresh MockRedis instance for each test
    mock_redis = MockRedis.new

    # Stub Redis.new to return our mock
    allow(Redis).to receive(:new).and_return(mock_redis)

    # Also stub Redis.current if it's used
    allow(Redis).to receive(:current).and_return(mock_redis) if Redis.respond_to?(:current)

    # Clear any cached redis instance in ServiceRegistry
    if defined?(ServiceRegistry) && ServiceRegistry.respond_to?(:instance_variable_set)
      ServiceRegistry.instance_variable_set(:@redis, nil) if ServiceRegistry.instance_variable_defined?(:@redis)
    end
  end

  config.after(:each) do
    # Clear all Redis data after each test
    Redis.new.flushdb rescue nil
  end
end
