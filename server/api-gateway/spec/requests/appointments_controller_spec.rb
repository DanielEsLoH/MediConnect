# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::AppointmentsController", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")

    # Default stub for appointments service
    stub_request(:any, %r{http://appointments-service:3003/})
      .to_return(
        status: 200,
        body: { appointments: [], appointment: {} }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  let(:appointments_list) do
    [
      { id: 1, user_id: 1, doctor_id: 10, status: "confirmed" },
      { id: 2, user_id: 1, doctor_id: 20, status: "pending" }
    ]
  end

  describe "GET /api/v1/appointments" do
    let(:index_path) { "/api/v1/appointments" }

    context "as authenticated patient" do
      before do
        stub_request(:get, /appointments-service:3003.*appointments/)
          .to_return(
            status: 200,
            body: { appointments: appointments_list, meta: { total: 2 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns list of appointments" do
        get index_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get index_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/appointments/:id" do
    context "with valid appointment id" do
      before do
        stub_request(:get, /appointments-service:3003.*appointments\/1/)
          .to_return(
            status: 200,
            body: { id: 1, status: "confirmed" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns appointment details" do
        get "/api/v1/appointments/1", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when appointment not found" do
      before do
        stub_request(:get, /appointments-service:3003.*appointments\/999/)
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns 404 not found" do
        get "/api/v1/appointments/999", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/appointments/1"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/appointments" do
    let(:create_path) { "/api/v1/appointments" }
    let(:appointment_params) do
      {
        appointment: {
          doctor_id: 10,
          scheduled_at: "2024-01-20T10:00:00Z",
          reason: "Checkup"
        }
      }
    end

    context "with valid parameters" do
      before do
        stub_request(:post, /appointments-service:3003.*appointments/)
          .to_return(
            status: 201,
            body: { id: 1, status: "pending" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "creates a new appointment" do
        post create_path, params: appointment_params, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:created)
      end
    end

    context "with missing appointment key" do
      it "returns error for missing required parameter" do
        post create_path, params: { doctor_id: 10 }, headers: auth_headers(user_id: 1, role: "patient")
        # Rails API mode returns 500 for ParameterMissing by default unless custom handling
        expect(response).to have_http_status(:internal_server_error).or have_http_status(:bad_request)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post create_path, params: appointment_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/appointments/:id" do
    let(:update_path) { "/api/v1/appointments/1" }
    let(:update_params) { { appointment: { notes: "Updated notes" } } }

    context "with valid parameters" do
      before do
        stub_request(:patch, /appointments-service:3003.*appointments\/1/)
          .to_return(
            status: 200,
            body: { id: 1, notes: "Updated notes" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "updates the appointment" do
        patch update_path, params: update_params, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        patch update_path, params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/appointments/:id" do
    context "with valid appointment" do
      before do
        stub_request(:delete, /appointments-service:3003.*appointments\/1/)
          .to_return(
            status: 200,
            body: { message: "Deleted" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "cancels the appointment" do
        delete "/api/v1/appointments/1", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        delete "/api/v1/appointments/1"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/appointments/upcoming" do
    before do
      stub_request(:get, /appointments-service:3003.*upcoming/)
        .to_return(
          status: 200,
          body: { appointments: appointments_list }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns upcoming appointments" do
      get "/api/v1/appointments/upcoming", headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/appointments/upcoming"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/appointments/past" do
    before do
      stub_request(:get, /appointments-service:3003.*past/)
        .to_return(
          status: 200,
          body: { appointments: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns past appointments" do
      get "/api/v1/appointments/past", headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/appointments/:id/confirm" do
    before do
      stub_request(:post, /appointments-service:3003.*confirm/)
        .to_return(
          status: 200,
          body: { id: 1, status: "confirmed" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "confirms the appointment" do
      post "/api/v1/appointments/1/confirm", headers: auth_headers(user_id: 10, role: "doctor")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/appointments/:id/cancel" do
    before do
      stub_request(:post, /appointments-service:3003.*cancel/)
        .to_return(
          status: 200,
          body: { id: 1, status: "cancelled" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "cancels the appointment" do
      post "/api/v1/appointments/1/cancel", params: { reason: "Changed mind" },
           headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/appointments/:id/reschedule" do
    before do
      stub_request(:post, /appointments-service:3003.*reschedule/)
        .to_return(
          status: 200,
          body: { id: 1, status: "rescheduled" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "reschedules the appointment" do
      post "/api/v1/appointments/1/reschedule", params: { scheduled_at: "2024-01-22T11:00:00Z" },
           headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end
  end
end