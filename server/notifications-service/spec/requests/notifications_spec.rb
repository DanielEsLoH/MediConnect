# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notifications API", type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:json) { JSON.parse(response.body) }

  describe "GET /notifications" do
    before do
      create_list(:notification, 5, user_id: user_id)
      create_list(:notification, 3, user_id: SecureRandom.uuid)
    end

    it "returns notifications for specified user" do
      get "/notifications", params: { user_id: user_id }

      expect(response).to have_http_status(:ok)
      expect(json["notifications"].count).to eq(5)
      expect(json["meta"]["total_count"]).to eq(5)
    end

    it "supports pagination" do
      get "/notifications", params: { user_id: user_id, per_page: 2, page: 1 }

      expect(response).to have_http_status(:ok)
      expect(json["notifications"].count).to eq(2)
      expect(json["meta"]["current_page"]).to eq(1)
      expect(json["meta"]["total_pages"]).to eq(3)
    end

    it "filters by notification type" do
      create(:notification, :appointment_reminder, user_id: user_id)
      get "/notifications", params: { user_id: user_id, notification_type: "appointment_reminder" }

      expect(response).to have_http_status(:ok)
      expect(json["notifications"].count).to eq(1)
      expect(json["notifications"].first["notification_type"]).to eq("appointment_reminder")
    end

    it "filters by status" do
      create(:notification, :sent, user_id: user_id)
      create(:notification, :failed, user_id: user_id)

      get "/notifications", params: { user_id: user_id, status: "sent" }

      expect(response).to have_http_status(:ok)
      expect(json["notifications"].all? { |n| n["status"] == "sent" }).to be true
    end

    it "returns notifications in descending order by created_at" do
      get "/notifications", params: { user_id: user_id }

      timestamps = json["notifications"].map { |n| Time.parse(n["created_at"]) }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end

  describe "GET /notifications/unread_count" do
    before do
      create_list(:notification, 3, :pending, user_id: user_id)
      create_list(:notification, 2, :read, user_id: user_id)
      create(:notification, :failed, user_id: user_id)
    end

    it "returns count of unread notifications" do
      get "/notifications/unread_count", params: { user_id: user_id }

      expect(response).to have_http_status(:ok)
      expect(json["unread_count"]).to eq(3)
    end

    it "requires user_id parameter" do
      get "/notifications/unread_count"

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("user_id is required")
    end
  end

  describe "GET /notifications/:id" do
    let(:notification) { create(:notification, user_id: user_id) }

    it "returns the notification" do
      get "/notifications/#{notification.id}"

      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(notification.id)
      expect(json["title"]).to eq(notification.title)
    end

    it "returns 404 for non-existent notification" do
      get "/notifications/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("Notification not found")
    end
  end

  describe "POST /notifications/:id/mark_as_read" do
    let(:notification) { create(:notification, :sent, user_id: user_id) }

    it "marks notification as read" do
      expect {
        post "/notifications/#{notification.id}/mark_as_read"
      }.to change { notification.reload.status }.from("sent").to("read")

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("read")
      expect(json["read_at"]).to be_present
    end

    it "returns error if already read" do
      notification.mark_as_read!

      post "/notifications/#{notification.id}/mark_as_read"

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /notifications/mark_all_as_read" do
    before do
      create_list(:notification, 5, :sent, user_id: user_id)
      create_list(:notification, 2, :read, user_id: user_id)
    end

    it "marks all unread notifications as read" do
      expect {
        post "/notifications/mark_all_as_read", params: { user_id: user_id }
      }.to change { Notification.for_user(user_id).unread.count }.from(5).to(0)

      expect(response).to have_http_status(:ok)
      expect(json["marked_count"]).to eq(5)
      expect(json["message"]).to include("5 notifications marked as read")
    end

    it "requires user_id parameter" do
      post "/notifications/mark_all_as_read"

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("user_id is required")
    end
  end

  describe "DELETE /notifications/:id" do
    let(:notification) { create(:notification, user_id: user_id) }

    it "deletes the notification" do
      delete "/notifications/#{notification.id}"

      expect(response).to have_http_status(:no_content)
      expect(Notification.find_by(id: notification.id)).to be_nil
    end

    it "returns 404 for non-existent notification" do
      delete "/notifications/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /notifications" do
    let(:valid_params) do
      {
        notification: {
          user_id: user_id,
          notification_type: "general",
          title: "Test Notification",
          message: "This is a test",
          delivery_method: "email",
          priority: 5,
          data: { user_email: "test@example.com" }
        }
      }
    end

    it "creates a new notification" do
      expect {
        post "/notifications", params: valid_params
      }.to change(Notification, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["title"]).to eq("Test Notification")
    end

    it "validates required fields" do
      post "/notifications", params: { notification: { user_id: user_id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to be_present
    end

    it "enqueues SendNotificationJob" do
      expect(SendNotificationJob).to receive(:perform_later)
      post "/notifications", params: valid_params
    end
  end
end
