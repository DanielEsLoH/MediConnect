# frozen_string_literal: true

class Notification < ApplicationRecord
  # Enums
  enum :notification_type, {
    appointment_created: "appointment_created",
    appointment_confirmed: "appointment_confirmed",
    appointment_reminder: "appointment_reminder",
    appointment_cancelled: "appointment_cancelled",
    appointment_completed: "appointment_completed",
    welcome_email: "welcome_email",
    password_reset: "password_reset",
    payment_received: "payment_received",
    general: "general"
  }, validate: true

  enum :delivery_method, {
    email: "email",
    sms: "sms",
    push: "push",
    in_app: "in_app"
  }, validate: true

  enum :status, {
    pending: "pending",
    sent: "sent",
    delivered: "delivered",
    failed: "failed",
    read: "read"
  }, validate: true

  # Validations
  validates :user_id, presence: true
  validates :notification_type, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :message, presence: true
  validates :delivery_method, presence: true
  validates :status, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }

  validate :scheduled_for_must_be_in_future, on: :create

  # Callbacks
  after_create :enqueue_for_delivery, if: -> { pending? && scheduled_for.blank? }
  after_update :retry_if_failed, if: -> { saved_change_to_status? && failed? && can_retry? }

  # Scopes
  scope :for_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :by_type, ->(type) { where(notification_type: type) if type.present? }
  scope :by_delivery_method, ->(method) { where(delivery_method: method) if method.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :unread, -> { where(read_at: nil).where.not(status: :failed) }
  scope :read_notifications, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_priority, -> { where("priority >= ?", 5) }
  scope :low_priority, -> { where("priority < ?", 5) }
  scope :scheduled, -> { where.not(scheduled_for: nil).where("scheduled_for > ?", Time.current) }
  scope :ready_for_delivery, -> { pending.where("scheduled_for IS NULL OR scheduled_for <= ?", Time.current) }
  scope :failed_retryable, -> { failed.where("retry_count < ?", 3) }
  scope :old_notifications, -> { where("created_at < ?", 90.days.ago) }

  # Instance methods
  def mark_as_read!
    return false if read?

    update(read_at: Time.current, status: :read)
  end

  def mark_as_sent!
    update(status: :sent, sent_at: Time.current)
  end

  def mark_as_delivered!
    update(status: :delivered, delivered_at: Time.current)
  end

  def mark_as_failed!(error_message)
    update(
      status: :failed,
      error_message: error_message,
      retry_count: retry_count + 1
    )
  end

  def can_retry?
    retry_count < 3
  end

  def retry_delay
    # Exponential backoff: 5 minutes, 15 minutes, 45 minutes
    (5 * (3**retry_count)).minutes
  end

  def unread?
    read_at.nil? && !failed?
  end

  def should_send?
    pending? && (scheduled_for.nil? || scheduled_for <= Time.current)
  end

  def as_json(options = {})
    super(options.merge(
      methods: [ :unread? ],
      except: [ :error_message ]
    ))
  end

  private

  def scheduled_for_must_be_in_future
    return unless scheduled_for.present?

    if scheduled_for <= Time.current
      errors.add(:scheduled_for, "must be in the future")
    end
  end

  def enqueue_for_delivery
    SendNotificationJob.perform_later(id)
  end

  def retry_if_failed
    return unless can_retry?

    SendNotificationJob.set(wait: retry_delay).perform_later(id)
    Rails.logger.info("Scheduled retry #{retry_count} for notification #{id} in #{retry_delay.inspect}")
  end
end
