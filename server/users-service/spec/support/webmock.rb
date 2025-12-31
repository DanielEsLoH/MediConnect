# frozen_string_literal: true

require "webmock/rspec"

# Disable all real HTTP connections in tests
# This ensures tests don't make actual network requests
WebMock.disable_net_connect!(
  allow_localhost: false,
  allow: [
    # Allow connections to SimpleCov if needed
    /codeclimate.com/
  ]
)

RSpec.configure do |config|
  config.before(:each) do
    # Reset WebMock stubs before each test
    WebMock.reset!
  end

  config.after(:each) do
    # Verify all stubs were used (optional - can be disabled if too strict)
    # WebMock.verify!
  end
end

# Helper module for common stub patterns
module WebMockHelpers
  # Stub service registry lookups
  def stub_service_registry(service_name, url)
    stub_request(:get, /service-registry.*#{service_name}/)
      .to_return(
        status: 200,
        body: { url: url }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stub any external service call with a success response
  def stub_external_service(url_pattern, response_body = {}, status: 200)
    stub_request(:any, url_pattern)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stub doctors service calls
  def stub_doctors_service(path = nil, response_body = {}, status: 200)
    pattern = path ? %r{localhost:8082#{path}} : /localhost:8082/
    stub_request(:any, pattern)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stub appointments service calls
  def stub_appointments_service(path = nil, response_body = {}, status: 200)
    pattern = path ? %r{localhost:8083#{path}} : /localhost:8083/
    stub_request(:any, pattern)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stub notifications service calls
  def stub_notifications_service(path = nil, response_body = {}, status: 200)
    pattern = path ? %r{localhost:8084#{path}} : /localhost:8084/
    stub_request(:any, pattern)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stub API gateway calls
  def stub_api_gateway(path = nil, response_body = {}, status: 200)
    pattern = path ? %r{localhost:8085#{path}} : /localhost:8085/
    stub_request(:any, pattern)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

RSpec.configure do |config|
  config.include WebMockHelpers
end
