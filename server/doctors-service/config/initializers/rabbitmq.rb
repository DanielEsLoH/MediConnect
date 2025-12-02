# frozen_string_literal: true

# RabbitMQ configuration
# Connection is lazy-loaded in EventPublisher service
Rails.application.config.rabbitmq_url = ENV.fetch("RABBITMQ_URL", "amqp://guest:guest@localhost:5672")
