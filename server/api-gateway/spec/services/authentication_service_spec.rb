# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthenticationService do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("REVOKE_ON_REFRESH", "true").and_return("true")
    allow(ENV).to receive(:fetch).with("JWT_EXPIRATION", anything).and_return(86_400)
  end

  describe ".login" do
    let(:email) { "user@example.com" }
    let(:password) { "password123" }
    let(:user_data) do
      {
        "id" => 1,
        "email" => email,
        "first_name" => "Test",
        "last_name" => "User",
        "role" => "patient"
      }
    end

    context "with valid credentials" do
      before do
        stub_request(:post, "http://users-service:3001/api/internal/authenticate")
          .with(body: { email: email, password: password }.to_json)
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success result" do
        result = described_class.login(email: email, password: password)

        expect(result).to be_success
        expect(result).not_to be_failure
      end

      it "returns user data" do
        result = described_class.login(email: email, password: password)

        expect(result.user["id"]).to eq(1)
        expect(result.user["email"]).to eq(email)
      end

      it "returns tokens" do
        result = described_class.login(email: email, password: password)

        expect(result.tokens).to include(:access_token, :refresh_token, :token_type, :expires_in)
        expect(result.tokens[:token_type]).to eq("Bearer")
      end

      it "generates valid access token" do
        result = described_class.login(email: email, password: password)

        decoded = JsonWebToken.decode(result.tokens[:access_token])
        expect(decoded[:user_id]).to eq(1)
        expect(decoded[:type]).to eq("access")
      end

      it "generates valid refresh token" do
        result = described_class.login(email: email, password: password)

        decoded = JsonWebToken.decode(result.tokens[:refresh_token])
        expect(decoded[:user_id]).to eq(1)
        expect(decoded[:type]).to eq("refresh")
      end

      it "accepts request_id for tracing" do
        result = described_class.login(email: email, password: password, request_id: "trace-123")

        expect(result).to be_success
      end
    end

    context "with invalid credentials" do
      before do
        stub_request(:post, "http://users-service:3001/api/internal/authenticate")
          .to_return(
            status: 401,
            body: { error: "Invalid credentials" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns failure result" do
        result = described_class.login(email: email, password: password)

        expect(result).to be_failure
        expect(result).not_to be_success
      end

      it "returns unauthorized status" do
        result = described_class.login(email: email, password: password)

        expect(result.status).to eq(:unauthorized)
      end

      it "returns error message" do
        result = described_class.login(email: email, password: password)

        expect(result.error).to eq("Invalid email or password")
      end
    end

    context "with missing email" do
      it "returns failure result" do
        result = described_class.login(email: nil, password: password)

        expect(result).to be_failure
        expect(result.error).to eq("Invalid email or password")
      end
    end

    context "with missing password" do
      it "returns failure result" do
        result = described_class.login(email: email, password: nil)

        expect(result).to be_failure
        expect(result.error).to eq("Invalid email or password")
      end
    end

    context "with blank credentials" do
      it "returns failure for blank email" do
        result = described_class.login(email: "", password: password)

        expect(result).to be_failure
      end

      it "returns failure for blank password" do
        result = described_class.login(email: email, password: "")

        expect(result).to be_failure
      end
    end

    context "when users service is unavailable" do
      before do
        stub_request(:post, "http://users-service:3001/api/internal/authenticate")
          .to_timeout
      end

      it "returns service unavailable error" do
        result = described_class.login(email: email, password: password)

        expect(result).to be_failure
        expect(result.status).to eq(:service_unavailable)
      end
    end

    context "when users service returns 404" do
      before do
        stub_request(:post, "http://users-service:3001/api/internal/authenticate")
          .to_return(
            status: 404,
            body: { error: "User not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns not found result" do
        result = described_class.login(email: email, password: password)

        expect(result).to be_failure
        expect(result.error).to eq("User not found")
      end
    end

    context "when users service returns 422" do
      before do
        stub_request(:post, "http://users-service:3001/api/internal/authenticate")
          .to_return(
            status: 422,
            body: { error: "Account locked" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns validation error" do
        result = described_class.login(email: email, password: password)

        expect(result).to be_failure
        expect(result.status).to eq(:unprocessable_entity)
        expect(result.error).to eq("Account locked")
      end
    end
  end

  describe ".refresh" do
    let(:user_data) do
      {
        "id" => 1,
        "email" => "user@example.com",
        "first_name" => "Test",
        "last_name" => "User",
        "role" => "patient"
      }
    end

    context "with valid refresh token" do
      let(:refresh_token) { JsonWebToken.encode_refresh_token({ user_id: 1 }) }

      before do
        stub_request(:get, "http://users-service:3001/api/internal/users/1")
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success result" do
        result = described_class.refresh(refresh_token: refresh_token)

        expect(result).to be_success
      end

      it "returns new tokens" do
        result = described_class.refresh(refresh_token: refresh_token)

        expect(result.tokens).to include(:access_token, :refresh_token)
      end

      it "returns fresh user data" do
        result = described_class.refresh(refresh_token: refresh_token)

        expect(result.user["id"]).to eq(1)
      end
    end

    context "with expired refresh token" do
      let(:expired_payload) do
        {
          user_id: 1,
          exp: 1.day.ago.to_i,
          iat: 2.days.ago.to_i,
          jti: SecureRandom.uuid,
          type: :refresh
        }
      end
      let(:expired_token) { JWT.encode(expired_payload, "test_secret_key", "HS256") }

      it "returns failure with expired error" do
        result = described_class.refresh(refresh_token: expired_token)

        expect(result).to be_failure
        expect(result.error).to include("expired")
        expect(result.status).to eq(:unauthorized)
      end
    end

    context "with invalid refresh token" do
      it "returns failure with invalid token error" do
        result = described_class.refresh(refresh_token: "invalid.token.here")

        expect(result).to be_failure
        expect(result.error).to include("Invalid")
        expect(result.status).to eq(:unauthorized)
      end
    end

    context "with access token instead of refresh token" do
      let(:access_token) { JsonWebToken.encode({ user_id: 1, email: "test@example.com", role: "patient" }) }

      it "returns failure with wrong token type error" do
        result = described_class.refresh(refresh_token: access_token)

        expect(result).to be_failure
        expect(result.error).to eq("Invalid token type")
        expect(result.status).to eq(:unauthorized)
      end
    end

    context "with missing refresh token" do
      it "returns failure when nil" do
        result = described_class.refresh(refresh_token: nil)

        expect(result).to be_failure
        expect(result.error).to eq("Token is required")
      end

      it "returns failure when blank" do
        result = described_class.refresh(refresh_token: "")

        expect(result).to be_failure
        expect(result.error).to eq("Token is required")
      end
    end

    context "when user no longer exists" do
      let(:refresh_token) { JsonWebToken.encode_refresh_token({ user_id: 999 }) }

      before do
        stub_request(:get, "http://users-service:3001/api/internal/users/999")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns not found error" do
        result = described_class.refresh(refresh_token: refresh_token)

        expect(result).to be_failure
        expect(result.error).to eq("User not found")
        expect(result.status).to eq(:not_found)
      end
    end
  end

  describe ".validate" do
    context "with valid access token" do
      let(:token) { JsonWebToken.encode({ user_id: 1, email: "user@example.com", role: "patient" }) }

      it "returns success result" do
        result = described_class.validate(token: token)

        expect(result).to be_success
      end

      it "returns user info from token" do
        result = described_class.validate(token: token)

        expect(result.user[:user_id]).to eq(1)
        expect(result.user[:email]).to eq("user@example.com")
        expect(result.user[:role]).to eq("patient")
      end
    end

    context "with expired access token" do
      let(:expired_payload) do
        {
          user_id: 1,
          email: "user@example.com",
          role: "patient",
          exp: 1.hour.ago.to_i,
          iat: 2.hours.ago.to_i,
          jti: SecureRandom.uuid,
          type: :access
        }
      end
      let(:expired_token) { JWT.encode(expired_payload, "test_secret_key", "HS256") }

      it "returns failure with expired error" do
        result = described_class.validate(token: expired_token)

        expect(result).to be_failure
        expect(result.error).to eq("Token has expired")
        expect(result.status).to eq(:unauthorized)
      end
    end

    context "with invalid token" do
      it "returns failure with invalid error" do
        result = described_class.validate(token: "invalid.token")

        expect(result).to be_failure
        expect(result.error).to eq("Invalid token")
        expect(result.status).to eq(:unauthorized)
      end
    end

    context "with refresh token instead of access token" do
      let(:refresh_token) { JsonWebToken.encode_refresh_token({ user_id: 1 }) }

      it "returns failure with wrong token type error" do
        result = described_class.validate(token: refresh_token)

        expect(result).to be_failure
        expect(result.error).to eq("Invalid token type")
        expect(result.status).to eq(:unauthorized)
      end
    end

    context "with missing token" do
      it "returns failure when nil" do
        result = described_class.validate(token: nil)

        expect(result).to be_failure
        expect(result.error).to eq("Token is required")
      end

      it "returns failure when blank" do
        result = described_class.validate(token: "")

        expect(result).to be_failure
        expect(result.error).to eq("Token is required")
      end
    end
  end

  describe ".logout" do
    context "with valid tokens" do
      let(:access_token) { JsonWebToken.encode({ user_id: 1, email: "user@example.com", role: "patient" }) }
      let(:refresh_token) { JsonWebToken.encode_refresh_token({ user_id: 1 }) }

      it "returns success result" do
        result = described_class.logout(access_token: access_token, refresh_token: refresh_token)

        expect(result).to be_success
      end

      it "reports tokens as revoked" do
        result = described_class.logout(access_token: access_token, refresh_token: refresh_token)

        expect(result.tokens[:access_token_revoked]).to be true
        expect(result.tokens[:refresh_token_revoked]).to be true
      end
    end

    context "with only access token" do
      let(:access_token) { JsonWebToken.encode({ user_id: 1, email: "user@example.com", role: "patient" }) }

      it "revokes only access token" do
        result = described_class.logout(access_token: access_token)

        expect(result).to be_success
        expect(result.tokens[:access_token_revoked]).to be true
        expect(result.tokens[:refresh_token_revoked]).to be false
      end
    end

    context "with nil tokens" do
      it "handles nil access token" do
        result = described_class.logout(access_token: nil)

        expect(result).to be_success
        expect(result.tokens[:access_token_revoked]).to be false
      end
    end
  end

  describe ".fetch_user" do
    let(:user_data) do
      {
        "id" => 1,
        "email" => "user@example.com",
        "first_name" => "Test",
        "last_name" => "User",
        "role" => "patient"
      }
    end

    context "when user exists" do
      before do
        stub_request(:get, "http://users-service:3001/api/internal/users/1")
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns user data" do
        result = described_class.fetch_user(1)

        expect(result["id"]).to eq(1)
        expect(result["email"]).to eq("user@example.com")
      end

      it "accepts request_id for tracing" do
        result = described_class.fetch_user(1, request_id: "trace-123")

        expect(result).to be_present
      end
    end

    context "when user does not exist" do
      before do
        stub_request(:get, "http://users-service:3001/api/internal/users/999")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        result = described_class.fetch_user(999)

        expect(result).to be_nil
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "http://users-service:3001/api/internal/users/1")
          .to_timeout
      end

      it "returns nil and logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch user/)

        result = described_class.fetch_user(1)

        expect(result).to be_nil
      end
    end
  end

  describe "Result class" do
    describe "#success?" do
      it "returns true for success result" do
        result = AuthenticationService::Result.new(success: true)
        expect(result.success?).to be true
      end

      it "returns false for failure result" do
        result = AuthenticationService::Result.new(success: false)
        expect(result.success?).to be false
      end
    end

    describe "#failure?" do
      it "returns false for success result" do
        result = AuthenticationService::Result.new(success: true)
        expect(result.failure?).to be false
      end

      it "returns true for failure result" do
        result = AuthenticationService::Result.new(success: false)
        expect(result.failure?).to be true
      end
    end

    describe "attributes" do
      it "stores user data" do
        result = AuthenticationService::Result.new(success: true, user: { id: 1 })
        expect(result.user).to eq({ id: 1 })
      end

      it "stores tokens" do
        result = AuthenticationService::Result.new(success: true, tokens: { access_token: "token" })
        expect(result.tokens).to eq({ access_token: "token" })
      end

      it "stores error message" do
        result = AuthenticationService::Result.new(success: false, error: "Error message")
        expect(result.error).to eq("Error message")
      end

      it "stores status" do
        result = AuthenticationService::Result.new(success: false, status: :unauthorized)
        expect(result.status).to eq(:unauthorized)
      end

      it "defaults status to :ok" do
        result = AuthenticationService::Result.new(success: true)
        expect(result.status).to eq(:ok)
      end
    end
  end
end
