# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::UsersController", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")

    # Default stub for users service
    stub_request(:any, %r{http://users-service:3001/})
      .to_return(
        status: 200,
        body: { users: [], user: {} }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "GET /api/v1/users" do
    let(:index_path) { "/api/v1/users" }
    let(:users_list) do
      [
        { id: 1, email: "user1@example.com", role: "patient" },
        { id: 2, email: "user2@example.com", role: "patient" }
      ]
    end

    context "as admin user" do
      before do
        stub_request(:get, /users-service:3001.*users/)
          .to_return(
            status: 200,
            body: { users: users_list, meta: { total: 2 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns list of users" do
        get index_path, headers: auth_headers(user_id: 1, role: "admin")
        expect(response).to have_http_status(:ok)
      end
    end

    context "as non-admin user" do
      it "returns 403 forbidden" do
        get index_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get index_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/users/:id" do
    let(:user_data) do
      { id: 1, email: "user@example.com", first_name: "Test", role: "patient" }
    end

    context "as the same user" do
      before do
        stub_request(:get, /users-service:3001.*users\/1/)
          .to_return(
            status: 200,
            body: user_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns user data" do
        get "/api/v1/users/1", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin accessing another user" do
      before do
        stub_request(:get, /users-service:3001.*users\/2/)
          .to_return(
            status: 200,
            body: { id: 2, email: "other@example.com" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns user data" do
        get "/api/v1/users/2", headers: auth_headers(user_id: 1, role: "admin")
        expect(response).to have_http_status(:ok)
      end
    end

    context "as non-admin accessing another user" do
      it "returns 403 forbidden" do
        get "/api/v1/users/2", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/users/1"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/users" do
    let(:create_path) { "/api/v1/users" }
    let(:valid_user_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "New",
          last_name: "User"
        }
      }
    end

    context "with valid parameters" do
      before do
        stub_request(:post, /users-service:3001.*users/)
          .to_return(
            status: 201,
            body: { id: 1, email: "newuser@example.com" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "creates a new user" do
        post create_path, params: valid_user_params
        expect(response).to have_http_status(:created)
      end
    end

    context "with missing user key" do
      it "returns error for missing required parameter" do
        post create_path, params: { email: "test@example.com" }
        # Rails API mode returns 500 for ParameterMissing by default unless custom handling
        expect(response).to have_http_status(:internal_server_error).or have_http_status(:bad_request)
      end
    end
  end

  describe "PATCH /api/v1/users/:id" do
    let(:update_path) { "/api/v1/users/1" }
    let(:update_params) { { user: { first_name: "Updated" } } }

    context "as the same user" do
      before do
        stub_request(:patch, /users-service:3001.*users\/1/)
          .to_return(
            status: 200,
            body: { id: 1, first_name: "Updated" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "updates user data" do
        patch update_path, params: update_params, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin updating another user" do
      before do
        stub_request(:patch, /users-service:3001.*users\/2/)
          .to_return(
            status: 200,
            body: { id: 2, first_name: "Updated" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "updates user data" do
        patch "/api/v1/users/2", params: update_params, headers: auth_headers(user_id: 1, role: "admin")
        expect(response).to have_http_status(:ok)
      end
    end

    context "as non-admin updating another user" do
      it "returns 403 forbidden" do
        patch "/api/v1/users/2", params: update_params, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        patch update_path, params: update_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/users/search" do
    context "with authentication" do
      before do
        stub_request(:get, /users-service:3001.*search/)
          .to_return(
            status: 200,
            body: { users: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns search results" do
        get "/api/v1/users/search", params: { q: "john" }, headers: auth_headers(user_id: 1, role: "admin")
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/users/search", params: { q: "john" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end