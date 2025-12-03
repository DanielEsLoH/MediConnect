# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notification Preferences API", type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:json) { JSON.parse(response.body) }

  describe "GET /notification_preferences/:user_id" do
    context "when preference exists" do
      let!(:preference) { create(:notification_preference, user_id: user_id) }

      it "returns the preference" do
        get "/notification_preferences/#{user_id}"

        expect(response).to have_http_status(:ok)
        expect(json["user_id"]).to eq(user_id)
        expect(json["email_enabled"]).to be true
      end
    end

    context "when preference does not exist" do
      it "creates and returns default preference" do
        expect {
          get "/notification_preferences/#{user_id}"
        }.to change(NotificationPreference, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json["user_id"]).to eq(user_id)
        expect(json["email_enabled"]).to be true
        expect(json["marketing_emails"]).to be false
      end
    end

    it "requires user_id" do
      get "/notification_preferences/"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT/PATCH /notification_preferences/:user_id" do
    let!(:preference) { create(:notification_preference, user_id: user_id) }

    let(:update_params) do
      {
        notification_preference: {
          email_enabled: false,
          sms_enabled: true,
          appointment_reminders: false
        }
      }
    end

    it "updates the preference" do
      put "/notification_preferences/#{user_id}", params: update_params

      expect(response).to have_http_status(:ok)
      expect(json["email_enabled"]).to be false
      expect(json["sms_enabled"]).to be true
      expect(json["appointment_reminders"]).to be false

      preference.reload
      expect(preference.email_enabled).to be false
    end

    it "validates boolean fields" do
      put "/notification_preferences/#{user_id}", params: {
        notification_preference: { email_enabled: "invalid" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to be_present
    end

    it "allows partial updates" do
      put "/notification_preferences/#{user_id}", params: {
        notification_preference: { marketing_emails: true }
      }

      expect(response).to have_http_status(:ok)
      expect(json["marketing_emails"]).to be true
      expect(json["email_enabled"]).to be true # unchanged
    end
  end
end
