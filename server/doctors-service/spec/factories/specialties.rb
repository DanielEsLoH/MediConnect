# frozen_string_literal: true

FactoryBot.define do
  factory :specialty do
    name { Faker::Medical::Medicine.medical_specialty }
    description { Faker::Lorem.paragraph }
  end
end
