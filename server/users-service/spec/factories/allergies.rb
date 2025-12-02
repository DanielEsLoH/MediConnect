# frozen_string_literal: true

FactoryBot.define do
  factory :allergy do
    association :user
    allergen { Faker::Food.allergen }
    severity { Allergy.severities.keys.sample }
    reaction { Faker::Lorem.sentence }
    diagnosed_at { Faker::Date.between(from: 5.years.ago, to: Date.today) }
    active { true }

    trait :mild do
      severity { :mild }
    end

    trait :moderate do
      severity { :moderate }
    end

    trait :severe do
      severity { :severe }
    end

    trait :life_threatening do
      severity { :life_threatening }
    end

    trait :inactive do
      active { false }
    end
  end
end
