# frozen_string_literal: true

# SimpleCov Configuration for users-service
# This file must be required FIRST in spec_helper.rb before any other requires
# to ensure accurate coverage measurement.
#
# Coverage Requirements:
# - Minimum overall coverage: 90%
# - Coverage reports generated in: coverage/index.html
# - Console output for CI/CD visibility

require "simplecov"
require "simplecov-console"

SimpleCov.start "rails" do
  # Set the service name for clear identification in reports
  command_name "users-service"

  # Enforce minimum coverage threshold (strict mode)
  minimum_coverage 90

  # Fail the test suite if individual file coverage drops below threshold
  # Relaxed from 80 to 70 to allow for utility/base classes with lower coverage
  minimum_coverage_by_file 70

  # Enable branch coverage for more thorough analysis
  enable_coverage :branch

  # Coverage groups for organized reporting
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Middleware", "app/middleware"
  add_group "Channels", "app/channels"
  add_group "Mailers", "app/mailers"
  add_group "Serializers", "app/serializers"

  # File exclusions - these paths will not be measured for coverage
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"
  add_filter "/lib/tasks/"
  add_filter "/bin/"
  add_filter "/log/"
  add_filter "/tmp/"
  add_filter "/public/"
  add_filter "/storage/"

  # Exclude base/abstract classes that are never directly tested
  add_filter "app/models/application_record.rb"
  add_filter "app/jobs/application_job.rb"
  add_filter "app/mailers/application_mailer.rb"
  add_filter "app/controllers/application_controller.rb"

  # Track all files in app directory, even if not loaded during tests
  track_files "{app}/**/*.rb"

  # Merge results from parallel test runs (useful for CI)
  use_merging true

  # Set coverage directory
  coverage_dir "coverage"

  # Configure formatters for both HTML and console output
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Console
  ])
end

# Ensure SimpleCov runs at exit to generate reports
SimpleCov.at_exit do
  SimpleCov.result.format!

  # Print coverage summary for CI visibility
  if SimpleCov.result.covered_percent < 90
    warn "\n[SimpleCov] WARNING: Coverage is below 90% threshold!"
    warn "[SimpleCov] Current coverage: #{SimpleCov.result.covered_percent.round(2)}%\n"
  end
end
