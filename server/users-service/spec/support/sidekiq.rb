# frozen_string_literal: true

require "sidekiq/testing"

# Use fake mode by default - jobs are pushed to a per-class array
# and can be inspected but not executed
Sidekiq::Testing.fake!

RSpec.configure do |config|
  config.before(:each) do
    # Clear all Sidekiq queues before each test
    Sidekiq::Worker.clear_all
  end

  # For tests that need to run jobs inline (synchronously)
  config.around(:each, :sidekiq_inline) do |example|
    Sidekiq::Testing.inline! do
      example.run
    end
  end

  # For tests that need to disable Sidekiq testing mode
  config.around(:each, :sidekiq_enabled) do |example|
    Sidekiq::Testing.disable! do
      example.run
    end
  end
end

# Helper module for Sidekiq job assertions
module SidekiqHelpers
  # Assert that a job was enqueued
  def expect_job_enqueued(job_class, *args)
    expect(job_class.jobs.size).to be > 0
    if args.any?
      expect(job_class.jobs.last["args"]).to eq(args)
    end
  end

  # Assert that no jobs were enqueued for a class
  def expect_no_jobs_enqueued(job_class)
    expect(job_class.jobs.size).to eq(0)
  end

  # Get the number of enqueued jobs for a class
  def enqueued_jobs_count(job_class)
    job_class.jobs.size
  end

  # Clear jobs for a specific class
  def clear_jobs(job_class)
    job_class.clear
  end
end

RSpec.configure do |config|
  config.include SidekiqHelpers
end
