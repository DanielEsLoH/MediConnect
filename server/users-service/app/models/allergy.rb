# frozen_string_literal: true

class Allergy < ApplicationRecord
  # Associations
  belongs_to :user

  # Enums
  enum :severity, {
    mild: "mild",
    moderate: "moderate",
    severe: "severe",
    life_threatening: "life_threatening"
  }, validate: true

  # Validations
  validates :user, presence: true
  validates :allergen, presence: true
  validates :severity, presence: true

  # Callbacks
  after_create :publish_allergy_created_event

  # Scopes
  scope :by_severity, ->(severity_level) { where(severity: severity_level) if severity_level.present? }
  scope :active_allergies, -> { where(active: true) }
  scope :critical, -> { where(severity: [:severe, :life_threatening]) }

  private

  def publish_allergy_created_event
    EventPublisher.publish("allergy.created", {
      allergy_id: id,
      user_id: user_id,
      allergen: allergen,
      severity: severity,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish allergy.created event: #{e.message}")
  end
end
