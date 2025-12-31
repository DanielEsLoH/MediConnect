# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Internal::Users", type: :request do
  let(:json) { JSON.parse(response.body) }
  let(:internal_headers) { { "X-Internal-Service" => "api-gateway" } }

  describe "GET /api/internal/users/:id (show)" do
    let!(:user) { create(:user) }

    context "with valid internal service header" do
      it "returns user data when found" do
        get "/api/internal/users/#{user.id}", headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["user"]["id"]).to eq(user.id)
      end

      it "returns correct JSON structure" do
        get "/api/internal/users/#{user.id}", headers: internal_headers

        expect(json["user"]).to include(
          "id" => user.id,
          "email" => user.email,
          "first_name" => user.first_name,
          "last_name" => user.last_name,
          "full_name" => user.full_name,
          "phone_number" => user.phone_number
        )
      end

      it "includes address information" do
        get "/api/internal/users/#{user.id}", headers: internal_headers

        expect(json["user"]).to include(
          "address" => user.address,
          "city" => user.city,
          "state" => user.state,
          "zip_code" => user.zip_code
        )
      end

      it "includes emergency contact information" do
        get "/api/internal/users/#{user.id}", headers: internal_headers

        expect(json["user"]).to include(
          "emergency_contact_name" => user.emergency_contact_name,
          "emergency_contact_phone" => user.emergency_contact_phone
        )
      end

      it "includes timestamps" do
        get "/api/internal/users/#{user.id}", headers: internal_headers

        expect(json["user"]).to have_key("created_at")
        expect(json["user"]).to have_key("updated_at")
      end

      it "returns 404 when user not found" do
        get "/api/internal/users/non-existent-id", headers: internal_headers

        expect(response).to have_http_status(:not_found)
        expect(json["error"]).to eq("Record not found")
      end
    end

    context "without internal service header" do
      it "returns 401 unauthorized" do
        get "/api/internal/users/#{user.id}"

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to include("internal service header required")
      end
    end
  end

  describe "POST /api/internal/users/batch (batch)" do
    let!(:users) { create_list(:user, 5) }
    let(:user_ids) { users.map(&:id) }

    context "with valid request" do
      it "returns multiple users by IDs" do
        post "/api/internal/users/batch",
             params: { user_ids: user_ids },
             headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["users"].length).to eq(5)
      end

      it "returns meta with requested and found counts" do
        post "/api/internal/users/batch",
             params: { user_ids: user_ids },
             headers: internal_headers

        expect(json["meta"]["requested"]).to eq(5)
        expect(json["meta"]["found"]).to eq(5)
      end

      it "returns correct user data for each user" do
        post "/api/internal/users/batch",
             params: { user_ids: user_ids },
             headers: internal_headers

        returned_ids = json["users"].map { |u| u["id"] }
        expect(returned_ids).to match_array(user_ids)
      end

      it "handles partial matches" do
        non_existent_id = "non-existent-uuid"
        mixed_ids = [users.first.id, non_existent_id]

        post "/api/internal/users/batch",
             params: { user_ids: mixed_ids },
             headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["meta"]["requested"]).to eq(2)
        expect(json["meta"]["found"]).to eq(1)
      end

      it "returns empty array when no users found" do
        post "/api/internal/users/batch",
             params: { user_ids: ["non-existent-1", "non-existent-2"] },
             headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["users"]).to eq([])
        expect(json["meta"]["found"]).to eq(0)
      end
    end

    context "with invalid request" do
      it "returns 400 when user_ids is not an array" do
        post "/api/internal/users/batch",
             params: { user_ids: "not-an-array" },
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]).to include("must be an array")
      end

      it "returns 400 when user_ids exceeds max 100 items" do
        large_ids = (1..101).map { |i| "user-#{i}" }

        post "/api/internal/users/batch",
             params: { user_ids: large_ids },
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]).to include("max 100")
      end

      it "returns 400 when user_ids is missing" do
        post "/api/internal/users/batch",
             params: {},
             headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without internal service header" do
      it "returns 401 unauthorized" do
        post "/api/internal/users/batch", params: { user_ids: user_ids }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/internal/users/by_email (by_email)" do
    let!(:user) { create(:user, email: "findme@example.com") }

    context "with valid request" do
      it "returns user by email when found" do
        get "/api/internal/users/by_email",
            params: { email: "findme@example.com" },
            headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["user"]["id"]).to eq(user.id)
        expect(json["user"]["email"]).to eq("findme@example.com")
      end

      it "performs case-insensitive email lookup" do
        get "/api/internal/users/by_email",
            params: { email: "FINDME@EXAMPLE.COM" },
            headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["user"]["id"]).to eq(user.id)
      end

      it "returns 404 when user not found" do
        get "/api/internal/users/by_email",
            params: { email: "nonexistent@example.com" },
            headers: internal_headers

        expect(response).to have_http_status(:not_found)
        expect(json["error"]).to eq("Record not found")
      end

      it "returns 400 when email is missing" do
        get "/api/internal/users/by_email",
            params: {},
            headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without internal service header" do
      it "returns 401 unauthorized" do
        get "/api/internal/users/by_email", params: { email: "findme@example.com" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/internal/users/:id/contact_info (contact_info)" do
    let!(:user) { create(:user, phone_number: "+1 555-123-4567") }

    context "with valid request" do
      it "returns minimal contact info" do
        get "/api/internal/users/#{user.id}/contact_info", headers: internal_headers

        expect(response).to have_http_status(:ok)
      end

      it "returns correct contact fields" do
        get "/api/internal/users/#{user.id}/contact_info", headers: internal_headers

        expect(json).to include(
          "user_id" => user.id,
          "email" => user.email,
          "phone_number" => user.phone_number,
          "first_name" => user.first_name,
          "last_name" => user.last_name,
          "full_name" => user.full_name
        )
      end

      it "includes notification preferences" do
        get "/api/internal/users/#{user.id}/contact_info", headers: internal_headers

        expect(json["notification_preferences"]).to include(
          "email_enabled" => true,
          "push_enabled" => true
        )
      end

      it "sets sms_enabled based on phone number presence" do
        get "/api/internal/users/#{user.id}/contact_info", headers: internal_headers

        expect(json["notification_preferences"]["sms_enabled"]).to be true
      end

      it "sets sms_enabled to false when no phone number" do
        user_without_phone = create(:user, phone_number: nil)

        get "/api/internal/users/#{user_without_phone.id}/contact_info", headers: internal_headers

        expect(json["notification_preferences"]["sms_enabled"]).to be false
      end

      it "returns 404 when user not found" do
        get "/api/internal/users/non-existent/contact_info", headers: internal_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without internal service header" do
      it "returns 401 unauthorized" do
        get "/api/internal/users/#{user.id}/contact_info"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/internal/users/:id/exists (exists)" do
    let!(:user) { create(:user) }

    context "with valid request" do
      it "returns exists: true when user exists" do
        get "/api/internal/users/#{user.id}/exists", headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["exists"]).to be true
      end

      it "returns exists: false when user does not exist" do
        get "/api/internal/users/non-existent-id/exists", headers: internal_headers

        expect(response).to have_http_status(:ok)
        expect(json["exists"]).to be false
      end

      it "never raises 404 - always returns 200" do
        get "/api/internal/users/definitely-not-here/exists", headers: internal_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context "without internal service header" do
      it "returns 401 unauthorized" do
        get "/api/internal/users/#{user.id}/exists"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "request context setup" do
    let!(:user) { create(:user) }

    it "accepts X-Request-ID header" do
      get "/api/internal/users/#{user.id}",
          headers: internal_headers.merge("X-Request-ID" => "req-12345")

      expect(response).to have_http_status(:ok)
    end

    it "accepts X-Correlation-ID header" do
      get "/api/internal/users/#{user.id}",
          headers: internal_headers.merge("X-Correlation-ID" => "corr-67890")

      expect(response).to have_http_status(:ok)
    end

    it "logs internal service name" do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/Request from api-gateway/).at_least(:once)

      get "/api/internal/users/#{user.id}", headers: internal_headers
    end
  end
end
