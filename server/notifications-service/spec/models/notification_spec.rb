# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "validations" do
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:notification_type) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:message) }
    it { should validate_presence_of(:delivery_method) }
    it { should validate_presence_of(:status) }

    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(10) }
    it { should validate_numericality_of(:retry_count).is_greater_than_or_equal_to(0) }

    describe "scheduled_for validation" do
      it "allows scheduled_for in the future" do
        notification = build(:notification, scheduled_for: 1.day.from_now)
        expect(notification).to be_valid
      end

      it "does not allow scheduled_for in the past" do
        notification = build(:notification, scheduled_for: 1.day.ago)
        expect(notification).not_to be_valid
        expect(notification.errors[:scheduled_for]).to include("must be in the future")
      end

      it "allows nil scheduled_for" do
        notification = build(:notification, scheduled_for: nil)
        expect(notification).to be_valid
      end
    end
  end

  describe "enums" do
    it do
      should define_enum_for(:notification_type)
        .with_values(
          appointment_created: "appointment_created",
          appointment_confirmed: "appointment_confirmed",
          appointment_reminder: "appointment_reminder",
          appointment_cancelled: "appointment_cancelled",
          appointment_completed: "appointment_completed",
          welcome_email: "welcome_email",
          password_reset: "password_reset",
          payment_received: "payment_received",
          general: "general"
        )
        .backed_by_column_of_type(:string)
    end

    it do
      should define_enum_for(:delivery_method)
        .with_values(
          email: "email",
          sms: "sms",
          push: "push",
          in_app: "in_app"
        )
        .backed_by_column_of_type(:string)
    end

    it do
      should define_enum_for(:status)
        .with_values(
          pending: "pending",
          sent: "sent",
          delivered: "delivered",
          failed: "failed",
          read: "read"
        )
        .backed_by_column_of_type(:string)
    end
  end

  describe "scopes" do
    let(:user_id) { SecureRandom.uuid }
    let(:other_user_id) { SecureRandom.uuid }

    before do
      create(:notification, :email, user_id: user_id, status: :pending)
      create(:notification, :sms, user_id: user_id, status: :sent)
      create(:notification, :push, user_id: other_user_id, status: :delivered)
      create(:notification, :in_app, user_id: user_id, status: :read, read_at: Time.current)
      create(:notification, :email, user_id: user_id, status: :failed)
    end

    describe ".for_user" do
      it "returns notifications for the specified user" do
        notifications = Notification.for_user(user_id)
        expect(notifications.count).to eq(4)
        expect(notifications.pluck(:user_id).uniq).to eq([ user_id ])
      end
    end

    describe ".by_type" do
      it "returns notifications of the specified type" do
        notifications = Notification.by_type(:appointment_created)
        expect(notifications.pluck(:notification_type).uniq).to eq([ "appointment_created" ])
      end
    end

    describe ".by_delivery_method" do
      it "returns notifications with the specified delivery method" do
        notifications = Notification.by_delivery_method(:email)
        expect(notifications.count).to eq(2)
        expect(notifications.pluck(:delivery_method).uniq).to eq([ "email" ])
      end
    end

    describe ".by_status" do
      it "returns notifications with the specified status" do
        notifications = Notification.by_status(:pending)
        expect(notifications.count).to eq(1)
        expect(notifications.first.status).to eq("pending")
      end
    end

    describe ".unread" do
      it "returns unread notifications (excluding failed)" do
        notifications = Notification.unread
        expect(notifications.count).to eq(2) # pending and sent
        expect(notifications.pluck(:status)).to match_array(%w[pending sent])
      end
    end

    describe ".read_notifications" do
      it "returns read notifications" do
        notifications = Notification.read_notifications
        expect(notifications.count).to eq(1)
        expect(notifications.first.status).to eq("read")
      end
    end

    describe ".high_priority" do
      before do
        create(:notification, :high_priority, user_id: user_id)
      end

      it "returns notifications with priority >= 5" do
        notifications = Notification.high_priority
        expect(notifications.count).to be >= 1
        expect(notifications.all? { |n| n.priority >= 5 }).to be true
      end
    end

    describe ".scheduled" do
      before do
        create(:notification, :scheduled, user_id: user_id)
      end

      it "returns scheduled future notifications" do
        notifications = Notification.scheduled
        expect(notifications.count).to eq(1)
        expect(notifications.first.scheduled_for).to be > Time.current
      end
    end

    describe ".ready_for_delivery" do
      before do
        create(:notification, :pending, scheduled_for: nil, user_id: user_id)
        create(:notification, :pending, scheduled_for: 1.minute.ago, user_id: user_id)
        create(:notification, :pending, scheduled_for: 1.hour.from_now, user_id: user_id)
      end

      it "returns pending notifications ready to be sent" do
        notifications = Notification.ready_for_delivery
        expect(notifications.count).to eq(3) # Including the existing pending one
        expect(notifications.all?(&:pending?)).to be true
      end
    end

    describe ".failed_retryable" do
      before do
        create(:notification, :failed, retry_count: 0, user_id: user_id)
        create(:notification, :failed, retry_count: 2, user_id: user_id)
        create(:notification, :failed, retry_count: 3, user_id: user_id)
      end

      it "returns failed notifications that can be retried" do
        notifications = Notification.failed_retryable
        expect(notifications.count).to eq(3) # retry_count < 3
        expect(notifications.all? { |n| n.retry_count < 3 }).to be true
      end
    end

    describe ".old_notifications" do
      before do
        create(:notification, user_id: user_id, created_at: 91.days.ago)
        create(:notification, user_id: user_id, created_at: 89.days.ago)
      end

      it "returns notifications older than 90 days" do
        notifications = Notification.old_notifications
        expect(notifications.count).to eq(1)
      end
    end
  end

  describe "instance methods" do
    describe "#mark_as_read!" do
      let(:notification) { create(:notification, :sent) }

      it "marks notification as read" do
        expect { notification.mark_as_read! }
          .to change { notification.reload.status }.from("sent").to("read")
          .and change { notification.reload.read_at }.from(nil)
      end

      it "returns false if already read" do
        notification.update(status: :read, read_at: Time.current)
        expect(notification.mark_as_read!).to be false
      end
    end

    describe "#mark_as_sent!" do
      let(:notification) { create(:notification, :pending) }

      it "marks notification as sent" do
        expect { notification.mark_as_sent! }
          .to change { notification.reload.status }.from("pending").to("sent")
          .and change { notification.reload.sent_at }.from(nil)
      end
    end

    describe "#mark_as_delivered!" do
      let(:notification) { create(:notification, :sent) }

      it "marks notification as delivered" do
        expect { notification.mark_as_delivered! }
          .to change { notification.reload.status }.from("sent").to("delivered")
          .and change { notification.reload.delivered_at }.from(nil)
      end
    end

    describe "#mark_as_failed!" do
      let(:notification) { create(:notification, :pending) }

      it "marks notification as failed with error message" do
        expect { notification.mark_as_failed!("Test error") }
          .to change { notification.reload.status }.from("pending").to("failed")
          .and change { notification.reload.error_message }.from(nil).to("Test error")
          .and change { notification.reload.retry_count }.by(1)
      end
    end

    describe "#can_retry?" do
      it "returns true when retry_count < 3" do
        notification = create(:notification, retry_count: 2)
        expect(notification.can_retry?).to be true
      end

      it "returns false when retry_count >= 3" do
        notification = create(:notification, retry_count: 3)
        expect(notification.can_retry?).to be false
      end
    end

    describe "#retry_delay" do
      it "returns exponentially increasing delay" do
        notification = create(:notification, retry_count: 0)
        expect(notification.retry_delay).to eq(5.minutes)

        notification.update(retry_count: 1)
        expect(notification.retry_delay).to eq(15.minutes)

        notification.update(retry_count: 2)
        expect(notification.retry_delay).to eq(45.minutes)
      end
    end

    describe "#unread?" do
      it "returns true for unread notification" do
        notification = create(:notification, :sent, read_at: nil)
        expect(notification.unread?).to be true
      end

      it "returns false for read notification" do
        notification = create(:notification, :read)
        expect(notification.unread?).to be false
      end

      it "returns false for failed notification" do
        notification = create(:notification, :failed)
        expect(notification.unread?).to be false
      end
    end

    describe "#should_send?" do
      it "returns true for pending notification without schedule" do
        notification = create(:notification, :pending, scheduled_for: nil)
        expect(notification.should_send?).to be true
      end

      it "returns true for scheduled notification that is ready" do
        notification = create(:notification, :pending, scheduled_for: 1.minute.ago)
        expect(notification.should_send?).to be true
      end

      it "returns false for scheduled notification in the future" do
        notification = create(:notification, :pending, scheduled_for: 1.hour.from_now)
        expect(notification.should_send?).to be false
      end

      it "returns false for non-pending notification" do
        notification = create(:notification, :sent)
        expect(notification.should_send?).to be false
      end
    end
  end

  describe "callbacks" do
    describe "after_create" do
      it "enqueues SendNotificationJob for pending notification" do
        expect(SendNotificationJob).to receive(:perform_later)
        create(:notification, :pending, scheduled_for: nil)
      end

      it "does not enqueue job for scheduled notification" do
        expect(SendNotificationJob).not_to receive(:perform_later)
        create(:notification, :pending, :scheduled)
      end
    end
  end
end
