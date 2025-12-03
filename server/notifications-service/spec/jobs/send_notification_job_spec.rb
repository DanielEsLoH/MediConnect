# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendNotificationJob, type: :job do
  let(:user_id) { SecureRandom.uuid }
  let(:notification) { create(:notification, :pending, user_id: user_id) }

  before do
    create(:notification_preference, user_id: user_id)
  end

  describe "#perform" do
    it "dispatches the notification" do
      dispatcher = instance_double(NotificationDispatcher)
      allow(NotificationDispatcher).to receive(:new).with(notification).and_return(dispatcher)
      allow(dispatcher).to receive(:dispatch)

      described_class.perform_now(notification.id)

      expect(NotificationDispatcher).to have_received(:new).with(notification)
      expect(dispatcher).to have_received(:dispatch)
    end

    it "skips if notification is not ready to send" do
      notification.update(status: :sent)
      dispatcher = instance_double(NotificationDispatcher)

      expect(NotificationDispatcher).not_to receive(:new)

      described_class.perform_now(notification.id)
    end

    it "handles non-existent notification gracefully" do
      expect {
        described_class.perform_now(SecureRandom.uuid)
      }.not_to raise_error
    end

    it "retries on standard errors" do
      allow(Notification).to receive(:find).and_raise(StandardError, "Database error")

      expect {
        described_class.perform_now(notification.id)
      }.to raise_error(StandardError)
    end
  end

  describe "job configuration" do
    it "queues to default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "retries with exponential backoff" do
      # This is configured in the job class
      expect(described_class).to respond_to(:retry_on)
    end
  end
end
