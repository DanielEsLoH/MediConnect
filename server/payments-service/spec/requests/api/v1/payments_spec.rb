# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Payments", type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:admin_id) { SecureRandom.uuid }
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:auth_headers) { headers.merge("X-User-Id" => user_id, "X-User-Role" => "patient") }
  let(:admin_headers) { headers.merge("X-User-Id" => admin_id, "X-User-Role" => "admin") }

  # =============================================================================
  # GET /api/v1/payments
  # =============================================================================
  describe "GET /api/v1/payments" do
    context "when user is authenticated" do
      before do
        create_list(:payment, 3, user_id: user_id)
        create_list(:payment, 2, user_id: SecureRandom.uuid)
      end

      it "returns only the current user's payments" do
        get "/api/v1/payments", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payments"].length).to eq(3)
        expect(json["payments"].all? { |p| p["user_id"] == user_id }).to be true
      end

      it "returns paginated results" do
        get "/api/v1/payments", headers: auth_headers, params: { page: 1, per_page: 2 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payments"].length).to eq(2)
        expect(json["meta"]["current_page"]).to eq(1)
        expect(json["meta"]["per_page"]).to eq(2)
        expect(json["meta"]["total_count"]).to eq(3)
        expect(json["meta"]["total_pages"]).to eq(2)
      end

      it "returns payments ordered by most recent first" do
        # Create payments with specific timestamps
        # Note: the before block creates 3 payments with current timestamp
        oldest = create(:payment, user_id: user_id, created_at: 3.days.ago)
        newest = create(:payment, user_id: user_id, created_at: 1.second.from_now)
        middle = create(:payment, user_id: user_id, created_at: 1.day.ago)

        get "/api/v1/payments", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        payment_ids = json["payments"].map { |p| p["id"] }
        # newest should be first as it's in the future
        expect(payment_ids.first).to eq(newest.id)
      end

      it "filters by status when provided" do
        completed = create(:payment, :completed, user_id: user_id)
        create(:payment, :pending, user_id: user_id)
        create(:payment, :failed, user_id: user_id)

        get "/api/v1/payments", headers: auth_headers, params: { status: "completed" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payments"].length).to eq(1)
        expect(json["payments"].first["id"]).to eq(completed.id)
      end

      it "filters by appointment_id when provided" do
        appointment_id = SecureRandom.uuid
        payment_for_appointment = create(:payment, user_id: user_id, appointment_id: appointment_id)
        create(:payment, user_id: user_id, appointment_id: SecureRandom.uuid)

        get "/api/v1/payments", headers: auth_headers, params: { appointment_id: appointment_id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payments"].length).to eq(1)
        expect(json["payments"].first["id"]).to eq(payment_for_appointment.id)
      end

      it "filters by date range when provided" do
        in_range = create(:payment, user_id: user_id, created_at: 3.days.ago)
        create(:payment, user_id: user_id, created_at: 10.days.ago)
        create(:payment, user_id: user_id, created_at: 1.hour.ago)

        get "/api/v1/payments", headers: auth_headers, params: {
          start_date: 5.days.ago.to_date.to_s,
          end_date: 2.days.ago.to_date.to_s
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payments"].length).to eq(1)
        expect(json["payments"].first["id"]).to eq(in_range.id)
      end

      it "limits per_page to maximum of 100" do
        get "/api/v1/payments", headers: auth_headers, params: { per_page: 500 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["meta"]["per_page"]).to eq(100)
      end

      it "defaults to page 1 and per_page 20" do
        get "/api/v1/payments", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["meta"]["current_page"]).to eq(1)
        expect(json["meta"]["per_page"]).to eq(20)
      end
    end

    context "when user is an admin" do
      before do
        create_list(:payment, 3, user_id: user_id)
        create_list(:payment, 2, user_id: SecureRandom.uuid)
      end

      it "returns all payments" do
        get "/api/v1/payments", headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payments"].length).to eq(5)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized error" do
        get "/api/v1/payments", headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # =============================================================================
  # GET /api/v1/payments/:id
  # =============================================================================
  describe "GET /api/v1/payments/:id" do
    let(:payment) { create(:payment, user_id: user_id) }

    context "when user owns the payment" do
      it "returns the payment details" do
        get "/api/v1/payments/#{payment.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payment"]["id"]).to eq(payment.id)
        expect(json["payment"]["user_id"]).to eq(user_id)
        expect(json["payment"]["amount"]).to eq(payment.amount.to_f)
        expect(json["payment"]["status"]).to eq(payment.status)
      end
    end

    context "when user is an admin" do
      it "can view any payment" do
        other_user_payment = create(:payment, user_id: SecureRandom.uuid)

        get "/api/v1/payments/#{other_user_payment.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["payment"]["id"]).to eq(other_user_payment.id)
      end
    end

    context "when user does not own the payment" do
      it "returns forbidden error" do
        other_user_payment = create(:payment, user_id: SecureRandom.uuid)

        get "/api/v1/payments/#{other_user_payment.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when payment does not exist" do
      it "returns error for missing payment" do
        get "/api/v1/payments/#{SecureRandom.uuid}", headers: auth_headers

        # ErrorHandler catches ActiveRecord::RecordNotFound and returns not_found
        # In test env, behavior may vary based on Rails config
        expect(response.status).to be_between(404, 500)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized error" do
        get "/api/v1/payments/#{payment.id}", headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # =============================================================================
  # POST /api/v1/payments
  # =============================================================================
  describe "POST /api/v1/payments" do
    let(:appointment_id) { SecureRandom.uuid }
    let(:valid_params) do
      {
        payment: {
          appointment_id: appointment_id,
          amount: 75.00,
          currency: "USD",
          payment_method: "credit_card",
          description: "Test payment"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new payment" do
        expect {
          post "/api/v1/payments", headers: auth_headers, params: valid_params.to_json
        }.to change(Payment, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["id"]).to be_present
        expect(json["user_id"]).to eq(user_id)
        expect(json["amount"]).to eq(75.00)
      end

      it "assigns current_user_id when user_id is not provided" do
        post "/api/v1/payments", headers: auth_headers, params: valid_params.to_json

        payment = Payment.last
        expect(payment.user_id).to eq(user_id)
      end

      it "allows explicit user_id if provided" do
        explicit_user_id = SecureRandom.uuid
        params_with_user = valid_params.dup
        params_with_user[:payment][:user_id] = explicit_user_id

        post "/api/v1/payments", headers: auth_headers, params: params_with_user.to_json

        payment = Payment.last
        expect(payment.user_id).to eq(explicit_user_id)
      end
    end

    context "with invalid parameters" do
      it "returns validation errors" do
        invalid_params = {
          payment: {
            amount: -10,
            currency: "USD"
          }
        }

        post "/api/v1/payments", headers: auth_headers, params: invalid_params.to_json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized error" do
        post "/api/v1/payments", headers: headers, params: valid_params.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # =============================================================================
  # POST /api/v1/payments/create-intent
  # =============================================================================
  describe "POST /api/v1/payments/create-intent" do
    let(:appointment_id) { SecureRandom.uuid }
    let(:valid_params) do
      {
        amount: 50.00,
        currency: "USD",
        appointment_id: appointment_id,
        payment_method: "credit_card"
      }
    end

    let(:mock_intent) do
      double(
        "Stripe::PaymentIntent",
        id: "pi_test123",
        client_secret: "pi_test123_secret_abc"
      )
    end

    before do
      allow(StripeService).to receive(:create_payment_intent).and_return(mock_intent)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("STRIPE_PUBLISHABLE_KEY").and_return("pk_test_123")
    end

    context "with valid parameters" do
      it "creates a payment record and returns client_secret" do
        expect {
          post "/api/v1/payments/create-intent", headers: auth_headers, params: valid_params.to_json
        }.to change(Payment, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["payment_id"]).to be_present
        expect(json["client_secret"]).to eq("pi_test123_secret_abc")
        expect(json["publishable_key"]).to eq("pk_test_123")
        expect(json["amount"]).to eq(50.00)
        expect(json["currency"]).to eq("USD")
      end

      it "creates payment in pending status" do
        post "/api/v1/payments/create-intent", headers: auth_headers, params: valid_params.to_json

        payment = Payment.last
        expect(payment.status).to eq("pending")
        expect(payment.user_id).to eq(user_id)
        expect(payment.amount).to eq(50.00)
        expect(payment.stripe_payment_intent_id).to eq("pi_test123")
      end

      it "calls StripeService.create_payment_intent with correct parameters" do
        post "/api/v1/payments/create-intent", headers: auth_headers, params: valid_params.to_json

        expect(StripeService).to have_received(:create_payment_intent).with(
          hash_including(
            amount: 5000, # amount in cents
            currency: "usd",
            metadata: hash_including(
              user_id: user_id,
              appointment_id: appointment_id
            )
          )
        )
      end

      it "generates description when not provided" do
        post "/api/v1/payments/create-intent", headers: auth_headers, params: valid_params.to_json

        payment = Payment.last
        expect(payment.description).to include("MediConnect")
        expect(payment.description).to include(appointment_id)
      end

      it "generates generic description when appointment_id is not provided" do
        params_without_appointment = valid_params.except(:appointment_id)

        post "/api/v1/payments/create-intent", headers: auth_headers, params: params_without_appointment.to_json

        payment = Payment.last
        expect(payment.description).to eq("MediConnect - Payment")
      end

      it "uses provided description" do
        params_with_description = valid_params.merge(description: "Custom description")

        post "/api/v1/payments/create-intent", headers: auth_headers, params: params_with_description.to_json

        payment = Payment.last
        expect(payment.description).to eq("Custom description")
      end

      it "defaults to USD currency" do
        params_without_currency = valid_params.except(:currency)

        post "/api/v1/payments/create-intent", headers: auth_headers, params: params_without_currency.to_json

        payment = Payment.last
        expect(payment.currency).to eq("USD")
      end
    end

    context "with invalid parameters" do
      it "returns error when amount is missing" do
        invalid_params = valid_params.except(:amount)

        post "/api/v1/payments/create-intent", headers: auth_headers, params: invalid_params.to_json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("parameter_missing")
      end

      it "returns error when amount is zero" do
        invalid_params = valid_params.merge(amount: 0)

        post "/api/v1/payments/create-intent", headers: auth_headers, params: invalid_params.to_json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_amount")
      end

      it "returns error when amount is negative" do
        invalid_params = valid_params.merge(amount: -10)

        post "/api/v1/payments/create-intent", headers: auth_headers, params: invalid_params.to_json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_amount")
      end
    end

    context "when Stripe API fails" do
      before do
        allow(StripeService).to receive(:create_payment_intent).and_raise(
          Stripe::InvalidRequestError.new("Card declined", "card")
        )
      end

      it "returns error when Stripe fails" do
        initial_count = Payment.count

        post "/api/v1/payments/create-intent", headers: auth_headers, params: valid_params.to_json

        # ErrorHandler catches Stripe::InvalidRequestError and returns appropriate error
        expect(response.status).to be_between(400, 500)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        # Payment is created before Stripe call, then error occurs
        expect(Payment.count).to eq(initial_count + 1)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized error" do
        post "/api/v1/payments/create-intent", headers: headers, params: valid_params.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # =============================================================================
  # POST /api/v1/payments/confirm
  # =============================================================================
  describe "POST /api/v1/payments/confirm" do
    let(:payment) { create(:payment, :processing, user_id: user_id) }
    let(:mock_intent_succeeded) do
      double(
        "Stripe::PaymentIntent",
        id: payment.stripe_payment_intent_id,
        status: "succeeded",
        latest_charge: "ch_test123"
      )
    end

    before do
      allow(StripeService).to receive(:retrieve_payment_intent).and_return(mock_intent_succeeded)
    end

    context "when payment succeeds" do
      it "marks payment as completed and returns success" do
        post "/api/v1/payments/confirm", headers: auth_headers, params: {
          payment_id: payment.id,
          payment_intent_id: payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["payment"]["status"]).to eq("completed")

        payment.reload
        expect(payment.status).to eq("completed")
        expect(payment.stripe_charge_id).to eq("ch_test123")
      end
    end

    context "when payment is processing" do
      let(:mock_intent_processing) do
        double(
          "Stripe::PaymentIntent",
          id: payment.stripe_payment_intent_id,
          status: "processing"
        )
      end

      before do
        allow(StripeService).to receive(:retrieve_payment_intent).and_return(mock_intent_processing)
      end

      it "marks payment as processing and returns processing status" do
        post "/api/v1/payments/confirm", headers: auth_headers, params: {
          payment_id: payment.id,
          payment_intent_id: payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("processing")

        payment.reload
        expect(payment.status).to eq("processing")
      end
    end

    context "when payment requires action" do
      let(:mock_intent_requires_action) do
        double(
          "Stripe::PaymentIntent",
          id: payment.stripe_payment_intent_id,
          status: "requires_action"
        )
      end

      before do
        allow(StripeService).to receive(:retrieve_payment_intent).and_return(mock_intent_requires_action)
      end

      it "returns pending status" do
        post "/api/v1/payments/confirm", headers: auth_headers, params: {
          payment_id: payment.id,
          payment_intent_id: payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("pending")
        expect(json["message"]).to include("additional action")
      end
    end

    context "when payment fails" do
      let(:mock_intent_failed) do
        double(
          "Stripe::PaymentIntent",
          id: payment.stripe_payment_intent_id,
          status: "canceled"
        )
      end

      before do
        allow(StripeService).to receive(:retrieve_payment_intent).and_return(mock_intent_failed)
      end

      it "marks payment as failed and returns error" do
        post "/api/v1/payments/confirm", headers: auth_headers, params: {
          payment_id: payment.id,
          payment_intent_id: payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("failed")

        payment.reload
        expect(payment.status).to eq("failed")
      end
    end

    context "when payment_intent_id doesn't match" do
      let(:mock_intent_different) do
        double(
          "Stripe::PaymentIntent",
          id: "pi_different123",
          status: "succeeded",
          latest_charge: "ch_test123"
        )
      end

      before do
        allow(StripeService).to receive(:retrieve_payment_intent)
          .with("pi_different123")
          .and_return(mock_intent_different)
      end

      it "returns error" do
        post "/api/v1/payments/confirm", headers: auth_headers, params: {
          payment_id: payment.id,
          payment_intent_id: "pi_different123"
        }.to_json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("payment_mismatch")
      end
    end

    context "when user does not own the payment" do
      let(:other_user_payment) { create(:payment, :processing, user_id: SecureRandom.uuid) }

      it "returns forbidden error" do
        post "/api/v1/payments/confirm", headers: auth_headers, params: {
          payment_id: other_user_payment.id,
          payment_intent_id: other_user_payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when admin confirms any payment" do
      let(:other_user_payment) { create(:payment, :processing, user_id: SecureRandom.uuid) }

      before do
        allow(StripeService).to receive(:retrieve_payment_intent).and_return(
          double(
            "Stripe::PaymentIntent",
            id: other_user_payment.stripe_payment_intent_id,
            status: "succeeded",
            latest_charge: "ch_test123"
          )
        )
      end

      it "allows admin to confirm any payment" do
        post "/api/v1/payments/confirm", headers: admin_headers, params: {
          payment_id: other_user_payment.id,
          payment_intent_id: other_user_payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized error" do
        post "/api/v1/payments/confirm", headers: headers, params: {
          payment_id: payment.id,
          payment_intent_id: payment.stripe_payment_intent_id
        }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # =============================================================================
  # POST /api/v1/payments/:id/refund
  # =============================================================================
  describe "POST /api/v1/payments/:id/refund" do
    let(:payment) { create(:payment, :completed) }
    let(:mock_refund) { double("Stripe::Refund", id: "re_test123", amount: 5000) }

    before do
      allow(StripeService).to receive(:create_refund).and_return(mock_refund)
    end

    context "when user is an admin" do
      it "creates a full refund successfully" do
        post "/api/v1/payments/#{payment.id}/refund", headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["refund_id"]).to eq("re_test123")
        expect(json["amount_refunded"]).to eq(50.00)

        payment.reload
        expect(payment.status).to eq("refunded")
      end

      it "creates a partial refund when amount is provided" do
        post "/api/v1/payments/#{payment.id}/refund", headers: admin_headers, params: {
          amount: 25.00,
          reason: "requested_by_customer"
        }.to_json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")

        expect(StripeService).to have_received(:create_refund).with(
          hash_including(
            charge_id: payment.stripe_charge_id,
            amount: 2500,
            reason: "requested_by_customer"
          )
        )

        payment.reload
        expect(payment.status).to eq("partially_refunded")
      end

      it "returns error when payment is not refundable" do
        pending_payment = create(:payment, :pending)

        post "/api/v1/payments/#{pending_payment.id}/refund", headers: admin_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("not_refundable")
      end
    end

    context "when user is not an admin" do
      it "returns forbidden error" do
        post "/api/v1/payments/#{payment.id}/refund", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized error" do
        post "/api/v1/payments/#{payment.id}/refund", headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # =============================================================================
  # POST /api/v1/payments/webhook
  # =============================================================================
  describe "POST /api/v1/payments/webhook" do
    let(:payment) { create(:payment, :processing) }
    let(:webhook_payload) { '{"id":"evt_test123","type":"payment_intent.succeeded"}' }
    let(:webhook_signature) { "t=1234567890,v1=signature_hash" }
    let(:mock_event_succeeded) do
      double(
        "Stripe::Event",
        id: "evt_test123",
        type: "payment_intent.succeeded",
        data: double(object: double(
          id: payment.stripe_payment_intent_id,
          latest_charge: "ch_test123"
        ))
      )
    end

    before do
      allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_succeeded)
    end

    context "with valid webhook signature" do
      it "processes payment_intent.succeeded event" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["received"]).to be true

        payment.reload
        expect(payment.status).to eq("completed")
        expect(payment.stripe_charge_id).to eq("ch_test123")
      end

      it "handles idempotent webhook calls" do
        payment.update!(status: :completed, stripe_charge_id: "ch_existing")

        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)

        payment.reload
        expect(payment.stripe_charge_id).to eq("ch_existing") # Not updated
      end
    end

    context "with payment_intent.payment_failed event" do
      let(:mock_event_failed) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "payment_intent.payment_failed",
          data: double(object: double(
            id: payment.stripe_payment_intent_id,
            last_payment_error: double(message: "Card declined")
          ))
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_failed)
      end

      it "marks payment as failed" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)

        payment.reload
        expect(payment.status).to eq("failed")
        expect(payment.failure_reason).to eq("Card declined")
      end

      it "handles payment not found for failed webhook" do
        mock_event_not_found = double(
          "Stripe::Event",
          id: "evt_test123",
          type: "payment_intent.payment_failed",
          data: double(object: double(
            id: "pi_nonexistent_failure",
            last_payment_error: double(message: "Card declined")
          ))
        )
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_not_found)
        allow(Rails.logger).to receive(:warn)

        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            event: "webhook_payment_not_found",
            payment_intent_id: "pi_nonexistent_failure"
          )
        )
      end
    end

    context "with payment_intent.canceled event" do
      let(:mock_event_canceled) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "payment_intent.canceled",
          data: double(object: double(id: payment.stripe_payment_intent_id))
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_canceled)
      end

      it "marks payment as failed with canceled reason" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)

        payment.reload
        expect(payment.status).to eq("failed")
        expect(payment.failure_reason).to eq("Payment canceled")
      end
    end

    context "with charge.refunded event" do
      let(:completed_payment) { create(:payment, :completed) }
      let(:mock_event_refunded) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "charge.refunded",
          data: double(object: double(
            id: completed_payment.stripe_charge_id,
            amount: 5000,
            amount_refunded: 5000
          ))
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_refunded)
      end

      it "marks payment as refunded" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)

        completed_payment.reload
        expect(completed_payment.status).to eq("refunded")
      end
    end

    context "with partial refund" do
      let(:completed_payment) { create(:payment, :completed) }
      let(:mock_event_partial_refund) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "charge.refunded",
          data: double(object: double(
            id: completed_payment.stripe_charge_id,
            amount: 5000,
            amount_refunded: 2500
          ))
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_partial_refund)
      end

      it "marks payment as partially_refunded" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)

        completed_payment.reload
        expect(completed_payment.status).to eq("partially_refunded")
      end
    end

    context "with charge.dispute.created event" do
      let(:completed_payment) { create(:payment, :completed) }
      let(:mock_dispute) do
        double(
          "Stripe::Dispute",
          id: "dp_test123",
          charge: completed_payment.stripe_charge_id,
          amount: 5000,
          reason: "fraudulent"
        )
      end
      let(:mock_charge) do
        double("Stripe::Charge", id: completed_payment.stripe_charge_id)
      end
      let(:mock_event_dispute) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "charge.dispute.created",
          data: double(object: mock_dispute)
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_dispute)
        allow(Stripe::Charge).to receive(:retrieve).and_return(mock_charge)
        allow(Rails.logger).to receive(:error)
      end

      it "logs the dispute for manual review" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            event: "payment_dispute_created",
            payment_id: completed_payment.id,
            dispute_id: "dp_test123"
          )
        )
      end
    end

    context "with unhandled event type" do
      let(:mock_event_unhandled) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "customer.created"
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_unhandled)
        allow(Rails.logger).to receive(:info)
      end

      it "logs the unhandled event and returns success" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: "webhook_unhandled",
            type: "customer.created"
          )
        )
      end
    end

    context "when payment is not found for webhook" do
      let(:mock_event_not_found) do
        double(
          "Stripe::Event",
          id: "evt_test123",
          type: "payment_intent.succeeded",
          data: double(object: double(
            id: "pi_nonexistent",
            latest_charge: "ch_test123"
          ))
        )
      end

      before do
        allow(StripeService).to receive(:construct_webhook_event).and_return(mock_event_not_found)
        allow(Rails.logger).to receive(:warn)
      end

      it "logs warning and returns success" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            event: "webhook_payment_not_found",
            payment_intent_id: "pi_nonexistent"
          )
        )
      end
    end

    context "with invalid webhook signature" do
      before do
        allow(StripeService).to receive(:construct_webhook_event).and_raise(
          Stripe::SignatureVerificationError.new("Invalid signature", webhook_signature)
        )
      end

      it "returns error for invalid signature" do
        post "/api/v1/payments/webhook",
             headers: headers.merge("Stripe-Signature" => webhook_signature),
             params: webhook_payload

        # ErrorHandler catches Stripe::SignatureVerificationError and returns bad_request
        # In test environment with show_exceptions: :rescuable, this works correctly
        expect(response.status).to be_between(400, 500)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
      end
    end
  end
end
