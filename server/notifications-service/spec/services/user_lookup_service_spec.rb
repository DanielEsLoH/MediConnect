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
      "phone_number" => "+1234567890"
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

    context "when cache returns data" do
      before do
        # Stub the private method for cache hit
        allow(described_class).to receive(:fetch_from_cache).with(user_id).and_return(user_data.symbolize_keys)
      end

      it "returns cached data without calling HTTP" do
        expect(HttpClient).not_to receive(:get)

        result = described_class.find(user_id)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq(user_id)
      end

      it "returns data with symbolized keys" do
        result = described_class.find(user_id)

        expect(result.keys).to all(be_a(Symbol))
      end
    end

    context "when cache misses" do
      before do
        allow(described_class).to receive(:fetch_from_cache).with(user_id).and_return(nil)
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

      it "returns symbolized user data" do
        result = described_class.find(user_id)

        expect(result[:id]).to eq(user_id)
        expect(result[:email]).to eq("patient@example.com")
      end
    end

    context "when cache is disabled" do
      before do
        allow(HttpClient).to receive(:get).and_return(success_response)
        allow(success_response).to receive(:dig).with("user").and_return(user_data)
      end

      it "makes HTTP request even when cache exists" do
        Rails.cache.write("user_lookup:#{user_id}", user_data)

        expect(HttpClient).to receive(:get)

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
        expect(result[:phone_number]).to eq("+1234567890")
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
          status: 500,
          body: { "error" => "Internal error" }
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
        expect(Rails.logger).to receive(:error).with(/Failed to fetch user/)

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
        expect(Rails.logger).to receive(:warn).with(/Circuit open/)

        begin
          described_class.find(user_id)
        rescue described_class::ServiceUnavailable
          # Expected
        end
      end
    end

    context "when service is unavailable" do
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
        }.to raise_error(described_class::ServiceUnavailable)
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
        "phone_number" => "+1234567890",
        "full_name" => "John Doe"
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
        expect(result[:phone_number]).to eq("+1234567890")
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
          status: 500,
          body: { "error" => "Internal error" }
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

      it "returns nil and logs warning" do
        expect(Rails.logger).to receive(:warn).with(/Circuit open/)

        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::ServiceUnavailable.new("Unavailable"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(/Users service unavailable/)

        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end

    context "when request times out" do
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::RequestTimeout.new("Timeout"))
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(/Users service unavailable.*Timeout/)

        result = described_class.contact_info(user_id)

        expect(result).to be_nil
      end
    end
  end

  describe ".find_many" do
    let(:user_ids) { [SecureRandom.uuid, SecureRandom.uuid] }
    let(:batch_response) do
      instance_double(
        HttpClient::Response,
        success?: true,
        status: 200
      )
    end

    context "when user_ids is blank" do
      it "returns empty hash" do
        result = described_class.find_many([])

        expect(result).to eq({})
      end
    end

    context "when user_ids is nil" do
      it "returns empty hash" do
        result = described_class.find_many(nil)

        expect(result).to eq({})
      end
    end

    context "when users are found" do
      let(:users_data) do
        user_ids.map { |id| { "id" => id, "email" => "#{id}@example.com" } }
      end

      before do
        allow(HttpClient).to receive(:post).and_return(batch_response)
        allow(batch_response).to receive(:dig).with("users").and_return(users_data)
      end

      it "makes batch request" do
        expect(HttpClient).to receive(:post).with(
          :users,
          "/internal/users/batch",
          { user_ids: user_ids }
        )

        described_class.find_many(user_ids)
      end

      it "returns hash indexed by user id" do
        result = described_class.find_many(user_ids)

        expect(result).to be_a(Hash)
        expect(result.keys).to match_array(user_ids)
      end
    end

    context "when request fails" do
      let(:error_response) do
        instance_double(
          HttpClient::Response,
          success?: false,
          status: 500,
          body: { "error" => "Internal error" }
        )
      end

      before do
        allow(HttpClient).to receive(:post).and_return(error_response)
      end

      it "returns empty hash" do
        result = described_class.find_many(user_ids)

        expect(result).to eq({})
      end
    end

    context "when service errors occur" do
      before do
        allow(HttpClient).to receive(:post).and_raise(HttpClient::ServiceUnavailable.new("Down"))
      end

      it "returns empty hash" do
        result = described_class.find_many(user_ids)

        expect(result).to eq({})
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
      before do
        allow(HttpClient).to receive(:get).and_raise(HttpClient::CircuitOpen.new("Open"))
      end

      it "returns false" do
        result = described_class.exists?(user_id)

        expect(result).to be false
      end
    end
  end

  describe ".clear_cache" do
    it "deletes the cache for the given user_id" do
      Rails.cache.write("user_lookup:#{user_id}", user_data)

      described_class.clear_cache(user_id)

      cached = Rails.cache.read("user_lookup:#{user_id}")
      expect(cached).to be_nil
    end
  end
end
