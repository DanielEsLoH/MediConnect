# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::VideoSessions", type: :request do
  # LiveKit environment variables for testing
  let(:api_key) { "devkey" }
  let(:api_secret) { "secret_that_is_at_least_32_characters_long" }
  let(:host) { "http://localhost:7880" }
  let(:ws_url) { "ws://localhost:7880" }

  before do
    # Set up test environment variables for LiveKit
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("LIVEKIT_API_KEY").and_return(api_key)
    allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return(api_secret)
    allow(ENV).to receive(:fetch).with("LIVEKIT_HOST", anything).and_return(host)
    allow(ENV).to receive(:fetch).with("LIVEKIT_WS_URL", anything).and_return(ws_url)
    allow(ENV).to receive(:fetch).with("LIVEKIT_FRONTEND_URL", anything).and_return("http://localhost:5173/video")
  end

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
    let(:confirmed_appointment) { create(:appointment, :confirmed, :video_consultation) }
    let(:video_session) { create(:video_session, appointment: confirmed_appointment) }

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

  describe "GET /api/v1/video_sessions/:id/token" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:expected_token) { "jwt_token_for_user" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(expected_token)
      allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
    end

    context "with valid parameters" do
      it "returns a token for the user" do
        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "user-123", user_name: "John Doe" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["token"]).to eq(expected_token)
      end

      it "includes room_name in response" do
        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["room_name"]).to eq(video_session.room_name)
      end

      it "includes websocket_url in response" do
        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["websocket_url"]).to eq(ws_url)
      end

      it "includes expires_in in response (4 hours in seconds)" do
        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["expires_in"]).to eq(4.hours.to_i)
      end

      it "uses default user_name when not provided" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(user_name: "Participant")
        )

        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "user-123" }
      end

      it "passes is_doctor=true as is_owner to LiveKit service" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(is_owner: true)
        )

        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "doctor-123", user_name: "Dr. Smith", is_doctor: "true" }
      end

      it "handles is_doctor as boolean" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(is_owner: true)
        )

        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "doctor-123", is_doctor: true }
      end

      it "defaults is_doctor to false" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(is_owner: false)
        )

        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "patient-123" }
      end
    end

    context "when user_id is missing" do
      it "returns bad_request status" do
        get "/api/v1/video_sessions/#{video_session.id}/token"

        expect(response).to have_http_status(:bad_request)
      end

      it "includes error message in response" do
        get "/api/v1/video_sessions/#{video_session.id}/token"

        json = JSON.parse(response.body)
        expect(json["errors"]).to include("user_id is required")
        expect(json["message"]).to eq("Please provide a user_id parameter")
      end

      it "returns bad_request when user_id is empty string" do
        get "/api/v1/video_sessions/#{video_session.id}/token",
            params: { user_id: "" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include("user_id is required")
      end
    end

    context "when video session not found" do
      it "returns 404" do
        get "/api/v1/video_sessions/#{SecureRandom.uuid}/token",
            params: { user_id: "user-123" }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include("Video session not found")
      end
    end
  end

  describe "GET /api/v1/video_sessions/:id/connection_info" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:expected_token) { "connection_jwt_token" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(expected_token)
      allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
    end

    context "with valid parameters" do
      it "returns connection info successfully" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123", user_name: "John Doe" }

        expect(response).to have_http_status(:ok)
      end

      it "includes connection_info object in response" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["connection_info"]).to be_present
        expect(json["connection_info"]).to be_a(Hash)
      end

      it "includes room_name in connection_info" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["connection_info"]["room_name"]).to eq(video_session.room_name)
      end

      it "includes token in connection_info" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["connection_info"]["token"]).to eq(expected_token)
      end

      it "includes websocket_url in connection_info" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["connection_info"]["websocket_url"]).to eq(ws_url)
      end

      it "includes session_url in connection_info" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["connection_info"]["session_url"]).to eq(video_session.session_url)
      end

      it "includes video_session object in response" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["video_session"]).to be_present
        expect(json["video_session"]["id"]).to eq(video_session.id)
      end

      it "includes success message in response" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Connection info retrieved successfully")
      end

      it "uses default user_name when not provided" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(user_name: "Participant")
        )

        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123" }
      end

      it "passes is_doctor=true as is_owner to LiveKit service" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(is_owner: true)
        )

        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "doctor-123", user_name: "Dr. Smith", is_doctor: "true" }
      end

      it "handles is_doctor as boolean true" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(is_owner: true)
        )

        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "doctor-123", is_doctor: true }
      end

      it "defaults is_doctor to false" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(is_owner: false)
        )

        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "patient-123" }
      end

      it "passes custom user_name to service" do
        expect(mock_livekit_service).to receive(:generate_token).with(
          hash_including(user_name: "Custom Name")
        )

        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "user-123", user_name: "Custom Name" }
      end
    end

    context "when user_id is missing" do
      it "returns bad_request status" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info"

        expect(response).to have_http_status(:bad_request)
      end

      it "includes error message in response" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info"

        json = JSON.parse(response.body)
        expect(json["errors"]).to include("user_id is required")
        expect(json["message"]).to eq("Please provide a user_id parameter")
      end

      it "returns bad_request when user_id is empty string" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include("user_id is required")
      end

      it "returns bad_request when user_id is only whitespace" do
        get "/api/v1/video_sessions/#{video_session.id}/connection_info",
            params: { user_id: "   " }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when video session not found" do
      it "returns 404" do
        get "/api/v1/video_sessions/#{SecureRandom.uuid}/connection_info",
            params: { user_id: "user-123" }

        expect(response).to have_http_status(:not_found)
      end

      it "includes error message" do
        get "/api/v1/video_sessions/#{SecureRandom.uuid}/connection_info",
            params: { user_id: "user-123" }

        json = JSON.parse(response.body)
        expect(json["errors"]).to include("Video session not found")
      end
    end

    context "with different session states" do
      it "works for active sessions" do
        active_session = create(:video_session, :active)

        get "/api/v1/video_sessions/#{active_session.id}/connection_info",
            params: { user_id: "user-123" }

        expect(response).to have_http_status(:ok)
      end

      it "works for ended sessions" do
        ended_session = create(:video_session, :ended)

        get "/api/v1/video_sessions/#{ended_session.id}/connection_info",
            params: { user_id: "user-123" }

        expect(response).to have_http_status(:ok)
      end

      it "works for failed sessions" do
        failed_session = create(:video_session, :failed)

        get "/api/v1/video_sessions/#{failed_session.id}/connection_info",
            params: { user_id: "user-123" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "response format consistency" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return("token")
      allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
    end

    it "returns JSON content type for token endpoint" do
      get "/api/v1/video_sessions/#{video_session.id}/token",
          params: { user_id: "user-123" }

      expect(response.content_type).to include("application/json")
    end

    it "returns JSON content type for connection_info endpoint" do
      get "/api/v1/video_sessions/#{video_session.id}/connection_info",
          params: { user_id: "user-123" }

      expect(response.content_type).to include("application/json")
    end

    it "returns JSON content type for error responses" do
      get "/api/v1/video_sessions/#{video_session.id}/token"

      expect(response.content_type).to include("application/json")
    end
  end

  describe "edge cases for token endpoint" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return("token")
      allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
    end

    it "handles numeric user_id" do
      get "/api/v1/video_sessions/#{video_session.id}/token",
          params: { user_id: 12345 }

      expect(response).to have_http_status(:ok)
    end

    it "handles UUID user_id" do
      get "/api/v1/video_sessions/#{video_session.id}/token",
          params: { user_id: SecureRandom.uuid }

      expect(response).to have_http_status(:ok)
    end

    it "handles special characters in user_name" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(user_name: "Dr. O'Brien-Smith")
      )

      get "/api/v1/video_sessions/#{video_session.id}/token",
          params: { user_id: "user-123", user_name: "Dr. O'Brien-Smith" }

      expect(response).to have_http_status(:ok)
    end

    it "handles unicode in user_name" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(user_name: "Dr. Mueller")
      )

      get "/api/v1/video_sessions/#{video_session.id}/token",
          params: { user_id: "user-123", user_name: "Dr. Mueller" }

      expect(response).to have_http_status(:ok)
    end
  end
end
