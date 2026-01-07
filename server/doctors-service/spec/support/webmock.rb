# frozen_string_literal: true

require "webmock/rspec"

# Disable all external network connections by default
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    # Reset WebMock before each test
    WebMock.reset!
  end
end
