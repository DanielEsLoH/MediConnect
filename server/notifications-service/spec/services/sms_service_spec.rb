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

    context "when phone number is in alternative field" do
      before do
        notification.data.delete("phone_number")
        notification.data["phone"] = "+12345678901"
      end

      it "uses the phone field" do
        result = service.send_sms
        expect(result[:success]).to be true
      end
    end

    context "when phone number is missing but user data can be fetched" do
      before do
        notification.data.delete("phone_number")
        notification.data.delete("phone")
        allow(UserLookupService).to receive(:contact_info).and_return({
          phone_number: "+12345678901"
        })
      end

      it "fetches user data from UserLookupService" do
        expect(UserLookupService).to receive(:contact_info).with(notification.user_id)

        result = service.send_sms
        expect(result[:success]).to be true
      end
    end

    context "when phone number is missing and user data fetch fails" do
      before do
        notification.data.delete("phone_number")
        notification.data.delete("phone")
        allow(UserLookupService).to receive(:contact_info).and_raise(
          UserLookupService::ServiceUnavailable.new("Service down")
        )
      end

      it "returns failure" do
        result = service.send_sms
        expect(result[:success]).to be false
        expect(result[:error]).to eq("No phone number provided")
      end
    end

    context "when phone number is missing and user lookup returns nil" do
      before do
        notification.data.delete("phone_number")
        notification.data.delete("phone")
        allow(UserLookupService).to receive(:contact_info).and_return(nil)
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

    context "when an error occurs during send" do
      before do
        notification.data["phone_number"] = "+12345678901"
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info).and_raise(StandardError.new("Unexpected error"))
      end

      it "catches the error and returns failure" do
        result = service.send_sms
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Unexpected error")
      end
    end
  end
end
