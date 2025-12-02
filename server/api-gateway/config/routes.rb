# frozen_string_literal: true

Rails.application.routes.draw do
  # Health check endpoints
  # Basic health check (Rails built-in)
  get "up" => "rails/health#show", as: :rails_health_check

  # Detailed health check with database and Redis status
  get "health", to: "health#show"

  # Service health checks (checks all downstream services)
  get "health/services", to: "health#services"

  # API Gateway routes
  namespace :api do
    namespace :v1 do
      # ============================================
      # Authentication endpoints
      # ============================================
      scope :auth do
        post "login", to: "auth#login"
        post "refresh", to: "auth#refresh"
        post "logout", to: "auth#logout"
        get "me", to: "auth#me"

        # Password management (proxied to users-service)
        post "password/reset", to: "auth#request_password_reset"
        put "password/reset", to: "auth#reset_password"
      end

      # ============================================
      # Users service proxy
      # ============================================
      resources :users, only: [:index, :show, :create, :update] do
        collection do
          get :search
        end
      end

      # ============================================
      # Doctors service proxy
      # ============================================
      resources :doctors, only: [:index, :show] do
        collection do
          get :search
          get :specialties
        end
        member do
          get :availability
          get :reviews
        end
      end

      # ============================================
      # Appointments service proxy
      # ============================================
      resources :appointments, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :upcoming
          get :past
        end
        member do
          post :confirm
          post :cancel
          post :reschedule
        end
      end

      # ============================================
      # Notifications service proxy (if needed)
      # ============================================
      resources :notifications, only: [:index, :show, :update] do
        collection do
          post :mark_all_read
          get :unread_count
        end
      end

      # ============================================
      # Payments service proxy (if needed)
      # ============================================
      resources :payments, only: [:index, :show, :create] do
        collection do
          get :methods
          post :methods, action: :add_payment_method
        end
        member do
          post :refund
        end
      end
    end
  end

  # Catch-all route for undefined API endpoints
  match "/api/*path", to: "application#route_not_found", via: :all
end
