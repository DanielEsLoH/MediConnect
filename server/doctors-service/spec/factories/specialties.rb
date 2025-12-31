# frozen_string_literal: true

FactoryBot.define do
  factory :specialty do
    sequence(:name) { |n| "Specialty #{n}" }
    description { Faker::Lorem.paragraph }
  end
end
