# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id                       :uuid             not null, primary key
#  user_id                  :uuid             not null
#  appointment_id           :uuid
#  amount                   :decimal(10, 2)   not null
#  currency                 :string           default("USD")
#  status                   :integer          default("pending")
#  payment_method           :integer
#  stripe_payment_intent_id :string
#  stripe_charge_id         :string
#  description              :string
#  paid_at                  :datetime
#  failure_reason           :text
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes:
#  index_payments_on_appointment_id            (appointment_id)
#  index_payments_on_created_at                (created_at)
#  index_payments_on_status                    (status)
#  index_payments_on_stripe_payment_intent_id  (stripe_payment_intent_id) UNIQUE
#  index_payments_on_user_id                   (user_id)
#  index_payments_on_user_id_and_status        (user_id, status)
#
class Payment < ApplicationRecord
  # =============================================================================
  # ENUMS
  # =============================================================================
  # Status enum represents the lifecycle of a payment
  # - pending: Payment created but not yet processed
  # - processing: Payment is being processed by Stripe
  # - completed: Payment successfully charged
  # - failed: Payment failed (see failure_reason)
  # - refunded: Full refund has been issued
  # - partially_refunded: Partial refund has been issued
  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    refunded: 4,
    partially_refunded: 5
  }, prefix: true

  # Payment method used for the transaction
  enum :payment_method, {
    credit_card: 0,
    debit_card: 1,
    wallet: 2,
    insurance: 3
  }, prefix: true

  # =============================================================================
  # VALIDATIONS
  # =============================================================================
  validates :user_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true

  # =============================================================================
  # SCOPES
  # =============================================================================
  # Retrieves all successfully completed payments
  scope :successful, -> { where(status: :completed) }

  # Retrieves all failed payments
  scope :failed, -> { where(status: :failed) }

  # Retrieves payments for a specific user
  # @param user_id [String] UUID of the user
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  # Orders payments by creation date (newest first)
  scope :recent, -> { order(created_at: :desc) }

  # Retrieves payments within a date range
  # @param start_date [Date] Start of the range
  # @param end_date [Date] End of the range
  scope :between_dates, ->(start_date, end_date) {
    where(created_at: start_date.beginning_of_day..end_date.end_of_day)
  }

  # Retrieves payments for a specific appointment
  # @param appointment_id [String] UUID of the appointment
  scope :for_appointment, ->(appointment_id) { where(appointment_id: appointment_id) }

  # Retrieves pending payments older than a specified time
  # Useful for cleanup/expiration jobs
  # @param time_ago [ActiveSupport::Duration] How old the payment should be
  scope :stale_pending, ->(time_ago = 1.hour) {
    where(status: :pending).where("created_at < ?", time_ago.ago)
  }

  # =============================================================================
  # CALLBACKS
  # =============================================================================
  after_create :publish_payment_events
  after_update :publish_payment_events, if: :saved_change_to_status?

  # =============================================================================
  # INSTANCE METHODS
  # =============================================================================

  # Marks the payment as completed and records the charge details
  # This should be called when Stripe confirms the payment succeeded
  #
  # @param charge_id [String] The Stripe charge ID
  # @return [Boolean] True if the update was successful
  # @raise [ActiveRecord::RecordInvalid] If validation fails
  def mark_as_completed!(charge_id:)
    update!(
      status: :completed,
      stripe_charge_id: charge_id,
      paid_at: Time.current
    )
  end

  # Marks the payment as failed with a reason
  # This should be called when Stripe reports a payment failure
  #
  # @param reason [String] The failure reason from Stripe
  # @return [Boolean] True if the update was successful
  # @raise [ActiveRecord::RecordInvalid] If validation fails
  def mark_as_failed!(reason:)
    update!(
      status: :failed,
      failure_reason: reason
    )
  end

  # Marks the payment as processing
  # This should be called when the payment is submitted to Stripe
  #
  # @return [Boolean] True if the update was successful
  def mark_as_processing!
    update!(status: :processing)
  end

  # Marks the payment as refunded
  #
  # @param partial [Boolean] Whether this is a partial refund
  # @return [Boolean] True if the update was successful
  def mark_as_refunded!(partial: false)
    update!(status: partial ? :partially_refunded : :refunded)
  end

  # Checks if the payment can be refunded
  #
  # @return [Boolean] True if the payment is eligible for refund
  def refundable?
    status_completed? && stripe_charge_id.present?
  end

  # Returns the amount in cents (for Stripe API)
  #
  # @return [Integer] Amount in cents
  def amount_in_cents
    (amount * 100).to_i
  end

  # Returns a human-readable description of the payment status
  #
  # @return [String] Status description
  def status_description
    case status
    when "pending"
      "Awaiting payment"
    when "processing"
      "Payment in progress"
    when "completed"
      "Payment successful"
    when "failed"
      "Payment failed: #{failure_reason || 'Unknown error'}"
    when "refunded"
      "Fully refunded"
    when "partially_refunded"
      "Partially refunded"
    else
      "Unknown status"
    end
  end

  private

  # Publishes events to the message queue when payment status changes
  # This allows other services to react to payment events
  def publish_payment_events
    event_payload = {
      payment_id: id,
      user_id: user_id,
      appointment_id: appointment_id,
      amount: amount.to_f,
      currency: currency
    }

    case status
    when "completed"
      EventPublisher.publish("payment.completed", event_payload)
    when "failed"
      EventPublisher.publish("payment.failed", event_payload.merge(reason: failure_reason))
    when "refunded", "partially_refunded"
      EventPublisher.publish("payment.refunded", event_payload.merge(partial: status == "partially_refunded"))
    end
  rescue StandardError => e
    # Log the error but don't fail the transaction
    # Payment events are important but not critical to the payment flow
    Rails.logger.error("Failed to publish payment event: #{e.message}")
  end
end
