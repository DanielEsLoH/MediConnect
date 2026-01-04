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
    resources :appointments, only: [ :show ] do
      collection do
        post :batch
        get "by_user/:user_id", to: "appointments#by_user", as: :by_user
        get "by_doctor/:doctor_id", to: "appointments#by_doctor", as: :by_doctor
      end
      member do
        get :exists
        get :payment_info
      end
    end
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Appointments
      resources :appointments do
        member do
          post :confirm
          post :cancel
          post :complete
        end

        collection do
          get :upcoming
          get :history
        end
      end

      # Video sessions
      resources :video_sessions, only: [ :create, :show ] do
        member do
          post :start
          post :end
          get :token
          get :connection_info
        end
      end
    end
  end
end
