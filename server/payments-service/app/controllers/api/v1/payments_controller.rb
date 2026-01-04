# frozen_string_literal: true

module Api
  module V1
    # PaymentsController handles all payment-related API endpoints
    # including creating payment intents, confirming payments, and
    # processing Stripe webhooks.
    #
    # Authentication is required for all endpoints except webhooks,
    # which use signature verification instead.
    #
    # @example Creating a payment intent
    #   POST /api/v1/payments/create-intent
    #   {
    #     "amount": 50.00,
    #     "appointment_id": "uuid-here"
    #   }
    #
    class PaymentsController < ApplicationController
      # Skip authentication for webhook endpoint (uses signature verification)
      skip_before_action :set_request_id, only: [ :webhook ]
      before_action :authenticate_request, except: [ :webhook ]
      before_action :set_payment, only: [ :show ]

      # GET /api/v1/payments
      # Lists payments for the current user (or all payments for admins)
      # Supports pagination via page and per_page parameters
      #
      # @param page [Integer] Page number (default: 1)
      # @param per_page [Integer] Items per page (default: 20, max: 100)
      # @param status [String] Optional status filter
      # @return [JSON] Paginated list of payments
      def index
        payments = build_payment_scope
        payments = apply_filters(payments)
        payments = payments.recent

        # Apply pagination
        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].to_i
        per_page = 20 if per_page <= 0
        per_page = [ per_page, 100 ].min

        offset = (page - 1) * per_page
        total_count = payments.count
        paginated_payments = payments.limit(per_page).offset(offset)

        render json: {
          payments: serialize_payments(paginated_payments),
          meta: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }
      end

      # GET /api/v1/payments/:id
      # Shows details for a specific payment
      # Users can only view their own payments unless they are admins
      #
      # @return [JSON] Payment details
      def show
        return unless authorize_payment_access!
        render json: { payment: serialize_payment(@payment) }
      end

      # POST /api/v1/payments
      # Creates a new payment record directly
      #
      # @return [JSON] Payment details
      def create
        payment = Payment.new(payment_params)
        payment.user_id ||= current_user_id

        if payment.save
          render json: serialize_payment(payment), status: :created
        else
          render json: { errors: payment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/payments/create-intent
      # Creates a new payment and Stripe PaymentIntent
      # Returns client_secret for frontend payment completion
      #
      # @param amount [Float] Payment amount (required)
      # @param appointment_id [String] UUID of the appointment (optional)
      # @param description [String] Payment description (optional)
      # @return [JSON] Payment ID and Stripe client_secret
      def create_intent
        return unless validate_create_intent_params!

        amount = params[:amount].to_f
        appointment_id = params[:appointment_id]
        description = params[:description] || generate_description(appointment_id)

        # Create Payment record in pending state
        payment = Payment.create!(
          user_id: current_user_id,
          appointment_id: appointment_id,
          amount: amount,
          currency: params[:currency] || "USD",
          status: :pending,
          payment_method: params[:payment_method],
          description: description
        )

        # Create Stripe PaymentIntent
        intent = StripeService.create_payment_intent(
          amount: payment.amount_in_cents,
          currency: payment.currency.downcase,
          metadata: {
            payment_id: payment.id,
            user_id: current_user_id,
            appointment_id: appointment_id
          }.compact,
          description: description
        )

        # Update payment with Stripe reference
        payment.update!(stripe_payment_intent_id: intent.id)

        render json: {
          payment_id: payment.id,
          client_secret: intent.client_secret,
          publishable_key: ENV["STRIPE_PUBLISHABLE_KEY"],
          amount: amount,
          currency: payment.currency
        }, status: :created
      end

      # POST /api/v1/payments/confirm
      # Confirms a payment after client-side completion
      # Verifies the PaymentIntent status with Stripe
      #
      # @param payment_id [String] UUID of the payment (required)
      # @param payment_intent_id [String] Stripe PaymentIntent ID (required)
      # @return [JSON] Payment status and details
      def confirm
        payment_id = params.require(:payment_id)
        payment_intent_id = params.require(:payment_intent_id)

        payment = Payment.find(payment_id)

        # Verify the user owns this payment
        unless current_user_admin? || payment.user_id == current_user_id
          render_forbidden("You cannot confirm this payment")
          return
        end

        # Retrieve PaymentIntent from Stripe to verify status
        intent = StripeService.retrieve_payment_intent(payment_intent_id)

        # Verify the intent matches the payment
        unless payment.stripe_payment_intent_id == intent.id
          render json: {
            error: "payment_mismatch",
            message: "Payment intent does not match payment record"
          }, status: :bad_request
          return
        end

        case intent.status
        when "succeeded"
          # Get charge ID from the latest charge
          charge_id = extract_charge_id(intent)
          payment.mark_as_completed!(charge_id: charge_id)

          render json: {
            status: "success",
            payment: serialize_payment(payment)
          }
        when "processing"
          payment.mark_as_processing!

          render json: {
            status: "processing",
            message: "Payment is being processed",
            payment: serialize_payment(payment)
          }
        when "requires_payment_method", "requires_confirmation", "requires_action"
          render json: {
            status: "pending",
            message: "Payment requires additional action",
            payment: serialize_payment(payment)
          }
        else
          payment.mark_as_failed!(reason: "Payment not completed: #{intent.status}")

          render json: {
            status: "failed",
            error: "Payment not completed",
            payment_status: intent.status
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/payments/:id/refund
      # Creates a refund for a completed payment
      # Admins can refund any payment; users can only request refunds
      #
      # @param amount [Float] Amount to refund (optional, defaults to full refund)
      # @param reason [String] Refund reason (optional)
      # @return [JSON] Refund status
      def refund
        payment = Payment.find(params[:id])

        # Only admins can process refunds directly
        unless current_user_admin?
          render_forbidden("Only administrators can process refunds")
          return
        end

        unless payment.refundable?
          render json: {
            error: "not_refundable",
            message: "This payment cannot be refunded"
          }, status: :unprocessable_entity
          return
        end

        # Calculate refund amount
        refund_amount = params[:amount].present? ? (params[:amount].to_f * 100).to_i : nil
        partial = refund_amount.present? && refund_amount < payment.amount_in_cents

        # Create refund via Stripe
        refund = StripeService.create_refund(
          charge_id: payment.stripe_charge_id,
          amount: refund_amount,
          reason: params[:reason]
        )

        # Update payment status
        payment.mark_as_refunded!(partial: partial)

        render json: {
          status: "success",
          refund_id: refund.id,
          amount_refunded: refund.amount / 100.0,
          payment: serialize_payment(payment.reload)
        }
      end

      # POST /api/v1/payments/webhook
      # Handles Stripe webhook events
      # Verifies signature and processes payment status updates
      #
      # This endpoint does not require authentication as it's called by Stripe.
      # Security is ensured via webhook signature verification.
      #
      # @return [JSON] Acknowledgement of webhook receipt
      def webhook
        payload = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

        # Verify and construct the webhook event
        event = StripeService.construct_webhook_event(
          payload: payload,
          signature: sig_header
        )

        # Process the event based on type
        case event.type
        when "payment_intent.succeeded"
          handle_payment_success(event.data.object)
        when "payment_intent.payment_failed"
          handle_payment_failure(event.data.object)
        when "payment_intent.canceled"
          handle_payment_canceled(event.data.object)
        when "charge.refunded"
          handle_charge_refunded(event.data.object)
        when "charge.dispute.created"
          handle_dispute_created(event.data.object)
        else
          # Log unhandled event types for monitoring
          Rails.logger.info(
            event: "webhook_unhandled",
            type: event.type,
            event_id: event.id
          )
        end

        render json: { received: true }, status: :ok
      end

      private

      # =============================================================================
      # BEFORE ACTIONS
      # =============================================================================

      # Finds and sets the payment for show/update actions
      def set_payment
        @payment = Payment.find(params[:id])
      end

      # =============================================================================
      # AUTHORIZATION
      # =============================================================================

      # Builds the base scope for payments query
      # Admins see all payments; users see only their own
      #
      # @return [ActiveRecord::Relation] Payment scope
      def build_payment_scope
        if current_user_admin?
          Payment.all
        else
          Payment.for_user(current_user_id)
        end
      end

      # Applies optional filters to the payments query
      #
      # @param scope [ActiveRecord::Relation] The base scope
      # @return [ActiveRecord::Relation] Filtered scope
      def apply_filters(scope)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(appointment_id: params[:appointment_id]) if params[:appointment_id].present?

        if params[:start_date].present? && params[:end_date].present?
          scope = scope.between_dates(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end

        scope
      end

      # Verifies the current user can access the payment
      # Admins can access any payment; users can only access their own
      #
      # @return [Boolean] true if authorized, false if forbidden (and response was rendered)
      def authorize_payment_access!
        return true if current_user_admin?
        return true if @payment.user_id == current_user_id

        render_forbidden("You do not have permission to view this payment")
        false
      end

      # =============================================================================
      # PARAMETER VALIDATION
      # =============================================================================

      # Validates required parameters for create_intent
      # @return [Boolean] true if valid, false if validation failed (and response was rendered)
      def validate_create_intent_params!
        amount = params[:amount]

        if amount.blank?
          render json: {
            error: "parameter_missing",
            message: "Amount is required"
          }, status: :bad_request
          return false
        end

        if amount.to_f <= 0
          render json: {
            error: "invalid_amount",
            message: "Amount must be greater than zero"
          }, status: :bad_request
          return false
        end

        true
      end

      # =============================================================================
      # WEBHOOK HANDLERS
      # =============================================================================

      # Handles successful payment webhook
      #
      # @param payment_intent [Stripe::PaymentIntent] The payment intent object
      def handle_payment_success(payment_intent)
        payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)

        unless payment
          Rails.logger.warn(
            event: "webhook_payment_not_found",
            payment_intent_id: payment_intent.id
          )
          return
        end

        return if payment.status_completed? # Idempotency check

        charge_id = extract_charge_id(payment_intent)
        payment.mark_as_completed!(charge_id: charge_id)

        Rails.logger.info(
          event: "webhook_payment_completed",
          payment_id: payment.id,
          amount: payment.amount
        )
      end

      # Handles failed payment webhook
      #
      # @param payment_intent [Stripe::PaymentIntent] The payment intent object
      def handle_payment_failure(payment_intent)
        payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)

        unless payment
          Rails.logger.warn(
            event: "webhook_payment_not_found",
            payment_intent_id: payment_intent.id
          )
          return
        end

        return if payment.status_failed? # Idempotency check

        failure_reason = payment_intent.last_payment_error&.message || "Payment failed"
        payment.mark_as_failed!(reason: failure_reason)

        Rails.logger.info(
          event: "webhook_payment_failed",
          payment_id: payment.id,
          reason: failure_reason
        )
      end

      # Handles canceled payment webhook
      #
      # @param payment_intent [Stripe::PaymentIntent] The payment intent object
      def handle_payment_canceled(payment_intent)
        payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)

        return unless payment

        payment.mark_as_failed!(reason: "Payment canceled")

        Rails.logger.info(
          event: "webhook_payment_canceled",
          payment_id: payment.id
        )
      end

      # Handles refund webhook
      #
      # @param charge [Stripe::Charge] The charge object with refund info
      def handle_charge_refunded(charge)
        payment = Payment.find_by(stripe_charge_id: charge.id)

        return unless payment

        # Check if fully or partially refunded
        partial = charge.amount_refunded < charge.amount
        payment.mark_as_refunded!(partial: partial)

        Rails.logger.info(
          event: "webhook_payment_refunded",
          payment_id: payment.id,
          partial: partial
        )
      end

      # Handles dispute creation webhook
      #
      # @param dispute [Stripe::Dispute] The dispute object
      def handle_dispute_created(dispute)
        charge = Stripe::Charge.retrieve(dispute.charge)
        payment = Payment.find_by(stripe_charge_id: charge.id)

        return unless payment

        # Log dispute for manual review
        Rails.logger.error(
          event: "payment_dispute_created",
          payment_id: payment.id,
          dispute_id: dispute.id,
          amount: dispute.amount,
          reason: dispute.reason
        )

        # Optionally notify admins here
        # AdminNotificationService.notify_dispute(payment, dispute)
      end

      # =============================================================================
      # HELPERS
      # =============================================================================

      # Extracts the charge ID from a PaymentIntent
      # Handles both the latest_charge field and charges list
      #
      # @param intent [Stripe::PaymentIntent] The payment intent
      # @return [String, nil] The charge ID
      def extract_charge_id(intent)
        # Stripe v10+ uses latest_charge
        if intent.respond_to?(:latest_charge) && intent.latest_charge
          intent.latest_charge
        elsif intent.charges&.data&.any?
          intent.charges.data.first.id
        end
      end

      # Generates a description for the payment
      #
      # @param appointment_id [String, nil] The appointment ID
      # @return [String] The payment description
      def generate_description(appointment_id)
        if appointment_id.present?
          "MediConnect - Payment for appointment #{appointment_id}"
        else
          "MediConnect - Payment"
        end
      end

      # Serializes a single payment for JSON response
      #
      # @param payment [Payment] The payment to serialize
      # @return [Hash] Serialized payment data
      def serialize_payment(payment)
        {
          id: payment.id,
          user_id: payment.user_id,
          appointment_id: payment.appointment_id,
          amount: payment.amount.to_f,
          currency: payment.currency,
          status: payment.status,
          status_description: payment.status_description,
          payment_method: payment.payment_method,
          description: payment.description,
          paid_at: payment.paid_at&.iso8601,
          failure_reason: payment.failure_reason,
          created_at: payment.created_at.iso8601,
          updated_at: payment.updated_at.iso8601
        }
      end

      # Serializes multiple payments for JSON response
      #
      # @param payments [ActiveRecord::Relation] The payments to serialize
      # @return [Array<Hash>] Serialized payments data
      def serialize_payments(payments)
        payments.map { |payment| serialize_payment(payment) }
      end

      def payment_params
        params.require(:payment).permit(
          :appointment_id,
          :amount,
          :currency,
          :payment_method,
          :status,
          :stripe_charge_id,
          :description,
          :user_id
        )
      end
    end
  end
end
