# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeService do
  let(:stripe_api_key) { "sk_test_123" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("STRIPE_SECRET_KEY", any_args).and_return(stripe_api_key)
    allow(ENV).to receive(:fetch).with("STRIPE_WEBHOOK_SECRET").and_return("whsec_test123")
    Stripe.api_key = stripe_api_key
  end

  describe ".create_payment_intent" do
    let(:amount) { 5000 } # $50.00
    let(:currency) { "usd" }
    let(:metadata) { { payment_id: "test123", user_id: "user123" } }
    let(:description) { "Test payment" }

    let(:mock_intent) do
      double(
        "Stripe::PaymentIntent",
        id: "pi_test123",
        client_secret: "pi_test123_secret_abc",
        amount: amount,
        currency: currency
      )
    end

    context "with successful API call" do
      before do
        allow(Stripe::PaymentIntent).to receive(:create).and_return(mock_intent)
      end

      it "creates a payment intent with required parameters" do
        result = described_class.create_payment_intent(
          amount: amount,
          currency: currency,
          metadata: metadata
        )

        expect(Stripe::PaymentIntent).to have_received(:create).with(
          hash_including(
            amount: amount,
            currency: currency,
            metadata: metadata,
            automatic_payment_methods: { enabled: true }
          )
        )
        expect(result).to eq(mock_intent)
      end

      it "includes optional description when provided" do
        described_class.create_payment_intent(
          amount: amount,
          currency: currency,
          metadata: metadata,
          description: description
        )

        expect(Stripe::PaymentIntent).to have_received(:create).with(
          hash_including(description: description)
        )
      end

      it "includes optional receipt_email when provided" do
        receipt_email = "test@example.com"

        described_class.create_payment_intent(
          amount: amount,
          currency: currency,
          metadata: metadata,
          receipt_email: receipt_email
        )

        expect(Stripe::PaymentIntent).to have_received(:create).with(
          hash_including(receipt_email: receipt_email)
        )
      end

      it "logs successful creation" do
        allow(Rails.logger).to receive(:info)

        described_class.create_payment_intent(
          amount: amount,
          currency: currency,
          metadata: metadata
        )

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: "stripe_payment_intent_created",
            payment_intent_id: "pi_test123",
            amount: amount,
            currency: currency
          )
        )
      end
    end

    context "when Stripe API fails" do
      let(:stripe_error) { Stripe::InvalidRequestError.new("Invalid parameters", "param") }

      before do
        allow(Stripe::PaymentIntent).to receive(:create).and_raise(stripe_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        expect {
          described_class.create_payment_intent(amount: amount, currency: currency)
        }.to raise_error(Stripe::InvalidRequestError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_payment_intent_failed",
            error: "Invalid parameters"
          )
        )
      end

      it "raises the Stripe error" do
        expect {
          described_class.create_payment_intent(amount: amount, currency: currency)
        }.to raise_error(Stripe::InvalidRequestError)
      end
    end
  end

  describe ".retrieve_payment_intent" do
    let(:payment_intent_id) { "pi_test123" }
    let(:mock_intent) { double("Stripe::PaymentIntent", id: payment_intent_id) }

    context "when payment intent exists" do
      before do
        allow(Stripe::PaymentIntent).to receive(:retrieve).with(payment_intent_id).and_return(mock_intent)
      end

      it "retrieves the payment intent" do
        result = described_class.retrieve_payment_intent(payment_intent_id)

        expect(Stripe::PaymentIntent).to have_received(:retrieve).with(payment_intent_id)
        expect(result).to eq(mock_intent)
      end
    end

    context "when payment intent doesn't exist" do
      let(:stripe_error) { Stripe::InvalidRequestError.new("No such payment_intent", "id") }

      before do
        allow(Stripe::PaymentIntent).to receive(:retrieve).and_raise(stripe_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        expect {
          described_class.retrieve_payment_intent(payment_intent_id)
        }.to raise_error(Stripe::InvalidRequestError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_payment_intent_retrieve_failed",
            payment_intent_id: payment_intent_id
          )
        )
      end

      it "raises the error" do
        expect {
          described_class.retrieve_payment_intent(payment_intent_id)
        }.to raise_error(Stripe::InvalidRequestError)
      end
    end
  end

  describe ".confirm_payment_intent" do
    let(:payment_intent_id) { "pi_test123" }
    let(:payment_method_id) { "pm_card_visa" }
    let(:mock_intent) { double("Stripe::PaymentIntent", id: payment_intent_id, status: "succeeded") }

    context "with successful confirmation" do
      before do
        allow(Stripe::PaymentIntent).to receive(:confirm).and_return(mock_intent)
      end

      it "confirms the payment intent without payment method" do
        result = described_class.confirm_payment_intent(payment_intent_id)

        expect(Stripe::PaymentIntent).to have_received(:confirm).with(payment_intent_id, {})
        expect(result).to eq(mock_intent)
      end

      it "confirms the payment intent with payment method" do
        result = described_class.confirm_payment_intent(payment_intent_id, payment_method_id: payment_method_id)

        expect(Stripe::PaymentIntent).to have_received(:confirm).with(
          payment_intent_id,
          { payment_method: payment_method_id }
        )
        expect(result).to eq(mock_intent)
      end
    end

    context "when confirmation fails" do
      # Stripe v10+ CardError takes message and param as positional args
      let(:stripe_error) { Stripe::CardError.new("Card declined", "card") }

      before do
        allow(Stripe::PaymentIntent).to receive(:confirm).and_raise(stripe_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        expect {
          described_class.confirm_payment_intent(payment_intent_id)
        }.to raise_error(Stripe::CardError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_payment_intent_confirm_failed",
            payment_intent_id: payment_intent_id
          )
        )
      end
    end
  end

  describe ".cancel_payment_intent" do
    let(:payment_intent_id) { "pi_test123" }
    let(:mock_intent) { double("Stripe::PaymentIntent", id: payment_intent_id, status: "canceled") }

    before do
      allow(Stripe::PaymentIntent).to receive(:cancel).and_return(mock_intent)
    end

    it "cancels the payment intent without reason" do
      result = described_class.cancel_payment_intent(payment_intent_id)

      expect(Stripe::PaymentIntent).to have_received(:cancel).with(payment_intent_id, {})
      expect(result).to eq(mock_intent)
    end

    it "cancels the payment intent with reason" do
      reason = "requested_by_customer"

      result = described_class.cancel_payment_intent(payment_intent_id, reason: reason)

      expect(Stripe::PaymentIntent).to have_received(:cancel).with(
        payment_intent_id,
        { cancellation_reason: reason }
      )
      expect(result).to eq(mock_intent)
    end
  end

  describe ".construct_webhook_event" do
    let(:payload) { '{"id":"evt_test123","type":"payment_intent.succeeded"}' }
    let(:signature) { "t=1234567890,v1=signature_hash" }
    let(:webhook_secret) { "whsec_test123" }
    let(:mock_event) { double("Stripe::Event", id: "evt_test123", type: "payment_intent.succeeded") }

    before do
      allow(ENV).to receive(:fetch).with("STRIPE_WEBHOOK_SECRET").and_return(webhook_secret)
    end

    context "with valid signature" do
      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(mock_event)
        allow(Rails.logger).to receive(:info)
      end

      it "constructs and verifies the webhook event" do
        result = described_class.construct_webhook_event(payload: payload, signature: signature)

        expect(Stripe::Webhook).to have_received(:construct_event).with(
          payload,
          signature,
          webhook_secret
        )
        expect(result).to eq(mock_event)
      end

      it "logs the webhook receipt" do
        described_class.construct_webhook_event(payload: payload, signature: signature)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: "stripe_webhook_received",
            webhook_type: "payment_intent.succeeded",
            event_id: "evt_test123"
          )
        )
      end
    end

    context "with invalid signature" do
      let(:signature_error) { Stripe::SignatureVerificationError.new("Invalid signature", signature) }

      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_raise(signature_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the signature verification error" do
        expect {
          described_class.construct_webhook_event(payload: payload, signature: signature)
        }.to raise_error(Stripe::SignatureVerificationError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_webhook_signature_invalid"
          )
        )
      end

      it "raises the signature verification error" do
        expect {
          described_class.construct_webhook_event(payload: payload, signature: signature)
        }.to raise_error(Stripe::SignatureVerificationError)
      end
    end

    context "with invalid JSON payload" do
      let(:invalid_payload) { "not valid json" }
      let(:json_error) { JSON::ParserError.new("unexpected token") }

      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_raise(json_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the parse error" do
        expect {
          described_class.construct_webhook_event(payload: invalid_payload, signature: signature)
        }.to raise_error(StripeService::StripeError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_webhook_parse_error"
          )
        )
      end

      it "raises a StripeService error" do
        expect {
          described_class.construct_webhook_event(payload: invalid_payload, signature: signature)
        }.to raise_error(StripeService::StripeError, /Invalid webhook payload/)
      end
    end
  end

  describe ".create_refund" do
    let(:charge_id) { "ch_test123" }
    let(:amount) { 5000 }
    let(:reason) { "requested_by_customer" }
    let(:mock_refund) { double("Stripe::Refund", id: "re_test123", amount: amount) }

    context "with successful refund" do
      before do
        allow(Stripe::Refund).to receive(:create).and_return(mock_refund)
        allow(Rails.logger).to receive(:info)
      end

      it "creates a full refund without amount" do
        result = described_class.create_refund(charge_id: charge_id)

        expect(Stripe::Refund).to have_received(:create).with(
          { charge: charge_id }
        )
        expect(result).to eq(mock_refund)
      end

      it "creates a partial refund with amount" do
        result = described_class.create_refund(charge_id: charge_id, amount: amount)

        expect(Stripe::Refund).to have_received(:create).with(
          { charge: charge_id, amount: amount }
        )
        expect(result).to eq(mock_refund)
      end

      it "includes reason when provided" do
        result = described_class.create_refund(charge_id: charge_id, reason: reason)

        expect(Stripe::Refund).to have_received(:create).with(
          { charge: charge_id, reason: reason }
        )
        expect(result).to eq(mock_refund)
      end

      it "logs successful refund" do
        described_class.create_refund(charge_id: charge_id, amount: amount)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: "stripe_refund_created",
            refund_id: "re_test123",
            charge_id: charge_id,
            amount: amount
          )
        )
      end
    end

    context "when refund fails" do
      let(:stripe_error) { Stripe::InvalidRequestError.new("Charge already refunded", "charge") }

      before do
        allow(Stripe::Refund).to receive(:create).and_raise(stripe_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        expect {
          described_class.create_refund(charge_id: charge_id)
        }.to raise_error(Stripe::InvalidRequestError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_refund_failed",
            charge_id: charge_id
          )
        )
      end
    end
  end

  describe ".create_refund_for_intent" do
    let(:payment_intent_id) { "pi_test123" }
    let(:amount) { 5000 }
    let(:mock_refund) { double("Stripe::Refund", id: "re_test123", amount: amount) }

    before do
      allow(Stripe::Refund).to receive(:create).and_return(mock_refund)
      allow(Rails.logger).to receive(:info)
    end

    it "creates a refund for a payment intent" do
      result = described_class.create_refund_for_intent(payment_intent_id: payment_intent_id)

      expect(Stripe::Refund).to have_received(:create).with(
        { payment_intent: payment_intent_id }
      )
      expect(result).to eq(mock_refund)
    end

    it "creates a partial refund with amount" do
      result = described_class.create_refund_for_intent(
        payment_intent_id: payment_intent_id,
        amount: amount
      )

      expect(Stripe::Refund).to have_received(:create).with(
        { payment_intent: payment_intent_id, amount: amount }
      )
      expect(result).to eq(mock_refund)
    end

    it "logs successful refund" do
      described_class.create_refund_for_intent(payment_intent_id: payment_intent_id)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          event: "stripe_refund_created",
          payment_intent_id: payment_intent_id
        )
      )
    end
  end

  describe ".list_payment_methods" do
    let(:customer_id) { "cus_test123" }
    let(:mock_list) { double("Stripe::ListObject", data: []) }

    before do
      allow(Stripe::PaymentMethod).to receive(:list).and_return(mock_list)
    end

    it "lists payment methods for a customer" do
      result = described_class.list_payment_methods(customer_id: customer_id)

      expect(Stripe::PaymentMethod).to have_received(:list).with(
        customer: customer_id,
        type: "card"
      )
      expect(result).to eq(mock_list)
    end

    it "accepts custom payment method type" do
      result = described_class.list_payment_methods(customer_id: customer_id, type: "us_bank_account")

      expect(Stripe::PaymentMethod).to have_received(:list).with(
        customer: customer_id,
        type: "us_bank_account"
      )
      expect(result).to eq(mock_list)
    end
  end

  describe ".create_customer" do
    let(:email) { "test@example.com" }
    let(:name) { "Test User" }
    let(:metadata) { { user_id: "user123" } }
    let(:mock_customer) { double("Stripe::Customer", id: "cus_test123", email: email) }

    context "with successful creation" do
      before do
        allow(Stripe::Customer).to receive(:create).and_return(mock_customer)
      end

      it "creates a customer with email" do
        result = described_class.create_customer(email: email)

        expect(Stripe::Customer).to have_received(:create).with(
          hash_including(email: email)
        )
        expect(result).to eq(mock_customer)
      end

      it "includes optional name and metadata" do
        result = described_class.create_customer(
          email: email,
          name: name,
          metadata: metadata
        )

        expect(Stripe::Customer).to have_received(:create).with(
          hash_including(
            email: email,
            name: name,
            metadata: metadata
          )
        )
        expect(result).to eq(mock_customer)
      end
    end

    context "when creation fails" do
      let(:stripe_error) { Stripe::InvalidRequestError.new("Email already exists", "email") }

      before do
        allow(Stripe::Customer).to receive(:create).and_raise(stripe_error)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error" do
        expect {
          described_class.create_customer(email: email)
        }.to raise_error(Stripe::InvalidRequestError)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "stripe_create_customer_failed",
            email: email
          )
        )
      end
    end
  end

  describe ".get_balance" do
    let(:mock_balance) { double("Stripe::Balance", available: [], pending: []) }

    before do
      allow(Stripe::Balance).to receive(:retrieve).and_return(mock_balance)
    end

    it "retrieves the account balance" do
      result = described_class.get_balance

      expect(Stripe::Balance).to have_received(:retrieve)
      expect(result).to eq(mock_balance)
    end
  end
end
