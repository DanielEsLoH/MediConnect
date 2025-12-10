# frozen_string_literal: true

Rails.application.routes.draw do
  # =============================================================================
  # HEALTH CHECK ENDPOINTS
  # =============================================================================

  # Basic health check (Rails built-in)
  get "up" => "rails/health#show", as: :rails_health_check

  # Detailed health check with database and Redis status
  get "health", to: "health#show"

  # =============================================================================
  # API ROUTES
  # =============================================================================

  namespace :api do
    namespace :v1 do
      # -------------------------------------------------------------------------
      # PAYMENTS
      # -------------------------------------------------------------------------
      # RESTful payment resources
      resources :payments, only: [ :index, :show, :create ] do
        member do
          # POST /api/v1/payments/:id/refund
          # Process a refund for a completed payment (admin only)
          post :refund
        end
      end

      # Payment processing endpoints (non-RESTful actions)
      # POST /api/v1/payments/create-intent
      # Creates a new payment and Stripe PaymentIntent
      post "payments/create-intent", to: "payments#create_intent"

      # POST /api/v1/payments/confirm
      # Confirms a payment after client-side completion
      post "payments/confirm", to: "payments#confirm"

      # POST /api/v1/payments/webhook
      # Stripe webhook endpoint for payment status updates
      # Note: This endpoint should not require authentication
      # as it's called by Stripe servers
      post "payments/webhook", to: "payments#webhook"

      # -------------------------------------------------------------------------
      # FUTURE ENDPOINTS (placeholders)
      # -------------------------------------------------------------------------
      # Uncomment and implement as needed:
      #
      # resources :invoices, only: [:index, :show, :create] do
      #   member do
      #     post :send_email
      #     post :mark_paid
      #   end
      # end
      #
      # resources :subscriptions, only: [:index, :show, :create, :update, :destroy] do
      #   member do
      #     post :cancel
      #     post :resume
      #   end
      # end
      #
      # resources :payment_methods, only: [:index, :create, :destroy] do
      #   member do
      #     post :set_default
      #   end
      # end
    end
  end

  # =============================================================================
  # CATCH-ALL ROUTE (Optional)
  # =============================================================================
  # Uncomment to return 404 for unknown routes instead of Rails default error
  #
  # match "*unmatched", to: proc { |_env|
  #   [
  #     404,
  #     { "Content-Type" => "application/json" },
  #     [{ error: "not_found", message: "Endpoint not found" }.to_json]
  #   ]
  # }, via: :all
end
