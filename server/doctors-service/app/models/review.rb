# frozen_string_literal: true

class Review < ApplicationRecord
  # Associations
  belongs_to :doctor

  # Validations
  validates :doctor, presence: true
  validates :user_id, presence: true
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :user_id, uniqueness: { scope: :doctor_id, message: "has already reviewed this doctor" }

  # Callbacks
  after_create :publish_review_created_event
  after_create :update_doctor_cache

  # Scopes
  scope :verified_reviews, -> { where(verified: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_rating, ->(rating) { where(rating: rating) if rating.present? }
  scope :high_rated, -> { where("rating >= ?", 4) }

  private

  def publish_review_created_event
    EventPublisher.publish("review.created", {
      review_id: id,
      doctor_id: doctor_id,
      user_id: user_id,
      rating: rating,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish review.created event: #{e.message}")
  end

  def update_doctor_cache
    # Update cached rating count/average - could be done with Redis
    Rails.logger.info("Review created for doctor #{doctor_id}, new average: #{doctor.average_rating}")
  end
end
