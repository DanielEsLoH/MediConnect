# frozen_string_literal: true

class EmailService
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def send_email
    # Validate email can be sent
    return { success: false, error: "No user email provided" } unless user_email.present?

    # Build email
    mail = build_email

    # Send email
    mail.deliver_now

    { success: true }
  rescue StandardError => e
    Rails.logger.error("Email send error for notification #{notification.id}: #{e.message}")
    { success: false, error: e.message }
  end

  private

  def user_email
    # In production, this would fetch from Users Service API
    # For now, we'll use the data field if present
    notification.data["user_email"] || notification.data["email"]
  end

  def user_name
    notification.data["user_name"] || notification.data["name"] || "User"
  end

  def build_email
    NotificationMailer.with(
      to: user_email,
      subject: notification.title,
      notification: notification,
      user_name: user_name
    ).send(email_template)
  end

  def email_template
    case notification.notification_type
    when "welcome_email"
      :welcome_email
    when "appointment_created", "appointment_confirmed"
      :appointment_confirmation
    when "appointment_reminder"
      :appointment_reminder
    when "appointment_cancelled"
      :appointment_cancellation
    when "appointment_completed"
      :appointment_completed
    when "password_reset"
      :password_reset
    when "payment_received"
      :payment_receipt
    else
      :general_notification
    end
  end
end
