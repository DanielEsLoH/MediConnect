# frozen_string_literal: true

# Bullet RSpec integration for N+1 query detection
# https://github.com/flyerhzm/bullet#run-in-your-test-suite
#
# This configuration ensures that:
# - Bullet is started before each spec
# - Bullet checks for N+1 queries after each spec
# - Errors are raised if any N+1 queries are detected (strict mode)

if defined?(Bullet)
  RSpec.configure do |config|
    config.before(:each) do
      Bullet.start_request
    end

    config.after(:each) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end

    config.after(:each) do
      if Bullet.notification?
        # Collect all Bullet warnings for this spec
        bullet_warnings = []

        # Check for N+1 queries
        if Bullet.n_plus_one_query_enable && Bullet.notification?
          bullet_warnings << Bullet.warnings
        end

        # If we have warnings and raise mode is enabled, fail the spec
        if bullet_warnings.any? && Bullet.raise?
          # The initializer already sets Bullet.raise = true for test env
          # This will cause Bullet to raise an error automatically
          # We just need to ensure notification processing happens
        end
      end
    end
  end
end
