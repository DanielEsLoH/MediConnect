# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessScheduledNotificationsJob, type: :job do
  describe "#perform" do
    let(:user_id) { SecureRandom.uuid }

    before do
      create(:notification_preference, user_id: user_id)
    end

    context "with scheduled notifications ready to send" do
      let!(:ready_notification1) { create(:notification, :pending, scheduled_for: 1.minute.ago, user_id: user_id) }
      let!(:ready_notification2) { create(:notification, :pending, scheduled_for: 5.minutes.ago, user_id: user_id) }
      let!(:future_notification) { create(:notification, :pending, scheduled_for: 1.hour.from_now, user_id: user_id) }

      it "enqueues SendNotificationJob for ready notifications" do
        expect(SendNotificationJob).to receive(:perform_later).with(ready_notification1.id)
        expect(SendNotificationJob).to receive(:perform_later).with(ready_notification2.id)
        expect(SendNotificationJob).not_to receive(:perform_later).with(future_notification.id)

        described_class.perform_now
      end

      it "returns processed count" do
        allow(SendNotificationJob).to receive(:perform_later)

        result = described_class.perform_now

        expect(result[:processed_count]).to eq(2)
        expect(result[:completed_at]).to be_present
      end
    end

    context "with no scheduled notifications ready" do
      before do
        create_list(:notification, 3, :pending, scheduled_for: 1.hour.from_now, user_id: user_id)
      end

      it "does not enqueue any jobs" do
        expect(SendNotificationJob).not_to receive(:perform_later)

        described_class.perform_now
      end

      it "returns zero processed count" do
        result = described_class.perform_now

        expect(result[:processed_count]).to eq(0)
      end
    end

    context "with immediate notifications (no schedule)" do
      before do
        create_list(:notification, 2, :pending, scheduled_for: nil, user_id: user_id)
      end

      it "does not process immediate notifications" do
        expect(SendNotificationJob).not_to receive(:perform_later)

        described_class.perform_now
      end
    end
  end

  describe "job configuration" do
    it "queues to default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
