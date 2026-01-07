# frozen_string_literal: true

module Api
  module V1
    # Controller for payment endpoints
    # Proxies requests to the payments-service
    class PaymentsController < Api::BaseController
      before_action :authenticate_request!
      skip_before_action :authenticate_request!, only: [:webhook]

      # GET /api/v1/payments
      # Lists payments for the current user
      #
      # @query_param [Integer] page Page number for pagination
      # @query_param [Integer] per_page Number of items per page
      # @query_param [String] status Filter by status
      def index
        proxy_request(
          service: :payments,
          path: "/api/v1/payments",
          method: :get,
          params: filter_params.merge(user_scope_params)
        )
      end

      # GET /api/v1/payments/:id
      # Shows a specific payment
      def show
        proxy_request(
          service: :payments,
          path: "/api/v1/payments/#{params[:id]}",
          method: :get
        )
      end

      # POST /api/v1/payments
      # Creates a new payment
      #
      # @body_param [Integer] appointment_id The appointment ID
      # @body_param [Decimal] amount Payment amount
      # @body_param [String] currency Currency code (default: USD)
      # @body_param [String] payment_method_id Stripe payment method ID
      def create
        payment_data = payment_params.to_h
        payment_data[:user_id] = current_user_id unless current_user_has_role?(:admin)

        proxy_request(
          service: :payments,
          path: "/api/v1/payments",
          method: :post,
          body: { payment: payment_data }
        )
      end

      # POST /api/v1/payments/:id/refund
      # Refunds a payment
      #
      # @body_param [Decimal] amount Amount to refund (optional, defaults to full refund)
      # @body_param [String] reason Reason for refund
      def refund
        proxy_request(
          service: :payments,
          path: "/api/v1/payments/#{params[:id]}/refund",
          method: :post,
          body: refund_params.to_h
        )
      end

      # GET /api/v1/payments/methods
      # Lists saved payment methods for the current user
      def methods
        proxy_request(
          service: :payments,
          path: "/api/v1/payment_methods",
          method: :get,
          params: { user_id: current_user_id }
        )
      end

      # POST /api/v1/payments/methods
      # Adds a new payment method for the current user
      #
      # @body_param [String] payment_method_id Stripe payment method ID
      # @body_param [Boolean] set_default Whether to set as default
      def add_payment_method
        proxy_request(
          service: :payments,
          path: "/api/v1/payment_methods",
          method: :post,
          body: payment_method_params.to_h.merge(user_id: current_user_id)
        )
      end

      # POST /api/v1/payments/create_intent
      # Creates a Stripe payment intent
      #
      # @body_param [Integer] appointment_id The appointment ID
      # @body_param [Decimal] amount Payment amount
      def create_intent
        proxy_request(
          service: :payments,
          path: "/api/v1/payments/create-intent",
          method: :post,
          body: intent_params.to_h.merge(user_id: current_user_id)
        )
      end

      # POST /api/v1/payments/confirm
      # Confirms a payment intent
      #
      # @body_param [String] payment_intent_id Stripe payment intent ID
      def confirm
        proxy_request(
          service: :payments,
          path: "/api/v1/payments/confirm",
          method: :post,
          body: confirm_params.to_h
        )
      end

      # POST /api/v1/payments/webhook
      # Handles Stripe webhook events
      # Note: Authentication is skipped for webhooks
      def webhook
        proxy_request(
          service: :payments,
          path: "/api/v1/payments/webhook",
          method: :post,
          body: request.raw_post
        )
      end

      private

      def payment_params
        params.require(:payment).permit(
          :appointment_id,
          :amount,
          :currency,
          :payment_method_id,
          :description
        )
      end

      def filter_params
        params.permit(:page, :per_page, :status, :start_date, :end_date)
      end

      def refund_params
        params.permit(:amount, :reason)
      end

      def payment_method_params
        params.permit(:payment_method_id, :set_default)
      end

      def intent_params
        params.permit(:appointment_id, :amount, :currency)
      end

      def confirm_params
        params.permit(:payment_intent_id)
      end

      # Adds user scope parameters based on role
      def user_scope_params
        return {} if current_user_has_role?(:admin)
        { user_id: current_user_id }
      end
    end
  end
end