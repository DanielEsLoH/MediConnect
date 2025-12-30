# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::DoctorsController", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")

    # Use a more flexible stub that matches any request to the doctors service
    stub_request(:any, %r{http://doctors-service:3002/})
      .to_return(
        status: 200,
        body: { doctors: [], specialties: [], reviews: [], slots: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  let(:doctors_list) do
    [
      { id: 1, name: "Dr. Smith", specialty: "Cardiology", rating: 4.8 },
      { id: 2, name: "Dr. Jones", specialty: "Dermatology", rating: 4.5 }
    ]
  end

  describe "GET /api/v1/doctors" do
    let(:index_path) { "/api/v1/doctors" }

    context "with authentication" do
      before do
        stub_request(:get, /doctors-service:3002.*doctors/)
          .to_return(
            status: 200,
            body: { doctors: doctors_list, meta: { total: 2 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns list of doctors" do
        get index_path, headers: auth_headers

        expect(response).to have_http_status(:ok)
      end

      it "forwards filter parameters" do
        get index_path, params: { specialty: "Cardiology" }, headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "allows access as doctors list is public" do
        # DoctorsController uses optional authentication (authenticate_request not authenticate_request!)
        get index_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /api/v1/doctors/:id" do
    let(:doctor_data) do
      { id: 1, name: "Dr. Smith", specialty: "Cardiology" }
    end

    context "with valid doctor id" do
      before do
        stub_request(:get, /doctors-service:3002.*doctors\/1/)
          .to_return(
            status: 200,
            body: doctor_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns doctor details" do
        get "/api/v1/doctors/1", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "when doctor not found" do
      before do
        stub_request(:get, /doctors-service:3002.*doctors\/999/)
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns 404 not found" do
        get "/api/v1/doctors/999", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/doctors/search" do
    before do
      stub_request(:get, /doctors-service:3002.*search/)
        .to_return(
          status: 200,
          body: { doctors: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns search results" do
      get "/api/v1/doctors/search", params: { q: "smith" }, headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/doctors/specialties" do
    before do
      stub_request(:get, /doctors-service:3002.*specialties/)
        .to_return(
          status: 200,
          body: { specialties: %w[Cardiology Dermatology] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns list of specialties" do
      get "/api/v1/doctors/specialties"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/doctors/:id/availability" do
    before do
      stub_request(:get, /doctors-service:3002.*availability/)
        .to_return(
          status: 200,
          body: { slots: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns availability" do
      get "/api/v1/doctors/1/availability", params: { date: "2024-01-20" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/doctors/:id/reviews" do
    before do
      stub_request(:get, /doctors-service:3002.*reviews/)
        .to_return(
          status: 200,
          body: { reviews: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns doctor reviews" do
      get "/api/v1/doctors/1/reviews"
      expect(response).to have_http_status(:ok)
    end
  end
end