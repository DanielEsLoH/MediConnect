# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::NotificationsController", type: :request do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("JWT_SECRET").and_return("test_secret_key")
    allow(ENV).to receive(:fetch).with("JWT_SECRET", anything).and_return("test_secret_key")

    # Default stub for notifications service
    stub_request(:any, %r{http://notifications-service:3004/})
      .to_return(
        status: 200,
        body: { notifications: [], notification: {} }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  let(:notifications_list) do
    [
      { id: 1, user_id: 1, title: "Appointment Reminder", read: false },
      { id: 2, user_id: 1, title: "Payment Confirmed", read: true }
    ]
  end

  describe "GET /api/v1/notifications" do
    let(:index_path) { "/api/v1/notifications" }

    context "as authenticated user" do
      before do
        stub_request(:get, /notifications-service:3004.*notifications/)
          .to_return(
            status: 200,
            body: { notifications: notifications_list, meta: { total: 2 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns list of notifications" do
        get index_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end

      it "proxies the request to notifications service" do
        get index_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(a_request(:get, /notifications-service:3004/)).to have_been_made
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get index_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/notifications/:id" do
    context "with valid notification id" do
      before do
        stub_request(:get, /notifications-service:3004.*notifications\/1/)
          .to_return(
            status: 200,
            body: { id: 1, title: "Appointment Reminder", read: false }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns notification details" do
        get "/api/v1/notifications/1", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when notification not found" do
      before do
        stub_request(:get, /notifications-service:3004.*notifications\/999/)
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns 404 not found" do
        get "/api/v1/notifications/999", headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/notifications/1"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/notifications/:id" do
    let(:update_path) { "/api/v1/notifications/1" }

    context "marking notification as read" do
      before do
        stub_request(:post, /notifications-service:3004.*notifications\/1\/mark_as_read/)
          .to_return(
            status: 200,
            body: { id: 1, read: true }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "marks the notification as read" do
        patch update_path, headers: auth_headers(user_id: 1, role: "patient")
        expect(response).to have_http_status(:ok)
      end
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        patch update_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/notifications/unread_count" do
    before do
      stub_request(:get, /notifications-service:3004.*unread_count/)
        .to_return(
          status: 200,
          body: { count: 5 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns unread notification count" do
      get "/api/v1/notifications/unread_count", headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        get "/api/v1/notifications/unread_count"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/notifications/mark_all_read" do
    before do
      stub_request(:post, /notifications-service:3004.*mark_all_as_read/)
        .to_return(
          status: 200,
          body: { message: "All notifications marked as read" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "marks all notifications as read" do
      post "/api/v1/notifications/mark_all_read", headers: auth_headers(user_id: 1, role: "patient")
      expect(response).to have_http_status(:ok)
    end

    context "without authentication" do
      it "returns 401 unauthorized" do
        post "/api/v1/notifications/mark_all_read"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
