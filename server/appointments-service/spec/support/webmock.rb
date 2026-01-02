# frozen_string_literal: true

require "webmock/rspec"

# Allow localhost connections for test database and redis
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    "127.0.0.1",
    "localhost"
  ]
)

# Reset WebMock between each example
RSpec.configure do |config|
  config.before(:each) do
    WebMock.reset!
  end

  # Make WebMock methods available globally
  config.include WebMock::API
  config.include WebMock::Matchers
end