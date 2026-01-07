# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PaymentsController", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")

    # Default stub for payments service
    stub_request(:any, %r{http://payments-service:3005/})
      .to_return(
        status: 200,
        body: { payments: [], payment: {} }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  let(:payments_list) do
    [
      { id: 1, user_id: 1, amount: 100.00, status: "completed" },
      { id: 2, user_id: 1, amount: 150.00, status: "pending" }
    ]
  end

  describe "GET /api/v1/payments" do
    let(:index_path) { "/api/v1/payments" }

    context "as authenticated user" do
      before do
        stub_request(:get, /payments-service:3005.*payments/)
          .to_return(
            status: 200,
            body: { payments: payments_list, meta: { total: 2 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns list of payments" do
        get index_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end

      it "proxies the request to payments service" do
        get index_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(a_request(:get, /payments-service:3005/)).to have_been_made
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get index_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/payments/:id" do
    context "with valid payment id" do
      before do
        stub_request(:get, /payments-service:3005.*payments\/1/)
          .to_return(
            status: 200,
            body: { id: 1, amount: 100.00, status: "completed" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns payment details" do
        get "/api/v1/payments/1", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when payment not found" do
      before do
        stub_request(:get, /payments-service:3005.*payments\/999/)
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns 404 not found" do
        get "/api/v1/payments/999", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/payments/1"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/payments" do
    let(:create_path) { "/api/v1/payments" }
    let(:payment_params) do
      {
        payment: {
          appointment_id: 1,
          amount: 100.00,
          currency: "USD",
          payment_method_id: "pm_test_123"
        }
      }
    end

    context "with valid parameters" do
      before do
        stub_request(:post, /payments-service:3005.*payments/)
          .to_return(
            status: 201,
            body: { id: 1, status: "pending" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "creates a new payment" do
        post create_path, params: payment_params, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:created)
      end
    end

    context "with missing payment key" do
      it "returns error for missing required parameter" do
        post create_path, params: { amount: 100 }, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:internal_server_error).or have_http_status(:bad_request)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post create_path, params: payment_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/payments/:id/refund" do
    let(:refund_path) { "/api/v1/payments/1/refund" }

    context "with valid refund request" do
      before do
        stub_request(:post, /payments-service:3005.*payments\/1\/refund/)
          .to_return(
            status: 200,
            body: { id: 1, status: "refunded", refund_amount: 100.00 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "processes the refund" do
        post refund_path, params: { reason: "Customer request" },
             headers: auth_headers(user_id: 1, role: "admin")
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post refund_path, params: { reason: "Test" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/payments/methods" do
    before do
      stub_request(:get, /payments-service:3005.*payment_methods/)
        .to_return(
          status: 200,
          body: { payment_methods: [ { id: "pm_1", last4: "4242" } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns saved payment methods" do
      get "/api/v1/payments/methods", headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/payments/methods"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/payments/methods" do
    let(:payment_method_params) { { payment_method_id: "pm_test_123", set_default: true } }

    before do
      stub_request(:post, /payments-service:3005.*payment_methods/)
        .to_return(
          status: 201,
          body: { id: "pm_test_123", last4: "4242" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "adds a new payment method" do
      post "/api/v1/payments/methods", params: payment_method_params,
           headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:created)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post "/api/v1/payments/methods", params: payment_method_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/payments/create_intent" do
    let(:intent_params) { { appointment_id: 1, amount: 100.00 } }

    before do
      stub_request(:post, /payments-service:3005.*create-intent/)
        .to_return(
          status: 200,
          body: { client_secret: "pi_test_secret", payment_intent_id: "pi_test_123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "creates a payment intent" do
      post "/api/v1/payments/create_intent", params: intent_params,
           headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post "/api/v1/payments/create_intent", params: intent_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/payments/confirm" do
    let(:confirm_params) { { payment_intent_id: "pi_test_123" } }

    before do
      stub_request(:post, /payments-service:3005.*confirm/)
        .to_return(
          status: 200,
          body: { status: "succeeded", payment_id: 1 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "confirms a payment intent" do
      post "/api/v1/payments/confirm", params: confirm_params,
           headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post "/api/v1/payments/confirm", params: confirm_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/payments/webhook" do
    let(:webhook_payload) do
      {
        type: "payment_intent.succeeded",
        data: { object: { id: "pi_test_123" } }
      }.to_json
    end

    before do
      stub_request(:post, /payments-service:3005.*webhook/)
        .to_return(
          status: 200,
          body: { received: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "handles webhook without authentication" do
      post "/api/v1/payments/webhook",
           params: webhook_payload,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:ok)
    end
  end
end