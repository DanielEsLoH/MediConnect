# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppointmentBookingService do
  let(:user_id) { SecureRandom.uuid }
  let(:doctor_id) { SecureRandom.uuid }
  let(:clinic_id) { SecureRandom.uuid }

  let(:valid_params) do
    {
      user_id: user_id,
      doctor_id: doctor_id,
      clinic_id: clinic_id,
      appointment_date: 1.week.from_now.to_date,
      start_time: "10:00",
      end_time: "10:30",
      consultation_type: "in_person",
      reason: "Regular checkup"
    }
  end

  let(:doctor_data) do
    {
      "id" => doctor_id,
      "clinic_id" => clinic_id,
      "active" => true,
      "accepting_new_patients" => true,
      "consultation_fee" => 150.00
    }
  end

  # Helper to create HttpClient::Response objects
  def mock_response(status:, body:)
    HttpClient::Response.new(status: status, body: body, headers: {})
  end

  def stub_user_lookup(success: true)
    response = if success
      mock_response(status: 200, body: { "id" => user_id })
    else
      mock_response(status: 404, body: { "error" => "Not found" })
    end
    allow(HttpClient).to receive(:get)
      .with(:users, "/api/v1/users/#{user_id}")
      .and_return(response)
  end

  def stub_doctor_lookup(success: true, data: nil)
    body = data || doctor_data
    response = if success
      mock_response(status: 200, body: body)
    else
      mock_response(status: 404, body: { "error" => "Not found" })
    end
    allow(HttpClient).to receive(:get)
      .with(:doctors, "/api/v1/doctors/#{doctor_id}")
      .and_return(response)
  end

  describe "#call" do
    context "with valid parameters" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true)
      end

      it "creates an appointment successfully" do
        service = described_class.new(valid_params)

        expect { service.call }.to change(Appointment, :count).by(1)
      end

      it "returns success result" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be true
        expect(result[:appointment]).to be_a(Appointment)
        expect(result[:message]).to eq("Appointment booked successfully")
      end

      it "sets consultation fee from doctor data" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:appointment].consultation_fee).to eq(150.00)
      end

      it "sets status to pending" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:appointment].status).to eq("pending")
      end

      it "generates a request_id" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:appointment].request_id).to be_present
        expect(result[:appointment].request_id).to start_with("APT-")
      end
    end

    context "with missing parameters" do
      it "returns error when user_id is missing" do
        params = valid_params.except(:user_id)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("User is required")
      end

      it "returns error when doctor_id is missing" do
        params = valid_params.except(:doctor_id)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Doctor is required")
      end

      it "returns error when appointment_date is missing" do
        params = valid_params.except(:appointment_date)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Appointment date is required")
      end

      it "returns error when clinic_id is missing" do
        params = valid_params.except(:clinic_id)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Clinic is required")
      end

      it "returns error when start_time is missing" do
        params = valid_params.except(:start_time)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Start time is required")
      end

      it "returns error when end_time is missing" do
        params = valid_params.except(:end_time)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("End time is required")
      end

      it "returns error when consultation_type is missing" do
        params = valid_params.except(:consultation_type)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Consultation type is required")
      end
    end

    context "with invalid consultation_type" do
      it "returns error for invalid consultation type" do
        params = valid_params.merge(consultation_type: "invalid_type")
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Consultation type must be one of: in_person, video, phone")
      end
    end

    context "when user does not exist" do
      before do
        stub_user_lookup(success: false)
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors].first).to match(/User not found/)
      end
    end

    context "when doctor does not exist" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: false)
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Doctor not found")
      end
    end

    context "when clinic does not match doctor" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true, data: doctor_data.merge("clinic_id" => SecureRandom.uuid))
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Doctor is not associated with the specified clinic")
      end
    end

    context "when doctor is not active" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true, data: doctor_data.merge("active" => false))
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Doctor is not currently active")
      end
    end

    context "when doctor is not accepting new patients" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true, data: doctor_data.merge("accepting_new_patients" => false))
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Doctor is not accepting new patients")
      end
    end

    context "when doctor has overlapping appointment" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true)

        # Create an existing appointment that overlaps with the test params (10:00-10:30)
        # The existing appointment is from 09:30-10:30, overlapping with 10:00-10:30
        create(:appointment,
               doctor_id: doctor_id,
               appointment_date: valid_params[:appointment_date],
               start_time: "09:30:00",
               end_time: "10:30:00",
               duration_minutes: 60,
               status: "confirmed")
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Doctor is not available at the requested time")
      end
    end

    context "when appointment date is in the past" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true)
      end

      it "returns error" do
        params = valid_params.merge(appointment_date: 1.day.ago.to_date)
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Appointment date cannot be in the past")
      end
    end

    context "when start_time is after end_time" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true)
      end

      it "returns error" do
        params = valid_params.merge(start_time: "11:00", end_time: "10:00")
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Start time must be before end time")
      end
    end

    context "when duration is too short" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true)
      end

      it "returns error" do
        params = valid_params.merge(start_time: "10:00", end_time: "10:10")
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Appointment duration must be between 15 and 120 minutes")
      end
    end

    context "when duration is too long" do
      before do
        stub_user_lookup(success: true)
        stub_doctor_lookup(success: true)
      end

      it "returns error" do
        params = valid_params.merge(start_time: "10:00", end_time: "12:30")
        service = described_class.new(params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Appointment duration must be between 15 and 120 minutes")
      end
    end

    context "when external service is unavailable" do
      before do
        allow(HttpClient).to receive(:get)
          .with(:users, "/api/v1/users/#{user_id}")
          .and_raise(HttpClient::ServiceUnavailable, "Service down")
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Unable to verify user: Service down")
      end
    end

    context "when circuit breaker is open" do
      before do
        allow(HttpClient).to receive(:get)
          .with(:users, "/api/v1/users/#{user_id}")
          .and_raise(HttpClient::CircuitOpen, "Circuit breaker is open for service: users")
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors].first).to include("Unable to verify user")
      end
    end

    context "when doctor service is unavailable" do
      before do
        stub_user_lookup(success: true)
        allow(HttpClient).to receive(:get)
          .with(:doctors, "/api/v1/doctors/#{doctor_id}")
          .and_raise(HttpClient::ServiceUnavailable, "Service down")
      end

      it "returns error" do
        service = described_class.new(valid_params)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Unable to verify doctor: Service down")
      end
    end
  end

  describe "#errors" do
    it "returns empty array for new service" do
      service = described_class.new(valid_params)
      expect(service.errors).to eq([])
    end

    it "returns accumulated errors after failed call" do
      params = valid_params.except(:user_id, :doctor_id)
      service = described_class.new(params)
      service.call

      expect(service.errors).to include("User is required")
      expect(service.errors).to include("Doctor is required")
    end
  end
end