# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check endpoints
  # Basic health check (Rails built-in)
  get "up" => "rails/health#show", as: :rails_health_check

  # Detailed health check with database and Redis status
  get "health", to: "health#show"

  # API routes
  namespace :api do
    namespace :v1 do
      # Doctor routes will be added here
      # resources :doctors
      # resources :specialties
      # resources :schedules
    end
  end
end
