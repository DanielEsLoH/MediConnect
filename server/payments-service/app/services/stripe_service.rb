# frozen_string_literal: true

# StripeService encapsulates all Stripe API interactions for the payments service.
# It provides a clean interface for creating payment intents, handling webhooks,
# and processing refunds.
#
# This service uses class methods for simplicity, as Stripe operations
# are stateless and don't require instance state.
#
# @example Creating a payment intent
#   intent = StripeService.create_payment_intent(
#     amount: 5000,  # $50.00 in cents
#     currency: 'usd',
#     metadata: { payment_id: '123', user_id: '456' }
#   )
#
# @example Processing a webhook event
#   event = StripeService.construct_webhook_event(
#     payload: request.body.read,
#     signature: request.env['HTTP_STRIPE_SIGNATURE']
#   )
#
class StripeService
  # Custom error class for Stripe-related errors
  class StripeError < StandardError; end

  class << self
    # Creates a PaymentIntent with Stripe
    # PaymentIntents are used to collect card payments
    #
    # @param amount [Integer] Amount in cents (e.g., 5000 for $50.00)
    # @param currency [String] Three-letter ISO currency code (default: 'usd')
    # @param metadata [Hash] Additional data to store with the payment
    # @param description [String] Optional description for the payment
    # @param receipt_email [String] Optional email for sending receipt
    # @return [Stripe::PaymentIntent] The created payment intent
    # @raise [Stripe::StripeError] If the API call fails
    def create_payment_intent(amount:, currency: "usd", metadata: {}, description: nil, receipt_email: nil)
      params = {
        amount: amount,
        currency: currency.downcase,
        metadata: metadata,
        automatic_payment_methods: {
          enabled: true
        }
      }

      # Add optional parameters if provided
      params[:description] = description if description.present?
      params[:receipt_email] = receipt_email if receipt_email.present?

      intent = Stripe::PaymentIntent.create(params)

      Rails.logger.info(
        event: "stripe_payment_intent_created",
        payment_intent_id: intent.id,
        amount: amount,
        currency: currency
      )

      intent
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_payment_intent_failed",
        error: e.message,
        amount: amount,
        currency: currency
      )
      raise
    end

    # Retrieves an existing PaymentIntent from Stripe
    #
    # @param payment_intent_id [String] The ID of the PaymentIntent to retrieve
    # @return [Stripe::PaymentIntent] The retrieved payment intent
    # @raise [Stripe::InvalidRequestError] If the PaymentIntent doesn't exist
    def retrieve_payment_intent(payment_intent_id)
      Stripe::PaymentIntent.retrieve(payment_intent_id)
    rescue Stripe::InvalidRequestError => e
      Rails.logger.error(
        event: "stripe_payment_intent_retrieve_failed",
        payment_intent_id: payment_intent_id,
        error: e.message
      )
      raise
    end

    # Confirms a PaymentIntent server-side
    # Typically used after client-side payment method collection
    #
    # @param payment_intent_id [String] The ID of the PaymentIntent to confirm
    # @param payment_method_id [String] Optional payment method to use
    # @return [Stripe::PaymentIntent] The confirmed payment intent
    def confirm_payment_intent(payment_intent_id, payment_method_id: nil)
      params = {}
      params[:payment_method] = payment_method_id if payment_method_id.present?

      Stripe::PaymentIntent.confirm(payment_intent_id, params)
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_payment_intent_confirm_failed",
        payment_intent_id: payment_intent_id,
        error: e.message
      )
      raise
    end

    # Cancels a PaymentIntent
    # Can only cancel intents that haven't been captured
    #
    # @param payment_intent_id [String] The ID of the PaymentIntent to cancel
    # @param reason [String] Optional cancellation reason
    # @return [Stripe::PaymentIntent] The cancelled payment intent
    def cancel_payment_intent(payment_intent_id, reason: nil)
      params = {}
      params[:cancellation_reason] = reason if reason.present?

      Stripe::PaymentIntent.cancel(payment_intent_id, params)
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_payment_intent_cancel_failed",
        payment_intent_id: payment_intent_id,
        error: e.message
      )
      raise
    end

    # Constructs and validates a webhook event from Stripe
    # This verifies the signature to ensure the webhook is authentic
    #
    # @param payload [String] The raw request body
    # @param signature [String] The Stripe-Signature header value
    # @return [Stripe::Event] The verified webhook event
    # @raise [Stripe::SignatureVerificationError] If the signature is invalid
    def construct_webhook_event(payload:, signature:)
      webhook_secret = ENV.fetch("STRIPE_WEBHOOK_SECRET")

      event = Stripe::Webhook.construct_event(
        payload,
        signature,
        webhook_secret
      )

      Rails.logger.info(
        event: "stripe_webhook_received",
        webhook_type: event.type,
        event_id: event.id
      )

      event
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error(
        event: "stripe_webhook_signature_invalid",
        error: e.message
      )
      raise
    rescue JSON::ParserError => e
      Rails.logger.error(
        event: "stripe_webhook_parse_error",
        error: e.message
      )
      raise StripeError, "Invalid webhook payload: #{e.message}"
    end

    # Creates a refund for a charge
    #
    # @param charge_id [String] The ID of the charge to refund
    # @param amount [Integer, nil] Amount to refund in cents (nil for full refund)
    # @param reason [String] Optional refund reason
    # @return [Stripe::Refund] The created refund
    # @raise [Stripe::StripeError] If the refund fails
    def create_refund(charge_id:, amount: nil, reason: nil)
      params = { charge: charge_id }
      params[:amount] = amount if amount.present?
      params[:reason] = reason if reason.present?

      refund = Stripe::Refund.create(params)

      Rails.logger.info(
        event: "stripe_refund_created",
        refund_id: refund.id,
        charge_id: charge_id,
        amount: amount || "full"
      )

      refund
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_refund_failed",
        charge_id: charge_id,
        amount: amount,
        error: e.message
      )
      raise
    end

    # Creates a refund for a PaymentIntent
    # This is the newer method and should be preferred over charge-based refunds
    #
    # @param payment_intent_id [String] The ID of the PaymentIntent to refund
    # @param amount [Integer, nil] Amount to refund in cents (nil for full refund)
    # @param reason [String] Optional refund reason
    # @return [Stripe::Refund] The created refund
    def create_refund_for_intent(payment_intent_id:, amount: nil, reason: nil)
      params = { payment_intent: payment_intent_id }
      params[:amount] = amount if amount.present?
      params[:reason] = reason if reason.present?

      refund = Stripe::Refund.create(params)

      Rails.logger.info(
        event: "stripe_refund_created",
        refund_id: refund.id,
        payment_intent_id: payment_intent_id,
        amount: amount || "full"
      )

      refund
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_refund_failed",
        payment_intent_id: payment_intent_id,
        amount: amount,
        error: e.message
      )
      raise
    end

    # Retrieves a customer's payment methods
    # Useful for displaying saved cards for returning customers
    #
    # @param customer_id [String] The Stripe customer ID
    # @param type [String] Payment method type (default: 'card')
    # @return [Stripe::ListObject] List of payment methods
    def list_payment_methods(customer_id:, type: "card")
      Stripe::PaymentMethod.list(
        customer: customer_id,
        type: type
      )
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_list_payment_methods_failed",
        customer_id: customer_id,
        error: e.message
      )
      raise
    end

    # Creates or retrieves a Stripe customer
    # Customers allow storing payment methods for future use
    #
    # @param email [String] Customer email
    # @param name [String] Customer name
    # @param metadata [Hash] Additional metadata
    # @return [Stripe::Customer] The created or existing customer
    def create_customer(email:, name: nil, metadata: {})
      Stripe::Customer.create(
        email: email,
        name: name,
        metadata: metadata
      )
    rescue Stripe::StripeError => e
      Rails.logger.error(
        event: "stripe_create_customer_failed",
        email: email,
        error: e.message
      )
      raise
    end

    # Retrieves the current Stripe balance
    # Useful for dashboard/admin reporting
    #
    # @return [Stripe::Balance] The account balance
    def get_balance
      Stripe::Balance.retrieve
    end
  end
end
