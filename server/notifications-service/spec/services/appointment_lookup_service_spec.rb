# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppointmentLookupService do
  let(:appointment_id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }
  let(:doctor_id) { SecureRandom.uuid }

  let(:success_response) do
    instance_double(
      HttpClient::Response,
      success?: true,
      not_found?: false,
      status: 200,
      body: { "appointment" => appointment_data }
    )
  end

  let(:appointment_data) do
    {
      "id" => appointment_id,
      "user_id" => user_id,
      "doctor_id" => doctor_id,
      "scheduled_datetime" => 3.days.from_now.iso8601,
      "status" => "confirmed"
    }
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:debug)
    Rails.cache.clear
  end

  describe "constants" do
    it "has a CACHE_TTL constant" do
      expect(described_class::CACHE_TTL).to be_a(ActiveSupport::Duration)
    end

    it "has a CACHE_KEY_PREFIX constant" do
      expect(described_class::CACHE_KEY_PREFIX).to eq("appointment_lookup")
    end
  end

  describe "custom exceptions" do
    it "defines AppointmentNotFound exception" do
      expect(described_class::AppointmentNotFound).to be < StandardError
    end

    it "defines ServiceUnavailable exception" do
      expect(described_class::ServiceUnavailable).to be < StandardError
    end
  end

  describe ".find" do
    context "when appointment_id is nil" do
      it "returns nil without making a request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find(nil)

        expect(result).to be_nil
      end
    end

    context "when appointment_id is blank" do
      it "returns nil without making a request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find("")

        expect(result).to be_nil
      end
    end

    context "when cache returns data" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(appointment_id).and_return(appointment_data.symbolize_keys)
      end

      it "returns cached data without calling HTTP" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find(appointment_id)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq(appointment_id)
      end
    end

    context "when cache misses" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(appointment_id).and_return(nil)
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("appointment").and_return(appointment_data)
      end

      it "makes HTTP request to appointments service" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/#{appointment_id}"
        )

        described_class.find(appointment_id)
      end

      it "returns symbolized appointment data" do
        result = described_class.find(appointment_id)

        expect(result[:id]).to eq(appointment_id)
        expect(result[:status]).to eq("confirmed")
      end
    end

    context "when appointment is not found (404 response)" do
      let(:not_found_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          not_found?: true,
          status: 404
        )
      end

      before do
        allow(described_class).to receive(:fetch_from_cache).with(appointment_id).and_return(nil)
        allow(HttpClient).to receive(:get).and_return(not_found_response)
      end

      it "returns nil" do
        result = described_class.find(appointment_id)

        expect(result).to be_nil
      end
    end

    context "when circuit breaker is open" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(appointment_id).and_return(nil)
        allow(HttpClient).to receive(:get).and_raise(
          HttpClient::CircuitOpen.new("Circuit is open")
        )
      end

      it "raises ServiceUnavailable" do
        expect {
          described_class.find(appointment_id)
        }.to raise_error(described_class::ServiceUnavailable, /circuit is open/)
      end
    end
  end

  describe ".find!" do
    context "when appointment exists" do
      before do
        allow(described_class).to receive(:find).with(appointment_id).and_return(appointment_data.symbolize_keys)
      end

      it "returns the appointment" do
        result = described_class.find!(appointment_id)

        expect(result[:id]).to eq(appointment_id)
      end
    end

    context "when appointment does not exist" do
      before do
        allow(described_class).to receive(:find).with(appointment_id).and_return(nil)
      end

      it "raises AppointmentNotFound" do
        expect {
          described_class.find!(appointment_id)
        }.to raise_error(described_class::AppointmentNotFound, /Appointment #{appointment_id} not found/)
      end
    end
  end

  describe ".for_user" do
    let(:appointments_data) do
      [
        { "id" => SecureRandom.uuid, "user_id" => user_id, "status" => "confirmed" },
        { "id" => SecureRandom.uuid, "user_id" => user_id, "status" => "pending" }
      ]
    end

    let(:user_appointments_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        status: 200
      )
    end

    context "when user_id is blank" do
      it "returns empty array" do
        result = described_class.for_user("")

        expect(result).to eq([])
      end
    end

    context "when appointments exist" do
      before do
        allow(HttpClient).to receive(:get).and_return(user_appointments_response)
        allow(user_appointments_response).to receive(:dig).with("appointments").and_return(appointments_data)
      end

      it "makes request to by_user endpoint" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/by_user/#{user_id}",
          params: {}
        )

        described_class.for_user(user_id)
      end

      it "returns array of appointments with symbolized keys" do
        result = described_class.for_user(user_id)

        expect(result).to be_an(Array)
        expect(result.first[:user_id]).to eq(user_id)
      end

      it "accepts status and from_date params" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/by_user/#{user_id}",
          params: { status: "confirmed", from_date: "2025-01-01" }
        )

        described_class.for_user(user_id, status: "confirmed", from_date: "2025-01-01")
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Down"))
      end

      it "returns empty array and logs error" do
        expect(Rails.logger).to receive(:error).with(/Service error/)

        result = described_class.for_user(user_id)

        expect(result).to eq([])
      end
    end

    context "when server returns error response" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          status: 500,
          body: { "error" => "Internal error" }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(error_response)
      end

      it "returns empty array and logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch user appointments/)

        result = described_class.for_user(user_id)

        expect(result).to eq([])
      end
    end
  end

  describe ".for_doctor" do
    let(:appointments_data) do
      [
        { "id" => SecureRandom.uuid, "doctor_id" => doctor_id, "status" => "confirmed" }
      ]
    end

    let(:doctor_appointments_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        status: 200
      )
    end

    context "when doctor_id is blank" do
      it "returns empty array" do
        result = described_class.for_doctor("")

        expect(result).to eq([])
      end
    end

    context "when appointments exist" do
      before do
        allow(HttpClient).to receive(:get).and_return(doctor_appointments_response)
        allow(doctor_appointments_response).to receive(:dig).with("appointments").and_return(appointments_data)
      end

      it "makes request to by_doctor endpoint" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/by_doctor/#{doctor_id}",
          params: {}
        )

        described_class.for_doctor(doctor_id)
      end

      it "returns array of appointments with symbolized keys" do
        result = described_class.for_doctor(doctor_id)

        expect(result).to be_an(Array)
        expect(result.first[:doctor_id]).to eq(doctor_id)
      end

      it "accepts status and date params" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/by_doctor/#{doctor_id}",
          params: { status: "confirmed", date: "2025-01-15" }
        )

        described_class.for_doctor(doctor_id, status: "confirmed", date: "2025-01-15")
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
      end

      it "returns empty array and logs error" do
        expect(Rails.logger).to receive(:error).with(/Service error/)

        result = described_class.for_doctor(doctor_id)

        expect(result).to eq([])
      end
    end

    context "when server returns error response" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          status: 500,
          body: { "error" => "Internal error" }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(error_response)
      end

      it "returns empty array and logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch doctor appointments/)

        result = described_class.for_doctor(doctor_id)

        expect(result).to eq([])
      end
    end
  end

  describe ".exists?" do
    context "when appointment_id is blank" do
      it "returns exists: false" do
        result = described_class.exists?("")

        expect(result[:exists]).to be false
      end
    end

    context "when appointment exists" do
      let(:exists_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          status: 200,
          body: { "exists" => true, "status" => "confirmed", "user_id" => user_id }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(exists_response)
      end

      it "returns the exists response" do
        result = described_class.exists?(appointment_id)

        expect(result[:exists]).to be true
        expect(result[:status]).to eq("confirmed")
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
      end

      it "returns exists: false with error" do
        result = described_class.exists?(appointment_id)

        expect(result[:exists]).to be false
        expect(result[:error]).to eq("service_unavailable")
      end
    end
  end

  describe ".clear_cache" do
    it "deletes the cache for the given appointment_id" do
      expect(Rails.cache).to receive(:delete).with("appointment_lookup:#{appointment_id}")

      described_class.clear_cache(appointment_id)
    end
  end
end
