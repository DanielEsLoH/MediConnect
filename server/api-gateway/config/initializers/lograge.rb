# frozen_string_literal: true

# Lograge configuration for structured JSON logging
# Provides cleaner, more parseable logs for production monitoring
#
Rails.application.configure do
  config.lograge.enabled = true

  # Use JSON formatter for structured logging
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Keep original Rails logger for non-request logs
  config.lograge.keep_original_rails_log = false

  # Log to STDOUT in all environments (for Docker/container compatibility)
  config.lograge.logger = ActiveSupport::Logger.new($stdout)

  # Custom options to include in each log entry
  config.lograge.custom_options = lambda do |event|
    options = {
      timestamp: Time.current.iso8601,
      service: "api-gateway",
      environment: Rails.env,
      host: Socket.gethostname
    }

    # Add request ID for distributed tracing
    if event.payload[:request_id].present?
      options[:request_id] = event.payload[:request_id]
    elsif Thread.current[:request_id].present?
      options[:request_id] = Thread.current[:request_id]
    end

    # Add correlation ID if present
    if Thread.current[:correlation_id].present?
      options[:correlation_id] = Thread.current[:correlation_id]
    end

    # Add user ID for authenticated requests
    options[:user_id] = event.payload[:user_id] if event.payload[:user_id].present?

    # Add exception info if present
    if event.payload[:exception].present?
      exception_class, exception_message = event.payload[:exception]
      options[:exception] = {
        class: exception_class,
        message: exception_message
      }
    end

    # Add custom tags if present
    options[:tags] = event.payload[:tags] if event.payload[:tags].present?

    # Add params (filtered)
    if event.payload[:params].present?
      options[:params] = filter_params(event.payload[:params])
    end

    options
  end

  # Custom payload to capture request ID and user ID from controller
  config.lograge.custom_payload do |controller|
    payload = {}

    # Capture request ID
    payload[:request_id] = controller.request.request_id if controller.request.respond_to?(:request_id)

    # Capture user ID if available (from Authenticatable concern)
    payload[:user_id] = controller.current_user_id if controller.respond_to?(:current_user_id)

    payload
  end

  # Ignore certain paths from logging
  config.lograge.ignore_actions = [
    "HealthController#show",
    "Rails::HealthController#show"
  ]

  # Ignore certain statuses (uncomment if needed)
  # config.lograge.ignore_custom = lambda do |event|
  #   event.payload[:status] == 304
  # end
end

# Helper method to filter sensitive parameters
def filter_params(params)
  return {} if params.blank?

  sensitive_keys = %w[
    password
    password_confirmation
    current_password
    token
    access_token
    refresh_token
    api_key
    secret
    secret_key
    credit_card
    card_number
    cvv
    ssn
    social_security
  ]

  filtered = params.deep_dup

  filtered.each do |key, value|
    if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
      filtered[key] = "[FILTERED]"
    elsif value.is_a?(Hash)
      filtered[key] = filter_params(value)
    elsif value.is_a?(Array)
      filtered[key] = value.map { |v| v.is_a?(Hash) ? filter_params(v) : v }
    end
  end

  # Remove controller and action from params (already in log)
  filtered.except("controller", "action")
end
