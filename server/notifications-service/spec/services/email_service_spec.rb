# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailService do
  let(:notification) { create(:notification, :email, :appointment_created) }
  let(:service) { described_class.new(notification) }

  describe "#send_email" do
    context "when email is present in notification data" do
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

      it "uses correct email template for appointment_confirmed" do
        notification.update(notification_type: :appointment_confirmed)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
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

      it "uses correct email template for appointment_reminder" do
        notification.update(notification_type: :appointment_reminder)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(appointment_reminder: double(deliver_now: true)))

        service.send_email
      end

      it "uses correct email template for appointment_cancelled" do
        notification.update(notification_type: :appointment_cancelled)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(appointment_cancellation: double(deliver_now: true)))

        service.send_email
      end

      it "uses correct email template for appointment_completed" do
        notification.update(notification_type: :appointment_completed)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(appointment_completed: double(deliver_now: true)))

        service.send_email
      end

      it "uses correct email template for payment_received" do
        notification.update(notification_type: :payment_received)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(payment_receipt: double(deliver_now: true)))

        service.send_email
      end

      it "uses general_notification template for unknown types" do
        notification.update(notification_type: :general)
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "test@example.com")
        ).and_return(double(general_notification: double(deliver_now: true)))

        service.send_email
      end
    end

    context "when email is present in alternative field" do
      before do
        notification.data.delete("user_email")
        notification.data["email"] = "alternative@example.com"
      end

      it "uses the email field" do
        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "alternative@example.com")
        ).and_return(double(appointment_confirmation: double(deliver_now: true)))

        service.send_email
      end
    end

    context "when email is missing but user data can be fetched" do
      before do
        notification.data.delete("user_email")
        notification.data.delete("email")
        allow(UserLookupService).to receive(:contact_info).and_return({
          email: "fetched@example.com",
          full_name: "Fetched User"
        })
      end

      it "fetches user data from UserLookupService" do
        expect(UserLookupService).to receive(:contact_info).with(notification.user_id)

        expect(NotificationMailer).to receive(:with).with(
          hash_including(to: "fetched@example.com")
        ).and_return(double(appointment_confirmation: double(deliver_now: true)))

        service.send_email
      end
    end

    context "when email is missing and user data fetch fails" do
      before do
        notification.data.delete("user_email")
        notification.data.delete("email")
        allow(UserLookupService).to receive(:contact_info).and_raise(
          UserLookupService::ServiceUnavailable.new("Service down")
        )
      end

      it "returns failure" do
        result = service.send_email
        expect(result[:success]).to be false
        expect(result[:error]).to eq("No user email provided")
      end
    end

    context "when email is missing and user lookup returns nil" do
      before do
        notification.data.delete("user_email")
        notification.data.delete("email")
        allow(UserLookupService).to receive(:contact_info).and_return(nil)
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

  describe "user_name resolution" do
    before do
      notification.data["user_email"] = "test@example.com"
      notification.data.delete("user_name")
      notification.data.delete("name")
    end

    context "when user_name is in notification data" do
      before do
        notification.data["user_name"] = "Direct Name"
      end

      it "uses the provided user_name" do
        expect(NotificationMailer).to receive(:with).with(
          hash_including(user_name: "Direct Name")
        ).and_return(double(appointment_confirmation: double(deliver_now: true)))

        service.send_email
      end
    end

    context "when name is in notification data" do
      before do
        notification.data["name"] = "Alternative Name"
      end

      it "uses the name field" do
        expect(NotificationMailer).to receive(:with).with(
          hash_including(user_name: "Alternative Name")
        ).and_return(double(appointment_confirmation: double(deliver_now: true)))

        service.send_email
      end
    end

    context "when no name is provided" do
      it "falls back to User" do
        expect(NotificationMailer).to receive(:with).with(
          hash_including(user_name: "User")
        ).and_return(double(appointment_confirmation: double(deliver_now: true)))

        service.send_email
      end
    end
  end
end
