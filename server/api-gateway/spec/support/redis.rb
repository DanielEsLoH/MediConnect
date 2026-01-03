# frozen_string_literal: true

require 'mock_redis'

RSpec.configure do |config|
  config.before(:each) do
    # Create a fresh MockRedis instance for each test
    mock_redis = MockRedis.new

    # Stub Redis.new to return our mock
    allow(Redis).to receive(:new).and_return(mock_redis)

    # Also stub Redis.current if it's used
    allow(Redis).to receive(:current).and_return(mock_redis) if Redis.respond_to?(:current)

    # Reset Rack::Attack cache to prevent rate limiting state from persisting between tests
    # Use a fresh MemoryStore for each test to ensure complete isolation
    if defined?(Rack::Attack)
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    end
  end

  config.after(:each) do
    # Clear all Redis data after each test
    Redis.new.flushdb rescue nil
  end
end