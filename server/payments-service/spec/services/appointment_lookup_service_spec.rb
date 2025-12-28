# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppointmentLookupService do
  let(:appointment_id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }

  # Mock response object that mimics HttpClient::Response
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
      "doctor_id" => SecureRandom.uuid,
      "scheduled_at" => "2024-12-30T10:00:00Z",
      "status" => "confirmed",
      "consultation_fee" => 150.00,
      "duration_minutes" => 30
    }
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    # Clear cache before each test
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

    context "when cache is enabled (default)" do
      context "and cache hit" do
        before do
          # Stub HttpClient to prevent actual network calls and simulate cache behavior
          allow(HttpClient).to receive(:get).and_return(success_response)
          allow(success_response).to receive(:dig).with("appointment").and_return(appointment_data)
          # Pre-populate cache
          Rails.cache.write("appointment_lookup:#{appointment_id}", appointment_data)
        end

        it "returns cached data without making HTTP request" do
          # Cache should be used, so HttpClient should not be called
          result = described_class.find(appointment_id)

          expect(result).to be_a(Hash)
          expect(result[:id]).to eq(appointment_id)
        end

        it "returns data with symbolized keys" do
          result = described_class.find(appointment_id)

          expect(result.keys).to all(be_a(Symbol))
        end
      end

      context "and cache miss" do
        before do
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

        it "writes to cache after successful fetch" do
          expect(Rails.cache).to receive(:write).with(
            "appointment_lookup:#{appointment_id}",
            appointment_data,
            expires_in: described_class::CACHE_TTL
          )

          described_class.find(appointment_id)
        end

        it "returns symbolized appointment data" do
          result = described_class.find(appointment_id)

          expect(result[:id]).to eq(appointment_id)
          expect(result[:status]).to eq("confirmed")
        end
      end
    end

    context "when cache is disabled" do
      before do
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("appointment").and_return(appointment_data)
      end

      it "makes HTTP request even when cache exists" do
        # Pre-populate cache
        Rails.cache.write("appointment_lookup:#{appointment_id}", appointment_data)

        expect(HttpClient).to receive(:get)

        described_class.find(appointment_id, cache: false)
      end

      it "does not write to cache when cache is disabled" do
        expect(Rails.cache).not_to receive(:write)

        described_class.find(appointment_id, cache: false)
      end
    end

    context "when appointment is found (200 response)" do
      before do
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("appointment").and_return(appointment_data)
      end

      it "returns the appointment data with symbolized keys" do
        result = described_class.find(appointment_id)

        expect(result).to be_a(Hash)
        expect(result[:user_id]).to eq(user_id)
        expect(result[:consultation_fee]).to eq(150.00)
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
        allow(HttpClient).to receive(:get).and_return(not_found_response)
      end

      it "returns nil" do
        result = described_class.find(appointment_id)

        expect(result).to be_nil
      end

      it "does not cache the not-found result" do
        described_class.find(appointment_id)

        cached = Rails.cache.read("appointment_lookup:#{appointment_id}")
        expect(cached).to be_nil
      end
    end

    context "when server returns error (500 response)" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          not_found?: false,
          status: 500
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(error_response)
      end

      it "returns nil" do
        result = described_class.find(appointment_id)

        expect(result).to be_nil
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Failed to fetch appointment_id=#{appointment_id}/
        )

        described_class.find(appointment_id)
      end
    end

    context "when circuit breaker is open" do
      before do
        allow(HttpClient).to receive(:get).and_raise(
          HttpClient::CircuitOpen.new("Circuit is open")
        )
      end

      it "raises ServiceUnavailable" do
        expect {
          described_class.find(appointment_id)
        }.to raise_error(described_class::ServiceUnavailable, /circuit is open/)
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(
          /\[AppointmentLookupService\] Circuit open/
        )

        begin
          described_class.find(appointment_id)
        rescue described_class::ServiceUnavailable
          # Expected
        end
      end
    end

    context "when service is unavailable (503)" do
      before do
        allow(HttpClient).to receive(:get).and_raise(
          HttpClient::ServiceUnavailable.new("Service unavailable")
        )
      end

      it "raises ServiceUnavailable" do
        expect {
          described_class.find(appointment_id)
        }.to raise_error(described_class::ServiceUnavailable, /is unavailable/)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Service unavailable/
        )

        begin
          described_class.find(appointment_id)
        rescue described_class::ServiceUnavailable
          # Expected
        end
      end
    end

    context "when request times out" do
      before do
        allow(HttpClient).to receive(:get).and_raise(
          HttpClient::RequestTimeout.new("Request timed out")
        )
      end

      it "raises ServiceUnavailable" do
        expect {
          described_class.find(appointment_id)
        }.to raise_error(described_class::ServiceUnavailable, /is unavailable/)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Service unavailable.*Request timed out/
        )

        begin
          described_class.find(appointment_id)
        rescue described_class::ServiceUnavailable
          # Expected
        end
      end
    end

    context "when response has nil appointment data" do
      let(:nil_data_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          not_found?: false,
          status: 200,
          body: { "appointment" => nil }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(nil_data_response)
        allow(nil_data_response).to receive(:dig).with("appointment").and_return(nil)
      end

      it "returns nil" do
        result = described_class.find(appointment_id)

        expect(result).to be_nil
      end

      it "does not cache nil data" do
        described_class.find(appointment_id)

        cached = Rails.cache.read("appointment_lookup:#{appointment_id}")
        expect(cached).to be_nil
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

  describe ".payment_info" do
    let(:payment_info_data) do
      {
        "appointment_id" => appointment_id,
        "user_id" => user_id,
        "consultation_fee" => 150.00,
        "currency" => "USD",
        "can_process_payment" => true
      }
    end

    let(:payment_info_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        not_found?: false,
        status: 200,
        body: payment_info_data
      )
    end

    context "when appointment_id is blank" do
      it "returns nil without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.payment_info("")

        expect(result).to be_nil
      end
    end

    context "when appointment_id is nil" do
      it "returns nil without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.payment_info(nil)

        expect(result).to be_nil
      end
    end

    context "when payment info is found" do
      before do
        allow(HttpClient).to receive(:get).and_return(payment_info_response)
      end

      it "makes request to payment_info endpoint" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/#{appointment_id}/payment_info"
        )

        described_class.payment_info(appointment_id)
      end

      it "returns symbolized payment info" do
        result = described_class.payment_info(appointment_id)

        expect(result[:consultation_fee]).to eq(150.00)
        expect(result[:can_process_payment]).to be true
      end
    end

    context "when appointment not found (404)" do
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
        result = described_class.payment_info(appointment_id)

        expect(result).to be_nil
      end
    end

    context "when server error occurs" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          not_found?: false,
          status: 500
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(error_response)
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Failed to fetch payment_info/
        )

        result = described_class.payment_info(appointment_id)

        expect(result).to be_nil
      end
    end

    context "when circuit breaker is open" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Circuit open"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Payment info fetch failed/
        )

        result = described_class.payment_info(appointment_id)

        expect(result).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Unavailable"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Payment info fetch failed/
        )

        result = described_class.payment_info(appointment_id)

        expect(result).to be_nil
      end
    end

    context "when request times out" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[AppointmentLookupService\] Payment info fetch failed.*Timeout/
        )

        result = described_class.payment_info(appointment_id)

        expect(result).to be_nil
      end
    end
  end

  describe ".exists?" do
    context "when appointment_id is blank" do
      it "returns { exists: false }" do
        result = described_class.exists?("")

        expect(result).to eq({ exists: false })
      end
    end

    context "when appointment_id is nil" do
      it "returns { exists: false }" do
        result = described_class.exists?(nil)

        expect(result).to eq({ exists: false })
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

      it "makes request to exists endpoint" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/#{appointment_id}/exists"
        )

        described_class.exists?(appointment_id)
      end

      it "returns symbolized response" do
        result = described_class.exists?(appointment_id)

        expect(result[:exists]).to be true
        expect(result[:status]).to eq("confirmed")
        expect(result[:user_id]).to eq(user_id)
      end
    end

    context "when appointment does not exist" do
      let(:not_exists_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          status: 404
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(not_exists_response)
      end

      it "returns { exists: false }" do
        result = described_class.exists?(appointment_id)

        expect(result).to eq({ exists: false })
      end
    end

    context "when service errors occur" do
      context "circuit open" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
        end

        it "returns { exists: false, error: 'service_unavailable' }" do
          result = described_class.exists?(appointment_id)

          expect(result).to eq({ exists: false, error: "service_unavailable" })
        end
      end

      context "service unavailable" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Down"))
        end

        it "returns { exists: false, error: 'service_unavailable' }" do
          result = described_class.exists?(appointment_id)

          expect(result).to eq({ exists: false, error: "service_unavailable" })
        end
      end

      context "request timeout" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
        end

        it "returns { exists: false, error: 'service_unavailable' }" do
          result = described_class.exists?(appointment_id)

          expect(result).to eq({ exists: false, error: "service_unavailable" })
        end
      end
    end
  end

  describe ".for_user" do
    let(:appointments_list) do
      [
        { "id" => SecureRandom.uuid, "status" => "confirmed" },
        { "id" => SecureRandom.uuid, "status" => "completed" }
      ]
    end

    let(:list_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        status: 200
      )
    end

    context "when user_id is blank" do
      it "returns empty array without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.for_user("")

        expect(result).to eq([])
      end
    end

    context "when user_id is nil" do
      it "returns empty array without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.for_user(nil)

        expect(result).to eq([])
      end
    end

    context "when appointments are found" do
      before do
        allow(HttpClient).to receive(:get).and_return(list_response)
        allow(list_response).to receive(:dig).with("appointments").and_return(appointments_list)
      end

      it "makes request to by_user endpoint" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/by_user/#{user_id}",
          params: {}
        )

        described_class.for_user(user_id)
      end

      it "returns array of symbolized appointments" do
        result = described_class.for_user(user_id)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first[:status]).to eq("confirmed")
      end
    end

    context "with status filter" do
      before do
        allow(HttpClient).to receive(:get).and_return(list_response)
        allow(list_response).to receive(:dig).with("appointments").and_return(appointments_list)
      end

      it "includes status in params" do
        expect(HttpClient).to receive(:get).with(
          :appointments,
          "/internal/appointments/by_user/#{user_id}",
          params: { status: "confirmed" }
        )

        described_class.for_user(user_id, status: "confirmed")
      end
    end

    context "when no appointments found" do
      let(:empty_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          status: 200
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(empty_response)
        allow(empty_response).to receive(:dig).with("appointments").and_return([])
      end

      it "returns empty array" do
        result = described_class.for_user(user_id)

        expect(result).to eq([])
      end
    end

    context "when response has nil appointments" do
      let(:nil_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          status: 200
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(nil_response)
        allow(nil_response).to receive(:dig).with("appointments").and_return(nil)
      end

      it "returns empty array" do
        result = described_class.for_user(user_id)

        expect(result).to eq([])
      end
    end

    context "when request fails" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          status: 500
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(error_response)
      end

      it "returns empty array" do
        result = described_class.for_user(user_id)

        expect(result).to eq([])
      end
    end

    context "when service errors occur" do
      context "circuit open" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
        end

        it "returns empty array and logs error" do
          expect(Rails.logger).to receive(:error).with(
            /\[AppointmentLookupService\] User appointments fetch failed/
          )

          result = described_class.for_user(user_id)

          expect(result).to eq([])
        end
      end

      context "service unavailable" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Down"))
        end

        it "returns empty array and logs error" do
          expect(Rails.logger).to receive(:error).with(
            /\[AppointmentLookupService\] User appointments fetch failed/
          )

          result = described_class.for_user(user_id)

          expect(result).to eq([])
        end
      end

      context "request timeout" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
        end

        it "returns empty array and logs error" do
          expect(Rails.logger).to receive(:error).with(
            /\[AppointmentLookupService\] User appointments fetch failed/
          )

          result = described_class.for_user(user_id)

          expect(result).to eq([])
        end
      end
    end
  end

  describe ".clear_cache" do
    it "deletes the cache for the given appointment_id" do
      expect(Rails.cache).to receive(:delete).with("appointment_lookup:#{appointment_id}")

      described_class.clear_cache(appointment_id)
    end

    it "only deletes cache for specified appointment_id" do
      other_id = SecureRandom.uuid

      expect(Rails.cache).to receive(:delete).with("appointment_lookup:#{appointment_id}")
      expect(Rails.cache).not_to receive(:delete).with("appointment_lookup:#{other_id}")

      described_class.clear_cache(appointment_id)
    end
  end

  describe "cache behavior" do
    before do
      allow(HttpClient).to receive(:get).and_return(success_response)
      allow(success_response).to receive(:dig).with("appointment").and_return(appointment_data)
    end

    it "sets appropriate TTL on cached data" do
      expect(Rails.cache).to receive(:write).with(
        "appointment_lookup:#{appointment_id}",
        appointment_data,
        expires_in: described_class::CACHE_TTL
      )

      described_class.find(appointment_id)
    end
  end

  describe "thread safety" do
    it "can be called from multiple threads concurrently" do
      allow(HttpClient).to receive(:get).and_return(success_response)
      allow(success_response).to receive(:dig).with("appointment").and_return(appointment_data)

      results = []
      threads = 5.times.map do
        Thread.new do
          result = described_class.find(appointment_id)
          results << result
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(5)
      expect(results).to all(be_a(Hash))
    end
  end
end