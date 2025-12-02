# frozen_string_literal: true

FactoryBot.define do
  factory :clinic do
    name { Faker::Company.name + " Medical Center" }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }
    phone_number { Faker::PhoneNumber.phone_number }
    operating_hours do
      {
        monday: "09:00-17:00",
        tuesday: "09:00-17:00",
        wednesday: "09:00-17:00",
        thursday: "09:00-17:00",
        friday: "09:00-17:00"
      }
    end
    active { true }

    trait :inactive do
      active { false }
    end
  end
end
