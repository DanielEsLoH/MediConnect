# frozen_string_literal: true

require "rails_helper"

RSpec.describe SmsService do
  let(:notification) { create(:notification, :sms) }
  let(:service) { described_class.new(notification) }

  describe "#send_sms" do
    context "when phone number is present and valid" do
      before do
        notification.data["phone_number"] = "+1234567890"
      end

      it "returns success in development/test" do
        result = service.send_sms
        expect(result[:success]).to be true
        expect(result[:provider_id]).to be_present
      end
    end

    context "when phone number is missing" do
      before do
        notification.data.delete("phone_number")
        notification.data.delete("phone")
      end

      it "returns failure" do
        result = service.send_sms
        expect(result[:success]).to be false
        expect(result[:error]).to eq("No phone number provided")
      end
    end

    context "when phone number is invalid" do
      before do
        notification.data["phone_number"] = "invalid"
      end

      it "returns failure" do
        result = service.send_sms
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid phone number format")
      end
    end

    context "when phone number format is valid" do
      it "accepts E.164 format" do
        notification.data["phone_number"] = "+12345678901"
        result = service.send_sms
        expect(result[:success]).to be true
      end

      it "rejects missing + prefix" do
        notification.data["phone_number"] = "12345678901"
        result = service.send_sms
        expect(result[:success]).to be false
      end

      it "rejects too short numbers" do
        notification.data["phone_number"] = "+123456"
        result = service.send_sms
        expect(result[:success]).to be false
      end

      it "rejects too long numbers" do
        notification.data["phone_number"] = "+1234567890123456"
        result = service.send_sms
        expect(result[:success]).to be false
      end
    end
  end
end
