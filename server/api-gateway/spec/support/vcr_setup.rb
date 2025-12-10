# frozen_string_literal: true

require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Allow localhost connections for test server
  config.ignore_localhost = false

  # Filter sensitive data
  config.filter_sensitive_data("<JWT_SECRET>") { ENV.fetch("JWT_SECRET", "test_secret") }
  config.filter_sensitive_data("<REDIS_URL>") { ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Allow real HTTP connections when no cassette is present (for new recordings)
  config.allow_http_connections_when_no_cassette = false

  # Record mode (default to :none in CI, :new_episodes locally)
  config.default_cassette_options = {
    record: ENV["CI"] ? :none : :new_episodes,
    match_requests_on: [ :method, :uri, :body ]
  }
end
