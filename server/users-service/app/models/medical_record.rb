# frozen_string_literal: true

class MedicalRecord < ApplicationRecord
  # Associations
  belongs_to :user

  # Enums
  enum :record_type, {
    diagnosis: "diagnosis",
    prescription: "prescription",
    lab_result: "lab_result",
    imaging: "imaging",
    vaccination: "vaccination",
    surgery: "surgery",
    other: "other"
  }, validate: true

  # Validations
  validates :user, presence: true
  validates :record_type, presence: true
  validates :title, presence: true
  validates :recorded_at, presence: true

  # Callbacks
  after_create :publish_medical_record_created_event

  # Scopes
  scope :recent, -> { order(recorded_at: :desc) }
  scope :by_type, ->(type) { where(record_type: type) if type.present? }
  scope :for_date_range, lambda { |start_date, end_date|
    where(recorded_at: start_date..end_date) if start_date.present? && end_date.present?
  }

  private

  def publish_medical_record_created_event
    EventPublisher.publish("medical_record.created", {
      medical_record_id: id,
      user_id: user_id,
      record_type: record_type,
      title: title,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish medical_record.created event: #{e.message}")
  end
end
