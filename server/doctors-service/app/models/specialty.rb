# frozen_string_literal: true

class Specialty < ApplicationRecord
  # Associations
  has_many :doctors, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, uniqueness: true

  # Scopes
  scope :with_doctors, -> { joins(:doctors).distinct }
  scope :by_name, ->(name) { where("LOWER(name) LIKE ?", "%#{name.downcase}%") if name.present? }

  # Instance methods
  def doctors_count
    doctors.active.count
  end
end
