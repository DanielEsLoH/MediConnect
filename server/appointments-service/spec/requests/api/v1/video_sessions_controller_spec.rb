# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::VideoSessions", type: :request do
  describe "POST /api/v1/video_sessions" do
    let(:video_appointment) { create(:appointment, :video_consultation, :confirmed) }

    it "creates video session for appointment" do
      post "/api/v1/video_sessions", params: { appointment_id: video_appointment.id }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["video_session"]).to be_present
      expect(json["patient_url"]).to be_present
      expect(json["doctor_url"]).to be_present
    end

    it "returns error when appointment not found" do
      post "/api/v1/video_sessions", params: { appointment_id: SecureRandom.uuid }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Appointment not found")
    end

    it "returns error for non-video appointment" do
      in_person_appointment = create(:appointment, consultation_type: "in_person")
      post "/api/v1/video_sessions", params: { appointment_id: in_person_appointment.id }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Appointment must be of type 'video' to create a video session")
    end

    it "returns existing session if already created" do
      existing_session = create(:video_session, appointment: video_appointment)
      post "/api/v1/video_sessions", params: { appointment_id: video_appointment.id }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["video_session"]["id"]).to eq(existing_session.id)
    end
  end

  describe "GET /api/v1/video_sessions/:id" do
    let(:video_session) { create(:video_session) }

    it "returns video session details" do
      get "/api/v1/video_sessions/#{video_session.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["video_session"]["id"]).to eq(video_session.id)
      expect(json["patient_url"]).to be_present
      expect(json["doctor_url"]).to be_present
      expect(json["appointment"]).to be_present
    end

    it "returns 404 when session not found" do
      get "/api/v1/video_sessions/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Video session not found")
    end
  end

  describe "POST /api/v1/video_sessions/:id/start" do
    let(:video_session) { create(:video_session) }

    it "starts video session" do
      post "/api/v1/video_sessions/#{video_session.id}/start"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["video_session"]["status"]).to eq("active")
      expect(json["video_session"]["started_at"]).to be_present
    end

    it "updates appointment status to in_progress" do
      post "/api/v1/video_sessions/#{video_session.id}/start"

      expect(video_session.appointment.reload.status).to eq("in_progress")
    end

    it "returns error when session already active" do
      active_session = create(:video_session, :active)
      post "/api/v1/video_sessions/#{active_session.id}/start"

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when session not found" do
      post "/api/v1/video_sessions/#{SecureRandom.uuid}/start"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/video_sessions/:id/end" do
    let(:active_session) { create(:video_session, :active) }

    it "ends video session" do
      post "/api/v1/video_sessions/#{active_session.id}/end"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["video_session"]["status"]).to eq("ended")
      expect(json["video_session"]["ended_at"]).to be_present
      expect(json["duration_minutes"]).to be_present
    end

    it "returns error when session not active" do
      created_session = create(:video_session)
      post "/api/v1/video_sessions/#{created_session.id}/end"

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when session not found" do
      post "/api/v1/video_sessions/#{SecureRandom.uuid}/end"

      expect(response).to have_http_status(:not_found)
    end
  end
end
