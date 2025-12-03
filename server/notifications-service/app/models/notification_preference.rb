# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  # Validations
  validates :user_id, presence: true, uniqueness: true
  validates :email_enabled, inclusion: { in: [true, false] }
  validates :sms_enabled, inclusion: { in: [true, false] }
  validates :push_enabled, inclusion: { in: [true, false] }
  validates :appointment_reminders, inclusion: { in: [true, false] }
  validates :appointment_updates, inclusion: { in: [true, false] }
  validates :marketing_emails, inclusion: { in: [true, false] }

  # Class methods
  def self.for_user(user_id)
    find_or_create_by(user_id: user_id)
  end

  # Instance methods
  def allows_delivery_method?(method)
    case method.to_s
    when "email"
      email_enabled
    when "sms"
      sms_enabled
    when "push"
      push_enabled
    when "in_app"
      true # In-app notifications are always allowed
    else
      false
    end
  end

  def allows_notification_type?(type)
    case type.to_s
    when "appointment_created", "appointment_confirmed", "appointment_cancelled", "appointment_completed"
      appointment_updates
    when "appointment_reminder"
      appointment_reminders
    when "welcome_email", "password_reset", "payment_received"
      true # System notifications are always allowed
    when "general"
      marketing_emails
    else
      true
    end
  end

  def should_send_notification?(notification_type, delivery_method)
    allows_notification_type?(notification_type) && allows_delivery_method?(delivery_method)
  end
end
