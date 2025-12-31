# frozen_string_literal: true

FactoryBot.define do
  factory :doctor do
    association :specialty
    association :clinic
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    phone_number { "+1-555-#{rand(100..999)}-#{rand(1000..9999)}" }
    license_number { Faker::Alphanumeric.unique.alphanumeric(number: 10).upcase }
    bio { Faker::Lorem.paragraph(sentence_count: 3) }
    years_of_experience { rand(1..40) }
    languages { %w[English Spanish] }
    consultation_fee { rand(50.0..300.0).round(2) }
    accepting_new_patients { true }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :not_accepting_patients do
      accepting_new_patients { false }
    end

    trait :with_schedules do
      after(:create) do |doctor|
        create_list(:schedule, 5, doctor: doctor)
      end
    end

    trait :with_reviews do
      after(:create) do |doctor|
        create_list(:review, 5, doctor: doctor)
      end
    end
  end
end
