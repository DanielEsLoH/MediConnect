# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check endpoints
  # Basic health check (Rails built-in)
  get "up" => "rails/health#show", as: :rails_health_check

  # Detailed health check with database and Redis status
  get "health", to: "health#show"

  # Internal API routes for service-to-service communication
  # These endpoints are called by other microservices
  # api-gateway expects /api/internal/...
  namespace :api do
    namespace :internal do
      post "authenticate", to: "authentication#authenticate"
      
      resources :users, only: [ :show ] do
        collection do
          post :batch
          get :by_email
        end
        member do
          get :contact_info
          get :exists
        end
      end
      
      # Password reset endpoints
      post "password/reset", to: "password_reset#create"
      put "password/reset", to: "password_reset#update"
    end
  end

  # External API routes
  namespace :api do
    namespace :v1 do
      resources :users, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          get :search
        end
      end

      resources :medical_records, only: [ :index, :show, :create, :update, :destroy ]
      resources :allergies, only: [ :index, :show, :create, :update, :destroy ]
    end
  end
end
