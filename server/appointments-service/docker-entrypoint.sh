#!/bin/bash
set -e

# =============================================================================
# Rails Docker Entrypoint Script
# Handles: stale PIDs, gem verification, database preparation
# =============================================================================

echo "==> Starting entrypoint script..."

# Remove stale PID file if it exists (prevents "server already running" errors)
if [ -f tmp/pids/server.pid ]; then
  echo "==> Removing stale PID file..."
  rm -f tmp/pids/server.pid
fi

# Verify gems are installed and up to date
# This handles the case where Gemfile changes but volume cache is stale
echo "==> Checking gem bundle..."
if ! bundle check > /dev/null 2>&1; then
  echo "==> Bundle incomplete, installing gems..."
  bundle install
fi

# Prepare database (creates if not exists, runs pending migrations)
# The || true prevents failure if DB already exists or migrations already ran
echo "==> Preparing database..."
bundle exec rails db:prepare 2>/dev/null || bundle exec rails db:migrate 2>/dev/null || true

echo "==> Entrypoint complete, executing command: $@"
exec "$@"