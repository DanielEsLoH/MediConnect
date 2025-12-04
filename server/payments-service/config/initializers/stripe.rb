# frozen_string_literal: true

# Stripe Configuration
# ====================
# This initializer configures the Stripe Ruby library with API keys
# and optional settings for the Payments Service.
#
# Environment Variables Required:
# - STRIPE_SECRET_KEY: Your Stripe secret API key (sk_test_... or sk_live_...)
# - STRIPE_WEBHOOK_SECRET: Webhook endpoint signing secret (whsec_...)
# - STRIPE_PUBLISHABLE_KEY: Publishable key for frontend (pk_test_... or pk_live_...)
#
# Optional Environment Variables:
# - STRIPE_API_VERSION: Override the default API version
# - STRIPE_MAX_NETWORK_RETRIES: Number of automatic retries (default: 2)
#
# Security Notes:
# - Never commit API keys to version control
# - Use different keys for development, staging, and production
# - Rotate keys if compromised
# - Use restricted keys with minimum required permissions in production
#

Rails.application.configure do
  # Set the Stripe API key
  # This is required for all Stripe API calls
  Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY") do
    if Rails.env.production?
      raise "STRIPE_SECRET_KEY environment variable is required in production"
    else
      # Allow nil in development/test for easier setup
      Rails.logger.warn("STRIPE_SECRET_KEY not set - Stripe API calls will fail")
      nil
    end
  end

  # Set the API version to ensure consistent behavior
  # This prevents breaking changes when Stripe updates their API
  # Update this when you're ready to migrate to a new API version
  Stripe.api_version = ENV.fetch("STRIPE_API_VERSION", "2023-10-16")

  # Configure automatic retries for transient network errors
  # Stripe recommends 2-3 retries for production applications
  Stripe.max_network_retries = ENV.fetch("STRIPE_MAX_NETWORK_RETRIES", 2).to_i

  # Enable logging of Stripe requests in development
  if Rails.env.development?
    Stripe.log_level = Stripe::LEVEL_INFO
  end

  # Configure timeouts
  # Default open timeout is 30 seconds, read timeout is 80 seconds
  # Adjust based on your application's needs
  Stripe.open_timeout = ENV.fetch("STRIPE_OPEN_TIMEOUT", 30).to_i
  Stripe.read_timeout = ENV.fetch("STRIPE_READ_TIMEOUT", 80).to_i

  # Log configuration status
  if Stripe.api_key.present?
    key_type = Stripe.api_key.start_with?("sk_live") ? "LIVE" : "TEST"
    Rails.logger.info("Stripe configured with #{key_type} key")
  end
end
