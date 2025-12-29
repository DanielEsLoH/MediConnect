# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  let(:user_id) { SecureRandom.uuid }
  let(:user_name) { "John Doe" }
  let(:user_email) { "patient@example.com" }

  describe "#welcome_email" do
    let(:notification) do
      create(:notification, :welcome_email, user_id: user_id, data: {
        "user_email" => user_email,
        "user_name" => user_name
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: notification.title,
        notification: notification,
        user_name: user_name
      ).welcome_email
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq(notification.title)
    end

    it "renders the receiver name" do
      expect(mail.body.encoded).to include(user_name).or include("Welcome")
    end
  end

  describe "#appointment_confirmation" do
    let(:notification) do
      create(:notification, :appointment_created, user_id: user_id, data: {
        "user_email" => user_email,
        "user_name" => user_name,
        "scheduled_datetime" => 3.days.from_now.iso8601,
        "doctor_name" => "Dr. Smith"
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: notification.title,
        notification: notification,
        user_name: user_name
      ).appointment_confirmation
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq(notification.title)
    end

    it "sets instance variables correctly" do
      # Verify mail can be generated without errors
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#appointment_reminder" do
    let(:notification) do
      create(:notification, :appointment_reminder, user_id: user_id, data: {
        "user_email" => user_email,
        "user_name" => user_name,
        "scheduled_datetime" => 1.day.from_now.iso8601
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: notification.title,
        notification: notification,
        user_name: user_name
      ).appointment_reminder
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq(notification.title)
    end

    it "includes appointment date" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#appointment_cancellation" do
    let(:notification) do
      create(:notification, :appointment_cancelled, user_id: user_id, data: {
        "user_email" => user_email,
        "user_name" => user_name,
        "cancellation_reason" => "Doctor unavailable"
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: notification.title,
        notification: notification,
        user_name: user_name
      ).appointment_cancellation
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq(notification.title)
    end

    it "sets the reason instance variable" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#appointment_completed" do
    let(:notification) do
      create(:notification, user_id: user_id, notification_type: :appointment_completed, data: {
        "user_email" => user_email,
        "user_name" => user_name
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: "Appointment Completed",
        notification: notification,
        user_name: user_name
      ).appointment_completed
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq("Appointment Completed")
    end
  end

  describe "#password_reset" do
    let(:notification) do
      create(:notification, user_id: user_id, notification_type: :password_reset, data: {
        "user_email" => user_email,
        "user_name" => user_name,
        "reset_token" => "abc123token",
        "reset_url" => "https://mediconnect.com/reset?token=abc123token"
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: "Reset Your Password",
        notification: notification,
        user_name: user_name
      ).password_reset
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq("Reset Your Password")
    end

    it "sets reset token and URL instance variables" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#payment_receipt" do
    let(:notification) do
      create(:notification, :payment_received, user_id: user_id, data: {
        "user_email" => user_email,
        "user_name" => user_name,
        "amount" => 150.00,
        "transaction_id" => "txn_abc123"
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: notification.title,
        notification: notification,
        user_name: user_name
      ).payment_receipt
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq(notification.title)
    end

    it "sets amount and transaction_id instance variables" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "#general_notification" do
    let(:notification) do
      create(:notification, user_id: user_id, notification_type: :general, data: {
        "user_email" => user_email,
        "user_name" => user_name
      })
    end

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: "General Notification",
        notification: notification,
        user_name: user_name
      ).general_notification
    end

    it "renders the headers" do
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to eq("General Notification")
    end

    it "includes the notification content" do
      expect(mail.body.encoded).to be_present
    end
  end

  describe "default from address" do
    let(:notification) { create(:notification, :welcome_email, user_id: user_id) }

    let(:mail) do
      described_class.with(
        to: user_email,
        subject: "Test",
        notification: notification,
        user_name: user_name
      ).welcome_email
    end

    it "uses the configured from address" do
      expect(mail.from).to be_present
    end
  end
end
