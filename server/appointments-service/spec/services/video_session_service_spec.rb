# frozen_string_literal: true

require "rails_helper"

RSpec.describe VideoSessionService do
  let(:video_appointment) { create(:appointment, :video_consultation, :confirmed) }
  let(:in_person_appointment) { create(:appointment, consultation_type: "in_person") }

  describe "#create_session" do
    context "with valid video appointment" do
      it "creates video session successfully" do
        service = described_class.new(video_appointment)

        expect { service.create_session }.to change(VideoSession, :count).by(1)
      end

      it "returns success result with URLs" do
        service = described_class.new(video_appointment)
        result = service.create_session

        expect(result[:success]).to be true
        expect(result[:video_session]).to be_a(VideoSession)
        expect(result[:patient_url]).to be_present
        expect(result[:doctor_url]).to be_present
      end
    end

    context "when appointment is not video type" do
      it "returns error" do
        service = described_class.new(in_person_appointment)
        result = service.create_session

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Appointment must be of type 'video' to create a video session")
      end
    end

    context "when video session already exists" do
      before do
        create(:video_session, appointment: video_appointment)
      end

      it "returns existing session" do
        service = described_class.new(video_appointment)
        result = service.create_session

        expect(result[:success]).to be true
        expect(VideoSession.count).to eq(1) # No new session created
      end
    end

    context "when appointment is cancelled" do
      let(:cancelled_appointment) { create(:appointment, :video_consultation, :cancelled) }

      it "returns error" do
        service = described_class.new(cancelled_appointment)
        result = service.create_session

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Cannot create video session for appointment with status: cancelled")
      end
    end
  end

  describe "#start_session" do
    let(:video_session) { create(:video_session, appointment: video_appointment) }

    context "with valid session" do
      it "starts session successfully" do
        service = described_class.new(video_appointment)
        result = service.start_session(video_session)

        expect(result[:success]).to be true
        expect(video_session.reload.status).to eq("active")
        expect(video_session.started_at).to be_present
      end

      it "updates appointment status to in_progress" do
        service = described_class.new(video_appointment)
        service.start_session(video_session)

        expect(video_appointment.reload.status).to eq("in_progress")
      end
    end

    context "when session is already active" do
      let(:active_session) { create(:video_session, :active, appointment: video_appointment) }

      it "returns error" do
        service = described_class.new(video_appointment)
        result = service.start_session(active_session)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Cannot start video session in current status: active")
      end
    end
  end

  describe "#end_session" do
    let(:active_session) { create(:video_session, :active, appointment: video_appointment) }

    context "with active session" do
      it "ends session successfully" do
        service = described_class.new(video_appointment)
        result = service.end_session(active_session)

        expect(result[:success]).to be true
        expect(active_session.reload.status).to eq("ended")
        expect(active_session.ended_at).to be_present
        expect(active_session.duration_minutes).to be_present
      end
    end

    context "when session is not active" do
      let(:created_session) { create(:video_session, appointment: video_appointment) }

      it "returns error" do
        service = described_class.new(video_appointment)
        result = service.end_session(created_session)

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Cannot end video session in current status: created")
      end
    end
  end
end
