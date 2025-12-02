# frozen_string_literal: true

class Clinic < ApplicationRecord
  # Associations
  has_many :doctors, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :phone_number, format: { with: /\A\+?[\d\s\-()]+\z/, allow_blank: true }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_city, ->(city) { where(city: city) if city.present? }
  scope :by_state, ->(state) { where(state: state) if state.present? }
  scope :search_by_name, lambda { |query|
    where("LOWER(name) LIKE ?", "%#{query.downcase}%") if query.present?
  }

  # Instance methods
  def full_address
    [address, city, state, zip_code].compact.join(", ")
  end
end
