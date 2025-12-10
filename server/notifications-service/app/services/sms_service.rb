# frozen_string_literal: true

# Service for sending SMS notifications
# Fetches user phone data from Users Service via HttpClient
#
# @example
#   SmsService.new(notification).send_sms
#
class SmsService
  attr_reader :notification

  def initialize(notification)
    @notification = notification
    @user_data = nil
  end

  def send_sms
    # Fetch user data from Users Service if not in notification data
    fetch_user_data_if_needed

    # Validate phone number
    return { success: false, error: "No phone number provided" } unless phone_number.present?
    return { success: false, error: "Invalid phone number format" } unless valid_phone_number?

    # In production, this would integrate with Twilio
    send_via_twilio
  rescue StandardError => e
    Rails.logger.error(
      "[SmsService] SMS send error notification_id=#{notification.id}: #{e.message}"
    )
    { success: false, error: e.message }
  end

  private

  def fetch_user_data_if_needed
    # If we already have phone in notification data, skip fetching
    return if notification.data["phone_number"].present? || notification.data["phone"].present?

    # Fetch from Users Service
    @user_data = UserLookupService.contact_info(notification.user_id)

    if @user_data
      Rails.logger.debug(
        "[SmsService] Fetched user data from Users Service " \
        "user_id=#{notification.user_id}"
      )
    else
      Rails.logger.warn(
        "[SmsService] Could not fetch user data from Users Service " \
        "user_id=#{notification.user_id}"
      )
    end
  rescue UserLookupService::ServiceUnavailable => e
    Rails.logger.error(
      "[SmsService] Users Service unavailable, falling back to notification data: #{e.message}"
    )
  end

  def phone_number
    # Priority: notification data > fetched user data
    notification.data["phone_number"] ||
      notification.data["phone"] ||
      @user_data&.dig(:phone_number)
  end

  def valid_phone_number?
    # Basic validation - starts with + and has 10-15 digits
    # Or 10 digits without + (US format)
    return false unless phone_number.present?

    phone_number.match?(/^\+?\d{10,15}$/)
  end

  def send_via_twilio
    # Stub implementation
    # In production, this would use Twilio REST API:
    # client = Twilio::REST::Client.new(account_sid, auth_token)
    # client.messages.create(
    #   from: ENV['TWILIO_PHONE_NUMBER'],
    #   to: phone_number,
    #   body: notification.message
    # )

    Rails.logger.info(
      "[SmsService] SMS would be sent to=#{phone_number} " \
      "notification_id=#{notification.id}"
    )

    # Simulate success in development/test
    if Rails.env.development? || Rails.env.test?
      { success: true, provider_id: "stub_#{SecureRandom.hex(8)}" }
    else
      { success: false, error: "Twilio not configured" }
    end
  end
end
