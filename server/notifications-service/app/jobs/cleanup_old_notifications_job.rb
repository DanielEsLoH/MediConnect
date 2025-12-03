# frozen_string_literal: true

class CleanupOldNotificationsJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Delete notifications older than 90 days
    deleted_count = Notification.old_notifications.delete_all

    Rails.logger.info("CleanupOldNotificationsJob: Deleted #{deleted_count} old notifications")

    {
      deleted_count: deleted_count,
      completed_at: Time.current
    }
  end
end
