# frozen_string_literal: true

class PushNotificationService
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def send_push
    # Validate push token exists
    return { success: false, error: "No push token provided" } unless push_token.present?

    # In production, this would integrate with Expo Push Notifications or FCM
    # For now, we'll stub the implementation
    send_via_expo
  rescue StandardError => e
    Rails.logger.error("Push notification send error for notification #{notification.id}: #{e.message}")
    { success: false, error: e.message }
  end

  private

  def push_token
    notification.data["push_token"] || notification.data["device_token"]
  end

  def send_via_expo
    # Stub implementation
    # In production, this would use Expo Push Notification API:
    # expo = Exponent::Push::Client.new
    # messages = [{
    #   to: push_token,
    #   title: notification.title,
    #   body: notification.message,
    #   data: notification.data,
    #   priority: notification.priority >= 5 ? 'high' : 'normal',
    #   sound: 'default',
    #   badge: unread_count
    # }]
    # expo.send_messages(messages)

    Rails.logger.info("Push notification would be sent to #{push_token}: #{notification.title}")

    # Simulate success in development/test
    if Rails.env.development? || Rails.env.test?
      { success: true, provider_id: "stub_#{SecureRandom.hex(8)}" }
    else
      { success: false, error: "Expo Push Notifications not configured" }
    end
  end

  def unread_count
    Notification.where(user_id: notification.user_id).unread.count
  end
end
