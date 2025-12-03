# frozen_string_literal: true

class NotificationDispatcher
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def dispatch
    return false unless notification.should_send?
    return false unless check_user_preferences

    result = send_via_delivery_method

    if result[:success]
      notification.mark_as_sent!
      Rails.logger.info("Notification #{notification.id} sent successfully via #{notification.delivery_method}")
      true
    else
      notification.mark_as_failed!(result[:error])
      Rails.logger.error("Notification #{notification.id} failed: #{result[:error]}")
      false
    end
  rescue StandardError => e
    notification.mark_as_failed!(e.message)
    Rails.logger.error("Notification #{notification.id} dispatch error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    false
  end

  private

  def check_user_preferences
    preference = NotificationPreference.for_user(notification.user_id)

    unless preference.should_send_notification?(notification.notification_type, notification.delivery_method)
      notification.update(
        status: :failed,
        error_message: "User has disabled this notification type or delivery method"
      )
      Rails.logger.info("Notification #{notification.id} blocked by user preferences")
      return false
    end

    true
  end

  def send_via_delivery_method
    case notification.delivery_method
    when "email"
      EmailService.new(notification).send_email
    when "sms"
      SmsService.new(notification).send_sms
    when "push"
      PushNotificationService.new(notification).send_push
    when "in_app"
      # In-app notifications are stored in DB and retrieved by frontend
      { success: true }
    else
      { success: false, error: "Unknown delivery method: #{notification.delivery_method}" }
    end
  end
end
