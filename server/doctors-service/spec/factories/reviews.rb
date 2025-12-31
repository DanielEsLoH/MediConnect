# frozen_string_literal: true

FactoryBot.define do
  factory :review do
    association :doctor
    user_id { SecureRandom.uuid }
    rating { rand(1..5) }
    comment { Faker::Lorem.paragraph }
    verified { false }

    trait :verified do
      verified { true }
    end

    trait :high_rated do
      rating { rand(4..5) }
    end

    trait :low_rated do
      rating { rand(1..2) }
    end
  end
end
