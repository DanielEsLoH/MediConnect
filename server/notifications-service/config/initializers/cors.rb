# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Parse origins from environment variable or use defaults for development
    origins_list = ENV.fetch("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173").split(",")

    origins(*origins_list)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true,
      max_age: 86400
  end
end
