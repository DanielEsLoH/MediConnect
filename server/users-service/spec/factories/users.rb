# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "Password123" }
    password_confirmation { "Password123" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 90) }
    gender { %w[male female other].sample }
    phone_number { Faker::PhoneNumber.phone_number }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    zip_code { Faker::Address.zip_code }
    emergency_contact_name { Faker::Name.name }
    emergency_contact_phone { Faker::PhoneNumber.phone_number }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :with_medical_records do
      after(:create) do |user|
        create_list(:medical_record, 3, user: user)
      end
    end

    trait :with_allergies do
      after(:create) do |user|
        create_list(:allergy, 2, user: user)
      end
    end
  end
end
