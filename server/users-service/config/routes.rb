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
      resources :users, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :search
        end
      end

      resources :medical_records, only: [:index, :show, :create, :update, :destroy]
      resources :allergies, only: [:index, :show, :create, :update, :destroy]
    end
  end
end
