# frozen_string_literal: true

require "rails_helper"

RSpec.describe RetryFailedNotificationsJob, type: :job do
  describe "#perform" do
    let(:user_id) { SecureRandom.uuid }

    before do
      create(:notification_preference, user_id: user_id)
    end

    context "with retryable failed notifications" do
      let!(:failed_notification1) { create(:notification, :failed, retry_count: 0, user_id: user_id) }
      let!(:failed_notification2) { create(:notification, :failed, retry_count: 1, user_id: user_id) }
      let!(:failed_notification3) { create(:notification, :failed, retry_count: 3, user_id: user_id) }

      it "resets retryable notifications to pending" do
        described_class.perform_now

        expect(failed_notification1.reload.status).to eq("pending")
        expect(failed_notification2.reload.status).to eq("pending")
        expect(failed_notification3.reload.status).to eq("failed") # max retries reached
      end

      it "enqueues SendNotificationJob for each retryable notification" do
        expect(SendNotificationJob).to receive(:set).twice.and_return(SendNotificationJob)
        expect(SendNotificationJob).to receive(:perform_later).twice

        described_class.perform_now
      end

      it "uses exponential backoff delays" do
        expect(SendNotificationJob).to receive(:set).with(wait: 5.minutes).and_return(SendNotificationJob)
        expect(SendNotificationJob).to receive(:perform_later).with(failed_notification1.id)

        expect(SendNotificationJob).to receive(:set).with(wait: 15.minutes).and_return(SendNotificationJob)
        expect(SendNotificationJob).to receive(:perform_later).with(failed_notification2.id)

        described_class.perform_now
      end
    end

    context "with no failed notifications" do
      it "completes without errors" do
        expect {
          described_class.perform_now
        }.not_to raise_error
      end
    end
  end

  describe "job configuration" do
    it "queues to low_priority queue" do
      expect(described_class.new.queue_name).to eq("low_priority")
    end
  end
end
