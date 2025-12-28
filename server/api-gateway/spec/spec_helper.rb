# frozen_string_literal: true

# IMPORTANT: SimpleCov must be loaded FIRST, before any other requires
# This ensures accurate coverage measurement of all application code
require_relative "support/simplecov_setup"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed

  # Enable focus mode
  config.filter_run_when_matching :focus

  # Allow more verbose output when running a single spec file
  config.default_formatter = "doc" if config.files_to_run.one?
end
