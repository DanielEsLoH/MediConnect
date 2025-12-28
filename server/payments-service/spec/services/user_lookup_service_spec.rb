# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserLookupService do
  let(:user_id) { SecureRandom.uuid }

  # Mock response object that mimics HttpClient::Response
  let(:success_response) do
    instance_double(
      HttpClient::Response,
      success?: true,
      not_found?: false,
      status: 200,
      body: { "user" => user_data }
    )
  end

  let(:user_data) do
    {
      "id" => user_id,
      "email" => "patient@example.com",
      "full_name" => "John Doe",
      "phone" => "+1234567890",
      "date_of_birth" => "1990-05-15",
      "insurance_provider" => "BlueCross",
      "insurance_id" => "BC123456"
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
      expect(described_class::CACHE_KEY_PREFIX).to eq("user_lookup")
    end
  end

  describe "custom exceptions" do
    it "defines UserNotFound exception" do
      expect(described_class::UserNotFound).to be < StandardError
    end

    it "defines ServiceUnavailable exception" do
      expect(described_class::ServiceUnavailable).to be < StandardError
    end
  end

  describe ".find" do
    context "when user_id is nil" do
      it "returns nil without making a request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find(nil)

        expect(result).to be_nil
      end
    end

    context "when user_id is blank" do
      it "returns nil without making a request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find("")

        expect(result).to be_nil
      end
    end

    context "when cache is enabled (default)" do
      context "and cache hit" do
        before do
          # Stub HttpClient to prevent actual network calls
          allow(HttpClient).to receive(:get).and_return(success_response)
          allow(success_response).to receive(:dig).with("user").and_return(user_data)
          # Pre-populate cache
          Rails.cache.write("user_lookup:#{user_id}", user_data)
        end

        it "returns cached data without making HTTP request" do
          result = described_class.find(user_id)

          expect(result).to be_a(Hash)
          expect(result[:id]).to eq(user_id)
        end

        it "returns data with symbolized keys" do
          result = described_class.find(user_id)

          expect(result.keys).to all(be_a(Symbol))
        end
      end

      context "and cache miss" do
        before do
          allow(HttpClient).to receive(:get).and_return(success_response)
          allow(success_response).to receive(:dig).with("user").and_return(user_data)
        end

        it "makes HTTP request to users service" do
          expect(HttpClient).to receive(:get).with(
            :users,
            "/internal/users/#{user_id}"
          )

          described_class.find(user_id)
        end

        it "writes to cache after successful fetch" do
          expect(Rails.cache).to receive(:write).with(
            "user_lookup:#{user_id}",
            user_data,
            expires_in: described_class::CACHE_TTL
          )

          described_class.find(user_id)
        end

        it "returns symbolized user data" do
          result = described_class.find(user_id)

          expect(result[:id]).to eq(user_id)
          expect(result[:email]).to eq("patient@example.com")
          expect(result[:full_name]).to eq("John Doe")
        end
      end
    end

    context "when cache is disabled" do
      before do
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("user").and_return(user_data)
      end

      it "makes HTTP request even when cache exists" do
        # Pre-populate cache
        Rails.cache.write("user_lookup:#{user_id}", user_data)

        expect(HttpClient).to receive(:get)

        described_class.find(user_id, cache: false)
      end

      it "does not write to cache when cache is disabled" do
        expect(Rails.cache).not_to receive(:write)

        described_class.find(user_id, cache: false)
      end
    end

    context "when user is found (200 response)" do
      before do
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("user").and_return(user_data)
      end

      it "returns the user data with symbolized keys" do
        result = described_class.find(user_id)

        expect(result).to be_a(Hash)
        expect(result[:email]).to eq("patient@example.com")
        expect(result[:phone]).to eq("+1234567890")
        expect(result[:insurance_provider]).to eq("BlueCross")
      end
    end

    context "when user is not found (404 response)" do
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
        result = described_class.find(user_id)

        expect(result).to be_nil
      end

      it "does not cache the not-found result" do
        described_class.find(user_id)

        cached = Rails.cache.read("user_lookup:#{user_id}")
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
        result = described_class.find(user_id)

        expect(result).to be_nil
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /\[UserLookupService\] Failed to fetch user_id=#{user_id}/
        )

        described_class.find(user_id)
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
          described_class.find(user_id)
        }.to raise_error(described_class::ServiceUnavailable, /circuit is open/)
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(
          /\[UserLookupService\] Circuit open/
        )

        begin
          described_class.find(user_id)
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
          described_class.find(user_id)
        }.to raise_error(described_class::ServiceUnavailable, /is unavailable/)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /\[UserLookupService\] Service unavailable/
        )

        begin
          described_class.find(user_id)
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
          described_class.find(user_id)
        }.to raise_error(described_class::ServiceUnavailable, /is unavailable/)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /\[UserLookupService\] Service unavailable.*Request timed out/
        )

        begin
          described_class.find(user_id)
        rescue described_class::ServiceUnavailable
          # Expected
        end
      end
    end

    context "when response has nil user data" do
      let(:nil_data_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          not_found?: false,
          status: 200,
          body: { "user" => nil }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(nil_data_response)
        allow(nil_data_response).to receive(:dig).with("user").and_return(nil)
      end

      it "returns nil" do
        result = described_class.find(user_id)

        expect(result).to be_nil
      end

      it "does not cache nil data" do
        described_class.find(user_id)

        cached = Rails.cache.read("user_lookup:#{user_id}")
        expect(cached).to be_nil
      end
    end
  end

  describe ".find!" do
    context "when user exists" do
      before do
        allow(described_class).to receive(:find).with(user_id).and_return(user_data.symbolize_keys)
      end

      it "returns the user" do
        result = described_class.find!(user_id)

        expect(result[:id]).to eq(user_id)
        expect(result[:email]).to eq("patient@example.com")
      end
    end

    context "when user does not exist" do
      before do
        allow(described_class).to receive(:find).with(user_id).and_return(nil)
      end

      it "raises UserNotFound" do
        expect {
          described_class.find!(user_id)
        }.to raise_error(described_class::UserNotFound, /User #{user_id} not found/)
      end
    end
  end

  describe ".contact_info" do
    let(:contact_info_data) do
      {
        "user_id" => user_id,
        "email" => "patient@example.com",
        "phone" => "+1234567890",
        "full_name" => "John Doe",
        "preferred_contact_method" => "email"
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

    context "when user_id is blank" do
      it "returns nil without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.contact_info("")

        expect(result).to be_nil
      end
    end

    context "when user_id is nil" do
      it "returns nil without making request" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.contact_info(nil)

        expect(result).to be_nil
      end
    end

    context "when contact info is found" do
      before do
        allow(HttpClient).to receive(:get).and_return(contact_info_response)
      end

      it "makes request to contact_info endpoint" do
        expect(HttpClient).to receive(:get).with(
          :users,
          "/internal/users/#{user_id}/contact_info"
        )

        described_class.contact_info(user_id)
      end

      it "returns symbolized contact info" do
        result = described_class.contact_info(user_id)

        expect(result[:email]).to eq("patient@example.com")
        expect(result[:phone]).to eq("+1234567890")
        expect(result[:preferred_contact_method]).to eq("email")
      end
    end

    context "when user not found (404)" do
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
        result = described_class.contact_info(user_id)

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

      it "returns nil" do
        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end

    context "when circuit breaker is open" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Circuit open"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[UserLookupService\] Contact info fetch failed/
        )

        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Unavailable"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[UserLookupService\] Contact info fetch failed/
        )

        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end

    context "when request times out" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(
          /\[UserLookupService\] Contact info fetch failed.*Timeout/
        )

        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end
  end

  describe ".exists?" do
    context "when user_id is blank" do
      it "returns false" do
        result = described_class.exists?("")

        expect(result).to be false
      end
    end

    context "when user_id is nil" do
      it "returns false" do
        result = described_class.exists?(nil)

        expect(result).to be false
      end
    end

    context "when user exists" do
      let(:exists_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          status: 200
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(exists_response)
        allow(exists_response).to receive(:dig).with("exists").and_return(true)
      end

      it "makes request to exists endpoint" do
        expect(HttpClient).to receive(:get).with(
          :users,
          "/internal/users/#{user_id}/exists"
        )

        described_class.exists?(user_id)
      end

      it "returns true" do
        result = described_class.exists?(user_id)

        expect(result).to be true
      end
    end

    context "when user does not exist" do
      let(:exists_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          status: 200
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(exists_response)
        allow(exists_response).to receive(:dig).with("exists").and_return(false)
      end

      it "returns false" do
        result = described_class.exists?(user_id)

        expect(result).to be false
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

      it "returns false" do
        result = described_class.exists?(user_id)

        expect(result).to be false
      end
    end

    context "when service errors occur" do
      context "circuit open" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
        end

        it "returns false" do
          result = described_class.exists?(user_id)

          expect(result).to be false
        end
      end

      context "service unavailable" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Down"))
        end

        it "returns false" do
          result = described_class.exists?(user_id)

          expect(result).to be false
        end
      end

      context "request timeout" do
        before do
          allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
        end

        it "returns false" do
          result = described_class.exists?(user_id)

          expect(result).to be false
        end
      end
    end
  end

  describe ".clear_cache" do
    it "deletes the cache for the given user_id" do
      expect(Rails.cache).to receive(:delete).with("user_lookup:#{user_id}")

      described_class.clear_cache(user_id)
    end

    it "only deletes cache for specified user_id" do
      other_id = SecureRandom.uuid

      expect(Rails.cache).to receive(:delete).with("user_lookup:#{user_id}")
      expect(Rails.cache).not_to receive(:delete).with("user_lookup:#{other_id}")

      described_class.clear_cache(user_id)
    end
  end

  describe "cache behavior" do
    before do
      allow(HttpClient).to receive(:get).and_return(success_response)
      allow(success_response).to receive(:dig).with("user").and_return(user_data)
    end

    it "sets appropriate TTL on cached data" do
      expect(Rails.cache).to receive(:write).with(
        "user_lookup:#{user_id}",
        user_data,
        expires_in: described_class::CACHE_TTL
      )

      described_class.find(user_id)
    end
  end

  describe "thread safety" do
    it "can be called from multiple threads concurrently" do
      allow(HttpClient).to receive(:get).and_return(success_response)
      allow(success_response).to receive(:dig).with("user").and_return(user_data)

      results = []
      mutex = Mutex.new
      threads = 5.times.map do
        Thread.new do
          result = described_class.find(user_id)
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(5)
      expect(results).to all(be_a(Hash))
    end
  end

  describe "integration with payment flow" do
    let(:payment) { create(:payment, user_id: user_id) }

    before do
      allow(HttpClient).to receive(:get).and_return(success_response)
      allow(success_response).to receive(:dig).with("user").and_return(user_data)
    end

    it "can fetch user data for a payment" do
      result = described_class.find(payment.user_id)

      expect(result).not_to be_nil
      expect(result[:email]).to eq("patient@example.com")
    end
  end

  describe "edge cases" do
    context "with special characters in user data" do
      let(:user_data_with_special_chars) do
        {
          "id" => user_id,
          "email" => "patient+test@example.com",
          "full_name" => "John O'Brien-Smith",
          "phone" => "+1 (234) 567-8900"
        }
      end

      let(:special_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          not_found?: false,
          status: 200,
          body: { "user" => user_data_with_special_chars }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(special_response)
        allow(special_response).to receive(:dig).with("user").and_return(user_data_with_special_chars)
      end

      it "handles special characters correctly" do
        result = described_class.find(user_id)

        expect(result[:email]).to eq("patient+test@example.com")
        expect(result[:full_name]).to eq("John O'Brien-Smith")
      end
    end

    context "with unicode characters in user data" do
      let(:user_data_with_unicode) do
        {
          "id" => user_id,
          "email" => "patient@example.com",
          "full_name" => "Jose Garcia"
        }
      end

      let(:unicode_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          not_found?: false,
          status: 200,
          body: { "user" => user_data_with_unicode }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(unicode_response)
        allow(unicode_response).to receive(:dig).with("user").and_return(user_data_with_unicode)
      end

      it "handles unicode characters correctly" do
        result = described_class.find(user_id)

        expect(result[:full_name]).to eq("Jose Garcia")
      end
    end

    context "with empty string fields in user data" do
      let(:user_data_with_empty_fields) do
        {
          "id" => user_id,
          "email" => "patient@example.com",
          "full_name" => "",
          "phone" => nil
        }
      end

      let(:empty_fields_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          not_found?: false,
          status: 200,
          body: { "user" => user_data_with_empty_fields }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(empty_fields_response)
        allow(empty_fields_response).to receive(:dig).with("user").and_return(user_data_with_empty_fields)
      end

      it "handles empty and nil fields correctly" do
        result = described_class.find(user_id)

        expect(result[:full_name]).to eq("")
        expect(result[:phone]).to be_nil
      end
    end

    context "with invalid UUID format" do
      let(:invalid_user_id) { "not-a-valid-uuid" }

      before do
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("user").and_return(nil)
      end

      it "still makes the request and returns nil if not found" do
        expect(HttpClient).to receive(:get).with(
          :users,
          "/internal/users/#{invalid_user_id}"
        )

        result = described_class.find(invalid_user_id)

        expect(result).to be_nil
      end
    end
  end

  describe "response parsing" do
    context "when response body has extra fields" do
      let(:extended_user_data) do
        user_data.merge(
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-12-28T00:00:00Z",
          "metadata" => { "source" => "web" }
        )
      end

      let(:extended_response) do
        instance_double(
          HttpClient::Response,
          success?: true,
          not_found?: false,
          status: 200,
          body: { "user" => extended_user_data }
        )
      end

      before do
        allow(HttpClient).to receive(:get).and_return(extended_response)
        allow(extended_response).to receive(:dig).with("user").and_return(extended_user_data)
      end

      it "includes all fields from the response" do
        result = described_class.find(user_id)

        expect(result[:created_at]).to eq("2024-01-01T00:00:00Z")
        expect(result[:metadata]).to eq({ "source" => "web" })
      end
    end
  end
end