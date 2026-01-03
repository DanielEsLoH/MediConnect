# frozen_string_literal: true

class Doctor < ApplicationRecord
  include PgSearch::Model

  # Associations
  belongs_to :specialty
  belongs_to :clinic
  has_many :schedules, dependent: :destroy
  has_many :reviews, dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :license_number, presence: true, uniqueness: true
  validates :phone_number, format: { with: /\A\+?[\d\s\-()]+\z/, allow_blank: true }
  validates :years_of_experience, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :consultation_fee, numericality: { greater_than: 0 }, allow_nil: true

  # PgSearch configuration
  pg_search_scope :search_by_text,
                  against: [ :first_name, :last_name, :bio ],
                  associated_against: {
                    specialty: :name,
                    clinic: [ :name, :city, :state ]
                  },
                  using: {
                    tsearch: { prefix: true, any_word: true }
                  }

  # Callbacks
  after_create :publish_doctor_created_event
  after_update :publish_doctor_updated_event
  before_validation :normalize_email

  # Scopes
  scope :active, -> { where(active: true) }
  scope :accepting_patients, -> { where(accepting_new_patients: true) }
  scope :by_specialty, ->(specialty_id) { where(specialty_id: specialty_id) if specialty_id.present? }
  scope :by_clinic, ->(clinic_id) { where(clinic_id: clinic_id) if clinic_id.present? }
  scope :by_language, lambda { |language|
    where("languages @> ?", [ language ].to_json) if language.present?
  }
  scope :with_min_rating, lambda { |min_rating|
    joins(:reviews)
      .group("doctors.id")
      .having("AVG(reviews.rating) >= ?", min_rating)
  }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def average_rating
    reviews.average(:rating)&.to_f&.round(2) || 0.0
  end

  def total_reviews
    reviews.count
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def publish_doctor_created_event
    EventPublisher.publish("doctor.created", {
      doctor_id: id,
      specialty_id: specialty_id,
      clinic_id: clinic_id,
      full_name: full_name,
      email: email,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish doctor.created event: #{e.message}")
  end

  def publish_doctor_updated_event
    EventPublisher.publish("doctor.updated", {
      doctor_id: id,
      full_name: full_name,
      accepting_new_patients: accepting_new_patients,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish doctor.updated event: #{e.message}")
  end
end
