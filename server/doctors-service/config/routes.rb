# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check endpoints
  # Basic health check (Rails built-in)
  get "up" => "rails/health#show", as: :rails_health_check

  # Detailed health check with database and Redis status
  get "health", to: "health#show"

  # Internal API routes for service-to-service communication
  # These endpoints are called by other microservices
  namespace :internal do
    resources :doctors, only: [ :show ] do
      collection do
        post :batch
      end
      member do
        get :availability
        get :contact_info
        get :exists
        get :validate_for_appointment
      end
    end
  end

  # API routes
  namespace :api do
    namespace :v1 do
      resources :doctors, only: [ :index, :show ] do
        collection do
          get :search
          get :specialties
        end
        member do
          get :availability
          get :reviews
        end
      end

      resources :reviews, only: [ :create, :update, :destroy ]
      resources :specialties, only: [ :index, :show ]
    end
  end
end
