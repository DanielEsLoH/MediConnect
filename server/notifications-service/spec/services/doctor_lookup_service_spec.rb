# frozen_string_literal: true

require "rails_helper"

RSpec.describe DoctorLookupService do
  let(:doctor_id) { SecureRandom.uuid }

  let(:success_response) do
    instance_double(
      HttpClient::Response,
      success?: true,
      not_found?: false,
      status: 200,
      body: { "doctor" => doctor_data }
    )
  end

  let(:doctor_data) do
    {
      "id" => doctor_id,
      "email" => "doctor@example.com",
      "first_name" => "John",
      "last_name" => "Smith",
      "specialty" => "Cardiology"
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
      expect(described_class::CACHE_KEY_PREFIX).to eq("doctor_lookup")
    end
  end

  describe "custom exceptions" do
    it "defines DoctorNotFound exception" do
      expect(described_class::DoctorNotFound).to be < StandardError
    end

    it "defines ServiceUnavailable exception" do
      expect(described_class::ServiceUnavailable).to be < StandardError
    end
  end

  describe ".find" do
    context "when doctor_id is nil" do
      it "returns nil without making a request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find(nil)

        expect(result).to be_nil
      end
    end

    context "when doctor_id is blank" do
      it "returns nil without making a request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find("")

        expect(result).to be_nil
      end
    end

    context "when cache returns data" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(doctor_id).and_return(doctor_data.symbolize_keys)
      end

      it "returns cached data without calling HTTP" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find(doctor_id)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq(doctor_id)
      end
    end

    context "when cache misses" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(doctor_id).and_return(nil)
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("doctor").and_return(doctor_data)
      end

      it "makes HTTP request to doctors service" do
        expect(HttpClient).to receive(:get).with(
          :doctors,
          "/internal/doctors/#{doctor_id}"
        )

        described_class.find(doctor_id)
      end

      it "returns symbolized doctor data" do
        result = described_class.find(doctor_id)

        expect(result[:id]).to eq(doctor_id)
        expect(result[:email]).to eq("doctor@example.com")
      end
    end

    context "when doctor is not found (404 response)" do
      let(:not_found_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          not_found?: true,
          status: 404
        )
      end

      before do
        allow(described_class).to receive(:fetch_from_cache).with(doctor_id).and_return(nil)
        allow(HttpClient).to receive(:get).and_return(not_found_response)
      end

      it "returns nil" do
        result = described_class.find(doctor_id)

        expect(result).to be_nil
      end
    end

    context "when circuit breaker is open" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(doctor_id).and_return(nil)
        allow(HttpClient).to receive(:get).and_raise(
          HttpClient::CircuitOpen.new("Circuit is open")
        )
      end

      it "raises ServiceUnavailable" do
        expect {
          described_class.find(doctor_id)
        }.to raise_error(described_class::ServiceUnavailable, /circuit is open/)
      end
    end
  end

  describe ".find!" do
    context "when doctor exists" do
      before do
        allow(described_class).to receive(:find).with(doctor_id).and_return(doctor_data.symbolize_keys)
      end

      it "returns the doctor" do
        result = described_class.find!(doctor_id)

        expect(result[:id]).to eq(doctor_id)
      end
    end

    context "when doctor does not exist" do
      before do
        allow(described_class).to receive(:find).with(doctor_id).and_return(nil)
      end

      it "raises DoctorNotFound" do
        expect {
          described_class.find!(doctor_id)
        }.to raise_error(described_class::DoctorNotFound, /Doctor #{doctor_id} not found/)
      end
    end
  end

  describe ".contact_info" do
    let(:contact_info_data) do
      {
        "doctor_id" => doctor_id,
        "email" => "doctor@example.com",
        "phone" => "+1234567890",
        "full_name" => "Dr. John Smith",
        "clinic" => "City Medical Center"
      }
    end

    let(:contact_info_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        not_found?: false,
        status: 200,
        body: contact_info_data
      )
    end

    context "when doctor_id is blank" do
      it "returns nil without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.contact_info("")

        expect(result).to be_nil
      end
    end

    context "when contact info is found" do
      before do
        allow(HttpClient).to receive(:get).and_return(contact_info_response)
      end

      it "makes request to contact_info endpoint" do
        expect(HttpClient).to receive(:get).with(
          :doctors,
          "/internal/doctors/#{doctor_id}/contact_info"
        )

        described_class.contact_info(doctor_id)
      end

      it "returns symbolized contact info" do
        result = described_class.contact_info(doctor_id)

        expect(result[:email]).to eq("doctor@example.com")
        expect(result[:clinic]).to eq("City Medical Center")
      end
    end

    context "when doctor not found (404)" do
      let(:not_found_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          not_found?: true,
          status: 404
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(not_found_response)
      end

      it "returns nil" do
        result = described_class.contact_info(doctor_id)

        expect(result).to be_nil
      end
    end

    context "when server returns error" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          not_found?: false,
          status: 500,
          body: { "error" => "Internal error" }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(error_response)
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch contact info/)

        result = described_class.contact_info(doctor_id)

        expect(result).to be_nil
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Down"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(/Service error/)

        result = described_class.contact_info(doctor_id)

        expect(result).to be_nil
      end
    end

    context "when circuit is open" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
      end

      it "returns nil" do
        result = described_class.contact_info(doctor_id)

        expect(result).to be_nil
      end
    end

    context "when request times out" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
      end

      it "returns nil" do
        result = described_class.contact_info(doctor_id)

        expect(result).to be_nil
      end
    end
  end

  describe ".find_many" do
    let(:doctor_ids) { [ SecureRandom.uuid, SecureRandom.uuid ] }
    let(:batch_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        status: 200
      )
    end

    context "when doctor_ids is blank" do
      it "returns empty hash" do
        result = described_class.find_many([])

        expect(result).to eq({})
      end
    end

    context "when doctors are found" do
      let(:doctors_data) do
        doctor_ids.map { |id| { "id" => id, "email" => "#{id}@example.com" } }
      end

      before do
        allow(HttpClient).to receive(:post).and_return(batch_response)
        allow(batch_response).to receive(:dig).with("doctors").and_return(doctors_data)
      end

      it "makes batch request" do
        expect(HttpClient).to receive(:post).with(
          :doctors,
          "/internal/doctors/batch",
          { doctor_ids: doctor_ids }
        )

        described_class.find_many(doctor_ids)
      end

      it "returns hash indexed by doctor id" do
        result = described_class.find_many(doctor_ids)

        expect(result).to be_a(Hash)
        expect(result.keys).to match_array(doctor_ids)
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:post).and_raise(HttpClient::ServiceUnavailable.new("Down"))
      end

      it "returns empty hash" do
        result = described_class.find_many(doctor_ids)

        expect(result).to eq({})
      end
    end
  end

  describe ".exists?" do
    context "when doctor_id is blank" do
      it "returns exists: false" do
        result = described_class.exists?("")

        expect(result[:exists]).to be false
      end
    end

    context "when doctor exists" do
      let(:exists_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          status: 200,
          body: { "exists" => true, "accepting_new_patients" => true }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(exists_response)
      end

      it "returns the exists response" do
        result = described_class.exists?(doctor_id)

        expect(result[:exists]).to be true
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
      end

      it "returns exists: false with error" do
        result = described_class.exists?(doctor_id)

        expect(result[:exists]).to be false
        expect(result[:error]).to eq("service_unavailable")
      end
    end
  end

  describe ".clear_cache" do
    it "deletes the cache for the given doctor_id" do
      expect(Rails.cache).to receive(:delete).with("doctor_lookup:#{doctor_id}")

      described_class.clear_cache(doctor_id)
    end
  end
end
