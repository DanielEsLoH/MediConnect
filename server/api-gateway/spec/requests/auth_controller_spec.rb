# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::AuthController", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")
  end

  describe "POST /api/v1/auth/login" do
    let(:login_path) { "/api/v1/auth/login" }
    let(:valid_credentials) { { email: "user@example.com", password: "password123" } }
    let(:user_data) do
      {
        id: 1,
        email: "user@example.com",
        first_name: "Test",
        last_name: "User",
        role: "patient"
      }
    end

    context "with valid credentials" do
      let(:access_token) { generate_token(user_id: 1, email: "user@example.com", role: "patient") }
      let(:refresh_token) { generate_refresh_token(user_id: 1) }

      before do
        # Stub the AuthenticationService directly to avoid WebMock matching issues
        allow(AuthenticationService).to receive(:login).and_return(
          OpenStruct.new(
            success?: true,
            user: user_data,
            tokens: {
              access_token: access_token,
              refresh_token: refresh_token,
              expires_in: 3600,
              token_type: "Bearer"
            }
          )
        )
      end

      it "returns JWT tokens and user data" do
        post login_path, params: valid_credentials

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq("Login successful")
        expect(json_response[:tokens]).to include(:access_token, :refresh_token)
      end

      it "returns valid JWT access token" do
        post login_path, params: valid_credentials

        token_from_response = json_response[:tokens][:access_token]
        decoded = JsonWebToken.decode(token_from_response)

        expect(decoded[:user_id]).to eq(1)
        expect(decoded[:type]).to eq("access")
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

      it "returns 401 unauthorized" do
        post login_path, params: valid_credentials
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with missing credentials" do
      it "returns 401 for missing email" do
        post login_path, params: { password: "password123" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 for missing password" do
        post login_path, params: { email: "user@example.com" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    let(:refresh_path) { "/api/v1/auth/refresh" }
    let(:user_data) do
      { id: 1, email: "user@example.com", role: "patient" }
    end

    context "with valid refresh token" do
      before do
        stub_request(:get, %r{http://users-service:3001/api/internal/users/1})
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns new JWT tokens" do
        refresh_token = generate_refresh_token(user_id: 1)
        post refresh_path, params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq("Token refreshed successfully")
        expect(json_response[:tokens]).to include(:access_token, :refresh_token)
      end
    end

    context "with invalid refresh token" do
      it "returns 401 unauthorized" do
        post refresh_path, params: { refresh_token: "invalid.token.here" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with access token instead of refresh token" do
      it "returns 401 unauthorized for wrong token type" do
        access_token = generate_token(user_id: 1)
        post refresh_path, params: { refresh_token: access_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with missing refresh token" do
      it "returns 401 unauthorized" do
        post refresh_path, params: {}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/auth/logout" do
    let(:logout_path) { "/api/v1/auth/logout" }

    context "with valid access token" do
      it "logs out successfully" do
        token = generate_token(user_id: 1)
        post logout_path, headers: auth_headers(token: token)

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq("Logged out successfully")
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post logout_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/auth/me" do
    let(:me_path) { "/api/v1/auth/me" }
    let(:user_data) do
      { id: 1, email: "user@example.com", first_name: "Test", role: "patient" }
    end

    context "with valid authentication" do
      before do
        stub_request(:get, %r{http://users-service:3001/api/internal/users/1})
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns current user data" do
        get me_path, headers: auth_headers(user_id: 1)

        expect(response).to have_http_status(:ok)
        expect(json_response[:user]).to be_present
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get me_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user not found" do
      before do
        stub_request(:get, %r{http://users-service:3001/api/internal/users/999})
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns 404 not found" do
        get me_path, headers: auth_headers(user_id: 999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/auth/password/reset" do
    let(:password_reset_path) { "/api/v1/auth/password/reset" }

    context "with valid email" do
      before do
        stub_request(:post, "http://users-service:3001/api/internal/password/reset")
          .to_return(
            status: 200,
            body: { message: "Password reset email sent" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "requests password reset" do
        post password_reset_path, params: { email: "user@example.com" }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "PUT /api/v1/auth/password/reset" do
    let(:reset_password_path) { "/api/v1/auth/password/reset" }

    context "with valid reset token" do
      before do
        stub_request(:put, "http://users-service:3001/api/internal/password/reset")
          .to_return(
            status: 200,
            body: { message: "Password updated" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "resets password successfully" do
        put reset_password_path, params: {
          token: "valid_reset_token",
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
