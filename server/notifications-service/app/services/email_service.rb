# frozen_string_literal: true

# Service for sending email notifications
# Fetches user data from Users Service via HttpClient
#
# @example
#   EmailService.new(notification).send_email
#
class EmailService
  attr_reader :notification

  def initialize(notification)
    @notification = notification
    @user_data = nil
  end

  def send_email
    # Fetch user data from Users Service if not in notification data
    fetch_user_data_if_needed

    # Validate email can be sent
    return { success: false, error: "No user email provided" } unless user_email.present?

    # Build email
    mail = build_email

    # Send email
    mail.deliver_now

    Rails.logger.info(
      "[EmailService] Email sent successfully " \
      "notification_id=#{notification.id} to=#{user_email}"
    )

    { success: true }
  rescue StandardError => e
    Rails.logger.error(
      "[EmailService] Email send error notification_id=#{notification.id}: #{e.message}"
    )
    { success: false, error: e.message }
  end

  private

  def fetch_user_data_if_needed
    # If we already have email in notification data, skip fetching
    return if notification.data["user_email"].present? || notification.data["email"].present?

    # Fetch from Users Service
    @user_data = UserLookupService.contact_info(notification.user_id)

    unless @user_data
      Rails.logger.warn(
        "[EmailService] Could not fetch user data from Users Service " \
        "user_id=#{notification.user_id}"
      )
    end
  rescue UserLookupService::ServiceUnavailable => e
    Rails.logger.error(
      "[EmailService] Users Service unavailable, falling back to notification data: #{e.message}"
    )
  end

  def user_email
    # Priority: notification data > fetched user data
    notification.data["user_email"] ||
      notification.data["email"] ||
      @user_data&.dig(:email)
  end

  def user_name
    notification.data["user_name"] ||
      notification.data["name"] ||
      @user_data&.dig(:full_name) ||
      build_full_name ||
      "User"
  end

  def build_full_name
    first = @user_data&.dig(:first_name)
    last = @user_data&.dig(:last_name)
    return nil unless first || last

    [ first, last ].compact.join(" ")
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
