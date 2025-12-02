# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/users" do
    before do
      create_list(:user, 30)
    end

    it "returns paginated users" do
      get "/api/v1/users"

      expect(response).to have_http_status(:success)
      expect(json["users"].size).to eq(25)
      expect(json["meta"]).to include(
        "current_page" => 1,
        "total_count" => 30
      )
    end

    it "supports custom pagination" do
      get "/api/v1/users", params: { page: 2, per_page: 10 }

      expect(response).to have_http_status(:success)
      expect(json["users"].size).to eq(10)
      expect(json["meta"]["current_page"]).to eq(2)
    end

    it "excludes password_digest from response" do
      get "/api/v1/users"

      expect(json["users"].first).not_to have_key("password_digest")
    end

    it "only returns active users" do
      create(:user, :inactive)
      get "/api/v1/users"

      expect(json["users"].count).to eq(25)
      expect(json["meta"]["total_count"]).to eq(30)
    end
  end

  describe "GET /api/v1/users/:id" do
    let(:user) { create(:user, :with_medical_records, :with_allergies) }

    it "returns user details" do
      get "/api/v1/users/#{user.id}"

      expect(response).to have_http_status(:success)
      expect(json["user"]["id"]).to eq(user.id)
      expect(json["user"]["email"]).to eq(user.email)
    end

    it "includes medical records and allergies" do
      get "/api/v1/users/#{user.id}"

      expect(json["user"]["medical_records"]).to be_present
      expect(json["user"]["allergies"]).to be_present
    end

    it "excludes password_digest" do
      get "/api/v1/users/#{user.id}"

      expect(json["user"]).not_to have_key("password_digest")
    end

    it "returns 404 for non-existent user" do
      get "/api/v1/users/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("User not found")
    end
  end

  describe "POST /api/v1/users" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "SecurePass123",
          password_confirmation: "SecurePass123",
          first_name: "John",
          last_name: "Doe",
          phone_number: "123-456-7890"
        }
      }
    end

    it "creates a new user" do
      allow(WelcomeEmailJob).to receive(:perform_async)

      expect do
        post "/api/v1/users", params: valid_params
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["user"]["email"]).to eq("newuser@example.com")
    end

    it "excludes password_digest from response" do
      allow(WelcomeEmailJob).to receive(:perform_async)

      post "/api/v1/users", params: valid_params

      expect(json["user"]).not_to have_key("password_digest")
    end

    it "returns errors for invalid data" do
      invalid_params = valid_params.deep_merge(user: { email: "" })

      post "/api/v1/users", params: invalid_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to be_present
    end

    it "returns errors for weak password" do
      weak_password_params = valid_params.deep_merge(
        user: { password: "weak", password_confirmation: "weak" }
      )

      post "/api/v1/users", params: weak_password_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to match(/8 characters/)
    end
  end

  describe "PATCH /api/v1/users/:id" do
    let(:user) { create(:user) }

    it "updates user attributes" do
      patch "/api/v1/users/#{user.id}", params: {
        user: { first_name: "Updated", last_name: "Name" }
      }

      expect(response).to have_http_status(:success)
      expect(json["user"]["first_name"]).to eq("Updated")
      expect(json["user"]["last_name"]).to eq("Name")
    end

    it "does not allow email updates" do
      original_email = user.email

      patch "/api/v1/users/#{user.id}", params: {
        user: { email: "newemail@example.com" }
      }

      user.reload
      expect(user.email).to eq(original_email)
    end

    it "returns errors for invalid data" do
      patch "/api/v1/users/#{user.id}", params: {
        user: { phone_number: "invalid" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to be_present
    end
  end

  describe "DELETE /api/v1/users/:id" do
    let(:user) { create(:user) }

    it "soft deletes the user" do
      delete "/api/v1/users/#{user.id}"

      expect(response).to have_http_status(:no_content)

      user.reload
      expect(user.active).to be(false)
    end
  end

  describe "GET /api/v1/users/search" do
    let!(:user1) { create(:user, email: "john@example.com", first_name: "John", last_name: "Doe") }
    let!(:user2) { create(:user, email: "jane@example.com", first_name: "Jane", last_name: "Smith") }

    it "searches by email" do
      get "/api/v1/users/search", params: { email: "john@example.com" }

      expect(response).to have_http_status(:success)
      expect(json["users"].size).to eq(1)
      expect(json["users"].first["id"]).to eq(user1.id)
    end

    it "searches by name" do
      get "/api/v1/users/search", params: { name: "Jane" }

      expect(response).to have_http_status(:success)
      expect(json["users"].size).to eq(1)
      expect(json["users"].first["id"]).to eq(user2.id)
    end

    it "searches by phone" do
      user3 = create(:user, phone_number: "555-1234")

      get "/api/v1/users/search", params: { phone: "555" }

      expect(response).to have_http_status(:success)
      expect(json["users"].map { |u| u["id"] }).to include(user3.id)
    end

    it "supports pagination" do
      create_list(:user, 30)

      get "/api/v1/users/search", params: { page: 1, per_page: 10 }

      expect(response).to have_http_status(:success)
      expect(json["users"].size).to eq(10)
      expect(json["meta"]["current_page"]).to eq(1)
    end

    it "returns empty array when no matches" do
      get "/api/v1/users/search", params: { email: "nonexistent@example.com" }

      expect(response).to have_http_status(:success)
      expect(json["users"]).to be_empty
    end
  end
end
