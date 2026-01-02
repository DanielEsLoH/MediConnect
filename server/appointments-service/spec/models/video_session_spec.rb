# frozen_string_literal: true

require "rails_helper"

RSpec.describe VideoSession, type: :model do
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
      video_session = VideoSession.new(room_name: "test-room", provider: "daily", status: "created")
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
    describe "generate_room_name" do
      it "automatically generates room name on creation" do
        appointment = create(:appointment, :video_consultation)
        video_session = VideoSession.new(appointment: appointment, provider: "daily")
        video_session.save

        expect(video_session.room_name).to be_present
        expect(video_session.room_name).to start_with("mediconnect-")
      end

      it "does not override existing room name" do
        video_session = build(:video_session, room_name: "custom-room-name")
        video_session.save

        expect(video_session.room_name).to eq("custom-room-name")
      end
    end

    describe "generate_session_url" do
      it "automatically generates session URL on creation" do
        video_session = create(:video_session)
        expect(video_session.session_url).to be_present
        expect(video_session.session_url).to include("daily.co")
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
  end

  describe "#patient_url" do
    it "generates patient-specific URL with token" do
      video_session = create(:video_session)
      url = video_session.patient_url

      expect(url).to be_present
      expect(url).to include("role=patient")
      expect(url).to include("token=")
    end
  end

  describe "#doctor_url" do
    it "generates doctor-specific URL with token" do
      video_session = create(:video_session)
      url = video_session.doctor_url

      expect(url).to be_present
      expect(url).to include("role=doctor")
      expect(url).to include("token=")
    end
  end
end
