# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Internal::Authentication", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:internal_headers) { { "X-Internal-Service" => "api-gateway" } }

  describe "POST /api/internal/authenticate" do
    let!(:user) do
      create(:user,
             email: "auth-test@example.com",
             password: "SecurePass123",
             password_confirmation: "SecurePass123",
             first_name: "Auth",
             last_name: "User")
    end

    context "with valid credentials" do
      it "returns user data" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "SecurePass123" },
             headers: internal_headers

        expect(response).to have_http_status(:ok)
      end

      it "returns correct JSON structure" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "SecurePass123" },
             headers: internal_headers

        expect(json).to include(
          "id" => user.id,
          "email" => "auth-test@example.com",
          "first_name" => "Auth",
          "last_name" => "User"
        )
      end

      it "returns user role" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "SecurePass123" },
             headers: internal_headers

        expect(json).to have_key("role")
        expect(json["role"]).to eq("user")
      end

      it "returns admin role for admin email" do
        admin = create(:user,
                       email: "admin@mediconnect.com",
                       password: "AdminPass123",
                       password_confirmation: "AdminPass123")

        post "/api/internal/authenticate",
             params: { email: "admin@mediconnect.com", password: "AdminPass123" },
             headers: internal_headers

        expect(json["role"]).to eq("admin")
      end

      it "is case insensitive for email" do
        post "/api/internal/authenticate",
             params: { email: "AUTH-TEST@EXAMPLE.COM", password: "SecurePass123" },
             headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["id"]).to eq(user.id)
      end
    end

    context "with invalid password" do
      it "returns 401 unauthorized" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "WrongPassword" },
             headers: internal_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "WrongPassword" },
             headers: internal_headers

        expect(json["error"]).to eq("Invalid email or password")
      end
    end

    context "with non-existent email" do
      it "returns 401 unauthorized" do
        post "/api/internal/authenticate",
             params: { email: "nonexistent@example.com", password: "SomePassword123" },
             headers: internal_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns generic error message" do
        post "/api/internal/authenticate",
             params: { email: "nonexistent@example.com", password: "SomePassword123" },
             headers: internal_headers

        expect(json["error"]).to eq("Invalid email or password")
      end
    end

    context "with nil email" do
      it "returns 400 bad request" do
        post "/api/internal/authenticate",
             params: { email: nil, password: "SomePassword123" },
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with nil password" do
      it "returns 400 bad request" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: nil },
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with missing email" do
      it "returns 400 bad request" do
        post "/api/internal/authenticate",
             params: { password: "SomePassword123" },
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with missing password" do
      it "returns 400 bad request" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com" },
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without internal service header" do
      it "returns 401 unauthorized" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "SecurePass123" }

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to include("internal service header required")
      end
    end

    context "with empty internal service header" do
      it "returns 401 unauthorized" do
        post "/api/internal/authenticate",
             params: { email: "auth-test@example.com", password: "SecurePass123" },
             headers: { "X-Internal-Service" => "" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
