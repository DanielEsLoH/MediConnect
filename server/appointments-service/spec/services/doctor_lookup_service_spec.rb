# frozen_string_literal: true

require "rails_helper"

RSpec.describe DoctorLookupService do
  let(:doctor_id) { SecureRandom.uuid }
  let(:doctors_service_url) { ServiceRegistry.url_for(:doctors) }

  let(:doctor_data) do
    {
      "id" => doctor_id,
      "first_name" => "John",
      "last_name" => "Smith",
      "email" => "john.smith@example.com",
      "specialty" => { "name" => "Cardiology" },
      "active" => true,
      "accepting_new_patients" => true
    }
  end

  before do
    # Clear cache before each test
    Rails.cache.clear
    # Reset circuit breaker state
    ServiceRegistry.reset_all_circuits
  end

  describe "constants" do
    it "has cache TTL" do
      expect(described_class::CACHE_TTL).to eq(600.seconds)
    end

    it "has cache key prefix" do
      expect(described_class::CACHE_KEY_PREFIX).to eq("doctor_lookup")
    end
  end

  describe "exception classes" do
    it "has DoctorNotFound as StandardError subclass" do
      expect(DoctorLookupService::DoctorNotFound.ancestors).to include(StandardError)
    end

    it "has ServiceUnavailable as StandardError subclass" do
      expect(DoctorLookupService::ServiceUnavailable.ancestors).to include(StandardError)
    end
  end

  describe ".find" do
    context "with valid doctor_id" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}")
          .to_return(
            status: 200,
            body: { doctor: doctor_data }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns doctor data as symbolized hash" do
        result = described_class.find(doctor_id)

        expect(result[:id]).to eq(doctor_id)
        expect(result[:first_name]).to eq("John")
        expect(result[:last_name]).to eq("Smith")
      end

      it "caches the result" do
        described_class.find(doctor_id)

        # Second call should use cache, no HTTP request
        described_class.find(doctor_id)

        expect(a_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}"))
          .to have_been_made.once
      end
    end

    context "with cache: false" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}")
          .to_return(
            status: 200,
            body: { doctor: doctor_data }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "bypasses cache" do
        described_class.find(doctor_id, cache: false)
        described_class.find(doctor_id, cache: false)

        expect(a_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}"))
          .to have_been_made.twice
      end
    end

    context "with cached data" do
      before do
        Rails.cache.write("doctor_lookup:#{doctor_id}", doctor_data)
      end

      it "returns cached data without HTTP request" do
        result = described_class.find(doctor_id)

        expect(result[:first_name]).to eq("John")
        expect(a_request(:any, /doctors/)).not_to have_been_made
      end
    end

    context "when doctor not found (404)" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        result = described_class.find(doctor_id)

        expect(result).to be_nil
      end
    end

    context "when blank doctor_id" do
      it "returns nil for nil" do
        expect(described_class.find(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.find("")).to be_nil
      end
    end

    context "when circuit is open" do
      before do
        allow(HttpClient).to receive(:get)
          .and_raise(HttpClient::CircuitOpen.new("Circuit open"))
      end

      it "raises ServiceUnavailable" do
        expect { described_class.find(doctor_id) }
          .to raise_error(described_class::ServiceUnavailable, /circuit is open/)
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}")
          .to_timeout
      end

      it "raises ServiceUnavailable" do
        expect { described_class.find(doctor_id) }
          .to raise_error(described_class::ServiceUnavailable, /unavailable/)
      end
    end
  end

  describe ".find!" do
    context "when doctor exists" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}")
          .to_return(
            status: 200,
            body: { doctor: doctor_data }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns doctor data" do
        result = described_class.find!(doctor_id)

        expect(result[:id]).to eq(doctor_id)
      end
    end

    context "when doctor not found" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises DoctorNotFound" do
        expect { described_class.find!(doctor_id) }
          .to raise_error(described_class::DoctorNotFound, /#{doctor_id}/)
      end
    end
  end

  describe ".contact_info" do
    let(:contact_data) do
      {
        "email" => "john.smith@example.com",
        "phone" => "555-1234",
        "clinic_name" => "Heart Center"
      }
    end

    context "when doctor exists" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/contact_info")
          .to_return(
            status: 200,
            body: contact_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns contact info" do
        result = described_class.contact_info(doctor_id)

        expect(result[:email]).to eq("john.smith@example.com")
        expect(result[:phone]).to eq("555-1234")
      end
    end

    context "when doctor not found" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/contact_info")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(described_class.contact_info(doctor_id)).to be_nil
      end
    end

    context "when service returns error" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/contact_info")
          .to_return(
            status: 500,
            body: { error: "Server error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(described_class.contact_info(doctor_id)).to be_nil
      end
    end

    context "when blank doctor_id" do
      it "returns nil" do
        expect(described_class.contact_info(nil)).to be_nil
        expect(described_class.contact_info("")).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/contact_info")
          .to_timeout
      end

      it "returns nil" do
        expect(described_class.contact_info(doctor_id)).to be_nil
      end
    end
  end

  describe ".exists?" do
    context "when doctor exists and is active" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/exists")
          .to_return(
            status: 200,
            body: { exists: true, active: true, accepting_new_patients: true }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns status hash" do
        result = described_class.exists?(doctor_id)

        expect(result[:exists]).to be true
        expect(result[:active]).to be true
        expect(result[:accepting_new_patients]).to be true
      end
    end

    context "when doctor does not exist" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/exists")
          .to_return(
            status: 404,
            body: { exists: false }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns exists: false" do
        result = described_class.exists?(doctor_id)

        expect(result[:exists]).to be false
      end
    end

    context "when blank doctor_id" do
      it "returns exists: false" do
        expect(described_class.exists?(nil)).to eq({ exists: false })
        expect(described_class.exists?("")).to eq({ exists: false })
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/exists")
          .to_timeout
      end

      it "returns exists: false with error" do
        result = described_class.exists?(doctor_id)

        expect(result[:exists]).to be false
        expect(result[:error]).to eq("service_unavailable")
      end
    end
  end

  describe ".availability" do
    let(:date) { Date.current + 7.days }
    let(:availability_data) do
      {
        "date" => date.to_s,
        "available" => true,
        "slots" => [
          { "start_time" => "09:00", "end_time" => "09:30" },
          { "start_time" => "10:00", "end_time" => "10:30" }
        ]
      }
    end

    context "with available slots" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/availability")
          .with(query: { date: date.to_s })
          .to_return(
            status: 200,
            body: availability_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns availability data" do
        result = described_class.availability(doctor_id, date: date)

        expect(result[:available]).to be true
        expect(result[:slots]).to be_an(Array)
        expect(result[:slots].length).to eq(2)
      end
    end

    context "with Date object" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/availability")
          .with(query: { date: date.to_s })
          .to_return(
            status: 200,
            body: availability_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "converts date to string" do
        result = described_class.availability(doctor_id, date: date)

        expect(result[:available]).to be true
      end
    end

    context "with string date" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/availability")
          .with(query: { date: "2025-01-15" })
          .to_return(
            status: 200,
            body: availability_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "uses string directly" do
        result = described_class.availability(doctor_id, date: "2025-01-15")

        expect(result[:available]).to be true
      end
    end

    context "when service returns error" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/availability")
          .with(query: { date: date.to_s })
          .to_return(
            status: 500,
            body: { error: "Server error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(described_class.availability(doctor_id, date: date)).to be_nil
      end
    end

    context "when blank doctor_id" do
      it "returns nil" do
        expect(described_class.availability(nil, date: date)).to be_nil
        expect(described_class.availability("", date: date)).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{doctors_service_url}/internal/doctors/#{doctor_id}/availability")
          .with(query: { date: date.to_s })
          .to_timeout
      end

      it "returns nil" do
        expect(described_class.availability(doctor_id, date: date)).to be_nil
      end
    end
  end

  describe ".clear_cache" do
    before do
      Rails.cache.write("doctor_lookup:#{doctor_id}", doctor_data)
    end

    it "clears the cache for the doctor" do
      expect(Rails.cache.read("doctor_lookup:#{doctor_id}")).to be_present

      described_class.clear_cache(doctor_id)

      expect(Rails.cache.read("doctor_lookup:#{doctor_id}")).to be_nil
    end
  end
end