# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check endpoints
  # Basic health check (Rails built-in)
  get "up" => "rails/health#show", as: :rails_health_check

  # Detailed health check with database and Redis status
  get "health", to: "health#show"

  # Notifications routes
  resources :notifications, only: [ :index, :show, :create, :destroy ] do
    collection do
      get :unread_count
      post :mark_all_as_read
    end
    member do
      post :mark_as_read
    end
  end

  # Notification preferences routes
  resources :notification_preferences, only: [ :show, :update ]
end
