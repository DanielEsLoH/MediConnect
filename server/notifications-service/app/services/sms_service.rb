# frozen_string_literal: true

class SmsService
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def send_sms
    # Validate phone number
    return { success: false, error: "No phone number provided" } unless phone_number.present?
    return { success: false, error: "Invalid phone number format" } unless valid_phone_number?

    # In production, this would integrate with Twilio
    # For now, we'll stub the implementation
    send_via_twilio
  rescue StandardError => e
    Rails.logger.error("SMS send error for notification #{notification.id}: #{e.message}")
    { success: false, error: e.message }
  end

  private

  def phone_number
    notification.data["phone_number"] || notification.data["phone"]
  end

  def valid_phone_number?
    # Basic validation - starts with + and has 10-15 digits
    phone_number.match?(/^\+\d{10,15}$/)
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

    Rails.logger.info("SMS would be sent to #{phone_number}: #{notification.message}")

    # Simulate success in development/test
    if Rails.env.development? || Rails.env.test?
      { success: true, provider_id: "stub_#{SecureRandom.hex(8)}" }
    else
      { success: false, error: "Twilio not configured" }
    end
  end
end
