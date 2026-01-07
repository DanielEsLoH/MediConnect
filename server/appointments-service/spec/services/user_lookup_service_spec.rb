# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserLookupService do
  let(:user_id) { SecureRandom.uuid }
  let(:users_service_url) { ServiceRegistry.url_for(:users) }

  let(:user_data) do
    {
      "id" => user_id,
      "email" => "patient@example.com",
      "first_name" => "Jane",
      "last_name" => "Doe",
      "full_name" => "Jane Doe",
      "phone" => "555-5678",
      "active" => true
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
      expect(described_class::CACHE_TTL).to eq(300.seconds)
    end

    it "has cache key prefix" do
      expect(described_class::CACHE_KEY_PREFIX).to eq("user_lookup")
    end
  end

  describe "exception classes" do
    it "has UserNotFound as StandardError subclass" do
      expect(UserLookupService::UserNotFound.ancestors).to include(StandardError)
    end

    it "has ServiceUnavailable as StandardError subclass" do
      expect(UserLookupService::ServiceUnavailable.ancestors).to include(StandardError)
    end
  end

  describe ".find" do
    context "with valid user_id" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}")
          .to_return(
            status: 200,
            body: { user: user_data }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns user data as symbolized hash" do
        result = described_class.find(user_id)

        expect(result[:id]).to eq(user_id)
        expect(result[:email]).to eq("patient@example.com")
        expect(result[:first_name]).to eq("Jane")
        expect(result[:full_name]).to eq("Jane Doe")
      end

      it "caches the result" do
        described_class.find(user_id)

        # Second call should use cache, no HTTP request
        described_class.find(user_id)

        expect(a_request(:get, "#{users_service_url}/internal/users/#{user_id}"))
          .to have_been_made.once
      end
    end

    context "with cache: false" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}")
          .to_return(
            status: 200,
            body: { user: user_data }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "bypasses cache" do
        described_class.find(user_id, cache: false)
        described_class.find(user_id, cache: false)

        expect(a_request(:get, "#{users_service_url}/internal/users/#{user_id}"))
          .to have_been_made.twice
      end
    end

    context "with cached data" do
      before do
        Rails.cache.write("user_lookup:#{user_id}", user_data)
      end

      it "returns cached data without HTTP request" do
        result = described_class.find(user_id)

        expect(result[:email]).to eq("patient@example.com")
        expect(a_request(:any, /users/)).not_to have_been_made
      end
    end

    context "when user not found (404)" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        result = described_class.find(user_id)

        expect(result).to be_nil
      end
    end

    context "when blank user_id" do
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
        expect { described_class.find(user_id) }
          .to raise_error(described_class::ServiceUnavailable, /circuit is open/)
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}")
          .to_timeout
      end

      it "raises ServiceUnavailable" do
        expect { described_class.find(user_id) }
          .to raise_error(described_class::ServiceUnavailable, /unavailable/)
      end
    end
  end

  describe ".find!" do
    context "when user exists" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}")
          .to_return(
            status: 200,
            body: { user: user_data }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns user data" do
        result = described_class.find!(user_id)

        expect(result[:id]).to eq(user_id)
      end
    end

    context "when user not found" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises UserNotFound" do
        expect { described_class.find!(user_id) }
          .to raise_error(described_class::UserNotFound, /#{user_id}/)
      end
    end
  end

  describe ".contact_info" do
    let(:contact_data) do
      {
        "email" => "patient@example.com",
        "phone" => "555-5678",
        "full_name" => "Jane Doe"
      }
    end

    context "when user exists" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/contact_info")
          .to_return(
            status: 200,
            body: contact_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns contact info" do
        result = described_class.contact_info(user_id)

        expect(result[:email]).to eq("patient@example.com")
        expect(result[:phone]).to eq("555-5678")
        expect(result[:full_name]).to eq("Jane Doe")
      end
    end

    context "when user not found" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/contact_info")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(described_class.contact_info(user_id)).to be_nil
      end
    end

    context "when service returns error" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/contact_info")
          .to_return(
            status: 500,
            body: { error: "Server error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(described_class.contact_info(user_id)).to be_nil
      end
    end

    context "when blank user_id" do
      it "returns nil" do
        expect(described_class.contact_info(nil)).to be_nil
        expect(described_class.contact_info("")).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/contact_info")
          .to_timeout
      end

      it "returns nil" do
        expect(described_class.contact_info(user_id)).to be_nil
      end
    end
  end

  describe ".exists?" do
    context "when user exists" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/exists")
          .to_return(
            status: 200,
            body: { exists: true }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns true" do
        expect(described_class.exists?(user_id)).to be true
      end
    end

    context "when user does not exist" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/exists")
          .to_return(
            status: 200,
            body: { exists: false }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns false" do
        expect(described_class.exists?(user_id)).to be false
      end
    end

    context "when service returns error" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/exists")
          .to_return(
            status: 500,
            body: { error: "Server error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns false" do
        expect(described_class.exists?(user_id)).to be false
      end
    end

    context "when blank user_id" do
      it "returns false for nil" do
        expect(described_class.exists?(nil)).to be false
      end

      it "returns false for empty string" do
        expect(described_class.exists?("")).to be false
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{users_service_url}/internal/users/#{user_id}/exists")
          .to_timeout
      end

      it "returns false (fails closed)" do
        expect(described_class.exists?(user_id)).to be false
      end
    end

    context "when circuit is open" do
      before do
        allow(HttpClient).to receive(:get)
          .and_raise(HttpClient::CircuitOpen.new("Circuit open"))
      end

      it "returns false" do
        expect(described_class.exists?(user_id)).to be false
      end
    end
  end

  describe ".clear_cache" do
    before do
      Rails.cache.write("user_lookup:#{user_id}", user_data)
    end

    it "clears the cache for the user" do
      expect(Rails.cache.read("user_lookup:#{user_id}")).to be_present

      described_class.clear_cache(user_id)

      expect(Rails.cache.read("user_lookup:#{user_id}")).to be_nil
    end
  end
end
