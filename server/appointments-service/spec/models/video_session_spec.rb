# frozen_string_literal: true

require "rails_helper"

RSpec.describe VideoSession, type: :model do
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

  describe "associations" do
    it { should belong_to(:appointment) }
  end

  describe "validations" do
    # Need to create a proper subject with an appointment for shoulda-matchers
    subject { create(:video_session) }

    it { should validate_presence_of(:room_name) }
    it { should validate_presence_of(:provider) }
    it { should validate_presence_of(:status) }

    # Test uniqueness manually due to UUID case handling in PostgreSQL
    describe "uniqueness validations" do
      it "validates uniqueness of appointment_id" do
        existing = create(:video_session)
        duplicate = build(:video_session, appointment_id: existing.appointment_id)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:appointment_id]).to include("has already been taken")
      end

      it "validates uniqueness of room_name" do
        existing = create(:video_session)
        duplicate = build(:video_session, room_name: existing.room_name)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:room_name]).to include("has already been taken")
      end
    end

    it "requires an appointment" do
      video_session = VideoSession.new(room_name: "test-room", provider: "livekit", status: "created")
      expect(video_session).not_to be_valid
      expect(video_session.errors[:appointment]).to include("must exist")
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(VideoSession.statuses.keys).to contain_exactly("created", "active", "ended", "failed")
    end
  end

  describe "callbacks" do
    describe "setup_livekit_room" do
      let(:mock_livekit_service) { instance_double(LiveKitService) }
      let(:generated_room_name) { "mediconnect-test-abc123" }

      before do
        allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
        allow(mock_livekit_service).to receive(:create_room).and_return(generated_room_name)
        allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
      end

      it "automatically generates room name on creation via LiveKit" do
        appointment = create(:appointment, :video_consultation)
        video_session = VideoSession.new(appointment: appointment)
        video_session.save

        expect(video_session.room_name).to eq(generated_room_name)
      end

      it "sets provider to livekit on creation" do
        appointment = create(:appointment, :video_consultation)
        video_session = VideoSession.new(appointment: appointment)
        video_session.save

        expect(video_session.provider).to eq("livekit")
      end

      it "generates session URL based on room name" do
        appointment = create(:appointment, :video_consultation)
        video_session = VideoSession.new(appointment: appointment)
        video_session.save

        expect(video_session.session_url).to eq("http://localhost:5173/video/#{generated_room_name}")
      end

      it "does not override existing room name" do
        video_session = build(:video_session, room_name: "custom-room-name")
        video_session.save

        expect(video_session.room_name).to eq("custom-room-name")
      end

      it "calls LiveKitService.create_room with appointment_id" do
        appointment = create(:appointment, :video_consultation)

        expect(mock_livekit_service).to receive(:create_room).with(appointment.id)

        video_session = VideoSession.new(appointment: appointment)
        video_session.save
      end

      context "when LiveKitService raises an error" do
        before do
          allow(mock_livekit_service).to receive(:create_room)
            .and_raise(LiveKitService::ConfigurationError.new("Configuration error"))
        end

        it "aborts the save and adds an error" do
          appointment = create(:appointment, :video_consultation)
          video_session = VideoSession.new(appointment: appointment)

          expect(video_session.save).to be false
          expect(video_session.errors[:base]).to include("Failed to create video room: Configuration error")
        end
      end
    end

    describe "generate_session_url" do
      it "automatically generates session URL on creation" do
        video_session = create(:video_session)
        expect(video_session.session_url).to be_present
        expect(video_session.session_url).to include(video_session.room_name)
      end
    end
  end

  describe "scopes" do
    let!(:active_session) { create(:video_session, :active) }
    let!(:ended_session) { create(:video_session, :ended) }
    let!(:created_session) { create(:video_session) }

    describe ".active_sessions" do
      it "returns only active sessions" do
        expect(VideoSession.active_sessions).to include(active_session)
        expect(VideoSession.active_sessions).not_to include(ended_session, created_session)
      end
    end

    describe ".ended_sessions" do
      it "returns only ended sessions" do
        expect(VideoSession.ended_sessions).to include(ended_session)
        expect(VideoSession.ended_sessions).not_to include(active_session, created_session)
      end
    end

    describe ".for_appointment" do
      it "returns sessions for the given appointment" do
        expect(VideoSession.for_appointment(active_session.appointment_id)).to include(active_session)
        expect(VideoSession.for_appointment(active_session.appointment_id)).not_to include(ended_session)
      end

      it "returns all sessions when appointment_id is nil" do
        expect(VideoSession.for_appointment(nil)).to include(active_session, ended_session, created_session)
      end
    end

    describe ".recent" do
      it "orders sessions by created_at descending" do
        result = VideoSession.recent
        expect(result.first.created_at).to be >= result.last.created_at
      end
    end
  end

  describe "#start!" do
    it "starts a created session" do
      video_session = create(:video_session, status: "created")
      result = video_session.start!

      expect(result).to be true
      expect(video_session.reload.status).to eq("active")
      expect(video_session.started_at).to be_present
    end

    it "fails to start an already active session" do
      video_session = create(:video_session, :active)
      expect(video_session.start!).to be false
    end

    it "fails to start an ended session" do
      video_session = create(:video_session, :ended)
      expect(video_session.start!).to be false
    end
  end

  describe "#end!" do
    it "ends an active session and calculates duration" do
      video_session = create(:video_session, :active)
      result = video_session.end!

      expect(result).to be true
      expect(video_session.reload.status).to eq("ended")
      expect(video_session.ended_at).to be_present
      expect(video_session.duration_minutes).to be_present
    end

    it "fails to end a non-active session" do
      video_session = create(:video_session, status: "created")
      expect(video_session.end!).to be false
    end
  end

  describe "#fail!" do
    it "marks session as failed" do
      video_session = create(:video_session)
      video_session.fail!

      expect(video_session.reload.status).to eq("failed")
    end
  end

  describe "#active?" do
    it "returns true when status is active" do
      video_session = create(:video_session, :active)
      expect(video_session.active?).to be true
    end

    it "returns false when status is not active" do
      video_session = create(:video_session, status: "created")
      expect(video_session.active?).to be false
    end
  end

  describe "#session_duration" do
    it "calculates duration in minutes when session has ended" do
      video_session = create(:video_session,
                            started_at: 1.hour.ago,
                            ended_at: 30.minutes.ago)
      expect(video_session.session_duration).to eq(30)
    end

    it "returns nil when session has not ended" do
      video_session = create(:video_session, started_at: 10.minutes.ago, ended_at: nil)
      expect(video_session.session_duration).to be_nil
    end

    it "returns nil when session has not started" do
      video_session = create(:video_session, started_at: nil, ended_at: nil)
      expect(video_session.session_duration).to be_nil
    end
  end

  describe "#generate_participant_token" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:expected_token) { "jwt_token_for_participant" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(expected_token)
    end

    it "generates a token for the specified user" do
      token = video_session.generate_participant_token(
        user_id: "user-123",
        user_name: "Test User"
      )

      expect(token).to eq(expected_token)
    end

    it "calls LiveKitService with correct parameters" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        room_name: video_session.room_name,
        user_id: "user-123",
        user_name: "Test User",
        is_owner: false
      )

      video_session.generate_participant_token(
        user_id: "user-123",
        user_name: "Test User"
      )
    end

    it "passes is_owner flag correctly" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(is_owner: true)
      )

      video_session.generate_participant_token(
        user_id: "doctor-123",
        user_name: "Dr. Smith",
        is_owner: true
      )
    end

    it "defaults is_owner to false" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(is_owner: false)
      )

      video_session.generate_participant_token(
        user_id: "patient-123",
        user_name: "Patient"
      )
    end
  end

  describe "#patient_token" do
    let(:appointment) { create(:appointment, :video_consultation) }
    let(:video_session) { create(:video_session, appointment: appointment) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:expected_token) { "patient_jwt_token" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(expected_token)
    end

    it "returns a token for the patient" do
      expect(video_session.patient_token).to eq(expected_token)
    end

    it "generates token with patient user_id from appointment" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(user_id: appointment.user_id)
      )

      video_session.patient_token
    end

    it "sets is_owner to false for patient" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(is_owner: false)
      )

      video_session.patient_token
    end

    it "uses 'Patient' as display name" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(user_name: "Patient")
      )

      video_session.patient_token
    end

    context "when appointment is not present" do
      it "returns nil" do
        video_session.appointment = nil
        expect(video_session.patient_token).to be_nil
      end
    end
  end

  describe "#doctor_token" do
    let(:appointment) { create(:appointment, :video_consultation) }
    let(:video_session) { create(:video_session, appointment: appointment) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:expected_token) { "doctor_jwt_token" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(expected_token)
    end

    it "returns a token for the doctor" do
      expect(video_session.doctor_token).to eq(expected_token)
    end

    it "generates token with doctor user_id from appointment" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(user_id: appointment.doctor_id)
      )

      video_session.doctor_token
    end

    it "sets is_owner to true for doctor" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(is_owner: true)
      )

      video_session.doctor_token
    end

    it "uses 'Doctor' as display name" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(user_name: "Doctor")
      )

      video_session.doctor_token
    end

    context "when appointment is not present" do
      it "returns nil" do
        video_session.appointment = nil
        expect(video_session.doctor_token).to be_nil
      end
    end
  end

  describe "#livekit_websocket_url" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
    end

    it "returns the LiveKit WebSocket URL" do
      expect(video_session.livekit_websocket_url).to eq(ws_url)
    end

    it "delegates to LiveKitService" do
      expect(mock_livekit_service).to receive(:websocket_url)

      video_session.livekit_websocket_url
    end
  end

  describe "#connection_info" do
    let(:appointment) { create(:appointment, :video_consultation) }
    let(:video_session) { create(:video_session, appointment: appointment) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:expected_token) { "connection_jwt_token" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(expected_token)
      allow(mock_livekit_service).to receive(:websocket_url).and_return(ws_url)
    end

    it "returns a hash with connection information" do
      info = video_session.connection_info(
        user_id: "user-123",
        user_name: "Test User",
        is_doctor: false
      )

      expect(info).to be_a(Hash)
      expect(info).to have_key(:room_name)
      expect(info).to have_key(:token)
      expect(info).to have_key(:websocket_url)
      expect(info).to have_key(:session_url)
    end

    it "includes the room name" do
      info = video_session.connection_info(
        user_id: "user-123",
        user_name: "Test User"
      )

      expect(info[:room_name]).to eq(video_session.room_name)
    end

    it "includes the generated token" do
      info = video_session.connection_info(
        user_id: "user-123",
        user_name: "Test User"
      )

      expect(info[:token]).to eq(expected_token)
    end

    it "includes the WebSocket URL" do
      info = video_session.connection_info(
        user_id: "user-123",
        user_name: "Test User"
      )

      expect(info[:websocket_url]).to eq(ws_url)
    end

    it "includes the session URL" do
      info = video_session.connection_info(
        user_id: "user-123",
        user_name: "Test User"
      )

      expect(info[:session_url]).to eq(video_session.session_url)
    end

    it "generates token with is_owner based on is_doctor flag" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(is_owner: true)
      )

      video_session.connection_info(
        user_id: "doctor-123",
        user_name: "Dr. Smith",
        is_doctor: true
      )
    end

    it "defaults is_doctor to false" do
      expect(mock_livekit_service).to receive(:generate_token).with(
        hash_including(is_owner: false)
      )

      video_session.connection_info(
        user_id: "patient-123",
        user_name: "Patient"
      )
    end
  end

  describe "#patient_url" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:patient_token) { "patient_token_abc" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(patient_token)
    end

    it "generates patient-specific URL with token" do
      url = video_session.patient_url

      expect(url).to be_present
      expect(url).to include(video_session.session_url)
      expect(url).to include("token=#{patient_token}")
    end

    context "when session_url is not present" do
      it "returns nil" do
        video_session.session_url = nil
        expect(video_session.patient_url).to be_nil
      end
    end
  end

  describe "#doctor_url" do
    let(:video_session) { create(:video_session) }
    let(:mock_livekit_service) { instance_double(LiveKitService) }
    let(:doctor_token) { "doctor_token_xyz" }

    before do
      allow(LiveKitService).to receive(:new).and_return(mock_livekit_service)
      allow(mock_livekit_service).to receive(:generate_token).and_return(doctor_token)
    end

    it "generates doctor-specific URL with token" do
      url = video_session.doctor_url

      expect(url).to be_present
      expect(url).to include(video_session.session_url)
      expect(url).to include("token=#{doctor_token}")
    end

    context "when session_url is not present" do
      it "returns nil" do
        video_session.session_url = nil
        expect(video_session.doctor_url).to be_nil
      end
    end
  end
end
