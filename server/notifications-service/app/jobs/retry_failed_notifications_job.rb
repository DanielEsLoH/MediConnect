# frozen_string_literal: true

class RetryFailedNotificationsJob < ApplicationJob
  queue_as :low_priority

  def perform
    notifications = Notification.failed_retryable

    Rails.logger.info("Retrying #{notifications.count} failed notifications")

    notifications.find_each do |notification|
      # Reset to pending status for retry
      notification.update(status: :pending)

      # Enqueue for delivery with exponential backoff
      SendNotificationJob.set(wait: notification.retry_delay).perform_later(notification.id)
    end

    Rails.logger.info("Scheduled #{notifications.count} notifications for retry")
  end
end
