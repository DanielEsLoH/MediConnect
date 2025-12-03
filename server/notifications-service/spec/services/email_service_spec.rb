# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailService do
  let(:notification) { create(:notification, :email, :appointment_created) }
  let(:service) { described_class.new(notification) }

  describe "#send_email" do
    context "when email is present" do
      before do
        notification.data["user_email"] = "test@example.com"
        notification.data["user_name"] = "John Doe"
      end

      it "builds and delivers email" do
        mail = instance_double(ActionMailer::MessageDelivery)
        allow(NotificationMailer).to receive_message_chain(:with, :appointment_confirmation).and_return(mail)
        allow(mail).to receive(:deliver_now)

        result = service.send_email

        expect(result[:success]).to be true
        expect(mail).to have_received(:deliver_now)
      end

      it "uses correct email template for appointment_created" do
        notification.update(notification_type: :appointment_created)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(
            to: "test@example.com",
            subject: notification.title
          )
        ).and_return(double(appointment_confirmation: double(deliver_now: true)))

        service.send_email
      end

      it "uses correct email template for welcome_email" do
        notification.update(notification_type: :welcome_email)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(welcome_email: double(deliver_now: true)))

        service.send_email
      end

      it "uses correct email template for password_reset" do
        notification.update(notification_type: :password_reset)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(password_reset: double(deliver_now: true)))

        service.send_email
      end
    end

    context "when email is missing" do
      before do
        notification.data.delete("user_email")
        notification.data.delete("email")
      end

      it "returns failure" do
        result = service.send_email
        expect(result[:success]).to be false
        expect(result[:error]).to eq("No user email provided")
      end
    end

    context "when delivery fails" do
      before do
        notification.data["user_email"] = "test@example.com"
        allow(NotificationMailer).to receive_message_chain(:with, :appointment_confirmation)
          .and_raise(StandardError, "SMTP error")
      end

      it "returns failure with error message" do
        result = service.send_email
        expect(result[:success]).to be false
        expect(result[:error]).to eq("SMTP error")
      end
    end
  end
end
