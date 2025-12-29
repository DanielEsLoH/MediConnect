# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushNotificationService do
  let(:notification) { create(:notification, :push) }
  let(:service) { described_class.new(notification) }

  describe "#send_push" do
    context "when push token is present" do
      before do
        notification.data["push_token"] = "ExponentPushToken[abc123]"
      end

      it "returns success in development/test" do
        result = service.send_push
        expect(result[:success]).to be true
        expect(result[:provider_id]).to be_present
      end

      it "logs the push notification" do
        expect(Rails.logger).to receive(:info).with(/Push notification would be sent/)

        service.send_push
      end
    end

    context "when push token is missing" do
      before do
        notification.data.delete("push_token")
        notification.data.delete("device_token")
      end

      it "returns failure" do
        result = service.send_push
        expect(result[:success]).to be false
        expect(result[:error]).to eq("No push token provided")
      end
    end

    context "when using device_token field" do
      before do
        notification.data.delete("push_token")
        notification.data["device_token"] = "fcm_token_123"
      end

      it "accepts device_token as alias" do
        result = service.send_push
        expect(result[:success]).to be true
      end
    end

    context "when an error occurs during send" do
      before do
        notification.data["push_token"] = "ExponentPushToken[abc123]"
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info).and_raise(StandardError.new("Push error"))
      end

      it "catches the error and returns failure" do
        result = service.send_push
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Push error")
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Push notification send error/)

        service.send_push
      end
    end
  end
end
