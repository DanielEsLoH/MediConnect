# frozen_string_literal: true

# Bullet gem configuration for N+1 query detection
# https://github.com/flyerhzm/bullet
#
# This configuration enables Bullet for detecting:
# - N+1 queries (SELECT * FROM users WHERE id IN (...) without includes)
# - Unused eager loading (.includes(:association) but never uses it)
# - Missing counter cache (calling collection.count repeatedly)

if defined?(Bullet)
  Bullet.enable = true

  # N+1 query detection
  Bullet.n_plus_one_query_enable = true

  # Unused eager loading detection
  Bullet.unused_eager_loading_enable = true

  # Counter cache detection
  Bullet.counter_cache_enable = true

  # Include 3 lines of stacktrace for debugging
  Bullet.stacktrace_includes = []
  Bullet.stacktrace_excludes = []

  case Rails.env
  when "test"
    # STRICT MODE: Raise errors on N+1 queries in tests
    # This ensures no N+1 queries slip through CI/CD
    Bullet.raise = true

    # Disable non-essential notifications in test
    Bullet.alert = false
    Bullet.console = false
    Bullet.rails_logger = false
    Bullet.add_footer = false

    # Bullet callback for additional logging during test failures
    Bullet.bullet_logger = false

  when "development"
    # WARNING MODE: Log warnings without raising errors
    # Allows developers to see issues without blocking workflow
    Bullet.raise = false

    # Disable JavaScript alerts (can be annoying)
    Bullet.alert = false

    # Enable console logging for terminal visibility
    Bullet.console = true

    # Enable Rails logger for log file visibility
    Bullet.rails_logger = true

    # Add footer to HTML pages showing Bullet warnings
    Bullet.add_footer = true

    # Enable Bullet's own logger for detailed tracking
    Bullet.bullet_logger = true
  end

  # Stacktrace configuration - show 3 lines for context
  # This helps identify the source of N+1 queries
  Bullet.stacktrace_level = 3
end
