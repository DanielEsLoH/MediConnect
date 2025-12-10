# frozen_string_literal: true

# Start EventConsumer when Rails server starts
Rails.application.config.after_initialize do
  if defined?(Rails::Server)
    EventConsumer.start
  end
end
