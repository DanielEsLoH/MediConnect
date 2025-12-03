# frozen_string_literal: true

class ProcessScheduledNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    # Find all scheduled notifications that are ready to be sent
    notifications = Notification.ready_for_delivery.where.not(scheduled_for: nil)

    Rails.logger.info("Processing #{notifications.count} scheduled notifications")

    notifications.find_each do |notification|
      SendNotificationJob.perform_later(notification.id)
    end

    Rails.logger.info("Enqueued #{notifications.count} scheduled notifications")

    {
      processed_count: notifications.count,
      completed_at: Time.current
    }
  end
end
