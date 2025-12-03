# frozen_string_literal: true

class SendNotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(notification_id)
    notification = Notification.find(notification_id)

    # Skip if already sent or not ready
    return unless notification.should_send?

    # Dispatch notification
    dispatcher = NotificationDispatcher.new(notification)
    dispatcher.dispatch

    Rails.logger.info("SendNotificationJob completed for notification #{notification_id}")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("Notification #{notification_id} not found")
  rescue StandardError => e
    Rails.logger.error("SendNotificationJob failed for notification #{notification_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
