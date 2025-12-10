# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :medical_records, dependent: :destroy
  has_many :allergies, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :phone_number, format: { with: /\A\+?[\d\s\-()]+\z/, allow_blank: true }

  # Callbacks
  before_save :normalize_email
  after_create :publish_user_created_event
  after_update :publish_user_updated_event
  after_destroy :publish_user_deleted_event

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_email, ->(email) { where(email: email.downcase) if email.present? }
  scope :search_by_name, lambda { |query|
    where("LOWER(first_name) LIKE :query OR LOWER(last_name) LIKE :query",
          query: "%#{query.downcase}%")
  }
  scope :search_by_phone, ->(phone) { where("phone_number LIKE ?", "%#{phone}%") if phone.present? }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def age
    return nil unless date_of_birth

    now = Time.zone.today
    now.year - date_of_birth.year - (now.month > date_of_birth.month || (now.month == date_of_birth.month && now.day >= date_of_birth.day) ? 0 : 1)
  end

  def as_json(options = {})
    super(options.merge(except: [ :password_digest ]))
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def password_required?
    password_digest.nil? || password.present?
  end

  def publish_user_created_event
    EventPublisher.publish("user.created", {
      user_id: id,
      email: email,
      full_name: full_name,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish user.created event: #{e.message}")
  end

  def publish_user_updated_event
    EventPublisher.publish("user.updated", {
      user_id: id,
      email: email,
      full_name: full_name,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish user.updated event: #{e.message}")
  end

  def publish_user_deleted_event
    EventPublisher.publish("user.deleted", {
      user_id: id,
      email: email,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    Rails.logger.error("Failed to publish user.deleted event: #{e.message}")
  end
end
