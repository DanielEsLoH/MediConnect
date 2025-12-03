# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupOldNotificationsJob, type: :job do
  describe "#perform" do
    let(:user_id) { SecureRandom.uuid }

    before do
      create_list(:notification, 3, user_id: user_id, created_at: 91.days.ago)
      create_list(:notification, 2, user_id: user_id, created_at: 89.days.ago)
      create_list(:notification, 5, user_id: user_id, created_at: 1.day.ago)
    end

    it "deletes notifications older than 90 days" do
      expect {
        described_class.perform_now
      }.to change(Notification, :count).by(-3)
    end

    it "keeps notifications newer than 90 days" do
      described_class.perform_now

      recent_notifications = Notification.where("created_at > ?", 90.days.ago)
      expect(recent_notifications.count).to eq(7)
    end

    it "returns deleted count" do
      result = described_class.perform_now

      expect(result[:deleted_count]).to eq(3)
      expect(result[:completed_at]).to be_present
    end
  end

  describe "job configuration" do
    it "queues to low_priority queue" do
      expect(described_class.new.queue_name).to eq("low_priority")
    end
  end
end
